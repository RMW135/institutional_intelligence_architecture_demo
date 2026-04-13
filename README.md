# Institutional Intelligence Architecture

**A Governed Ontology for Enterprise AI — with Native Logical Reasoning**

> The LLM interprets language. The graph validates authority. These two roles are never conflated.

Most organizations deploy AI as a tool layered on top of existing processes — the model has no grounding in the organization's authority structures, policies, or institutional knowledge. This architecture inverts that pattern: the corporate structure itself becomes a formal component of every decision the AI makes.

The IIA also addresses a problem that distributed multi-agent AI systems — including architectures like Cisco Outshift's Internet of Cognition — have identified but not yet solved: **what guarantees that the symbolic and formal logic primitives agents negotiate over are internally consistent before any inter-agent communication begins?** The IIA is the institutional substrate that provides that guarantee.

---

## The Architecture

The IIA operates across two integrated layers: a **five-layer governance stack** for enterprise AI decision-making, and a **FOL primitive substrate** that provides native propositional reasoning within the labeled property graph — without external reasoners.

---

## Layer 1–5: Enterprise Governance Stack

| # | Layer | What It Solves |
|---|-------|----------------|
| 1 | **Operational Data** | Grounds every request in verified org facts — roles, departments, resources — before any inference is attempted |
| 2 | **Ontology & Semantics** | A knowledge graph encodes institutional meaning. Manager ≠ Finance Director — similar language is not equal authority |
| 3 | **Policy & Governance** | Governance rules become machine-checkable constraints. A plausible action can still violate institutional policy |
| 4 | **AI Interpretation** | Natural language is normalized into a canonical institutional action before policy checks are applied |
| 5 | **Institutional Learning** | Recurring decision patterns — repeated escalations, denials, ambiguous phrases — accumulate automatically as institutional knowledge |

---

## FOL Primitive Substrate (In Active Development)

The FOL primitive substrate sits beneath the governance stack and provides native propositional completeness within the labeled property graph. It is logically complete from two elements only:

1. **NAND edges** — the sole primitive relation type (Sheffer stroke)
2. **Negated endpoint flags** — `start_negated` / `end_negated` properties on each NAND edge

All propositional connectives are constructible from these two primitives:

| Connective | NAND Composition |
|------------|-----------------|
| NOT(A) | negated endpoint flag = true |
| OR(A,B) | NAND(NOT(A), NOT(B)) — start_negated:true, end_negated:true |
| IMPLIES(A→B) | NAND(A, NOT(B)) — start_negated:false, end_negated:true |
| AND(A,B) | NOT(NAND(A,B)) |

**What this enables:**

- **Forward chaining** from reified logical primitives — rules fire consequents when antecedents hold, propagating through the graph to fixpoint
- **Contradiction detection** — oscillating shadow cascade classified as Contradiction, NecessaryOscillation, or MalformedDependency
- **Gap proposals** — a contradiction between two legitimate ground rules surfaces a `GapProposal` node identifying the missing scope constraint, rather than flagging either rule as erroneous
- **Counterfactual preservation** — shadow graph generation 0 preserves the assumed state at cascade initiation for causal reasoning

This is the first implementation of propositional logical completeness natively within a labeled property graph without external RDF/OWL reasoners. The standard enterprise approach routes reasoning through external systems (Neosemantics, GraphScale, Virtuoso). The IIA eliminates that dependency entirely.

---

## Live Demo Scenarios

| Request | Decision | Why |
|---------|----------|-----|
| Can John sign off on the ACME invoice for $120,000? | **Escalate** | HighValuePaymentPolicy threshold is $100K; requires FinanceDirector |
| Can Maria approve the ACME invoice for $120,000? | **Approve** | Finance Director has unlimited authority |
| Can John push this contract through today? | **Escalate** | Ambiguous phrase normalized → amount exceeds limit; Finance Manager cannot approve Procurement contracts |
| Can Sarah see employee file E77? | **Deny** | Confidential HR records restricted to HR Director role |
| Can Emily greenlight the BoltWorks invoice for $40,000? | **Approve** | Budget Manager limit is $100K — within authority |
| Can Emily buy a coffee pot for $15,000? | **Insufficient context** | Resource "coffee pot" does not exist in the knowledge graph — the system refuses to reason about ungrounded entities. A context-loaded LLM approves this request. |

---

## Architecture Overview

```
User Request (natural language)
        │
        ▼
┌─────────────────────────────┐
│  Layer 4 · AI Interpretation │  Claude / OpenAI / rule-based
│  "sign off" → ApprovePayment │  normalizes ambiguous language
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Layer 1 · Operational Data  │  Neo4j knowledge graph
│  Person → Role → Department  │  verifies actor and resource exist
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Layer 2 · Ontology          │  Concept hierarchy
│  Role → Concept → Hierarchy  │  stabilizes institutional meaning
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Layer 3 · Policy Reasoning  │  Constraint evaluation
│  Amount > Threshold? Role OK?│  machine-checkable governance
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Layer 5 · Learning          │  Auto-generated LearningEvent nodes
│  Patterns → Recommendations  │  institutional knowledge accumulates
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  FOL Primitive Substrate     │  NAND edges + negated flags
│  Propositions → Rules →      │  forward chaining, contradiction
│  Contradiction → GapProposal │  detection, gap proposals
└─────────────────────────────┘
               │
               ▼
     Decision: APPROVE / ESCALATE / DENY
     + Justification chain (queryable, auditable)
     + GapProposal (if contradiction detected)
```

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Knowledge graph | Neo4j (Cypher) + APOC |
| LLM extraction | Claude (Anthropic) → OpenAI → rule-based fallback |
| Ontology methodology | Symbolic KB design (Cycorp / Cyc-derived) |
| FOL substrate | NAND-complete LPG schema + forward chaining |
| UI | Streamlit (seven-tab demo suite) |
| Graph visualization | PyVis (live subgraph rendering) |
| Language | Python 3.10+ |

---

## Project Structure

```
institutional-intelligence-architecture/
├── structural_demo_app.py                    # Core pipeline: extraction, graph queries, policy evaluation
├── structural_demo_ui.py                     # Streamlit UI — seven-tab demo suite
├── seed_ai_structural_graph.cypher           # Complete Neo4j seed graph (Apex Manufacturing org)
├── meta_ontology_logical_reification.cypher  # Drift detection: quantifiers, thresholds, hypothesis generation
├── meta_ontology_standalone_dev.txt          # Standalone dev environment for meta-ontological layer
├── fol_primitive_substrate.cypher            # FOL primitive layer: Propositions, NAND edges, Rules, Queue
├── fol_triggers.cypher                       # APOC trigger registration (run once only)
├── fol_procedures.cypher                     # Named query library: forward chaining, shadow cascade, gap proposals
├── requirements.txt
├── .env.example
└── README.md
```

---

## Quickstart

### 1. Clone and install
```bash
git clone https://github.com/RMW135/institutional-intelligence-architecture.git
cd institutional-intelligence-architecture
pip install -r requirements.txt
```

### 2. Set up Neo4j
**Option A — Local** (required for full FOL substrate with APOC triggers): Download Neo4j Desktop and create a local DBMS. Install the APOC plugin. Add `apoc.trigger.enabled=true` to `apoc.conf`.

**Option B — Cloud** (for the governance demo only): Create a free instance at [Neo4j AuraDB](https://neo4j.com/cloud/platform/aura-graph-database/). Note: APOC triggers are not available on AuraDB — the FOL substrate forward chaining runs via the Python pipeline in this configuration.

### 3. Load the graph (in order)
Open Neo4j Browser and run each file in sequence:

```
1. seed_ai_structural_graph.cypher
2. meta_ontology_logical_reification.cypher
3. fol_primitive_substrate.cypher
4. fol_triggers.cypher          ← run once only (requires local Neo4j with APOC)
```

### 4. Configure environment
```bash
cp .env.example .env
# Edit .env with your Neo4j credentials and API keys
```

The app works without any LLM API key — it falls back to deterministic rule-based extraction. With `ANTHROPIC_API_KEY` set, Claude handles extraction via structured tool use.

### 5. Run
```bash
streamlit run structural_demo_ui.py
```

---

## The Seven Demo Tabs

| Tab | Layer | What It Demonstrates |
|-----|-------|----------------------|
| 1 · Operational Context | Operational Data | Why AI needs grounded org context before reasoning |
| 2 · Ontology Mapping | Ontology & Semantics | Why similar language ≠ equivalent authority |
| 3 · Policy Reasoning | Policy & Governance | Why plausible actions can still violate policy |
| 4 · AI Interpretation | AI Interpretation | Why language normalization must precede policy checks |
| 5 · Learning | Institutional Learning | How the system accumulates patterns from decisions |
| 6 · Graph View | Visualization | Live PyVis rendering of the relevant knowledge subgraph |
| 7 · Full Architecture | End-to-end | One request through all five layers + optional raw LLM comparison |

---

## Raw LLM Comparison: Why Architecture Matters

When **Compare with raw LLM** is checked, Tab 7 shows a side-by-side: the same natural language request answered by an LLM with the full organizational context provided as prompt text versus the governed five-layer pipeline.

The LLM receives the complete org chart, every policy, and every threshold — the exact deployment pattern most enterprises use. With this information, it often reaches the same outcome as the governed pipeline. The difference is not accuracy. It is structure. The LLM produces prose: linguistically reasonable but not machine-checkable, not auditable, and not guaranteed to be consistent across runs. The pipeline produces a governed decision linked to a specific policy, a specific constraint evaluation, and a traceable authority chain from actor to role to threshold to outcome. That record is queryable by an auditor without reconstructing anything after the fact.

---

## Auto-Learning: How It Works

When **Log decision to Neo4j** is enabled, every pipeline run writes a `Decision` node to the graph and automatically detects structural patterns recorded as `LearningEvent` nodes.

| Pattern | Trigger | Recommendation Generated |
|---------|---------|--------------------------|
| `repeated_escalation` | Same policy triggers an escalation | Review approval routing or threshold |
| `repeated_denial` | Same actor is denied | Review role assignment or access training |
| `semantic_ambiguity` | An ambiguous phrase is used | Add phrase as canonical ontology alias |
| `role_boundary` | Actor is near but below approval limit | Consider delegation pathway or limit revision |
| `ontology_absence` | LLM references a concept the graph doesn't contain | Classified structural gap — missing node, missing relationship, or misclassified entity |

The `ontology_absence` pattern feeds directly into the FOL primitive substrate's gap detection mechanism — absences that cross quantifier thresholds generate `DriftHypothesis` nodes, which in turn ground the `GapProposal` mechanism in the logical layer.

---

## The Governance Gap in Multi-Agent AI

Current multi-agent AI architectures — including Cisco Outshift's Internet of Cognition, the A2A protocol, and MCP — solve for how agents communicate and share context across organizational boundaries. They correctly identify that the fundamental challenge is semantic, not syntactic.

What they do not yet specify is what guarantees that an institution's policies are internally consistent before agents begin negotiating over them. Their own deadlock scenario — remediation, security, and compliance agents all correct but the system frozen — is precisely the contradiction this architecture detects and surfaces before any inter-agent communication occurs.

The IIA is the institutional prerequisite for distributed multi-agent cognition: a self-auditing, logically consistent, contradiction-detecting governance substrate that gives agents something true to reason from.

---

## Demo Scope Notes

The current demo evaluates three action types against policy: `ApprovePayment`, `ApproveContract`, and `ViewEmployeeRecord`. The remaining canonical actions (`ReviewContract`, `TerminateEmployee`) are defined in the graph but do not yet have policy constraints. This is a scope boundary of the demo, not the architecture.

---

## About

Built by **Ryan M. Williams, Ph.D.** — AI integration architect, formal ontologist, and former Cycorp knowledge engineer.

- 📧 rmwilliamsphd@gmail.com
- 📍 Montreal, QC

Prior to this work, Ryan served as an ontologist at Cycorp, Inc. (2016–2018), building symbolic knowledge bases for one of the world's largest AI inference engines. His approach to enterprise AI architecture draws directly on that methodology — applied to the organizational decision-making problems enterprises actually face, and extended to the problem of native logical completeness in labeled property graphs.

---

*The seed organization (Apex Manufacturing) is entirely fictional and used for demonstration purposes only.*
