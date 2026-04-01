# Institutional Intelligence Architecture

**A Five-Layer Enterprise AI Architecture**

> The LLM interprets language. The graph validates authority. These two roles are never conflated.

Most organizations deploy AI as a tool layered on top of existing processes — the model has no grounding in the organization's authority structures, policies, or institutional knowledge. This architecture inverts that pattern: the corporate structure itself becomes a formal component of every decision the AI makes.

---

## The Five Layers

| # | Layer | What It Solves |
|---|-------|----------------|
| 1 | **Operational Data** | Grounds every request in verified org facts — roles, departments, resources — before any inference is attempted |
| 2 | **Ontology & Semantics** | A knowledge graph encodes institutional meaning. Manager ≠ Finance Director — similar language is not equal authority |
| 3 | **Policy & Governance** | Governance rules become machine-checkable constraints. A plausible action can still violate institutional policy |
| 4 | **AI Interpretation** | Natural language is normalized into a canonical institutional action before policy checks are applied |
| 5 | **Institutional Learning** | Recurring decision patterns — repeated escalations, denials, ambiguous phrases — accumulate automatically as institutional knowledge |

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
└─────────────────────────────┘
               │
               ▼
     Decision: APPROVE / ESCALATE / DENY
```

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Knowledge graph | Neo4j (Cypher) |
| LLM extraction | Claude (Anthropic) → OpenAI → rule-based fallback |
| Ontology methodology | Symbolic KB design (Cycorp / Cyc-derived) |
| UI | Streamlit (seven-tab demo suite) |
| Graph visualization | PyVis (live subgraph rendering) |
| Language | Python 3.10+ |

---

## Project Structure

```
institutional-intelligence-architecture/
├── structural_demo_app.py                    # Core pipeline: extraction, graph queries, policy evaluation, absence classification
├── structural_demo_ui.py                     # Streamlit UI — seven-tab demo suite with graph visualization
├── seed_ai_structural_graph.cypher           # Complete Neo4j seed graph (Apex Manufacturing org)
├── meta_ontology_logical_reification.cypher  # Drift detection: quantifiers, thresholds, hypothesis generation
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
**Option A — Local** (recommended for development): Download Neo4j Desktop and create a local database.

**Option B — Cloud** (recommended for sharing a live demo): Create a free instance at [Neo4j AuraDB](https://neo4j.com/cloud/platform/aura-graph-database/).

### 3. Seed the graph
Open Neo4j Browser, paste the contents of `seed_ai_structural_graph.cypher`, and run it. You should see:
```
Institutional Intelligence Architecture demo graph seeded successfully.
```

**Optional — load the meta-ontological layer:** After the seed graph is loaded, paste and run `meta_ontology_logical_reification.cypher`. This adds the drift detection layer — quantifier nodes with thresholds, grounded in specific policies from the seed graph. The demo app works without it, but the automated drift detection and absence accumulation hypothesis generation require it.

### 4. Configure environment
```bash
cp .env.example .env
# Edit .env with your Neo4j credentials and (optionally) your Anthropic or OpenAI API key
```

The app works without any LLM API key — it falls back to deterministic rule-based extraction. With `ANTHROPIC_API_KEY` set, Claude handles extraction using structured tool use.

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

This comparison requires at least one LLM API key (`ANTHROPIC_API_KEY` or `OPENAI_API_KEY`).

---

## Auto-Learning: How It Works

When **Log decision to Neo4j** is enabled, every pipeline run writes a `Decision` node to the graph and automatically detects five structural patterns. Each pattern is recorded as a `LearningEvent` node from its first occurrence — the count increments with each subsequent match, and the recommendation is surfaced each time the pattern recurs.

| Pattern | Trigger | Recommendation Generated |
|---------|---------|--------------------------|
| `repeated_escalation` | Same policy triggers an escalation | Review approval routing or threshold |
| `repeated_denial` | Same actor is denied | Review role assignment or access training |
| `semantic_ambiguity` | An ambiguous phrase is used | Add phrase as canonical ontology alias |
| `role_boundary` | Actor is near but below their approval limit | Consider delegation pathway or limit revision |
| `ontology_absence` | LLM references a concept the graph doesn't contain | Classified structural gap — missing node, missing relationship, or misclassified entity |

The `ontology_absence` pattern is distinct from the other four. It is not triggered by the decision outcome but by a discrepancy between what the LLM's interpretation implicitly assumes about the institutional ontology and what the graph actually contains. Each absence is classified into one of three structural types: `OntologyGap` (expected node does not exist), `RelationshipMisdrawn` (node exists but a required edge is missing), or `EntityReclassification` (node and edges exist but type is wrong). These types align with the three hypothesis categories in the meta-ontological layer.

The count on each `LearningEvent` node reflects how many times the pattern has been observed. As decisions accumulate, the system builds an auditable record of structural friction points — policies that repeatedly block requests, roles that are consistently under-authorized, language that the ontology has not yet formalized, and structural gaps where the LLM's implicit model of the institution is broader than the graph's explicit model.

This transforms the system from a request evaluator into an institutional learning engine.

---

## Demo Scope Notes

The current demo evaluates three action types against policy: `ApprovePayment`, `ApproveContract`, and `ViewEmployeeRecord`. The remaining canonical actions (`ReviewContract`, `TerminateEmployee`) are defined in the graph but do not yet have policy constraints — they will default to approval. This is a scope boundary of the demo, not the architecture.

---

## About

Built by **Ryan M. Williams, Ph.D.** — AI integration architect, ontologist, and former Cycorp knowledge engineer.

- 📧 rmwilliamsphd@gmail.com
- 📍 Montreal, QC

Prior to this work, Ryan served as an ontologist at Cycorp, Inc. (2016–2018), building symbolic knowledge bases for one of the world's largest AI inference engines. His approach to enterprise AI architecture draws directly on that methodology — applied to the organizational decision-making problems enterprises actually face.

---

*The seed organization (Apex Manufacturing) is entirely fictional and used for demonstration purposes only.*
