// =============================================================================
// META-ONTOLOGICAL DRIFT DETECTION — Neo4j Cypher (Operational)
// Quantifier-based drift monitoring for the Institutional Intelligence Architecture
// Author: Ryan M. Williams, Ph.D.
// =============================================================================
//
// PURPOSE:
//   This file adds the operational meta-ontological layer to the seed graph.
//   It contains only the components that the running Python pipeline executes
//   against: Quantifier nodes, threshold-based drift detection, and
//   DriftHypothesis generation.
//
//   The formal logical substrate (ConnectiveType taxonomy, Propositions,
//   LogicalRelations, higher-order reification, Hypothesis containers) is
//   maintained separately in meta_ontology_standalone_dev.cypher for academic
//   development and the forthcoming technical paper.
//
// DEPENDENCY:
//   Requires seed_ai_structural_graph.cypher to be loaded first.
//   Quantifier nodes reference :Policy nodes from the seed via :GROUNDS_IN.
//
// LOAD ORDER:
//   1. seed_ai_structural_graph.cypher
//   2. This file
//
// =============================================================================


// ═══════════════════════════════════════════════════════════════════════════════
// 1. CONSTRAINTS
// ═══════════════════════════════════════════════════════════════════════════════

CREATE CONSTRAINT quantifier_id_unique IF NOT EXISTS
  FOR (q:Quantifier) REQUIRE q.id IS UNIQUE;

CREATE CONSTRAINT drift_hyp_id_unique IF NOT EXISTS
  FOR (dh:DriftHypothesis) REQUIRE dh.id IS UNIQUE;

CREATE INDEX drift_hyp_type_idx IF NOT EXISTS
  FOR (dh:DriftHypothesis) ON (dh.type);


// ═══════════════════════════════════════════════════════════════════════════════
// 2. QUANTIFIER NODES
// ═══════════════════════════════════════════════════════════════════════════════
// Quantifiers formalize drift detection thresholds. Each monitors a specific
// aspect of the company graph. When compound thresholds are exceeded, the
// Python pipeline generates a typed DriftHypothesis node.
//
// monitor_pattern: identifies which evaluation procedure the Python app uses.
//   'policy_decisions'  — traverse Policy → Decision → Person → Role
//   'absence_events'    — traverse LearningEvent {pattern_type: 'ontology_absence'}

// Q001-Q003: Policy boundary drift monitors.
// Fire when the same policy triggers escalations/denials from multiple
// distinct roles — evidence that the boundary itself may be misdrawn.

MERGE (:Quantifier {
  id:                     'Q001',
  label:                  'HighValuePaymentDriftMonitor',
  type:                   'EXISTENTIAL',
  monitor_pattern:        'policy_decisions',
  description:            'Monitors whether escalations against HighValuePaymentPolicy cross drift thresholds',
  threshold_frequency:    2,
  threshold_unique_roles: 2,
  created:                date('2026-03-28')
});

MERGE (:Quantifier {
  id:                     'Q002',
  label:                  'ContractApprovalDriftMonitor',
  type:                   'EXISTENTIAL',
  monitor_pattern:        'policy_decisions',
  description:            'Monitors whether escalations against ContractApprovalPolicy cross drift thresholds',
  threshold_frequency:    2,
  threshold_unique_roles: 2,
  created:                date('2026-03-28')
});

MERGE (:Quantifier {
  id:                     'Q003',
  label:                  'HRAccessDriftMonitor',
  type:                   'EXISTENTIAL',
  monitor_pattern:        'policy_decisions',
  description:            'Monitors whether denials against HRAccessPolicy cross drift thresholds',
  threshold_frequency:    2,
  threshold_unique_roles: 2,
  created:                date('2026-03-28')
});

// Q004: Ontology absence accumulation monitor.
// Unlike Q001-Q003 which monitor decision outcomes, Q004 monitors the
// structural gaps between what the LLM expects the ontology to contain
// and what the graph actually holds. These gaps are classified by the
// Python pipeline as OntologyGap, RelationshipMisdrawn, or
// EntityReclassification and written as LearningEvent nodes.
//
// This monitor fires when the LLM is consistently outrunning the graph —
// not because the LLM is wrong, but because the LLM's implicit model of
// the institution is broader than the graph's explicit model.
//
// threshold_frequency:    total absence events (summed across types)
// threshold_unique_types: distinct structural gap types observed (max 3)

MERGE (:Quantifier {
  id:                     'Q004',
  label:                  'OntologyAbsenceMonitor',
  type:                   'EXISTENTIAL',
  monitor_pattern:        'absence_events',
  description:            'Monitors whether classified ontology absences accumulate past thresholds',
  threshold_frequency:    3,
  threshold_unique_types: 2,
  created:                date('2026-03-28')
});


// ═══════════════════════════════════════════════════════════════════════════════
// 3. GROUNDS_IN BRIDGES
// ═══════════════════════════════════════════════════════════════════════════════
// Each policy-monitoring quantifier is grounded in a specific :Policy node
// from the seed graph. This is the bridge between the meta-ontological layer
// and the company graph it monitors.
//
// Q004 has no GROUNDS_IN — it monitors LearningEvent accumulation across
// the entire ontology, not a specific policy.

MATCH (q:Quantifier {id: 'Q001'}), (pol:Policy {policy_id: 'P001'})
MERGE (q)-[:GROUNDS_IN]->(pol);
MATCH (q:Quantifier {id: 'Q002'}), (pol:Policy {policy_id: 'P002'})
MERGE (q)-[:GROUNDS_IN]->(pol);
MATCH (q:Quantifier {id: 'Q003'}), (pol:Policy {policy_id: 'P003'})
MERGE (q)-[:GROUNDS_IN]->(pol);


// ═══════════════════════════════════════════════════════════════════════════════
// 4. VERIFICATION QUERIES (read-only)
// ═══════════════════════════════════════════════════════════════════════════════

// 4a. Show all quantifiers and what they monitor
MATCH (q:Quantifier)
OPTIONAL MATCH (q)-[:GROUNDS_IN]->(target)
RETURN
  q.id                      AS quantifier,
  q.label                   AS label,
  q.monitor_pattern         AS pattern,
  q.threshold_frequency     AS freq_threshold,
  COALESCE(q.threshold_unique_roles, q.threshold_unique_types) AS diversity_threshold,
  labels(target)[0]         AS target_type,
  COALESCE(target.name, target.policy_id, 'global') AS target_name
ORDER BY q.id;

// 4b. Policy drift status — actual counts vs thresholds
MATCH (q:Quantifier {monitor_pattern: 'policy_decisions'})-[:GROUNDS_IN]->(pol:Policy)
      <-[:TRIGGERED_POLICY]-(d:Decision)
      -[:MADE_BY]->(person:Person)
      -[:HAS_ROLE]->(role:Role)
WHERE d.status IN ['escalate', 'escalated', 'deny', 'denied']
WITH q, pol,
     count(DISTINCT role.name) AS actual_roles,
     count(DISTINCT d)         AS actual_freq
RETURN
  q.id                      AS quantifier,
  pol.name                  AS policy,
  q.threshold_frequency     AS freq_threshold,
  actual_freq               AS freq_actual,
  actual_freq >= q.threshold_frequency AS freq_met,
  q.threshold_unique_roles  AS role_threshold,
  actual_roles              AS roles_actual,
  actual_roles >= q.threshold_unique_roles AS roles_met;

// 4c. Absence accumulation status — actual counts vs Q004 thresholds
MATCH (le:LearningEvent {pattern_type: 'ontology_absence'})
WITH collect(DISTINCT le.absence_type)  AS types,
     count(DISTINCT le.absence_type)    AS unique_types,
     sum(le.count)                      AS total_events,
     collect(DISTINCT le.layer)         AS layers
MATCH (q:Quantifier {id: 'Q004'})
RETURN
  types                                          AS absence_types_observed,
  unique_types                                   AS unique_type_count,
  total_events                                   AS total_absence_events,
  layers                                         AS affected_layers,
  q.threshold_frequency                          AS freq_threshold,
  total_events >= q.threshold_frequency           AS freq_met,
  q.threshold_unique_types                       AS type_threshold,
  unique_types >= q.threshold_unique_types        AS types_met;

// 4d. Show all DriftHypothesis nodes
MATCH (dh:DriftHypothesis)
OPTIONAL MATCH (dh)-[:CONCERNS]->(pol:Policy)
OPTIONAL MATCH (dh)-[:GENERATED_BY]->(q:Quantifier)
RETURN
  dh.id                 AS hypothesis_id,
  dh.type               AS hypothesis_type,
  dh.label              AS label,
  dh.frequency_observed AS observed_frequency,
  dh.status             AS status,
  pol.name              AS policy_concerned,
  q.id                  AS triggered_by
ORDER BY dh.created DESC;

// 4e. Show all ontology absence LearningEvents
MATCH (le:LearningEvent {pattern_type: 'ontology_absence'})
RETURN
  le.event_id      AS event_id,
  le.absence_type  AS absence_type,
  le.layer         AS pipeline_layer,
  le.expected      AS expected,
  le.found         AS found,
  le.count         AS observation_count,
  le.first_seen    AS first_seen,
  le.last_seen     AS last_seen
ORDER BY le.absence_type, le.count DESC;


// =============================================================================
// END OF FILE
// =============================================================================
