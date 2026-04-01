from __future__ import annotations
import json
import os
from pathlib import Path
import pandas as pd
import streamlit as st
import streamlit.components.v1 as components
from structural_demo_app import SAMPLE_PROMPTS, run_full_pipeline, get_driver

st.set_page_config(page_title="Institutional Intelligence Architecture Demo", page_icon="🏛", layout="wide")

# ─── CUSTOM STYLES ────────────────────────────────────────────────────────────
st.markdown("""
<style>
  .layer-badge {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 600;
    margin-bottom: 6px;
  }
  .badge-op    { background: #dbeafe; color: #1e40af; }
  .badge-onto  { background: #ede9fe; color: #5b21b6; }
  .badge-pol   { background: #fef9c3; color: #92400e; }
  .badge-ai    { background: #dcfce7; color: #166534; }
  .badge-learn { background: #fee2e2; color: #991b1b; }
  .badge-full  { background: #f3f4f6; color: #374151; }
  .extraction-chip {
    font-size: 0.7rem;
    background: #f0fdf4;
    color: #166534;
    border: 1px solid #bbf7d0;
    border-radius: 8px;
    padding: 1px 8px;
  }
</style>
""", unsafe_allow_html=True)

# ─── HEADER ───────────────────────────────────────────────────────────────────
st.title("🏛 Institutional Intelligence Architecture")
st.caption(
    "A five-layer enterprise AI architecture — the LLM interprets language, "
    "the knowledge graph validates authority. These two roles are never conflated."
)

# ─── SIDEBAR ──────────────────────────────────────────────────────────────────
with st.sidebar:
    st.header("System Status")
    neo4j_ok = get_driver() is not None
    anthropic_ok = bool(os.getenv("ANTHROPIC_API_KEY"))
    openai_ok = bool(os.getenv("OPENAI_API_KEY"))

    st.write("Neo4j:", "🟢 Connected" if neo4j_ok else "🔴 Not connected")
    st.write("Claude (Anthropic):", "🟢 Configured" if anthropic_ok else "🟡 Not configured")
    st.write("OpenAI:", "🟢 Configured" if openai_ok else "🟡 Not configured")

    extraction_priority = (
        "Claude → OpenAI → Fallback" if anthropic_ok
        else "OpenAI → Fallback" if openai_ok
        else "Fallback (rule-based)"
    )
    st.caption(f"Extraction priority: {extraction_priority}")
    st.divider()
    st.markdown("**Setup**")
    st.markdown("1. Seed Neo4j with `seed_ai_structural_graph.cypher`")
    st.markdown("2. Set env vars: `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`")
    st.markdown("3. Optionally set `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`")
    st.markdown("4. `streamlit run structural_demo_ui.py`")

# ─── INPUT ────────────────────────────────────────────────────────────────────
col_select, col_input = st.columns([1, 2])
with col_select:
    sample = st.selectbox("Sample prompt", SAMPLE_PROMPTS, key="sample_select")

with col_input:
    custom_text = st.text_area(
        "Or enter your own request",
        value=sample,
        height=90,
        key="custom_text_area",
    )

# Use custom text if the user modified it, otherwise use the sample
active_text = custom_text.strip() if custom_text.strip() else sample

col_run, col_log, col_raw = st.columns([1, 2, 2])
with col_run:
    run_clicked = st.button("▶ Run Pipeline", type="primary", use_container_width=True)
with col_log:
    log_to_graph = st.checkbox(
        "Log decision to Neo4j (enables auto-learning)",
        value=False,
        disabled=not neo4j_ok,
        help="When checked, each run logs a Decision node and auto-generates LearningEvent patterns.",
    )
with col_raw:
    any_llm = anthropic_ok or openai_ok
    include_raw_llm = st.checkbox(
        "Compare with context-loaded LLM",
        value=False,
        disabled=not any_llm,
        help="Give the LLM the full org chart, policies, and thresholds as prompt text — the standard enterprise pattern — and compare its prose output against the governed pipeline's structured decision.",
    )

if run_clicked:
    with st.spinner("Running pipeline..."):
        st.session_state.demo_result = run_full_pipeline(
            active_text, log_to_graph=log_to_graph, include_raw_llm=include_raw_llm
        )

if "demo_result" not in st.session_state:
    st.info("Select a sample prompt or enter your own request, then click ▶ Run Pipeline.")
    st.stop()

result = st.session_state.demo_result
extracted = result["extracted"]
operational = result["operational"]
ontology = result["ontology"]
interpretation = result["interpretation"]
policy = result["policy"]
learning = result["learning"]
graph_data = result.get("graph_data", [])

# ─── EXTRACTION SUMMARY ───────────────────────────────────────────────────────
st.divider()
st.markdown(
    f"**Structured extraction** &nbsp; "
    f'<span class="extraction-chip">via {result["extraction_mode"]}</span>',
    unsafe_allow_html=True,
)
extraction_errors = result.get("extraction_errors", [])
if extraction_errors:
    with st.expander(f"⚠ {len(extraction_errors)} extraction provider(s) failed — click to diagnose", expanded=True):
        for err in extraction_errors:
            st.error(err)
        st.caption(
            "The pipeline fell back to rule-based extraction. "
            "Check that your API key is valid, not rate-limited, and that the model name in .env is correct."
        )
st.code(json.dumps(extracted, indent=2), language="json")

# ─── TABS ─────────────────────────────────────────────────────────────────────
tabs = st.tabs([
    "1 · Operational Context",
    "2 · Ontology Mapping",
    "3 · Policy Reasoning",
    "4 · AI Interpretation",
    "5 · Learning",
    "6 · Graph View",
    "7 · Full Architecture",
])

# ── TAB 1: OPERATIONAL ────────────────────────────────────────────────────────
with tabs[0]:
    st.markdown('<span class="layer-badge badge-op">Layer 1 — Operational Data</span>', unsafe_allow_html=True)
    st.markdown("### What this stage proves")
    st.write(
        "AI needs enough grounded operational context before reasoning can be trusted. "
        "Without verified facts about the actor and resource, downstream inference is unsafe."
    )
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("#### Retrieved context")
        st.json(operational)
    with c2:
        st.markdown("#### Validation result")
        missing = []
        if not operational.get("role"):
            missing.append("actor role is missing")
        if not operational.get("resource"):
            missing.append("resource context is missing")
        if missing:
            st.error("⚠ Operationally under-specified: " + " · ".join(missing))
        else:
            st.success("✓ Operational context is sufficient for downstream reasoning.")
        st.markdown(
            "**Why it matters:** An LLM reasoning over the plain text of a request may infer "
            "authority from tone or title. This layer forces grounding before any inference is attempted."
        )

# ── TAB 2: ONTOLOGY ───────────────────────────────────────────────────────────
with tabs[1]:
    st.markdown('<span class="layer-badge badge-onto">Layer 2 — Ontology & Semantic Alignment</span>', unsafe_allow_html=True)
    st.markdown("### What this stage proves")
    st.write(
        "Institutional meaning is not equivalent to linguistic meaning. "
        "The ontology layer maps roles and phrases to canonical concepts in a formal hierarchy."
    )
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("#### Phrase → Concept mapping")
        st.json(ontology["phrase_mapping"])
    with c2:
        st.markdown("#### Role → Concept mapping")
        st.json(ontology["role_mapping"])
    phrase_map = ontology["phrase_mapping"]
    role_map = ontology["role_mapping"]
    phrase = phrase_map.get("phrase", "")
    concept = phrase_map.get("mapped_concept", "")
    role = role_map.get("role", "")
    role_concept = role_map.get("concept", "")

    if phrase and concept and concept != "No direct ontology match":
        st.info(
            f"💡 '{phrase}' maps to **{concept}** — not a raw string match, "
            f"but a canonical institutional concept. "
            f"Similarly, '{role}' maps to **{role_concept}**, not a peer concept. "
            f"Semantic proximity is not authority equivalence — and the ontology enforces that distinction."
        )
    else:
        st.warning(
            f"💡 '{phrase}' has no direct ontology match. "
            f"The system fell back to the extracted action. "
            f"This phrase could be added as a canonical alias in the ontology layer."
        )

    # ── ONTOLOGY ABSENCE AUDIT ────────────────────────────────────────────────
    all_absences = result.get("ontology_absences", [])
    if all_absences:
        st.divider()
        st.markdown("### Structural gap audit")
        st.caption(
            "The LLM interpreted the request as if certain institutional structures exist. "
            "The graph audited those assumptions. The gaps below are not LLM errors — "
            "they are diagnostic signals about where the ontology is incomplete."
        )
        for absence in all_absences:
            abs_type = absence.get("type", "")
            icon = {"OntologyGap": "🔴", "RelationshipMisdrawn": "🟠", "EntityReclassification": "🟡"}.get(abs_type, "⚪")
            with st.expander(f"{icon} **{abs_type}** — {absence.get('layer', '')}"):
                st.write(f"**Expected:** {absence.get('expected', '')}")
                st.write(f"**Found:** {absence.get('found', '')}")
                st.write(absence.get("detail", ""))
    elif phrase and concept and concept != "No direct ontology match":
        st.divider()
        st.success("✓ No structural gaps detected — the LLM's implicit ontological assumptions are fully grounded in the graph.")

# ── TAB 3: POLICY ─────────────────────────────────────────────────────────────
with tabs[2]:
    st.markdown('<span class="layer-badge badge-pol">Layer 3 — Policy & Governance</span>', unsafe_allow_html=True)
    st.markdown("### What this stage proves")
    st.write(
        "A plausible action can still violate institutional policy. "
        "Policy reasoning converts governance rules into machine-checkable constraints."
    )
    c1, c2 = st.columns([3, 2])
    with c1:
        st.json(policy)
    with c2:
        status = policy["decision_status"]
        if status == "approve":
            st.success("✓ Decision: **APPROVED**")
        elif status == "escalate":
            st.warning("⚠ Decision: **ESCALATE**")
        elif status == "deny":
            st.error("✗ Decision: **DENIED**")
        else:
            st.info(f"Decision: **{status.upper()}**")
        st.write(policy["decision_reason"])
        threshold = policy.get("threshold")
        try:
            threshold_float = float(threshold) if threshold is not None else None
        except (ValueError, TypeError):
            threshold_float = None
        if threshold_float is not None:
            st.metric(
                "Approval threshold",
                f"${threshold_float:,.0f}",
                delta=f"Request: ${float(policy.get('evaluated_amount', 0)):,.0f}",
                delta_color="inverse",
            )

# ── TAB 4: INTERPRETATION ─────────────────────────────────────────────────────
with tabs[3]:
    st.markdown('<span class="layer-badge badge-ai">Layer 4 — AI Interpretation</span>', unsafe_allow_html=True)
    st.markdown("### What this stage proves")
    st.write(
        "Natural language must be normalized into a canonical institutional action "
        "before policy checks are applied."
    )
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("#### Ambiguous phrase (raw input)")
        st.code(interpretation["original_phrase"], language=None)
        st.markdown("#### Resolved canonical concept")
        st.code(interpretation["canonical_concept"], language=None)
    with c2:
        st.markdown("#### Candidate institutional actions")
        candidates = interpretation.get("candidate_actions") or []
        if candidates:
            for c in candidates:
                icon = "✓" if c == interpretation.get("resolved_action") else "○"
                st.write(f"{icon} `{c}`")
        else:
            st.write("No candidates returned from graph.")
        st.markdown("#### Resolved action")
        st.code(interpretation.get("resolved_action") or extracted["action"], language=None)
    st.info(
        "💡 The LLM should interpret language. The graph should validate authority. "
        "Conflating these two roles is the most common architectural failure in enterprise AI."
    )

# ── TAB 5: LEARNING ───────────────────────────────────────────────────────────
with tabs[4]:
    st.markdown('<span class="layer-badge badge-learn">Layer 5 — Institutional Learning</span>', unsafe_allow_html=True)
    st.markdown("### What this stage proves")
    st.write(
        "A mature system accumulates recurring decision patterns as institutional knowledge — "
        "rather than treating every request in isolation. LearningEvent nodes are auto-generated "
        "from repeated escalations, denials, and ambiguous phrases."
    )
    decisions = learning.get("decisions", [])
    events = learning.get("learning_events", [])
    if log_to_graph and (result.get("decision_log") or {}).get("logged"):
        st.success("✓ Decision logged. Learning events auto-updated.")
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("#### Recent decisions")
        if decisions:
            df_decisions = pd.DataFrame(decisions)
            if "timestamp" in df_decisions.columns:
                df_decisions["timestamp"] = df_decisions["timestamp"].astype(str)
            st.dataframe(df_decisions, use_container_width=True, hide_index=True)
        else:
            st.info("No logged decisions found. Run with 'Log decision' checked to populate.")
    with c2:
        st.markdown("#### Active learning events")
        if events:
            df = pd.DataFrame(events)
            for _, row in df.iterrows():
                with st.expander(f"🔍 {row.get('learning_event', 'Event')} (seen {row.get('count', 0)}x)"):
                    st.write(f"**Pattern:** `{row.get('pattern_type')}`")
                    st.write(f"**Recommendation:** {row.get('recommendation')}")
                    st.write(f"**Supporting decisions:** {row.get('supporting_decisions')}")
                    st.write(f"**Suggests change to:** {row.get('suggested_policy_targets')}")
        else:
            st.info("No learning events yet. Log decisions to generate patterns automatically.")
    st.markdown(
        "**Auto-detection patterns:** repeated escalation · repeated denial · "
        "semantic ambiguity · role boundary proximity · ontology absence"
    )
    # Show absence summary if any were detected this run
    run_absences = result.get("ontology_absences", [])
    if run_absences:
        st.divider()
        st.markdown("#### Ontology absences detected this run")
        st.caption(
            "Each absence is classified by structural type. When logged, these accumulate as "
            "LearningEvent nodes with an `absence_type` property. The meta-ontological layer's "
            "drift detection fires when absence counts cross quantifier thresholds."
        )
        # Group by type
        by_type: dict = {}
        for a in run_absences:
            t = a.get("type", "Unknown")
            by_type.setdefault(t, []).append(a)
        for abs_type, items in by_type.items():
            icon = {"OntologyGap": "🔴", "RelationshipMisdrawn": "🟠", "EntityReclassification": "🟡"}.get(abs_type, "⚪")
            st.markdown(f"{icon} **{abs_type}** × {len(items)}")
            for item in items:
                st.caption(f"  → {item.get('layer')}: {item.get('expected')}")
        if not log_to_graph:
            st.info("Enable **Log decision to Neo4j** to persist these absences as LearningEvent nodes.")

    # ── DRIFT HYPOTHESES ──────────────────────────────────────────────────────
    drift_hyps = result.get("drift_hypotheses", [])
    if drift_hyps:
        st.divider()
        st.markdown("### Drift hypotheses generated")
        st.caption(
            "The meta-ontological layer has detected that accumulated patterns cross "
            "quantifier thresholds. These are not recommendations — they are structured "
            "hypotheses about what would have to change for observed behavior to make sense."
        )
        for dh in drift_hyps:
            hyp_type = dh.get("hypothesis_type", "")
            icon = {
                "RelationshipMisdrawn": "🟠",
                "EntityReclassification": "🟡",
                "OntologyGap": "🔴",
            }.get(hyp_type, "⚪")
            with st.expander(f"{icon} **{dh.get('label', hyp_type)}**", expanded=True):
                st.write(f"**Type:** {hyp_type}")
                st.write(f"**Observed frequency:** {dh.get('frequency', '?')}")
                if dh.get("unique_roles"):
                    st.write(f"**Unique roles involved:** {dh.get('unique_roles')}")
                st.write(f"**Hypothesis ID:** `{dh.get('hypothesis_id', '?')}`")

# ── TAB 6: GRAPH VIEW ─────────────────────────────────────────────────────────
with tabs[5]:
    st.markdown('<span class="layer-badge badge-full">Graph Visualization</span>', unsafe_allow_html=True)
    st.markdown("### Live subgraph for this request")
    st.write(
        "The knowledge graph slice relevant to the current request — "
        "showing person, role, policy, constraint, action, and resource nodes."
    )
    if not neo4j_ok:
        st.warning("Connect Neo4j to enable live graph visualization.")
    elif not graph_data:
        st.info("No graph data returned. Check that the seed graph is loaded.")
    else:
        try:
            from pyvis.network import Network  # type: ignore
            import tempfile

            net = Network(height="520px", width="100%", bgcolor="#0f172a", font_color="#e2e8f0")
            net.set_options(json.dumps({
                "nodes": {
                    "shape": "dot",
                    "size": 18,
                    "font": {"size": 13, "face": "Arial"},
                    "borderWidth": 2,
                },
                "edges": {
                    "color": {"color": "#64748b"},
                    "font": {"size": 10, "color": "#94a3b8"},
                    "arrows": {"to": {"enabled": True, "scaleFactor": 0.6}},
                    "smooth": {"type": "curvedCW", "roundness": 0.2},
                },
                "physics": {
                    "barnesHut": {"gravitationalConstant": -8000, "springLength": 140},
                    "stabilization": {"iterations": 150},
                },
            }))

            NODE_COLORS = {
                "person":     "#3b82f6",
                "role":       "#a78bfa",
                "dept":       "#34d399",
                "policy":     "#fbbf24",
                "constraint": "#f87171",
                "action":     "#38bdf8",
                "resource":   "#fb923c",
            }
            added = set()
            row = graph_data[0]

            def add_node(label, ntype, extra=""):
                if label and label not in added:
                    net.add_node(
                        label,
                        label=label,
                        title=f"{ntype}: {label}\n{extra}",
                        color=NODE_COLORS.get(ntype, "#94a3b8"),
                    )
                    added.add(label)

            def add_edge(src, dst, rel):
                if src and dst and src in added and dst in added:
                    net.add_edge(src, dst, label=rel)

            add_node(row["person_name"], "person")
            add_node(row["role_name"], "role")
            add_node(row["dept_name"], "dept")
            add_node(row["policy_name"], "policy")
            add_node(row["action_name"], "action")
            add_node(row["required_role"], "role")
            if row.get("constraint_type"):
                clabel = f'{row["constraint_type"]} {row.get("constraint_value", "")}'
                add_node(clabel, "constraint")
            add_node(
                row["resource_id"],
                "resource",
                f'${float(row.get("resource_amount") or 0):,.0f}',
            )
            add_node(row["resource_dept"], "dept")

            add_edge(row["person_name"], row["role_name"], "HAS_ROLE")
            add_edge(row["person_name"], row["dept_name"], "IN_DEPT")
            add_edge(row["policy_name"], row["action_name"], "GOVERNS")
            add_edge(row["policy_name"], row["required_role"], "APPLIES_TO")
            if row.get("constraint_type"):
                clabel = f'{row["constraint_type"]} {row.get("constraint_value", "")}'
                add_edge(row["policy_name"], clabel, "HAS_CONSTRAINT")
            add_edge(row["resource_id"], row["resource_dept"], "OWNED_BY")
            add_edge(row["action_name"], row["resource_id"], "TARGETS")

            with tempfile.NamedTemporaryFile(suffix=".html", delete=False) as f:
                net.save_graph(f.name)
                html = Path(f.name).read_text()
            components.html(html, height=540, scrolling=False)

            st.markdown("**Legend:**")
            legend_cols = st.columns(7)
            legend_items = [
                ("Person", "#3b82f6"),
                ("Role", "#a78bfa"),
                ("Department", "#34d399"),
                ("Policy", "#fbbf24"),
                ("Constraint", "#f87171"),
                ("Action", "#38bdf8"),
                ("Resource", "#fb923c"),
            ]
            for col, (label, color) in zip(legend_cols, legend_items):
                col.markdown(
                    f'<span style="display:inline-block;width:12px;height:12px;'
                    f'border-radius:50%;background:{color};margin-right:4px"></span>{label}',
                    unsafe_allow_html=True,
                )
        except ImportError:
            st.warning("Install pyvis to enable graph visualization: `pip install pyvis`")
            st.markdown("**Raw graph data:**")
            st.json(graph_data[0] if graph_data else {})

# ── TAB 7: FULL ARCHITECTURE ──────────────────────────────────────────────────
with tabs[6]:
    st.markdown('<span class="layer-badge badge-full">End-to-End Architecture</span>', unsafe_allow_html=True)
    st.markdown("### One request through all five layers")
    st.write(
        "This pipeline demonstrates that reliable enterprise AI requires more than a language model. "
        "It requires grounded operational data, stable institutional meaning, policy constraints, "
        "interpretable language normalization, and a mechanism to learn from repeated decisions."
    )

    # ── CONTEXT-LOADED LLM vs GOVERNED PIPELINE COMPARISON ─────────────────
    raw_llm = result.get("raw_llm")
    if raw_llm:
        st.divider()
        st.markdown("### ⚖ Context-Loaded LLM vs. Governed Architecture")
        st.write(
            "Both systems receive the same request. Both have access to the same organizational facts. "
            "The difference is *how* the information is used: the LLM reasons from text, "
            "the architecture reasons from structure."
        )
        st.caption(
            f'Request: *"{result["input_text"]}"*'
        )
        col_raw, col_gov = st.columns(2)
        with col_raw:
            st.markdown(
                '<div style="background:#fefce8; border:1px solid #fcd34d; border-radius:8px; padding:16px;">'
                '<strong style="color:#92400e;">💬 LLM with Full Org Context as Prompt Text</strong><br>'
                '<span style="font-size:0.85em; color:#78716c;">'
                'Has roles, policies, thresholds, and org chart — the standard enterprise pattern.</span>'
                '</div>',
                unsafe_allow_html=True,
            )
            st.caption(f"Provider: {raw_llm['provider']}")
            st.markdown(raw_llm["response"])
            st.info(raw_llm["note"])
            st.markdown("**What's missing from this output:**")
            st.markdown(
                "- No machine-checkable decision — just prose\n"
                "- No link to the specific policy that governed the outcome\n"
                "- No traceable authority chain (role → threshold → constraint → result)\n"
                "- No structured record a regulator or auditor can query\n"
                "- No guarantee the same request produces the same answer tomorrow"
            )
        with col_gov:
            gov_status = policy["decision_status"]
            gov_color_bg = {
                "approve": "#f0fdf4", "escalate": "#fffbeb", "deny": "#fef2f2",
            }.get(gov_status, "#f3f4f6")
            gov_color_bd = {
                "approve": "#86efac", "escalate": "#fcd34d", "deny": "#fca5a5",
            }.get(gov_status, "#d1d5db")
            gov_icon = {"approve": "✓", "escalate": "⚠", "deny": "✗"}.get(gov_status, "?")
            st.markdown(
                f'<div style="background:{gov_color_bg}; border:1px solid {gov_color_bd}; border-radius:8px; padding:16px;">'
                f'<strong style="color:#166534;">🏛 Governed Pipeline — Graph-Validated Decision</strong><br>'
                f'<span style="font-size:0.85em; color:#78716c;">'
                f'Same facts, but encoded as queryable structure — not prompt text.</span>'
                f'</div>',
                unsafe_allow_html=True,
            )
            st.markdown(
                f"**Decision: {gov_icon} {gov_status.upper()}**"
            )
            st.markdown(f"**Reason:** {policy['decision_reason']}")
            if policy.get("policy"):
                st.markdown(f"**Policy triggered:** `{policy['policy']}`")
            if policy.get("actor_role"):
                st.markdown(f"**Actor role:** {policy['actor_role']} · **Required role:** {policy.get('required_role', 'N/A')}")
            threshold = policy.get("threshold")
            amount = policy.get("evaluated_amount", 0)
            try:
                if threshold and float(threshold) > 0:
                    st.markdown(f"**Threshold:** ${float(threshold):,.0f} · **Requested:** ${float(amount):,.0f}")
            except (TypeError, ValueError):
                pass
            st.markdown("**What this output provides:**")
            st.markdown(
                "- Deterministic, machine-checkable decision\n"
                "- Linked to a specific `Policy` node in the graph\n"
                "- Traceable chain: Person → Role → Threshold → Constraint → Decision\n"
                "- Structured record queryable by auditors and regulators\n"
                "- Identical result every time — the graph enforces, not approximates"
            )

        st.markdown(
            "> **Both systems had the same information. The LLM produced a reasonable paragraph. "
            "The architecture produced a governed decision. The difference is not accuracy — "
            "it's enforceability, traceability, and consistency. That's what governance requires, "
            "and what language alone cannot guarantee.**"
        )
        st.divider()

    # ── PIPELINE STEP DETAIL ─────────────────────────────────────────────────
    st.markdown("### Pipeline steps")
    steps = [
        ("1 · LLM Extraction", "AI Interpretation", extracted),
        ("2 · Operational Grounding", "Operational Data", operational),
        ("3 · Ontology Mapping", "Ontology & Semantics", ontology),
        ("4 · Interpretation Normalization", "AI Interpretation", interpretation),
        ("5 · Policy Evaluation", "Policy & Governance", policy),
    ]
    for label, layer, payload in steps:
        with st.expander(f"{label} · *{layer}*", expanded=False):
            st.json(payload)
    if result.get("decision_log"):
        with st.expander("Decision log (Neo4j write)", expanded=False):
            st.json(result["decision_log"])

    st.divider()
    st.markdown("### Executive takeaway")
    status = policy["decision_status"]
    decision_color = {"approve": "green", "escalate": "orange", "deny": "red"}.get(status, "gray")
    op_check = "✓" if operational.get("role") else "⚠"
    learn_check = "✓" if learning.get("learning_events") else "—"
    st.markdown(
        f"""
| Layer | Function | Status |
|-------|----------|--------|
| 1 · Operational Data | Grounds request in verified org facts | {op_check} |
| 2 · Ontology & Semantics | Stabilizes institutional meaning | ✓ |
| 3 · Policy & Governance | Enforces machine-checkable constraints | :{decision_color}[{status.upper()}] |
| 4 · AI Interpretation | Normalizes language to canonical action | ✓ |
| 5 · Institutional Learning | Accumulates institutional knowledge | {learn_check} |
"""
    )
    st.markdown(
        "> **The architecture treats the corporate structure itself as a reasoning component — "
        "not as background context for a language model, but as a formal knowledge system "
        "that governs every decision the AI makes.**"
    )

readme_path = Path(__file__).with_name("README.md")
if readme_path.exists():
    with st.expander("📄 Project notes"):
        st.markdown(readme_path.read_text(encoding="utf-8"))