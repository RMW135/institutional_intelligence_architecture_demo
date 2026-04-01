from __future__ import annotations
import json
import os
from dotenv import load_dotenv
load_dotenv()
import re
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

@dataclass
class ExtractedRequest:
    actor: str
    action: str
    resource: Optional[str]
    amount: float
    original_phrase: str
    resource_type: str = ""
    notes: str = ""

@dataclass
class OntologyAbsence:
    """A classified structural gap detected when the graph audits LLM output.

    Three types (aligned with DriftHypothesis taxonomy in meta-ontology):
      OntologyGap            — expected node does not exist in the graph at all
      RelationshipMisdrawn   — node exists but a required edge is missing
      EntityReclassification — node and edges exist but type/classification is wrong
    """
    type: str       # "OntologyGap" | "RelationshipMisdrawn" | "EntityReclassification"
    layer: str      # pipeline layer that detected it
    expected: str   # what the LLM/pipeline expected to find
    found: str      # what was actually there (or "absent")
    detail: str     # human-readable explanation

SAMPLE_PROMPTS = [
    "Can John sign off on the ACME invoice for $120,000?",
    "Can Maria approve the ACME invoice for $120,000?",
    "Can John push this contract through today?",
    "Can Sarah see employee file E77?",
    "Can Emily greenlight the BoltWorks invoice for $40,000?",
    "Can Emily buy a coffee pot for $15,000?",
]

PERSON_ALIASES = {
    "john": "John Smith",
    "maria": "Maria Chen",
    "sarah": "Sarah Lee",
    "david": "David Brown",
    "emily": "Emily Stone",
    "john smith": "John Smith",
    "maria chen": "Maria Chen",
    "sarah lee": "Sarah Lee",
    "david brown": "David Brown",
    "emily stone": "Emily Stone",
}

PHRASE_TO_ACTION = {
    "sign off": "ApprovePayment",
    "greenlight": "ApprovePayment",
    "approve": "ApprovePayment",
    "push this through": "ApproveContract",
    "contract through": "ApproveContract",
    "take care of": "ReviewContract",
    "see employee file": "ViewEmployeeRecord",
    "view employee record": "ViewEmployeeRecord",
    "view employee file": "ViewEmployeeRecord",
    "terminate": "TerminateEmployee",
}

RESOURCE_HINTS = [
    (re.compile(r"invoice\s*(?:#)?\s*a113", re.I), "Invoice_A113"),
    (re.compile(r"acme.*invoice|invoice.*acme", re.I), "Invoice_A113"),
    (re.compile(r"boltworks.*invoice|invoice.*boltworks", re.I), "Invoice_B210"),
    (re.compile(r"contract\s*(?:#)?\s*c201", re.I), "Contract_C201"),
    (re.compile(r"contract", re.I), "Contract_C201"),
    (re.compile(r"employee\s*(?:record|file)\s*e77", re.I), "EmployeeRecord_E77"),
    (re.compile(r"employee\s*(?:record|file)", re.I), "EmployeeRecord_E77"),
]

# ─── NEO4J ────────────────────────────────────────────────────────────────────
def _lazy_import_neo4j():
    from neo4j import GraphDatabase  # type: ignore
    return GraphDatabase

def get_driver() -> Optional[Any]:
    uri = os.getenv("NEO4J_URI")
    user = os.getenv("NEO4J_USER")
    password = os.getenv("NEO4J_PASSWORD")
    if not (uri and user and password):
        return None
    try:
        GraphDatabase = _lazy_import_neo4j()
        driver = GraphDatabase.driver(uri, auth=(user, password))
        driver.verify_connectivity()
        return driver
    except Exception:
        return None

def run_query(cypher: str, params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    driver = get_driver()
    if not driver:
        return []
    with driver.session() as session:
        result = session.run(cypher, params or {})
        return [dict(r) for r in result]

# ─── EXTRACTION ───────────────────────────────────────────────────────────────
def _find_person(text: str) -> str:
    lower = text.lower()
    for key, value in PERSON_ALIASES.items():
        if re.search(rf"\b{re.escape(key)}\b", lower):
            return value
    return "John Smith"

def _find_phrase(text: str) -> Tuple[str, str]:
    lower = text.lower()
    for phrase, action in PHRASE_TO_ACTION.items():
        if phrase in lower:
            return phrase, action
    if "approve" in lower and "contract" in lower:
        return "approve", "ApproveContract"
    return "approve", "ApprovePayment"

def _find_resource(text: str) -> Optional[str]:
    for pattern, resource in RESOURCE_HINTS:
        if pattern.search(text):
            return resource
    return None

def _get_actor_role_only(actor: str) -> Optional[str]:
    rows = run_query(
        """
        MATCH (p:Person {name: $actor})
        OPTIONAL MATCH (p)-[:HAS_ROLE]->(r:Role)
        RETURN r.name AS role
        """,
        {"actor": actor},
    )
    return rows[0].get("role") if rows else None

def _extract_amount(text: str) -> float:
    m = re.search(r"\$?\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+(?:\.[0-9]+)?)", text)
    if not m:
        return 0.0
    return float(m.group(1).replace(",", ""))

def extract_request_rule_based(text: str) -> ExtractedRequest:
    actor = _find_person(text)
    phrase, action = _find_phrase(text)
    resource = _find_resource(text)
    amount = _extract_amount(text)

    # Only backfill amount when we actually matched a known resource
    if resource == "Invoice_A113" and amount == 0:
        amount = 120000
    elif resource == "Invoice_B210" and amount == 0:
        amount = 40000
    elif resource == "Contract_C201" and amount == 0:
        amount = 80000

    resource_type = ""
    if resource:
        if resource.startswith("Invoice"):
            resource_type = "Invoice"
        elif resource.startswith("Contract"):
            resource_type = "VendorContract"
        elif resource.startswith("EmployeeRecord"):
            resource_type = "EmployeeRecord"

    return ExtractedRequest(
        actor=actor,
        action=action,
        resource=resource,
        amount=amount,
        original_phrase=phrase,
        resource_type=resource_type,
        notes=(
            "Rule-based fallback extraction"
            if resource is not None
            else "Rule-based fallback extraction; resource could not be grounded to a known canonical resource"
        ),
    )

def extract_request_claude(text: str, errors: List[str]) -> Optional[ExtractedRequest]:
    """Extract using Anthropic Claude API via tool use for structured output."""
    try:
        import anthropic  # type: ignore

        client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
        tools = [{
            "name": "extract_institutional_request",
            "description": "Extract a structured institutional authorization request from natural language.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "actor": {
                        "type": "string",
                        "description": "Full name of the person making the request. Map to canonical names: John Smith, Maria Chen, Sarah Lee, David Brown, Emily Stone.",
                    },
                    "action": {
                        "type": "string",
                        "enum": ["ApprovePayment", "ApproveContract", "ReviewContract", "ViewEmployeeRecord", "TerminateEmployee"],
                        "description": "Canonical institutional action. Map 'sign off'/'greenlight'/'approve' to ApprovePayment, 'push through'/'contract through' to ApproveContract.",
                    },
                    "resource": {
                        "type": ["string", "null"],
                        "enum": ["Invoice_A113", "Invoice_B210", "Contract_C201", "EmployeeRecord_E77", None],
                        "description": (
                            "Canonical resource ID when clearly identifiable. "
                            "Use null if the request refers to a resource not present in the known canonical set "
                            "or if the resource cannot be grounded with confidence."
                        ),
                    },
                    "amount": {
                        "type": "number",
                        "description": "Dollar amount if present, else 0.",
                    },
                    "original_phrase": {
                        "type": "string",
                        "description": "The exact ambiguous verb phrase used (e.g. 'sign off', 'greenlight', 'push through').",
                    },
                    "resource_type": {
                        "type": "string",
                        "description": "Invoice, VendorContract, EmployeeRecord, or empty string if unknown.",
                    },
                    "notes": {
                        "type": "string",
                        "description": "Any extraction notes or ambiguities.",
                    },
                },
                "required": ["actor", "action", "resource", "amount", "original_phrase"],
            },
        }]

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=512,
            system=(
                "You are an enterprise AI extraction engine. Extract structured institutional "
                "authorization requests from natural language. Always use the tool. "
                "Be precise about mapping vague language to canonical actions. "
                "Do not invent or coerce a resource into a known canonical resource if the text "
                "describes something else; use null for resource in that case."
            ),
            messages=[{"role": "user", "content": text}],
            tools=tools,
            tool_choice={"type": "tool", "name": "extract_institutional_request"},
        )

        for block in response.content:
            if block.type == "tool_use" and block.name == "extract_institutional_request":
                data = block.input
                return ExtractedRequest(
                    actor=data.get("actor", "John Smith"),
                    action=data.get("action", "ApprovePayment"),
                    resource=data.get("resource"),
                    amount=float(data.get("amount", 0)),
                    original_phrase=data.get("original_phrase", ""),
                    resource_type=data.get("resource_type", ""),
                    notes=data.get("notes", "Extracted by Claude"),
                )
    except Exception as e:
        errors.append(f"Claude extraction failed: {type(e).__name__}: {e}")
    return None

def extract_request_openai(text: str, errors: List[str]) -> Optional[ExtractedRequest]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        from openai import OpenAI  # type: ignore

        client = OpenAI(api_key=api_key)
        schema = {
            "name": "institutional_request",
            "schema": {
                "type": "object",
                "properties": {
                    "actor": {"type": "string"},
                    "action": {"type": "string"},
                    "resource": {"type": ["string", "null"]},
                    "amount": {"type": "number"},
                    "original_phrase": {"type": "string"},
                    "resource_type": {"type": "string"},
                    "notes": {"type": "string"},
                },
                "required": ["actor", "action", "resource", "amount", "original_phrase", "resource_type", "notes"],
                "additionalProperties": False,
            },
            "strict": True,
        }

        prompt = (
            "Extract a canonical institutional request from the user's text. "
            "Use only these canonical actors when present: John Smith, Maria Chen, Sarah Lee, David Brown, Emily Stone. "
            "Use only these canonical actions when possible: ApprovePayment, ApproveContract, ReviewContract, ViewEmployeeRecord, TerminateEmployee. "
            "Use only these resources when they are explicitly identifiable: Invoice_A113, Invoice_B210, Contract_C201, EmployeeRecord_E77. "
            "If the request refers to some other thing not in that set, set resource to null. "
            "Do not coerce unknown resources to a known invoice or contract. "
            "Map vague phrases like 'sign off' and 'greenlight' to ApprovePayment, "
            "'push this through'/'contract through' to ApproveContract. "
            f"User text: {text}"
        )

        resp = client.responses.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4.1-mini"),
            input=prompt,
            text={"format": {"type": "json_schema", "name": schema["name"], "schema": schema["schema"]}},
        )
        raw = getattr(resp, "output_text", "")
        if not raw:
            errors.append("OpenAI extraction failed: response returned empty output_text")
            return None

        data = json.loads(raw)
        return ExtractedRequest(**data)
    except Exception as e:
        errors.append(f"OpenAI extraction failed: {type(e).__name__}: {e}")
        return None

def extract_request(text: str) -> Tuple[ExtractedRequest, str, List[str]]:
    """Priority: Claude → OpenAI → Rule-based fallback.
    If an LLM returns a partial extraction with resource=None, use the rule-based
    extractor as a conservative recovery pass for clearly matchable resources.
    """
    errors: List[str] = []
    rule_based = extract_request_rule_based(text)

    if os.getenv("ANTHROPIC_API_KEY"):
        result = extract_request_claude(text, errors)
        if result:
            if result.resource is None and rule_based.resource is not None:
                result.resource = rule_based.resource
                result.resource_type = rule_based.resource_type
                if not result.notes:
                    result.notes = "Extracted by Claude"
                result.notes += " | resource recovered from deterministic rule-based matcher"
            return result, "Claude (Anthropic)", errors

    if os.getenv("OPENAI_API_KEY"):
        result = extract_request_openai(text, errors)
        if result:
            if result.resource is None and rule_based.resource is not None:
                result.resource = rule_based.resource
                result.resource_type = rule_based.resource_type
                if not result.notes:
                    result.notes = "Extracted by OpenAI"
                result.notes += " | resource recovered from deterministic rule-based matcher"
            return result, "OpenAI", errors

    return rule_based, "Fallback (rule-based)", errors

# ─── PROMPT-BASED LLM COMPARISON ─────────────────────────────────────────────
# This is the pattern most enterprises actually deploy: give the LLM the full
# organizational context as prompt text, then ask it to reason about the decision.
# The point is that even with perfect information, the output is prose — hedged,
# unenforceable, non-auditable, and inconsistent across runs.

CONTEXT_LOADED_SYSTEM = """You are an enterprise operations assistant for Apex Manufacturing.
You have access to the following organizational information:

ORGANIZATIONAL STRUCTURE:
- John Smith: Manager, Finance Department. Approval limit: $50,000.
- Maria Chen: Finance Director, Finance Department. Approval limit: unlimited.
- Sarah Lee: Procurement Manager, Procurement Department. Approval limit: $50,000.
- David Brown: HR Director, HR Department. Full HR record access.
- Emily Stone: Budget Manager, Finance Department. Approval limit: $100,000.

POLICIES:
- HighValuePaymentPolicy: Payments above $100,000 require Finance Director approval.
- ContractApprovalPolicy: Contracts above $50,000 require Procurement Manager approval.
- HRAccessPolicy: Confidential employee records require HR Director access only.

RESOURCES:
- Invoice A113 (ACME Supplies): $120,000, standard classification, Finance dept.
- Invoice B210 (BoltWorks): $40,000, standard classification, Finance dept.
- Contract C201 (ACME Vendor Contract): $80,000, commercial classification, Procurement dept.
- Employee Record E77: confidential classification, HR dept.

Based on this information, decide whether the following request should be APPROVED, ESCALATED, or DENIED. Provide your reasoning."""


def raw_llm_decision(text: str) -> Dict[str, Any]:
    """Send the request to an LLM with full organizational context provided as
    prompt text — the exact deployment pattern most enterprises use. The LLM has
    all the information it needs. The question is whether its output is structured,
    enforceable, traceable, and consistent — or whether it's prose."""

    # Try Claude
    if os.getenv("ANTHROPIC_API_KEY"):
        try:
            import anthropic  # type: ignore
            client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=400,
                system=CONTEXT_LOADED_SYSTEM,
                messages=[{"role": "user", "content": text}],
            )
            answer = response.content[0].text if response.content else ""
            return {
                "provider": "Claude (Anthropic)",
                "response": answer,
                "grounded": False,
                "note": (
                    "The LLM was given the full org chart, all policies, and all thresholds "
                    "as prompt text — the same pattern most enterprises deploy. "
                    "The output is prose: linguistically reasonable but not machine-checkable, "
                    "not auditable, and not guaranteed to be consistent across runs."
                ),
            }
        except Exception:
            pass  # fall through to OpenAI

    # Try OpenAI
    if os.getenv("OPENAI_API_KEY"):
        try:
            from openai import OpenAI  # type: ignore
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            resp = client.responses.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4.1-mini"),
                instructions=CONTEXT_LOADED_SYSTEM,
                input=text,
            )
            answer = getattr(resp, "output_text", "")
            return {
                "provider": "OpenAI",
                "response": answer,
                "grounded": False,
                "note": (
                    "The LLM was given the full org chart, all policies, and all thresholds "
                    "as prompt text — the same pattern most enterprises deploy. "
                    "The output is prose: linguistically reasonable but not machine-checkable, "
                    "not auditable, and not guaranteed to be consistent across runs."
                ),
            }
        except Exception:
            pass

    # No LLM available
    return {
        "provider": "None (no API key configured)",
        "response": (
            "Without an LLM API key, this comparison cannot be generated. "
            "Configure ANTHROPIC_API_KEY or OPENAI_API_KEY to see what a "
            "context-loaded LLM produces for this request."
        ),
        "grounded": False,
        "note": "No LLM available for comparison.",
    }


# ─── CYPHER QUERIES ───────────────────────────────────────────────────────────
Q_PERSON_EXISTS = """
MATCH (p:Person {name: $actor})
RETURN p.name AS name
"""

Q_RESOURCE_EXISTS = """
MATCH (r:Resource {resource_id: $resource})
RETURN r.resource_id AS resource_id
"""

Q_OPERATIONAL = """
MATCH (p:Person {name: $actor})
OPTIONAL MATCH (p)-[:HAS_ROLE]->(r:Role)
OPTIONAL MATCH (p)-[:IN_DEPARTMENT]->(d:Department)
OPTIONAL MATCH (res:Resource {resource_id: $resource})-[:OWNED_BY]->(owner:Department)
RETURN p.name AS actor,
       r.name AS role,
       d.name AS actor_department,
       res.resource_id AS resource,
       res.amount AS amount,
       res.classification AS classification,
       owner.name AS resource_department
"""

Q_ALIAS = """
MATCH (a:Alias {phrase: $phrase})-[:MAPS_TO]->(c:Concept)
OPTIONAL MATCH path = (c)-[:SUBCLASS_OF*0..3]->(root:Concept)
RETURN a.phrase AS phrase,
       c.name AS mapped_concept,
       [n IN nodes(path) | n.name] AS hierarchy
"""

Q_ROLE = """
MATCH (r:Role {name: $role})-[:INSTANCE_OF]->(c:Concept)
OPTIONAL MATCH path = (c)-[:SUBCLASS_OF*0..3]->(root:Concept)
RETURN r.name AS role,
       c.name AS concept,
       [n IN nodes(path) | n.name] AS hierarchy
"""

Q_INTERPRET = """
MATCH (a:Alias {phrase: $phrase})-[:MAPS_TO]->(c:Concept)
OPTIONAL MATCH (act:Action)-[:INSTANCE_OF]->(c)
RETURN a.phrase AS original_phrase,
       c.name AS canonical_concept,
       collect(act.name) AS candidate_actions
"""

Q_POLICY = """
MATCH (p:Person {name: $actor})-[:HAS_ROLE]->(r:Role)
MATCH (a:Action {name: $action})
MATCH (res:Resource {resource_id: $resource})
OPTIONAL MATCH (pol:Policy)-[:GOVERNS]->(a)
OPTIONAL MATCH (pol)-[:HAS_CONSTRAINT]->(c:Constraint)
OPTIONAL MATCH (pol)-[:APPLIES_TO]->(required_role:Role)
RETURN p.name AS actor,
       r.name AS actor_role,
       a.name AS action,
       res.resource_id AS resource,
       res.amount AS resource_amount,
       res.classification AS classification,
       pol.name AS policy,
       c.type AS constraint_type,
       c.operator AS operator,
       c.value AS threshold,
       c.unit AS unit,
       required_role.name AS required_role
"""

Q_DECISIONS = """
MATCH (d:Decision)-[:RESULTED_IN]->(o:Outcome)
OPTIONAL MATCH (d)-[:TRIGGERED_POLICY]->(p:Policy)
RETURN d.decision_id AS decision_id,
       d.timestamp AS timestamp,
       d.status AS status,
       d.reason AS reason,
       o.name AS outcome,
       p.name AS policy
ORDER BY d.timestamp DESC
LIMIT 20
"""

Q_LEARNING = """
MATCH (l:LearningEvent)
OPTIONAL MATCH (l)-[:DERIVED_FROM]->(d:Decision)
OPTIONAL MATCH (l)-[:SUGGESTS_CHANGE_TO]->(p:Policy)
RETURN l.event_id AS event_id,
       l.name AS learning_event,
       l.count AS count,
       l.pattern_type AS pattern_type,
       l.recommendation AS recommendation,
       collect(DISTINCT d.decision_id) AS supporting_decisions,
       collect(DISTINCT p.name) AS suggested_policy_targets
"""

Q_GRAPH_SUBGRAPH = """
MATCH (p:Person {name: $actor})-[:HAS_ROLE]->(r:Role)
OPTIONAL MATCH (p)-[:IN_DEPARTMENT]->(d:Department)
OPTIONAL MATCH (pol:Policy)-[:GOVERNS]->(a:Action {name: $action})
OPTIONAL MATCH (pol)-[:APPLIES_TO]->(req_role:Role)
OPTIONAL MATCH (pol)-[:HAS_CONSTRAINT]->(c:Constraint)
OPTIONAL MATCH (res:Resource {resource_id: $resource})-[:OWNED_BY]->(owner:Department)
RETURN
    p.name AS person_name,
    r.name AS role_name,
    d.name AS dept_name,
    pol.name AS policy_name,
    a.name AS action_name,
    req_role.name AS required_role,
    c.type AS constraint_type,
    c.value AS constraint_value,
    res.resource_id AS resource_id,
    res.amount AS resource_amount,
    owner.name AS resource_dept
"""

# ─── PIPELINE STAGES ──────────────────────────────────────────────────────────
def get_operational_context(extracted: ExtractedRequest, absences: List[OntologyAbsence]) -> Dict[str, Any]:
    # Handle unknown resource explicitly before querying by resource_id
    if not extracted.resource:
        person_exists = bool(run_query(Q_PERSON_EXISTS, {"actor": extracted.actor}))
        if not person_exists:
            absences.append(OntologyAbsence(
                type="OntologyGap",
                layer="Operational Data",
                expected=f"Person node '{extracted.actor}'",
                found="absent",
                detail=f"The LLM identified '{extracted.actor}' as an institutional actor but no Person node with this name exists in the knowledge graph.",
            ))

        absences.append(OntologyAbsence(
            type="OntologyGap",
            layer="Operational Data",
            expected="Known canonical resource node",
            found="absent",
            detail=(
                "The request refers to a resource that could not be grounded to any known Resource node "
                "in the graph. The system should not substitute a different resource."
            ),
        ))

        return {
            "actor": extracted.actor,
            "resource": None,
            "status": "under-specified",
            "role": _get_actor_role_only(extracted.actor) if person_exists else None,
            "amount": extracted.amount,
            "classification": None,
        }

    rows = run_query(Q_OPERATIONAL, {"actor": extracted.actor, "resource": extracted.resource})
    if rows:
        row = rows[0]
        row["status"] = "ok" if row.get("role") and row.get("resource") else "under-specified"

        if not row.get("role"):
            absences.append(OntologyAbsence(
                type="RelationshipMisdrawn",
                layer="Operational Data",
                expected=f"Person '{extracted.actor}' → :HAS_ROLE → Role",
                found="Person node exists but has no role assignment",
                detail=f"The actor '{extracted.actor}' exists in the graph but has no :HAS_ROLE relationship. The LLM assumed this person has institutional authority; the graph cannot confirm it.",
            ))
        if not row.get("resource"):
            absences.append(OntologyAbsence(
                type="OntologyGap",
                layer="Operational Data",
                expected=f"Resource node '{extracted.resource}'",
                found="absent",
                detail=f"The LLM extracted resource '{extracted.resource}' but no matching Resource node exists in the graph.",
            ))
        return row

    person_exists = bool(run_query(Q_PERSON_EXISTS, {"actor": extracted.actor}))
    resource_exists = bool(run_query(Q_RESOURCE_EXISTS, {"resource": extracted.resource}))

    if not person_exists:
        absences.append(OntologyAbsence(
            type="OntologyGap",
            layer="Operational Data",
            expected=f"Person node '{extracted.actor}'",
            found="absent",
            detail=f"The LLM identified '{extracted.actor}' as an institutional actor but no Person node with this name exists in the knowledge graph.",
        ))
    if not resource_exists:
        absences.append(OntologyAbsence(
            type="OntologyGap",
            layer="Operational Data",
            expected=f"Resource node '{extracted.resource}'",
            found="absent",
            detail=f"The LLM extracted resource '{extracted.resource}' but no matching Resource node exists in the graph.",
        ))

    return {
        "actor": extracted.actor,
        "resource": extracted.resource,
        "status": "under-specified",
        "role": None,
        "amount": extracted.amount,
        "classification": None,
    }


def get_ontology_mapping(extracted: ExtractedRequest, operational: Dict[str, Any], absences: List[OntologyAbsence]) -> Dict[str, Any]:
    alias_rows = run_query(Q_ALIAS, {"phrase": extracted.original_phrase})
    role_rows = []
    if operational.get("role"):
        role_rows = run_query(Q_ROLE, {"role": operational["role"]})

    phrase_mapping = alias_rows[0] if alias_rows else {
        "phrase": extracted.original_phrase,
        "mapped_concept": "No direct ontology match",
        "hierarchy": [],
    }
    role_mapping = role_rows[0] if role_rows else {
        "role": operational.get("role") or "Unknown",
        "concept": "No role concept",
        "hierarchy": [],
    }

    # Classify ontology absences
    if not alias_rows and extracted.original_phrase:
        absences.append(OntologyAbsence(
            type="OntologyGap",
            layer="Ontology & Semantics",
            expected=f"Alias node for phrase '{extracted.original_phrase}'",
            found="absent",
            detail=f"The LLM interpreted '{extracted.original_phrase}' as an institutional action phrase, but no :Alias node exists for it. This phrase should be considered for addition to the ontology.",
        ))

    if operational.get("role") and not role_rows:
        absences.append(OntologyAbsence(
            type="RelationshipMisdrawn",
            layer="Ontology & Semantics",
            expected=f"Role '{operational['role']}' → :INSTANCE_OF → Concept",
            found=f"Role node exists but has no concept hierarchy link",
            detail=f"The role '{operational['role']}' exists in the graph but has no :INSTANCE_OF edge to the concept hierarchy. The ontology knows this role exists but cannot reason about where it sits in the institutional structure.",
        ))

    return {
        "phrase_mapping": phrase_mapping,
        "role_mapping": role_mapping,
    }

def get_interpretation(extracted: ExtractedRequest, absences: List[OntologyAbsence]) -> Dict[str, Any]:
    rows = run_query(Q_INTERPRET, {"phrase": extracted.original_phrase})
    if rows:
        row = rows[0]
        candidates = [c for c in row.get("candidate_actions", []) if c]
        row["candidate_actions"] = candidates
        row["resolved_action"] = extracted.action if extracted.action in candidates or not candidates else candidates[0]
        if not candidates:
            # Alias→Concept exists but no Action linked to that Concept
            absences.append(OntologyAbsence(
                type="RelationshipMisdrawn",
                layer="AI Interpretation",
                expected=f"Action → :INSTANCE_OF → Concept for alias '{extracted.original_phrase}'",
                found="Concept exists but no Action is linked to it",
                detail=f"The alias '{extracted.original_phrase}' maps to a concept, but no Action node is connected via :INSTANCE_OF. The ontology recognizes the concept but cannot resolve it to an executable institutional action.",
            ))
        return row
    # No rows — alias doesn't exist (already caught by get_ontology_mapping,
    # so we don't double-count here)
    return {
        "original_phrase": extracted.original_phrase,
        "canonical_concept": "No concept",
        "candidate_actions": [extracted.action],
        "resolved_action": extracted.action,
    }

def evaluate_policy(
    extracted: ExtractedRequest,
    operational: Dict[str, Any],
    absences: List[OntologyAbsence],
) -> Dict[str, Any]:
    # If the resource is unknown, stop here: policy cannot be safely evaluated
    if not extracted.resource:
        return {
            "actor": extracted.actor,
            "actor_role": operational.get("role"),
            "action": extracted.action,
            "resource": None,
            "resource_amount": extracted.amount,
            "classification": None,
            "policy": None,
            "threshold": None,
            "required_role": None,
            "evaluated_amount": extracted.amount,
            "decision_status": "insufficient operational context",
            "decision_reason": (
                "The request refers to a resource that is not represented in the knowledge graph, "
                "so the system cannot safely evaluate authority or policy."
            ),
        }

    rows = run_query(Q_POLICY, {
        "actor": extracted.actor,
        "action": extracted.action,
        "resource": extracted.resource,
    })

    if rows:
        row = rows[0]
        if not row.get("policy"):
            absences.append(OntologyAbsence(
                type="OntologyGap",
                layer="Policy & Governance",
                expected=f"Policy → :GOVERNS → Action '{extracted.action}'",
                found="No policy governs this action",
                detail=(
                    f"No :Policy node with a :GOVERNS edge to Action '{extracted.action}' was found. "
                    "This action is ungoverned — requests will be approved by default. "
                    "This may be intentional (demo scope) or may indicate a missing policy definition."
                ),
            ))
    else:
        row = {
            "actor": extracted.actor,
            "actor_role": operational.get("role"),
            "action": extracted.action,
            "resource": extracted.resource,
            "resource_amount": operational.get("amount", extracted.amount),
            "classification": operational.get("classification"),
            "policy": None,
            "threshold": None,
            "required_role": None,
        }

        if operational.get("role") and operational.get("resource"):
            absences.append(OntologyAbsence(
                type="RelationshipMisdrawn",
                layer="Policy & Governance",
                expected=(
                    f"Policy linkage for actor '{extracted.actor}' performing "
                    f"'{extracted.action}' on '{extracted.resource}'"
                ),
                found="Operational grounding succeeded, but the policy query returned no rows",
                detail=(
                    "This suggests a broken linkage among Policy, Action, Role, or Resource "
                    "in the governance graph."
                ),
            ))

    amount = extracted.amount or row.get("resource_amount") or 0
    actor_role = row.get("actor_role")
    required_role = row.get("required_role")
    action = extracted.action
    classification = row.get("classification")

    status = "approve"
    reason = "No blocking policy condition detected."

    if actor_role is None:
        status = "insufficient operational context"
        reason = "The actor does not resolve to a role, so the request cannot be safely evaluated."
    elif action == "ApprovePayment":
        threshold = row.get("threshold") or 0
        if amount > float(threshold or 0) and actor_role != required_role:
            status = "escalate"
            reason = (
                f"Payment amount ${amount:,.0f} exceeds threshold ${float(threshold):,.0f}; "
                f"requires {required_role} approval."
            )
    elif action == "ApproveContract":
        threshold = row.get("threshold") or 0
        if amount > float(threshold or 0) and actor_role != required_role:
            status = "escalate"
            reason = (
                f"Contract amount ${amount:,.0f} exceeds threshold ${float(threshold):,.0f}; "
                f"requires {required_role} approval."
            )
    elif action == "ViewEmployeeRecord":
        if classification == "confidential" and actor_role != required_role:
            status = "deny"
            reason = f"Confidential employee records require role {required_role}."

    row.update({
        "evaluated_amount": amount,
        "decision_status": status,
        "decision_reason": reason,
    })
    return row


def log_decision(extracted: ExtractedRequest, policy: Dict[str, Any]) -> Dict[str, Any]:
    driver = get_driver()
    timestamp = datetime.now(timezone.utc).isoformat()
    decision_id = f"demo_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')}"
    outcome_name = {
        "approve": "Approved",
        "deny": "Denied",
        "escalate": "Escalated",
        "insufficient operational context": "Escalated",
    }.get(policy["decision_status"], "Escalated")
    if not driver:
        return {
            "decision_id": decision_id,
            "timestamp": timestamp,
            "status": policy["decision_status"],
            "reason": policy["decision_reason"],
            "outcome": outcome_name,
            "logged": False,
        }
    cypher = """
    MERGE (o:Outcome {outcome_id: $outcome_name})
    ON CREATE SET o.name = $outcome_name, o.impact = $status
    ON MATCH SET o.name = $outcome_name
CREATE (d:Decision {
    decision_id: $decision_id,
    timestamp: $timestamp,
    status: $status,
    reason: $reason,
    request_text: $request_text
})
WITH d, o
MATCH (p:Person {name: $actor})
MERGE (d)-[:MADE_BY]->(p)
WITH d, o
OPTIONAL MATCH (a:Action {name: $action})
FOREACH (_ IN CASE WHEN a IS NULL THEN [] ELSE [1] END | MERGE (d)-[:ABOUT_ACTION]->(a))
WITH d, o
OPTIONAL MATCH (r:Resource {resource_id: $resource})
FOREACH (_ IN CASE WHEN r IS NULL THEN [] ELSE [1] END | MERGE (d)-[:ABOUT_RESOURCE]->(r))
WITH d, o
OPTIONAL MATCH (pol:Policy {name: $policy})
FOREACH (_ IN CASE WHEN pol IS NULL THEN [] ELSE [1] END | MERGE (d)-[:TRIGGERED_POLICY]->(pol))
MERGE (d)-[:RESULTED_IN]->(o)
RETURN d.decision_id AS decision_id, d.timestamp AS timestamp, d.status AS status, d.reason AS reason
"""
    with driver.session() as session:
        row = session.run(
            cypher,
            {
                "decision_id": decision_id,
                "timestamp": timestamp,
                "status": policy["decision_status"],
                "reason": policy["decision_reason"],
                "request_text": json.dumps(asdict(extracted)),
                "actor": extracted.actor,
                "action": extracted.action,
                "resource": extracted.resource,
                "policy": policy.get("policy"),
                "outcome_name": outcome_name,
            },
        ).single()
    result = dict(row) if row else {}
    result["logged"] = True
    # ── AUTO-GENERATE LEARNING EVENTS ─────────────────────────────────────────
    _generate_learning_events(extracted, policy)
    # ── EVALUATE DRIFT THRESHOLDS ─────────────────────────────────────────────
    drift_hypotheses = _evaluate_drift_thresholds()
    result["drift_hypotheses"] = drift_hypotheses
    return result

def _generate_learning_events(extracted: ExtractedRequest, policy: Dict[str, Any]) -> None:
    """
    After each logged decision, scan for emerging patterns and write or update
    LearningEvent nodes in the graph automatically.

    Patterns detected:
    1. repeated_escalation — same policy triggered 3+ times with escalate status
    2. repeated_denial     — same actor denied 2+ times
    3. semantic_ambiguity  — same original phrase seen 2+ times across decisions
    4. role_boundary       — actor consistently near but below authority threshold
    """
    driver = get_driver()
    if not driver:
        return
    now = datetime.now(timezone.utc).isoformat()

    # Pattern 1: Repeated escalations on same policy
    if policy.get("decision_status") == "escalate" and policy.get("policy"):
        _upsert_learning_event(
            driver=driver,
            event_id_prefix="LE_ESC",
            key=policy["policy"],
            pattern_type="repeated_escalation",
            name=f"RepeatedEscalation_{policy['policy']}",
            recommendation=(
                f"Policy '{policy['policy']}' is triggering repeated escalations. "
                f"Consider adding an intermediate approval role or adjusting the threshold."
            ),
            decision_status="escalate",
            policy_name=policy.get("policy"),
            now=now,
        )

    # Pattern 2: Repeated denials for same actor
    if policy.get("decision_status") == "deny":
        _upsert_learning_event(
            driver=driver,
            event_id_prefix="LE_DENY",
            key=extracted.actor.replace(" ", "_"),
            pattern_type="repeated_denial",
            name=f"RepeatedDenial_{extracted.actor.replace(' ', '_')}",
            recommendation=(
                f"{extracted.actor} has been repeatedly denied. "
                f"Consider reviewing their role assignment or providing access training."
            ),
            decision_status="deny",
            policy_name=policy.get("policy"),
            now=now,
        )

    # Pattern 3: Semantic ambiguity — same original phrase used repeatedly
    if extracted.original_phrase:
        _upsert_learning_event(
            driver=driver,
            event_id_prefix="LE_SEM",
            key=extracted.original_phrase.replace(" ", "_"),
            pattern_type="semantic_ambiguity",
            name=f"AmbiguousPhrase_{extracted.original_phrase.replace(' ', '_')}",
            recommendation=(
                f"The phrase '{extracted.original_phrase}' is being used repeatedly. "
                f"Consider adding it as a canonical alias in the ontology layer."
            ),
            decision_status=policy.get("decision_status"),
            policy_name=policy.get("policy"),
            now=now,
        )

    # Pattern 4: Role boundary — actor role has a limit near the requested amount
    if policy.get("decision_status") == "escalate" and policy.get("threshold"):
        try:
            threshold = float(policy["threshold"])
            amount = float(policy.get("evaluated_amount", 0))
            proximity = (amount - threshold) / threshold if threshold > 0 else 0
            if 0 < proximity < 0.5:  # within 50% above threshold
                _upsert_learning_event(
                    driver=driver,
                    event_id_prefix="LE_BOUND",
                    key=f"{policy.get('actor_role', 'Unknown')}_{extracted.action}",
                    pattern_type="role_boundary",
                    name=f"RoleBoundary_{policy.get('actor_role', 'Unknown')}_{extracted.action}",
                    recommendation=(
                        f"Role '{policy.get('actor_role')}' is frequently near its approval limit. "
                        f"Consider raising the limit or creating a delegation pathway."
                    ),
                    decision_status="escalate",
                    policy_name=policy.get("policy"),
                    now=now,
                )
        except (TypeError, ValueError):
            pass

def _upsert_learning_event(
    driver: Any,
    event_id_prefix: str,
    key: str,
    pattern_type: str,
    name: str,
    recommendation: str,
    decision_status: Optional[str],
    policy_name: Optional[str],
    now: str,
) -> None:
    """Create or increment a LearningEvent node, link it to policy if present."""
    event_id = f"{event_id_prefix}_{key}"[:50]
    cypher = """
MERGE (l:LearningEvent {event_id: $event_id})
ON CREATE SET
    l.name = $name,
    l.pattern_type = $pattern_type,
    l.recommendation = $recommendation,
    l.count = 1,
    l.first_seen = $now,
    l.last_seen = $now
ON MATCH SET
    l.count = l.count + 1,
    l.last_seen = $now,
    l.recommendation = $recommendation
WITH l
OPTIONAL MATCH (pol:Policy {name: $policy_name})
FOREACH (_ IN CASE WHEN pol IS NULL THEN [] ELSE [1] END |
    MERGE (l)-[:SUGGESTS_CHANGE_TO]->(pol)
)
RETURN l.event_id AS event_id, l.count AS count
"""
    try:
        with driver.session() as session:
            session.run(cypher, {
                "event_id": event_id,
                "name": name,
                "pattern_type": pattern_type,
                "recommendation": recommendation,
                "now": now,
                "policy_name": policy_name,
            })
    except Exception as e:
        print(f"Learning event upsert failed: {e}")

def _upsert_absence_event(driver: Any, absence: OntologyAbsence, now: str) -> None:
    """Create or increment a LearningEvent node for a classified ontology absence.

    These events carry an absence_type property that the drift detection query
    in meta_ontology_logical_reification.cypher can filter on. When absence
    events accumulate past quantifier thresholds, a DriftHypothesis is generated.
    """
    # Sanitize expected field for use in event_id
    safe_expected = re.sub(r"[^a-zA-Z0-9_]", "_", absence.expected)[:30]
    event_id = f"LE_ABS_{absence.type}_{safe_expected}"[:50]
    cypher = """
MERGE (l:LearningEvent {event_id: $event_id})
ON CREATE SET
    l.name = $name,
    l.pattern_type = 'ontology_absence',
    l.absence_type = $absence_type,
    l.layer = $layer,
    l.expected = $expected,
    l.found = $found,
    l.recommendation = $detail,
    l.count = 1,
    l.first_seen = $now,
    l.last_seen = $now
ON MATCH SET
    l.count = l.count + 1,
    l.last_seen = $now
RETURN l.event_id AS event_id, l.count AS count
"""
    try:
        with driver.session() as session:
            session.run(cypher, {
                "event_id": event_id,
                "name": f"{absence.type}_{safe_expected}",
                "absence_type": absence.type,
                "layer": absence.layer,
                "expected": absence.expected,
                "found": absence.found,
                "detail": absence.detail,
                "now": now,
            })
    except Exception as e:
        print(f"Absence event upsert failed: {e}")

# ─── DRIFT DETECTION ──────────────────────────────────────────────────────────
# These queries are extracted from meta_ontology_logical_reification.cypher
# sections 8b (policy boundary drift, no APOC) and 8c (absence accumulation).
# They run after every logged decision so the full chain is live:
#   log decision → detect behavioral patterns → detect absence patterns →
#   evaluate drift thresholds → generate DriftHypothesis nodes.

Q_DRIFT_POLICY = """
MATCH (q:Quantifier)-[:GROUNDS_IN]->(pol:Policy)
      <-[:TRIGGERED_POLICY]-(d:Decision)
      -[:MADE_BY]->(person:Person)
      -[:HAS_ROLE]->(role:Role)
WHERE d.status IN ['escalate', 'deny']
WITH q, pol,
     collect(DISTINCT role.name)   AS roles_involved,
     count(DISTINCT role.name)     AS unique_roles,
     count(DISTINCT d)             AS frequency,
     collect(DISTINCT d.status)    AS statuses
WHERE unique_roles >= q.threshold_unique_roles
  AND frequency   >= q.threshold_frequency
WITH q, pol, roles_involved, unique_roles, frequency, statuses,
     CASE
       WHEN size([s IN statuses WHERE s = 'deny']) > 0
         THEN 'EntityReclassification'
       WHEN size([s IN statuses WHERE s = 'escalate']) = size(statuses)
         THEN 'RelationshipMisdrawn'
       ELSE 'OntologyGap'
     END AS hyp_type
MERGE (dh:DriftHypothesis {
  id: 'DH_' + q.id + '_' + pol.policy_id
})
ON CREATE SET
  dh.type                = hyp_type,
  dh.label               = hyp_type + '_' + pol.name,
  dh.description         = 'Drift detected: ' + toString(frequency) +
                            ' decisions across ' + toString(unique_roles) + ' roles triggered ' + pol.name,
  dh.frequency_observed  = frequency,
  dh.unique_roles        = unique_roles,
  dh.roles_involved      = roles_involved,
  dh.status              = 'candidate',
  dh.created             = datetime()
ON MATCH SET
  dh.frequency_observed  = frequency,
  dh.unique_roles        = unique_roles,
  dh.roles_involved      = roles_involved,
  dh.last_evaluated      = datetime()
MERGE (dh)-[:CONCERNS]->(pol)
MERGE (dh)-[:GENERATED_BY]->(q)
RETURN dh.id AS hypothesis_id, dh.type AS hypothesis_type, dh.label AS label,
       dh.frequency_observed AS frequency, dh.unique_roles AS unique_roles
"""

Q_DRIFT_ABSENCE = """
MATCH (q:Quantifier {id: 'Q004'})
MATCH (le:LearningEvent {pattern_type: 'ontology_absence'})
WITH q,
     collect(DISTINCT le.absence_type)  AS types_observed,
     count(DISTINCT le.absence_type)    AS unique_types,
     sum(le.count)                      AS total_frequency,
     collect(DISTINCT le.layer)         AS layers_affected
WHERE unique_types >= q.threshold_unique_types
  AND total_frequency >= q.threshold_frequency
WITH q, types_observed, unique_types, total_frequency, layers_affected,
     CASE
       WHEN 'OntologyGap' IN types_observed AND 'RelationshipMisdrawn' IN types_observed
         THEN 'OntologyGap'
       WHEN 'RelationshipMisdrawn' IN types_observed
         THEN 'RelationshipMisdrawn'
       WHEN 'EntityReclassification' IN types_observed
         THEN 'EntityReclassification'
       ELSE 'OntologyGap'
     END AS hyp_type
MERGE (dh:DriftHypothesis {
  id: 'DH_Q004_absence_accumulation'
})
ON CREATE SET
  dh.type                = hyp_type,
  dh.label               = 'AbsenceAccumulation_' + hyp_type,
  dh.description         = 'The LLM is consistently referencing institutional structures '
                          + 'that the knowledge graph does not contain. '
                          + toString(total_frequency) + ' absence events across '
                          + toString(unique_types) + ' structural gap types detected.',
  dh.frequency_observed  = total_frequency,
  dh.unique_types        = unique_types,
  dh.types_observed      = types_observed,
  dh.layers_affected     = layers_affected,
  dh.status              = 'candidate',
  dh.created             = datetime()
ON MATCH SET
  dh.frequency_observed  = total_frequency,
  dh.unique_types        = unique_types,
  dh.types_observed      = types_observed,
  dh.layers_affected     = layers_affected,
  dh.last_evaluated      = datetime()
MERGE (dh)-[:GENERATED_BY]->(q)
RETURN dh.id AS hypothesis_id, dh.type AS hypothesis_type, dh.label AS label,
       dh.frequency_observed AS frequency
"""

def _evaluate_drift_thresholds() -> List[Dict[str, Any]]:
    """Run both drift detection queries against the graph.

    Returns a list of DriftHypothesis records that were created or updated.
    These queries are idempotent (MERGE-based) so running them on every
    pipeline execution is safe — they update counts and timestamps on
    existing hypotheses rather than creating duplicates.

    Requires the meta-ontology layer (meta_ontology_logical_reification.cypher)
    to be loaded. If Quantifier nodes don't exist, the queries return nothing.
    """
    results: List[Dict[str, Any]] = []
    driver = get_driver()
    if not driver:
        return results
    try:
        with driver.session() as session:
            # Policy boundary drift (Q001, Q002, Q003)
            for record in session.run(Q_DRIFT_POLICY):
                results.append(dict(record))
            # Absence accumulation drift (Q004)
            for record in session.run(Q_DRIFT_ABSENCE):
                results.append(dict(record))
    except Exception as e:
        # Meta-ontology layer may not be loaded — Quantifier nodes absent.
        # This is expected when running with seed graph only.
        print(f"Drift evaluation skipped: {e}")
    return results

def get_learning() -> Dict[str, List[Dict[str, Any]]]:
    return {
        "decisions": run_query(Q_DECISIONS),
        "learning_events": run_query(Q_LEARNING),
    }

def get_graph_data(extracted: ExtractedRequest) -> List[Dict[str, Any]]:
    """Return subgraph rows for visualization."""
    return run_query(Q_GRAPH_SUBGRAPH, {
        "actor": extracted.actor,
        "action": extracted.action,
        "resource": extracted.resource,
    })

def run_full_pipeline(text: str, log_to_graph: bool = False, include_raw_llm: bool = False) -> Dict[str, Any]:
    absences: List[OntologyAbsence] = []
    extracted, extraction_mode, extraction_errors = extract_request(text)
    operational = get_operational_context(extracted, absences)
    ontology = get_ontology_mapping(extracted, operational, absences)
    interpretation = get_interpretation(extracted, absences)
    policy = evaluate_policy(extracted, operational, absences)
    decision_log = None
    if log_to_graph:
        decision_log = log_decision(extracted, policy)
        if absences:
            driver = get_driver()
            if driver:
                now = datetime.now(timezone.utc).isoformat()
                for absence in absences:
                    _upsert_absence_event(driver, absence, now)
    learning = get_learning()
    graph_data = get_graph_data(extracted)
    raw_llm = raw_llm_decision(text) if include_raw_llm else None
    return {
        "input_text": text,
        "extraction_mode": extraction_mode,
        "extraction_errors": extraction_errors,
        "extracted": asdict(extracted),
        "operational": operational,
        "ontology": ontology,
        "interpretation": interpretation,
        "policy": policy,
        "decision_log": decision_log,
        "learning": learning,
        "graph_data": graph_data,
        "raw_llm": raw_llm,
        "ontology_absences": [asdict(a) for a in absences],
        "drift_hypotheses": (decision_log or {}).get("drift_hypotheses", []),
    }