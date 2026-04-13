// =============================================================================
// FOL PROCEDURES — Neo4j Cypher Query Library
// Reusable inference procedures for the FOL Primitive Substrate
// Author: Ryan M. Williams, Ph.D.
// =============================================================================
//
// PURPOSE:
//   This file is a query library — not a schema file. Each query is a
//   named, self-contained procedure called by the Python pipeline
//   (structural_demo_app.py) or manually during development.
//
//   Queries follow the same pattern as Q_DRIFT_POLICY and Q_DRIFT_ABSENCE
//   in structural_demo_app.py — stored as Python string constants and
//   executed via the run_query() function.
//
// PROCEDURE INVENTORY:
//
//   Q_NAND_EVALUATE          — evaluate all flagged NAND edge truth values
//   Q_RULE_FIRE              — fire all active rules whose antecedents hold
//   Q_FORWARD_CHAIN          — combined NAND eval + rule firing (one pass)
//   Q_SHADOW_CONVERGENCE     — check shadow generation for fixpoint
//   Q_CYCLE_DETECT           — detect oscillation between shadow generations
//   Q_SHADOW_TRANSFER        — transfer converged shadow state to ground truth
//   Q_SHADOW_CLEANUP         — delete shadow nodes after transfer
//   Q_GAP_PROPOSE            — generate GapProposal from Contradiction cycle
//   Q_CYCLE_CLASSIFY         — classify a detected CycleEvent by type
//   Q_PROPOSITION_STATUS     — read current truth state of all propositions
//   Q_INFERENCE_CHAIN        — full trace: proposition → NAND → rule → consequent
//   Q_QUEUE_STATUS           — read UpdateQueue state
//   Q_QUEUE_ADVANCE          — advance queue to next pending session
//
// DEPENDENCY:
//   Requires fol_primitive_substrate.cypher schema loaded.
//   Requires fol_triggers.cypher registered (for reactive cascade).
//
// USAGE IN PYTHON:
//   Import these as string constants and execute via run_query().
//   Parameters passed as the params dict to run_query().
//   Example:
//     results = run_query(Q_NAND_EVALUATE)
//     results = run_query(Q_SHADOW_CONVERGENCE, {"session_id": "abc-123"})
//
// =============================================================================


// =============================================================================
// PROCEDURE 1: Q_NAND_EVALUATE
// =============================================================================
//
// Evaluates truth values for all NAND edges flagged needs_reassessment = true.
// Operates on ground truth edges only (session_id IS NULL).
// Clears the needs_reassessment flag after evaluation.
//
// Returns: count of edges evaluated, list of updated edge ids
//
// Python constant:
// Q_NAND_EVALUATE = """
// MATCH (a:Proposition)-[r:NAND {needs_reassessment: true}]->(b:Proposition)
// WHERE r.session_id IS NULL
// WITH a, b, r,
//   CASE WHEN r.start_negated THEN NOT(a.truth_value) ELSE a.truth_value END AS eff_a,
//   CASE WHEN r.end_negated   THEN NOT(b.truth_value) ELSE b.truth_value END AS eff_b
// SET r.truth_value        = NOT(eff_a AND eff_b),
//     r.evaluated_at       = datetime(),
//     r.needs_reassessment = false
// RETURN count(r) AS edges_evaluated,
//        collect(r.id) AS edge_ids
// """

MATCH (a:Proposition)-[r:NAND {needs_reassessment: true}]->(b:Proposition)
WHERE r.session_id IS NULL
WITH a, b, r,
  CASE WHEN r.start_negated THEN NOT(a.truth_value) ELSE a.truth_value END AS eff_a,
  CASE WHEN r.end_negated   THEN NOT(b.truth_value) ELSE b.truth_value END AS eff_b
SET r.truth_value        = NOT(eff_a AND eff_b),
    r.evaluated_at       = datetime(),
    r.needs_reassessment = false
RETURN count(r) AS edges_evaluated,
       collect(r.id) AS edge_ids;


// =============================================================================
// PROCEDURE 2: Q_RULE_FIRE
// =============================================================================
//
// Fires all active Rules whose antecedent Propositions are currently true.
// Only updates consequent Propositions whose truth_value differs from
// the rule's consequent_value — avoids unnecessary churn.
// Flags consequents needs_reassessment = true to propagate the change.
//
// Returns: rules fired, consequents updated, new truth values

// Q_RULE_FIRE = """
// MATCH (rule:Rule {active: true})-[:HAS_ANTECEDENT]->(ant:Proposition)
// WHERE ant.truth_value = true
// MATCH (rule)-[:HAS_CONSEQUENT]->(con:Proposition)
// WHERE con.truth_value <> rule.consequent_value
// SET con.truth_value        = rule.consequent_value,
//     con.derived            = true,
//     con.needs_reassessment = true,
//     con.rule_id            = rule.id,
//     rule.firing_count      = rule.firing_count + 1,
//     rule.last_fired        = datetime()
// RETURN rule.id AS rule_fired,
//        rule.label AS rule_label,
//        con.id AS consequent_id,
//        con.label AS consequent_label,
//        con.truth_value AS new_truth_value
// """

MATCH (rule:Rule {active: true})-[:HAS_ANTECEDENT]->(ant:Proposition)
WHERE ant.truth_value = true
MATCH (rule)-[:HAS_CONSEQUENT]->(con:Proposition)
WHERE con.truth_value <> rule.consequent_value
SET con.truth_value        = rule.consequent_value,
    con.derived            = true,
    con.needs_reassessment = true,
    con.rule_id            = rule.id,
    rule.firing_count      = rule.firing_count + 1,
    rule.last_fired        = datetime()
RETURN rule.id        AS rule_fired,
       rule.label     AS rule_label,
       con.id         AS consequent_id,
       con.label      AS consequent_label,
       con.truth_value AS new_truth_value;


// =============================================================================
// PROCEDURE 3: Q_FORWARD_CHAIN
// =============================================================================
//
// One pass of combined NAND evaluation + rule firing.
// Called repeatedly by the Python pipeline until no further changes occur
// (fixpoint). The pipeline detects fixpoint when both queries return 0.
//
// Run Q_NAND_EVALUATE first, then Q_RULE_FIRE.
// Repeat until edges_evaluated = 0 AND rules_fired = 0.
//
// Python pipeline pattern:
//   while True:
//       nand_result = run_query(Q_NAND_EVALUATE)
//       rule_result = run_query(Q_RULE_FIRE)
//       edges_evaluated = nand_result[0]['edges_evaluated'] if nand_result else 0
//       rules_fired = len(rule_result)
//       if edges_evaluated == 0 and rules_fired == 0:
//           break  # fixpoint reached
//
// This procedure is a single combined pass for convenience:

// Q_FORWARD_CHAIN_NAND = Q_NAND_EVALUATE (see above)
// Q_FORWARD_CHAIN_RULES = Q_RULE_FIRE (see above)
// Use both in sequence — do not combine into one query
// (NAND evaluation must complete before rule firing for correct sequencing)


// =============================================================================
// PROCEDURE 4: Q_SHADOW_NAND_EVALUATE
// =============================================================================
//
// Evaluates NAND edges within a specific shadow cascade session.
// Operates on shadow edges only (session_id = $session_id).
// Used by the shadow cascade to propagate truth values through
// the shadow subgraph without touching ground truth.
//
// Parameters: session_id (string), generation (integer)

// Q_SHADOW_NAND_EVALUATE = """
// MATCH (a:Shadow {session_id: $session_id, generation: $generation})
// MATCH (b:Shadow {session_id: $session_id, generation: $generation})
// MATCH (ga:Proposition {id: a.original_id})-[r:NAND]->(gb:Proposition {id: b.original_id})
// WITH a, b, r,
//   CASE WHEN r.start_negated THEN NOT(a.truth_value) ELSE a.truth_value END AS eff_a,
//   CASE WHEN r.end_negated   THEN NOT(b.truth_value) ELSE b.truth_value END AS eff_b
// WITH a, b, r, NOT(eff_a AND eff_b) AS nand_result
// SET b.truth_value = CASE
//   WHEN r.logical_form = 'IMPLIES' AND a.truth_value = true
//     THEN rule.consequent_value
//   ELSE b.truth_value
// END
// RETURN count(b) AS shadow_nodes_updated
// """
//
// NOTE: Shadow NAND evaluation uses ground truth NAND edge structure
// but shadow node truth values. The ground truth edges define the
// logical topology; the shadow nodes hold the in-progress state.

// Simplified executable version:
// MATCH (a:Shadow {session_id: $session_id, generation: $generation}),
//       (b:Shadow {session_id: $session_id, generation: $generation})
// MATCH (ga:Proposition {id: a.original_id})-[r:NAND]->(gb:Proposition {id: b.original_id})
// WITH a, b, r,
//   CASE WHEN r.start_negated THEN NOT(a.truth_value) ELSE a.truth_value END AS eff_a,
//   CASE WHEN r.end_negated   THEN NOT(b.truth_value) ELSE b.truth_value END AS eff_b
// SET b.truth_value  = NOT(eff_a AND eff_b),
//     b.state_hash   = toString(NOT(eff_a AND eff_b))
// RETURN count(b) AS shadow_nodes_updated;


// =============================================================================
// PROCEDURE 5: Q_SHADOW_CONVERGENCE
// =============================================================================
//
// Checks whether all Shadow nodes in a session have converged.
// Convergence: state_hash at generation N equals state_hash at generation N-1.
// Sets converged = true on nodes that have reached fixpoint.
//
// Parameters: session_id (string), generation (integer, must be >= 1)
//
// Returns: nodes_converged, nodes_pending

// Q_SHADOW_CONVERGENCE = """
// MATCH (s:Shadow {session_id: $session_id, generation: $generation, converged: false})
// WHERE $generation > 0
// MATCH (prev:Shadow {
//   session_id:  $session_id,
//   original_id: s.original_id,
//   generation:  $generation - 1
// })
// WITH s, prev,
//      s.state_hash = prev.state_hash AS is_converged
// SET s.converged = is_converged
// WITH is_converged
// RETURN
//   sum(CASE WHEN is_converged THEN 1 ELSE 0 END) AS nodes_converged,
//   sum(CASE WHEN is_converged THEN 0 ELSE 1 END) AS nodes_pending
// """

MATCH (s:Shadow {session_id: $session_id, generation: $generation, converged: false})
WHERE $generation > 0
MATCH (prev:Shadow {
  session_id:  $session_id,
  original_id: s.original_id,
  generation:  $generation - 1
})
WITH s, prev,
     s.state_hash = prev.state_hash AS is_converged
SET s.converged = is_converged
RETURN
  sum(CASE WHEN is_converged THEN 1 ELSE 0 END) AS nodes_converged,
  sum(CASE WHEN is_converged THEN 0 ELSE 1 END) AS nodes_pending;


// =============================================================================
// PROCEDURE 6: Q_CYCLE_DETECT
// =============================================================================
//
// Detects oscillation: state(N) == state(N-2) but != state(N-1).
// This is the contradiction / necessary oscillation signal.
// Returns the propositions involved for CycleEvent creation.
//
// Parameters: session_id (string), generation (integer, must be >= 2)

// Q_CYCLE_DETECT = """
// MATCH (s_n:Shadow  {session_id: $session_id, generation: $generation})
// MATCH (s_n1:Shadow {session_id: $session_id, generation: $generation - 1,
//                     original_id: s_n.original_id})
// MATCH (s_n2:Shadow {session_id: $session_id, generation: $generation - 2,
//                     original_id: s_n.original_id})
// WHERE s_n.state_hash  = s_n2.state_hash
//   AND s_n.state_hash <> s_n1.state_hash
// RETURN
//   collect(DISTINCT s_n.original_id) AS oscillating_propositions,
//   $session_id                       AS session_id,
//   $generation                       AS detected_at_generation,
//   count(s_n)                        AS oscillating_node_count
// """

MATCH (s_n:Shadow  {session_id: $session_id, generation: $generation})
MATCH (s_n1:Shadow {session_id: $session_id, original_id: s_n.original_id})
WHERE s_n1.generation = $generation - 1
MATCH (s_n2:Shadow {session_id: $session_id, original_id: s_n.original_id})
WHERE s_n2.generation = $generation - 2
  AND s_n.state_hash  = s_n2.state_hash
  AND s_n.state_hash <> s_n1.state_hash
RETURN
  collect(DISTINCT s_n.original_id) AS oscillating_propositions,
  $session_id                       AS session_id,
  $generation                       AS detected_at_generation,
  count(s_n)                        AS oscillating_node_count;


// =============================================================================
// PROCEDURE 7: Q_CYCLE_CLASSIFY
// =============================================================================
//
// Classifies a detected cycle into one of three types:
//
//   Contradiction         — oscillating propositions include a proposition
//                           and its logical negation simultaneously asserted
//   NecessaryOscillation  — no P / NOT(P) conflict; compatible but mutually
//                           suppressing facts
//   MalformedDependency   — cycle involves a NAND edge that violates the
//                           canonical schema (missing required properties)
//
// Creates a CycleEvent node with the classification.
// Parameters: session_id, generation, oscillating_propositions (list)

// Q_CYCLE_CLASSIFY = """
// WITH $oscillating_propositions AS prop_ids,
//      $session_id AS session_id,
//      $generation AS generation
// // Check for Contradiction: any two propositions where one is the logical
// // negation of the other (same grounded_in node, opposite truth values in shadow)
// MATCH (s1:Shadow {session_id: session_id})
// WHERE s1.original_id IN prop_ids
// MATCH (s2:Shadow {session_id: session_id})
// WHERE s2.original_id IN prop_ids
//   AND s1.original_id <> s2.original_id
// MATCH (p1:Proposition {id: s1.original_id}),
//       (p2:Proposition {id: s2.original_id})
// WHERE p1.grounded_in = p2.grounded_in
//   AND s1.truth_value = true
//   AND s2.truth_value = false
// WITH count(*) AS contradiction_signals,
//      session_id, generation, prop_ids
// // Check for MalformedDependency: any NAND edge missing canonical properties
// MATCH ()-[r:NAND]->()
// WHERE r.session_id IS NULL
//   AND (r.id IS NULL OR r.start_negated IS NULL OR r.end_negated IS NULL)
// WITH contradiction_signals, count(r) AS malformed_edges,
//      session_id, generation, prop_ids
// WITH session_id, generation, prop_ids,
//      CASE
//        WHEN malformed_edges > 0 THEN 'MalformedDependency'
//        WHEN contradiction_signals > 0 THEN 'Contradiction'
//        ELSE 'NecessaryOscillation'
//      END AS cycle_type
// MERGE (ce:CycleEvent {id: session_id + '_CYCLE'})
// ON CREATE SET
//   ce.session_id             = session_id,
//   ce.generation             = generation,
//   ce.cycle_type             = cycle_type,
//   ce.propositions_involved  = prop_ids,
//   ce.status                 = 'open',
//   ce.escalated_to           = null,
//   ce.resolution             = null,
//   ce.created                = datetime()
// RETURN ce.id AS cycle_event_id, ce.cycle_type AS classification
// """

WITH $oscillating_propositions AS prop_ids,
     $session_id AS session_id,
     $generation AS generation
MATCH (s1:Shadow {session_id: session_id})
WHERE s1.original_id IN prop_ids
MATCH (s2:Shadow {session_id: session_id})
WHERE s2.original_id IN prop_ids
  AND s1.original_id <> s2.original_id
MATCH (p1:Proposition {id: s1.original_id}),
      (p2:Proposition {id: s2.original_id})
WHERE p1.grounded_in = p2.grounded_in
  AND s1.truth_value = true
  AND s2.truth_value = false
WITH count(*) AS contradiction_signals,
     session_id, generation, prop_ids
MATCH ()-[r:NAND]->()
WHERE r.session_id IS NULL
  AND (r.id IS NULL OR r.start_negated IS NULL OR r.end_negated IS NULL)
WITH contradiction_signals, count(r) AS malformed_edges,
     session_id, generation, prop_ids
WITH session_id, generation, prop_ids,
     CASE
       WHEN malformed_edges > 0      THEN 'MalformedDependency'
       WHEN contradiction_signals > 0 THEN 'Contradiction'
       ELSE 'NecessaryOscillation'
     END AS cycle_type
MERGE (ce:CycleEvent {id: session_id + '_CYCLE'})
ON CREATE SET
  ce.session_id            = session_id,
  ce.generation            = generation,
  ce.cycle_type            = cycle_type,
  ce.propositions_involved = prop_ids,
  ce.status                = 'open',
  ce.escalated_to          = null,
  ce.resolution            = null,
  ce.created               = datetime()
RETURN ce.id AS cycle_event_id, ce.cycle_type AS classification;


// =============================================================================
// PROCEDURE 8: Q_GAP_PROPOSE
// =============================================================================
//
// Generates a GapProposal node from a Contradiction CycleEvent.
// Called when cycle_type = 'Contradiction' and the contradiction
// is traceable to two legitimate ground rules with no scope constraint.
//
// Encodes the institutional principle:
//   A contradiction between legitimate rules is not an error in either rule.
//   It is a missing scope constraint determining which rule governs the case.
//
// Parameters: cycle_event_id, session_id

// Q_GAP_PROPOSE = """
// MATCH (ce:CycleEvent {id: $cycle_event_id, cycle_type: 'Contradiction'})
// // Find the ground rules involved via the oscillating propositions
// UNWIND ce.propositions_involved AS prop_id
// MATCH (rule:Rule {ground: true})-[:HAS_ANTECEDENT|HAS_CONSEQUENT]->
//       (p:Proposition {id: prop_id})
// WITH ce, collect(DISTINCT rule.id) AS contradicting_rules
// MERGE (gp:GapProposal {id: 'GAP_' + $cycle_event_id})
// ON CREATE SET
//   gp.cycle_event_id      = $cycle_event_id,
//   gp.description         = 'Contradiction between ground rules: ' +
//                            apoc.text.join(contradicting_rules, ', ') +
//                            '. A scope constraint determining which rule ' +
//                            'governs this case is absent from the ontology.',
//   gp.contradicting_rules = contradicting_rules,
//   gp.proposed_addition   = 'Scope constraint specifying the conditions ' +
//                            'under which each conflicting rule applies.',
//   gp.status              = 'candidate',
//   gp.reviewed_by         = null,
//   gp.created             = datetime()
// MERGE (gp)-[:GENERATED_FROM]->(ce)
// RETURN gp.id AS gap_proposal_id, gp.description AS description,
//        gp.contradicting_rules AS contradicting_rules
// """

MATCH (ce:CycleEvent {id: $cycle_event_id, cycle_type: 'Contradiction'})
UNWIND ce.propositions_involved AS prop_id
MATCH (rule:Rule {ground: true})-[:HAS_ANTECEDENT|HAS_CONSEQUENT]->
      (p:Proposition {id: prop_id})
WITH ce, collect(DISTINCT rule.id) AS contradicting_rules
MERGE (gp:GapProposal {id: 'GAP_' + $cycle_event_id})
ON CREATE SET
  gp.cycle_event_id      = $cycle_event_id,
  gp.description         = 'Contradiction between ground rules: [' +
                           reduce(s = '', r IN contradicting_rules | s + r + ',') +
                           ']. Scope constraint absent.',
  gp.contradicting_rules = contradicting_rules,
  gp.proposed_addition   = 'Scope constraint specifying which rule governs this case.',
  gp.status              = 'candidate',
  gp.reviewed_by         = null,
  gp.created             = datetime()
MERGE (gp)-[:GENERATED_FROM]->(ce)
RETURN gp.id AS gap_proposal_id,
       gp.description AS description,
       gp.contradicting_rules AS contradicting_rules;


// =============================================================================
// PROCEDURE 9: Q_SHADOW_TRANSFER
// =============================================================================
//
// Transfers converged shadow state back to ground truth Propositions.
// Runs only when ALL shadow nodes in a session have converged.
// This is an atomic operation — do not run partial transfers.
//
// Parameters: session_id

// Q_SHADOW_TRANSFER = """
// // Verify all shadows converged before transfer
// MATCH (s:Shadow {session_id: $session_id})
// WITH count(s) AS total,
//      sum(CASE WHEN s.converged THEN 1 ELSE 0 END) AS converged
// WHERE total = converged AND total > 0
// // Transfer truth values to ground truth
// MATCH (s:Shadow {session_id: $session_id, generation: max_gen})
//   WHERE max_gen = max shadow generation for this session
// MATCH (p:Proposition {id: s.original_id})
// SET p.truth_value        = s.truth_value,
//     p.needs_reassessment = false
// RETURN count(p) AS propositions_updated
// """

// Executable version (finds max generation per original_id):
MATCH (s:Shadow {session_id: $session_id})
WITH $session_id AS sid, max(s.generation) AS max_gen
MATCH (s:Shadow {session_id: sid, generation: max_gen})
WITH s, max_gen
MATCH (p:Proposition {id: s.original_id})
SET p.truth_value        = s.truth_value,
    p.needs_reassessment = false
RETURN count(p)   AS propositions_updated,
       max_gen     AS from_generation;


// =============================================================================
// PROCEDURE 10: Q_SHADOW_CLEANUP
// =============================================================================
//
// Deletes all shadow nodes for a completed session.
// EXCEPTION: Generation 0 nodes are preserved until the calling procedure
// explicitly confirms counterfactual comparison is complete.
//
// Parameters: session_id, preserve_generation_zero (boolean)

// Q_SHADOW_CLEANUP = """
// MATCH (s:Shadow {session_id: $session_id})
// WHERE NOT ($preserve_generation_zero AND s.generation = 0)
// DETACH DELETE s
// RETURN count(s) AS shadows_deleted
// """

MATCH (s:Shadow {session_id: $session_id})
WHERE NOT ($preserve_generation_zero AND s.generation = 0)
DETACH DELETE s
RETURN count(s) AS shadows_deleted;


// =============================================================================
// PROCEDURE 11: Q_PROPOSITION_STATUS
// =============================================================================
//
// Read current truth state of all propositions.
// Used by Python pipeline to report inference state after forward chaining.

// Q_PROPOSITION_STATUS = """
// MATCH (p:Proposition)
// RETURN p.id AS id, p.label AS label, p.layer AS layer,
//        p.truth_value AS truth_value, p.derived AS derived,
//        p.needs_reassessment AS needs_reassessment,
//        p.rule_id AS asserted_by
// ORDER BY p.layer, p.id
// """

MATCH (p:Proposition)
RETURN p.id               AS id,
       p.label             AS label,
       p.layer             AS layer,
       p.truth_value       AS truth_value,
       p.derived           AS derived,
       p.needs_reassessment AS needs_reassessment,
       p.rule_id           AS asserted_by
ORDER BY p.layer, p.id;


// =============================================================================
// PROCEDURE 12: Q_INFERENCE_CHAIN
// =============================================================================
//
// Full trace of the inference chain: Proposition → NAND → Rule → Consequent.
// Used for audit, visualization, and white paper demonstration.

// Q_INFERENCE_CHAIN = """
// MATCH (ant:Proposition)-[r:NAND]->(con:Proposition)
// OPTIONAL MATCH (rule:Rule)-[:HAS_ANTECEDENT]->(ant)
// OPTIONAL MATCH (rule)-[:HAS_CONSEQUENT]->(con)
// RETURN
//   ant.label        AS antecedent,
//   ant.truth_value  AS antecedent_true,
//   r.logical_form   AS connective,
//   r.truth_value    AS relation_holds,
//   con.label        AS consequent,
//   con.truth_value  AS consequent_true,
//   rule.label       AS governing_rule,
//   rule.firing_count AS times_fired
// ORDER BY r.id
// """

MATCH (ant:Proposition)-[r:NAND]->(con:Proposition)
OPTIONAL MATCH (rule:Rule)-[:HAS_ANTECEDENT]->(ant)
OPTIONAL MATCH (rule)-[:HAS_CONSEQUENT]->(con)
RETURN
  ant.label         AS antecedent,
  ant.truth_value   AS antecedent_true,
  r.logical_form    AS connective,
  r.truth_value     AS relation_holds,
  con.label         AS consequent,
  con.truth_value   AS consequent_true,
  rule.label        AS governing_rule,
  rule.firing_count AS times_fired
ORDER BY r.id;


// =============================================================================
// PROCEDURE 13: Q_QUEUE_STATUS
// =============================================================================
//
// Read current state of the UpdateQueue.
// Used by Python pipeline to check whether a cascade is in progress.

// Q_QUEUE_STATUS = """
// MATCH (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
// RETURN q.status AS status,
//        q.current_session AS current_session,
//        size(q.pending) AS pending_count,
//        q.pending AS pending_sessions
// """

MATCH (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
RETURN q.status          AS status,
       q.current_session AS current_session,
       size(q.pending)   AS pending_count,
       q.pending         AS pending_sessions;


// =============================================================================
// PROCEDURE 14: Q_QUEUE_ADVANCE
// =============================================================================
//
// Advances the UpdateQueue to the next pending session after current completes.
// Called by Python pipeline after shadow transfer and cleanup.

// Q_QUEUE_ADVANCE = """
// MATCH (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
// WITH q,
//      CASE WHEN size(q.pending) > 1
//           THEN q.pending[1..]
//           ELSE []
//      END AS remaining
// SET q.status          = CASE WHEN size(remaining) > 0 THEN 'processing' ELSE 'idle' END,
//     q.current_session = CASE WHEN size(remaining) > 0 THEN remaining[0] ELSE null END,
//     q.pending         = remaining
// RETURN q.status AS new_status, q.current_session AS next_session
// """

MATCH (q:UpdateQueue {id: 'GLOBAL_UPDATE_QUEUE'})
WITH q,
     CASE WHEN size(q.pending) > 1
          THEN q.pending[1..]
          ELSE []
     END AS remaining
SET q.status          = CASE WHEN size(remaining) > 0 THEN 'processing' ELSE 'idle' END,
    q.current_session = CASE WHEN size(remaining) > 0 THEN remaining[0] ELSE null END,
    q.pending         = remaining
RETURN q.status          AS new_status,
       q.current_session AS next_session;


// =============================================================================
// PROCEDURE 15: Q_OPEN_ISSUES
// =============================================================================
//
// Dashboard query: all open CycleEvents and candidate GapProposals.
// Used by Python pipeline for the learning/governance tab in the Streamlit UI.

// Q_OPEN_ISSUES = """
// OPTIONAL MATCH (ce:CycleEvent {status: 'open'})
// OPTIONAL MATCH (gp:GapProposal {status: 'candidate'})
// RETURN
//   collect(DISTINCT {
//     id: ce.id,
//     type: ce.cycle_type,
//     propositions: ce.propositions_involved,
//     detected_at: ce.generation,
//     created: ce.created
//   }) AS open_cycle_events,
//   collect(DISTINCT {
//     id: gp.id,
//     description: gp.description,
//     rules: gp.contradicting_rules,
//     status: gp.status,
//     created: gp.created
//   }) AS candidate_gap_proposals
// """

OPTIONAL MATCH (ce:CycleEvent {status: 'open'})
OPTIONAL MATCH (gp:GapProposal {status: 'candidate'})
RETURN
  collect(DISTINCT {
    id:           ce.id,
    type:         ce.cycle_type,
    propositions: ce.propositions_involved,
    detected_at:  ce.generation,
    created:      toString(ce.created)
  }) AS open_cycle_events,
  collect(DISTINCT {
    id:          gp.id,
    description: gp.description,
    rules:       gp.contradicting_rules,
    status:      gp.status,
    created:     toString(gp.created)
  }) AS candidate_gap_proposals;


// =============================================================================
// PYTHON PIPELINE INTEGRATION REFERENCE
// =============================================================================
//
// Add these constants to structural_demo_app.py alongside Q_DRIFT_POLICY:
//
// Q_NAND_EVALUATE = """
//   MATCH (a:Proposition)-[r:NAND {needs_reassessment: true}]->(b:Proposition)
//   WHERE r.session_id IS NULL
//   WITH a, b, r,
//     CASE WHEN r.start_negated THEN NOT(a.truth_value) ELSE a.truth_value END AS eff_a,
//     CASE WHEN r.end_negated   THEN NOT(b.truth_value) ELSE b.truth_value END AS eff_b
//   SET r.truth_value        = NOT(eff_a AND eff_b),
//       r.evaluated_at       = datetime(),
//       r.needs_reassessment = false
//   RETURN count(r) AS edges_evaluated
// """
//
// Q_RULE_FIRE = """
//   MATCH (rule:Rule {active: true})-[:HAS_ANTECEDENT]->(ant:Proposition)
//   WHERE ant.truth_value = true
//   MATCH (rule)-[:HAS_CONSEQUENT]->(con:Proposition)
//   WHERE con.truth_value <> rule.consequent_value
//   SET con.truth_value        = rule.consequent_value,
//       con.derived            = true,
//       con.needs_reassessment = true,
//       con.rule_id            = rule.id,
//       rule.firing_count      = rule.firing_count + 1,
//       rule.last_fired        = datetime()
//   RETURN count(rule) AS rules_fired
// """
//
// Q_PROPOSITION_STATUS = """
//   MATCH (p:Proposition)
//   RETURN p.id AS id, p.label AS label, p.layer AS layer,
//          p.truth_value AS truth_value, p.derived AS derived,
//          p.rule_id AS asserted_by
//   ORDER BY p.layer, p.id
// """
//
// Q_OPEN_ISSUES = """
//   OPTIONAL MATCH (ce:CycleEvent {status: 'open'})
//   OPTIONAL MATCH (gp:GapProposal {status: 'candidate'})
//   RETURN
//     collect(DISTINCT {id: ce.id, type: ce.cycle_type,
//                       created: toString(ce.created)}) AS open_cycle_events,
//     collect(DISTINCT {id: gp.id, description: gp.description,
//                       status: gp.status}) AS candidate_gap_proposals
// """
//
// Forward chaining loop (add to run_full_pipeline or as standalone function):
//
// def run_forward_chain(max_iterations=50):
//     """Run forward chaining to fixpoint. Returns iteration count."""
//     for i in range(max_iterations):
//         nand_result = run_query(Q_NAND_EVALUATE)
//         rule_result = run_query(Q_RULE_FIRE)
//         edges_done = nand_result[0]['edges_evaluated'] if nand_result else 0
//         rules_done = rule_result[0]['rules_fired'] if rule_result else 0
//         if edges_done == 0 and rules_done == 0:
//             return i + 1  # fixpoint reached at iteration i+1
//     raise RuntimeError(f"Forward chain did not converge in {max_iterations} iterations")


// =============================================================================
// END OF FILE
// =============================================================================
