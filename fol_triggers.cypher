// =============================================================================
// FOL TRIGGER REGISTRATION — Neo4j / APOC 5
// APOC trigger registration for the FOL Primitive Substrate
// Author: Ryan M. Williams, Ph.D.
// =============================================================================
//
// WARNING: RUN THIS FILE EXACTLY ONCE.
//   APOC triggers persist in the database after registration.
//   Running this file a second time will create duplicate triggers.
//
// NOTE ON APOC VERSION:
//   This file uses apoc.trigger.install — the correct procedure name in
//   APOC 5.x (Neo4j 5.x). The legacy apoc.trigger.add was renamed.
//   Available trigger procedures on this instance:
//     apoc.trigger.install   — register a trigger
//     apoc.trigger.drop      — remove a trigger by name
//     apoc.trigger.dropAll   — remove all triggers
//     apoc.trigger.list      — list all triggers (legacy)
//     apoc.trigger.show      — show triggers (newer)
//     apoc.trigger.start     — resume a stopped trigger
//     apoc.trigger.stop      — pause a trigger
//
// PREFLIGHT — run these before executing triggers below:
//
//   Verify no existing triggers:
//   CALL apoc.trigger.show('neo4j') YIELD name RETURN name
//
//   If triggers exist from a prior run, remove them:
//   CALL apoc.trigger.drop('neo4j', 'proposition_change_flags_nand');
//   CALL apoc.trigger.drop('neo4j', 'nand_reassessment_propagates');
//   CALL apoc.trigger.drop('neo4j', 'shadow_cascade_initiator');
//
// LOAD ORDER:
//   1. seed_ai_structural_graph.cypher
//   2. meta_ontology_logical_reification.cypher
//   3. fol_primitive_substrate.cypher
//   4. THIS FILE (once only)
//
// =============================================================================


// ═══════════════════════════════════════════════════════════════════════════════
// TRIGGER 1: Proposition truth_value change → flag incident NAND edges
// ═══════════════════════════════════════════════════════════════════════════════
//
// Fires when any Proposition.truth_value property is updated.
// Flags all incident NAND edges needs_reassessment = true.
// Only affects ground truth edges (session_id = 'ground').

CALL apoc.trigger.install(
  'neo4j',
  'proposition_change_flags_nand',
  'UNWIND $assignedNodeProperties AS prop
   WITH prop
   WHERE prop.key = "truth_value"
   MATCH (n:Proposition) WHERE id(n) = prop.node
   WITH n
   OPTIONAL MATCH (n)-[r_out:NAND]->()
   WHERE r_out.session_id = "ground"
   SET r_out.needs_reassessment = true
   WITH n
   OPTIONAL MATCH ()-[r_in:NAND]->(n)
   WHERE r_in.session_id = "ground"
   SET r_in.needs_reassessment = true',
  {phase: 'before'},
  {}
)
YIELD name, query
RETURN name, query;


// ═══════════════════════════════════════════════════════════════════════════════
// TRIGGER 2: NAND edge reassessment flag → flag connected Propositions
// ═══════════════════════════════════════════════════════════════════════════════
//
// Fires when any NAND edge needs_reassessment is set to true.
// Flags both connected Proposition nodes needs_reassessment = true.
// Only affects ground truth edges.

CALL apoc.trigger.install(
  'neo4j',
  'nand_reassessment_propagates',
  'UNWIND $assignedRelationshipProperties AS relProp
   WITH relProp
   WHERE relProp.key = "needs_reassessment" AND relProp.value = true
   MATCH (start)-[r:NAND]->(end)
   WHERE id(r) = relProp.relationship
     AND r.session_id = "ground"
   SET start.needs_reassessment = true,
       end.needs_reassessment   = true',
  {phase: 'before'},
  {}
)
YIELD name, query
RETURN name, query;


// ═══════════════════════════════════════════════════════════════════════════════
// TRIGGER 3: Proposition reassessment flag → initiate shadow cascade
// ═══════════════════════════════════════════════════════════════════════════════
//
// Fires when any Proposition.needs_reassessment is set to true.
// Creates generation 0 shadow subgraph for the cascade.
// Assigns unique session_id to isolate concurrent cascades.
// Updates the UpdateQueue with the new session.

CALL apoc.trigger.install(
  'neo4j',
  'shadow_cascade_initiator',
  'UNWIND $assignedNodeProperties AS prop
   WITH prop
   WHERE prop.key = "needs_reassessment" AND prop.value = true
   WITH apoc.create.uuid() AS session_id
   MATCH (n:Proposition {needs_reassessment: true})
   CREATE (s:Shadow {
     shadow:             true,
     original_id:        n.id,
     session_id:         session_id,
     generation:         0,
     truth_value:        n.truth_value,
     state_hash:         toString(n.truth_value),
     converged:          false,
     assumed_state_hash: toString(n.truth_value)
   })
   WITH session_id, count(s) AS shadow_count
   MATCH (q:UpdateQueue {id: "GLOBAL_UPDATE_QUEUE"})
   SET q.status          = "processing",
       q.current_session = session_id,
       q.pending         = q.pending + [session_id]',
  {phase: 'after'},
  {}
)
YIELD name, query
RETURN name, query;


// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════════

CALL apoc.trigger.show('neo4j')
YIELD name, paused
RETURN name, paused
ORDER BY name;

// Expected output:
//   nand_reassessment_propagates    | false
//   proposition_change_flags_nand   | false
//   shadow_cascade_initiator        | false


// ═══════════════════════════════════════════════════════════════════════════════
// MANAGEMENT REFERENCE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Show all triggers:
// CALL apoc.trigger.show('neo4j') YIELD name, paused RETURN name, paused
//
// Stop a trigger:
// CALL apoc.trigger.stop('neo4j', 'trigger_name')
//
// Start a stopped trigger:
// CALL apoc.trigger.start('neo4j', 'trigger_name')
//
// Drop a trigger:
// CALL apoc.trigger.drop('neo4j', 'trigger_name')
//
// Drop all triggers:
// CALL apoc.trigger.dropAll('neo4j')


// =============================================================================
// END OF FILE
// =============================================================================
