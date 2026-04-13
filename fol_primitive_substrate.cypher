// =============================================================================
// FOL PRIMITIVE SUBSTRATE — Neo4j Cypher
// First-Order Logic Primitive Layer for the Institutional Intelligence Architecture
// Author: Ryan M. Williams, Ph.D.
// =============================================================================
//
// PURPOSE:
//   Establishes the logical primitive substrate beneath all higher-level
//   connectives, rules, and ontological structures in the IIA.
//   Logically complete schema from two elements only:
//     1. NAND edges    — the sole primitive relation type
//     2. negated flags — boolean endpoint properties on each NAND edge
//
//   All propositional logic constructible from these two elements:
//     NOT(A)         → negated endpoint flag = true
//     NAND(A,B)      → start_negated:false, end_negated:false
//     AND(A,B)       → NOT(NAND(A,B))
//     OR(A,B)        → NAND(NOT(A),NOT(B)) → start_negated:true, end_negated:true
//     IMPLIES(A→B)   → NAND(A,NOT(B)) → start_negated:false, end_negated:true
//     IFF(A↔B)       → AND(IMP(A,B),IMP(B,A))
//
// FIX NOTE (2026-04-12):
//   All MERGE statements use ONLY the unique identifier in the MERGE clause.
//   All other properties set via ON CREATE SET.
//   Null values replaced with sentinel strings ('none', 'pending', 'ground')
//   as Neo4j 5 does not permit null values in MERGE clauses.
//
// LOAD ORDER:
//   1. seed_ai_structural_graph.cypher
//   2. meta_ontology_logical_reification.cypher
//   3. This file
//   4. fol_triggers.cypher (once only)
//
// =============================================================================


// ═══════════════════════════════════════════════════════════════════════════════
// PART 1: CONSTRAINTS AND INDEXES
// ═══════════════════════════════════════════════════════════════════════════════

CREATE CONSTRAINT proposition_id_unique IF NOT EXISTS
  FOR (p:Proposition) REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT rule_id_unique IF NOT EXISTS
  FOR (r:Rule) REQUIRE r.id IS UNIQUE;

CREATE CONSTRAINT cycle_event_id_unique IF NOT EXISTS
  FOR (c:CycleEvent) REQUIRE c.id IS UNIQUE;

CREATE CONSTRAINT gap_proposal_id_unique IF NOT EXISTS
  FOR (g:GapProposal) REQUIRE g.id IS UNIQUE;

CREATE CONSTRAINT update_queue_id_unique IF NOT EXISTS
  FOR (u:UpdateQueue) REQUIRE u.id IS UNIQUE;

CREATE INDEX proposition_reassessment_idx IF NOT EXISTS
  FOR (p:Proposition) ON (p.needs_reassessment);

CREATE INDEX proposition_derived_idx IF NOT EXISTS
  FOR (p:Proposition) ON (p.derived);

CREATE INDEX shadow_session_idx IF NOT EXISTS
  FOR (s:Shadow) ON (s.session_id);

CREATE INDEX shadow_generation_idx IF NOT EXISTS
  FOR (s:Shadow) ON (s.generation);


// ═══════════════════════════════════════════════════════════════════════════════
// PART 2: PROPOSITION NODES
// ═══════════════════════════════════════════════════════════════════════════════
//
// Propositions are atomic logical units — claims that are true or false.
// MERGE on unique id only. All other properties via ON CREATE SET.
// rule_id = 'none' for ground truth propositions (not derived by a rule).

MERGE (p:Proposition {id: 'PROP_GOV_ACTIVE'})
ON CREATE SET
  p.label              = 'GovernanceLayerActive',
  p.description        = 'The governance layer is operationally enforcing policy',
  p.layer              = 'Policy & Governance',
  p.truth_value        = true,
  p.derived            = false,
  p.needs_reassessment = false,
  p.rule_id            = 'none',
  p.grounded_in        = 'Policy';

MERGE (p:Proposition {id: 'PROP_POLICY_BOUNDARY_CROSSED'})
ON CREATE SET
  p.label              = 'PolicyBoundaryCrossed',
  p.description        = 'A policy boundary has been crossed by an actor without sufficient authority',
  p.layer              = 'Policy & Governance',
  p.truth_value        = false,
  p.derived            = false,
  p.needs_reassessment = false,
  p.rule_id            = 'none',
  p.grounded_in        = 'Decision';

MERGE (p:Proposition {id: 'PROP_DRIFT_DETECTED'})
ON CREATE SET
  p.label              = 'DriftDetected',
  p.description        = 'Repeated boundary crossings across distinct roles indicate structural drift',
  p.layer              = 'Meta-Ontological',
  p.truth_value        = false,
  p.derived            = true,
  p.needs_reassessment = false,
  p.rule_id            = 'RULE_BOUNDARY_IMPLIES_DRIFT',
  p.grounded_in        = 'DriftHypothesis';

MERGE (p:Proposition {id: 'PROP_ONTOLOGY_SUFFICIENT'})
ON CREATE SET
  p.label              = 'OntologySufficient',
  p.description        = 'The ontology fully accounts for the institutional domain it governs',
  p.layer              = 'Meta-Ontological',
  p.truth_value        = true,
  p.derived            = false,
  p.needs_reassessment = false,
  p.rule_id            = 'none',
  p.grounded_in        = 'Quantifier';

MERGE (p:Proposition {id: 'PROP_REVISION_REQUIRED'})
ON CREATE SET
  p.label              = 'RevisionRequired',
  p.description        = 'A structural revision to the ontology is required',
  p.layer              = 'Meta-Ontological',
  p.truth_value        = false,
  p.derived            = true,
  p.needs_reassessment = false,
  p.rule_id            = 'RULE_GAP_IMPLIES_REVISION',
  p.grounded_in        = 'GapProposal';

MERGE (p:Proposition {id: 'PROP_LEARNING_TRIGGERED'})
ON CREATE SET
  p.label              = 'LearningTriggered',
  p.description        = 'An institutional learning event has been logged',
  p.layer              = 'Institutional Learning',
  p.truth_value        = false,
  p.derived            = false,
  p.needs_reassessment = false,
  p.rule_id            = 'none',
  p.grounded_in        = 'LearningEvent';

MERGE (p:Proposition {id: 'PROP_SCOPE_CONSTRAINT_ABSENT'})
ON CREATE SET
  p.label              = 'ScopeConstraintAbsent',
  p.description        = 'No scope constraint exists to resolve which rule governs a contradicted case',
  p.layer              = 'Meta-Ontological',
  p.truth_value        = false,
  p.derived            = true,
  p.needs_reassessment = false,
  p.rule_id            = 'RULE_CONTRADICTION_IMPLIES_GAP',
  p.grounded_in        = 'GapProposal';


// ═══════════════════════════════════════════════════════════════════════════════
// PART 3: NAND PRIMITIVE EDGES
// ═══════════════════════════════════════════════════════════════════════════════
//
// NAND is the sole primitive edge type.
// Null sentinel values:
//   truth_value  = 'pending'  until first evaluation
//   evaluated_at = 'none'     until first evaluation
//   rule_id      = 'none'     for ground truth edges
//   session_id   = 'ground'   for ground truth edges
//   generation   = -1         for ground truth edges

// NAND_001: IMPLIES(PolicyBoundaryCrossed, DriftDetected)
MATCH (a:Proposition {id: 'PROP_POLICY_BOUNDARY_CROSSED'}),
      (b:Proposition {id: 'PROP_DRIFT_DETECTED'})
MERGE (a)-[r:NAND {id: 'NAND_001'}]->(b)
ON CREATE SET
  r.start_negated      = false,
  r.end_negated        = true,
  r.logical_form       = 'IMPLIES',
  r.truth_value        = 'pending',
  r.evaluated_at       = 'none',
  r.needs_reassessment = true,
  r.derived            = false,
  r.rule_id            = 'none',
  r.depends_on         = ['PROP_POLICY_BOUNDARY_CROSSED', 'PROP_DRIFT_DETECTED'],
  r.session_id         = 'ground',
  r.generation         = -1;

// NAND_002: IMPLIES(DriftDetected, RevisionRequired)
MATCH (a:Proposition {id: 'PROP_DRIFT_DETECTED'}),
      (b:Proposition {id: 'PROP_REVISION_REQUIRED'})
MERGE (a)-[r:NAND {id: 'NAND_002'}]->(b)
ON CREATE SET
  r.start_negated      = false,
  r.end_negated        = true,
  r.logical_form       = 'IMPLIES',
  r.truth_value        = 'pending',
  r.evaluated_at       = 'none',
  r.needs_reassessment = true,
  r.derived            = false,
  r.rule_id            = 'none',
  r.depends_on         = ['PROP_DRIFT_DETECTED', 'PROP_REVISION_REQUIRED'],
  r.session_id         = 'ground',
  r.generation         = -1;

// NAND_003: NAND(OntologySufficient, DriftDetected)
MATCH (a:Proposition {id: 'PROP_ONTOLOGY_SUFFICIENT'}),
      (b:Proposition {id: 'PROP_DRIFT_DETECTED'})
MERGE (a)-[r:NAND {id: 'NAND_003'}]->(b)
ON CREATE SET
  r.start_negated      = false,
  r.end_negated        = false,
  r.logical_form       = 'NAND',
  r.truth_value        = 'pending',
  r.evaluated_at       = 'none',
  r.needs_reassessment = true,
  r.derived            = false,
  r.rule_id            = 'none',
  r.depends_on         = ['PROP_ONTOLOGY_SUFFICIENT', 'PROP_DRIFT_DETECTED'],
  r.session_id         = 'ground',
  r.generation         = -1;

// NAND_004: OR(GovernanceActive, LearningTriggered)
MATCH (a:Proposition {id: 'PROP_GOV_ACTIVE'}),
      (b:Proposition {id: 'PROP_LEARNING_TRIGGERED'})
MERGE (a)-[r:NAND {id: 'NAND_004'}]->(b)
ON CREATE SET
  r.start_negated      = true,
  r.end_negated        = true,
  r.logical_form       = 'OR',
  r.truth_value        = 'pending',
  r.evaluated_at       = 'none',
  r.needs_reassessment = true,
  r.derived            = false,
  r.rule_id            = 'none',
  r.depends_on         = ['PROP_GOV_ACTIVE', 'PROP_LEARNING_TRIGGERED'],
  r.session_id         = 'ground',
  r.generation         = -1;

// NAND_005: IMPLIES(DriftDetected, ScopeConstraintAbsent)
MATCH (a:Proposition {id: 'PROP_DRIFT_DETECTED'}),
      (b:Proposition {id: 'PROP_SCOPE_CONSTRAINT_ABSENT'})
MERGE (a)-[r:NAND {id: 'NAND_005'}]->(b)
ON CREATE SET
  r.start_negated      = false,
  r.end_negated        = true,
  r.logical_form       = 'IMPLIES',
  r.truth_value        = 'pending',
  r.evaluated_at       = 'none',
  r.needs_reassessment = true,
  r.derived            = false,
  r.rule_id            = 'none',
  r.depends_on         = ['PROP_DRIFT_DETECTED', 'PROP_SCOPE_CONSTRAINT_ABSENT'],
  r.session_id         = 'ground',
  r.generation         = -1;


// ═══════════════════════════════════════════════════════════════════════════════
// PART 4: RULE NODES
// ═══════════════════════════════════════════════════════════════════════════════
//
// Rules encode forward-chaining IF-THEN structures.
// last_fired = 'none' until first firing (replaces null).

MERGE (r:Rule {id: 'RULE_BOUNDARY_IMPLIES_DRIFT'})
ON CREATE SET
  r.label            = 'PolicyBoundaryCrossedImpliesDrift',
  r.description      = 'If a policy boundary is crossed, structural drift is present',
  r.consequent_value = true,
  r.ground           = true,
  r.active           = true,
  r.firing_count     = 0,
  r.last_fired       = 'none';

MERGE (r:Rule {id: 'RULE_DRIFT_IMPLIES_INSUFFICIENCY'})
ON CREATE SET
  r.label            = 'DriftImpliesOntologyInsufficiency',
  r.description      = 'If drift is detected the ontology is insufficient for the domain it governs',
  r.consequent_value = false,
  r.ground           = true,
  r.active           = true,
  r.firing_count     = 0,
  r.last_fired       = 'none';

MERGE (r:Rule {id: 'RULE_GAP_IMPLIES_REVISION'})
ON CREATE SET
  r.label            = 'InsufficientOntologyImpliesRevision',
  r.description      = 'If the ontology is insufficient a structural revision is required',
  r.consequent_value = true,
  r.ground           = true,
  r.active           = true,
  r.firing_count     = 0,
  r.last_fired       = 'none';

MERGE (r:Rule {id: 'RULE_CONTRADICTION_IMPLIES_GAP'})
ON CREATE SET
  r.label            = 'ContradictionImpliesScopeGap',
  r.description      = 'A contradiction between legitimate rules implies an absent scope constraint',
  r.consequent_value = true,
  r.ground           = true,
  r.active           = true,
  r.firing_count     = 0,
  r.last_fired       = 'none';

// Wire rules to antecedents and consequents
MATCH (rule:Rule {id: 'RULE_BOUNDARY_IMPLIES_DRIFT'}),
      (ant:Proposition {id: 'PROP_POLICY_BOUNDARY_CROSSED'}),
      (con:Proposition {id: 'PROP_DRIFT_DETECTED'})
MERGE (rule)-[:HAS_ANTECEDENT {position: 1}]->(ant)
MERGE (rule)-[:HAS_CONSEQUENT {position: 1}]->(con);

MATCH (rule:Rule {id: 'RULE_DRIFT_IMPLIES_INSUFFICIENCY'}),
      (ant:Proposition {id: 'PROP_DRIFT_DETECTED'}),
      (con:Proposition {id: 'PROP_ONTOLOGY_SUFFICIENT'})
MERGE (rule)-[:HAS_ANTECEDENT {position: 1}]->(ant)
MERGE (rule)-[:HAS_CONSEQUENT {position: 1}]->(con);

MATCH (rule:Rule {id: 'RULE_GAP_IMPLIES_REVISION'}),
      (ant:Proposition {id: 'PROP_ONTOLOGY_SUFFICIENT'}),
      (con:Proposition {id: 'PROP_REVISION_REQUIRED'})
MERGE (rule)-[:HAS_ANTECEDENT {position: 1}]->(ant)
MERGE (rule)-[:HAS_CONSEQUENT {position: 1}]->(con);

MATCH (rule:Rule {id: 'RULE_CONTRADICTION_IMPLIES_GAP'}),
      (ant:Proposition {id: 'PROP_DRIFT_DETECTED'}),
      (con:Proposition {id: 'PROP_SCOPE_CONSTRAINT_ABSENT'})
MERGE (rule)-[:HAS_ANTECEDENT {position: 1}]->(ant)
MERGE (rule)-[:HAS_CONSEQUENT {position: 1}]->(con);


// ═══════════════════════════════════════════════════════════════════════════════
// PART 5: UPDATE QUEUE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Singleton queue node. current_session = 'none' when idle.

MERGE (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
ON CREATE SET
  q.status          = 'idle',
  q.current_session = 'none',
  q.pending         = [],
  q.created         = toString(datetime());


// ═══════════════════════════════════════════════════════════════════════════════
// PART 6: BRIDGE TO EXISTING GRAPH
// ═══════════════════════════════════════════════════════════════════════════════

MATCH (prop:Proposition {id: 'PROP_GOV_ACTIVE'}),
      (pol:Policy {policy_id: 'P001'})
MERGE (prop)-[:GROUNDS_IN]->(pol);

MATCH (prop:Proposition {id: 'PROP_POLICY_BOUNDARY_CROSSED'}),
      (d:Decision)
WHERE d.status IN ['escalated', 'denied']
WITH prop, d ORDER BY d.timestamp DESC LIMIT 1
MERGE (prop)-[:GROUNDS_IN]->(d);

MATCH (prop:Proposition {id: 'PROP_DRIFT_DETECTED'}),
      (dh:DriftHypothesis {status: 'candidate'})
MERGE (prop)-[:GROUNDS_IN]->(dh);

MATCH (prop:Proposition {id: 'PROP_LEARNING_TRIGGERED'}),
      (le:LearningEvent)
WHERE le.count > 0
WITH prop, le ORDER BY le.count DESC LIMIT 1
MERGE (prop)-[:GROUNDS_IN]->(le);


// ═══════════════════════════════════════════════════════════════════════════════
// PART 7: VERIFICATION QUERIES
// ═══════════════════════════════════════════════════════════════════════════════

// V1. All propositions
MATCH (p:Proposition)
RETURN p.id AS id, p.label AS label, p.layer AS layer,
       p.truth_value AS truth, p.derived AS derived,
       p.needs_reassessment AS needs_reassessment,
       p.rule_id AS asserted_by
ORDER BY p.layer, p.id;

// V2. All NAND edges
MATCH (a:Proposition)-[r:NAND]->(b:Proposition)
RETURN
  a.label          AS from_proposition,
  b.label          AS to_proposition,
  r.id             AS nand_id,
  r.logical_form   AS composition,
  r.start_negated  AS start_neg,
  r.end_negated    AS end_neg,
  r.truth_value    AS truth_value,
  r.needs_reassessment AS needs_reassessment
ORDER BY r.id;

// V3. All rules
MATCH (rule:Rule)-[:HAS_ANTECEDENT]->(ant:Proposition),
      (rule)-[:HAS_CONSEQUENT]->(con:Proposition)
RETURN rule.id AS rule_id, rule.label AS label,
       ant.label AS antecedent, con.label AS consequent,
       rule.consequent_value AS fires_to,
       rule.active AS active, rule.firing_count AS times_fired
ORDER BY rule.id;

// V4. Full inference chain
MATCH (ant:Proposition)-[r:NAND]->(con:Proposition)
OPTIONAL MATCH (rule:Rule)-[:HAS_ANTECEDENT]->(ant)
OPTIONAL MATCH (rule)-[:HAS_CONSEQUENT]->(con)
RETURN ant.label AS antecedent, r.logical_form AS via,
       con.label AS consequent, rule.label AS governing_rule,
       ant.truth_value AS antecedent_true,
       con.truth_value AS consequent_true
ORDER BY r.id;

// V5. Propositions grounded in company graph
MATCH (prop:Proposition)-[:GROUNDS_IN]->(target)
RETURN prop.id AS proposition, prop.label AS label,
       labels(target)[0] AS grounded_in_type,
       COALESCE(target.id, target.policy_id,
                target.decision_id, target.event_id) AS grounded_in_id;

// V6. UpdateQueue status
MATCH (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
RETURN q.status AS status, q.current_session AS session,
       size(q.pending) AS pending_count;


// =============================================================================
// END OF FILE
// =============================================================================
