// Institutional Intelligence Architecture — Demo Graph
// Fabricated organization: Apex Manufacturing
// This single graph supports all five architectural layers:
// 1) Operational Data, 2) Ontology & Semantics,
// 3) Policy & Governance, 4) AI Interpretation,
// 5) Institutional Learning.

// ---------- Constraints ----------
CREATE CONSTRAINT person_name IF NOT EXISTS
FOR (n:Person) REQUIRE n.name IS UNIQUE;

CREATE CONSTRAINT role_name IF NOT EXISTS
FOR (n:Role) REQUIRE n.name IS UNIQUE;

CREATE CONSTRAINT dept_name IF NOT EXISTS
FOR (n:Department) REQUIRE n.name IS UNIQUE;

CREATE CONSTRAINT action_name IF NOT EXISTS
FOR (n:Action) REQUIRE n.name IS UNIQUE;

CREATE CONSTRAINT policy_id IF NOT EXISTS
FOR (n:Policy) REQUIRE n.policy_id IS UNIQUE;

CREATE CONSTRAINT concept_name IF NOT EXISTS
FOR (n:Concept) REQUIRE n.name IS UNIQUE;

CREATE CONSTRAINT alias_phrase IF NOT EXISTS
FOR (n:Alias) REQUIRE n.phrase IS UNIQUE;

CREATE CONSTRAINT resource_id IF NOT EXISTS
FOR (n:Resource) REQUIRE n.resource_id IS UNIQUE;

CREATE CONSTRAINT decision_id IF NOT EXISTS
FOR (n:Decision) REQUIRE n.decision_id IS UNIQUE;

CREATE CONSTRAINT learning_event_id IF NOT EXISTS
FOR (n:LearningEvent) REQUIRE n.event_id IS UNIQUE;

CREATE CONSTRAINT outcome_id IF NOT EXISTS
FOR (n:Outcome) REQUIRE n.outcome_id IS UNIQUE;

CREATE CONSTRAINT constraint_id IF NOT EXISTS
FOR (n:Constraint) REQUIRE n.constraint_id IS UNIQUE;

// ---------- Departments ----------
MERGE (:Department {name: 'Finance'});
MERGE (:Department {name: 'Procurement'});
MERGE (:Department {name: 'HR'});

// ---------- Roles ----------
MERGE (:Role {name: 'Manager', approval_limit: 50000, domain: 'Finance'});
MERGE (:Role {name: 'BudgetManager', approval_limit: 100000, domain: 'Finance'});
MERGE (:Role {name: 'FinanceDirector', approval_limit: 999999999, domain: 'Finance'});
MERGE (:Role {name: 'ProcurementManager', approval_limit: 50000, domain: 'Procurement'});
MERGE (:Role {name: 'HRDirector', approval_limit: 999999999, domain: 'HR'});

// ---------- People ----------
MERGE (:Person {person_id: 'P001', name: 'John Smith', status: 'active'});
MERGE (:Person {person_id: 'P002', name: 'Sarah Lee', status: 'active'});
MERGE (:Person {person_id: 'P003', name: 'Maria Chen', status: 'active'});
MERGE (:Person {person_id: 'P004', name: 'David Brown', status: 'active'});
MERGE (:Person {person_id: 'P005', name: 'Emily Stone', status: 'active'});

// ---------- Actions ----------
MERGE (:Action {name: 'ApprovePayment', category: 'Finance'});
MERGE (:Action {name: 'ApproveContract', category: 'Procurement'});
MERGE (:Action {name: 'ReviewContract', category: 'Procurement'});
MERGE (:Action {name: 'ViewEmployeeRecord', category: 'HR'});
MERGE (:Action {name: 'TerminateEmployee', category: 'HR'});

// ---------- Resources ----------
MERGE (:Resource {
  resource_id: 'Invoice_A113',
  type: 'Invoice',
  name: 'ACME Supplies Invoice A113',
  amount: 120000,
  vendor: 'ACME Supplies',
  classification: 'standard'
});

MERGE (:Resource {
  resource_id: 'Invoice_B210',
  type: 'Invoice',
  name: 'BoltWorks Invoice B210',
  amount: 40000,
  vendor: 'BoltWorks',
  classification: 'standard'
});

MERGE (:Resource {
  resource_id: 'Contract_C201',
  type: 'VendorContract',
  name: 'ACME Vendor Contract C201',
  amount: 80000,
  vendor: 'ACME Supplies',
  classification: 'commercial'
});

MERGE (:Resource {
  resource_id: 'EmployeeRecord_E77',
  type: 'EmployeeRecord',
  name: 'Employee Record E77',
  amount: 0,
  vendor: '',
  classification: 'confidential'
});

// ---------- Organizational Structure ----------
MATCH (p:Person {name: 'John Smith'}), (r:Role {name: 'Manager'})
MERGE (p)-[:HAS_ROLE]->(r);
MATCH (p:Person {name: 'Sarah Lee'}), (r:Role {name: 'ProcurementManager'})
MERGE (p)-[:HAS_ROLE]->(r);
MATCH (p:Person {name: 'Maria Chen'}), (r:Role {name: 'FinanceDirector'})
MERGE (p)-[:HAS_ROLE]->(r);
MATCH (p:Person {name: 'David Brown'}), (r:Role {name: 'HRDirector'})
MERGE (p)-[:HAS_ROLE]->(r);
MATCH (p:Person {name: 'Emily Stone'}), (r:Role {name: 'BudgetManager'})
MERGE (p)-[:HAS_ROLE]->(r);

MATCH (p:Person {name: 'John Smith'}), (d:Department {name: 'Finance'})
MERGE (p)-[:IN_DEPARTMENT]->(d);
MATCH (p:Person {name: 'Sarah Lee'}), (d:Department {name: 'Procurement'})
MERGE (p)-[:IN_DEPARTMENT]->(d);
MATCH (p:Person {name: 'Maria Chen'}), (d:Department {name: 'Finance'})
MERGE (p)-[:IN_DEPARTMENT]->(d);
MATCH (p:Person {name: 'David Brown'}), (d:Department {name: 'HR'})
MERGE (p)-[:IN_DEPARTMENT]->(d);
MATCH (p:Person {name: 'Emily Stone'}), (d:Department {name: 'Finance'})
MERGE (p)-[:IN_DEPARTMENT]->(d);

MATCH (r:Role {name: 'Manager'}), (d:Department {name: 'Finance'})
MERGE (r)-[:BELONGS_TO]->(d);
MATCH (r:Role {name: 'BudgetManager'}), (d:Department {name: 'Finance'})
MERGE (r)-[:BELONGS_TO]->(d);
MATCH (r:Role {name: 'FinanceDirector'}), (d:Department {name: 'Finance'})
MERGE (r)-[:BELONGS_TO]->(d);
MATCH (r:Role {name: 'ProcurementManager'}), (d:Department {name: 'Procurement'})
MERGE (r)-[:BELONGS_TO]->(d);
MATCH (r:Role {name: 'HRDirector'}), (d:Department {name: 'HR'})
MERGE (r)-[:BELONGS_TO]->(d);

MATCH (res:Resource {resource_id: 'Invoice_A113'}), (d:Department {name: 'Finance'})
MERGE (res)-[:OWNED_BY]->(d);
MATCH (res:Resource {resource_id: 'Invoice_B210'}), (d:Department {name: 'Finance'})
MERGE (res)-[:OWNED_BY]->(d);
MATCH (res:Resource {resource_id: 'Contract_C201'}), (d:Department {name: 'Procurement'})
MERGE (res)-[:OWNED_BY]->(d);
MATCH (res:Resource {resource_id: 'EmployeeRecord_E77'}), (d:Department {name: 'HR'})
MERGE (res)-[:OWNED_BY]->(d);

// ---------- Action Targets ----------
MATCH (a:Action {name: 'ApprovePayment'}), (res:Resource {resource_id: 'Invoice_A113'})
MERGE (a)-[:TARGETS]->(res);
MATCH (a:Action {name: 'ApprovePayment'}), (res:Resource {resource_id: 'Invoice_B210'})
MERGE (a)-[:TARGETS]->(res);
MATCH (a:Action {name: 'ApproveContract'}), (res:Resource {resource_id: 'Contract_C201'})
MERGE (a)-[:TARGETS]->(res);
MATCH (a:Action {name: 'ReviewContract'}), (res:Resource {resource_id: 'Contract_C201'})
MERGE (a)-[:TARGETS]->(res);
MATCH (a:Action {name: 'ViewEmployeeRecord'}), (res:Resource {resource_id: 'EmployeeRecord_E77'})
MERGE (a)-[:TARGETS]->(res);

// ---------- Role Capabilities ----------
MATCH (r:Role {name: 'Manager'}), (a:Action {name: 'ApprovePayment'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'BudgetManager'}), (a:Action {name: 'ApprovePayment'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'FinanceDirector'}), (a:Action {name: 'ApprovePayment'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'ProcurementManager'}), (a:Action {name: 'ReviewContract'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'ProcurementManager'}), (a:Action {name: 'ApproveContract'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'HRDirector'}), (a:Action {name: 'ViewEmployeeRecord'})
MERGE (r)-[:MAY_PERFORM]->(a);
MATCH (r:Role {name: 'HRDirector'}), (a:Action {name: 'TerminateEmployee'})
MERGE (r)-[:MAY_PERFORM]->(a);

// ---------- Concepts (Ontology Layer) ----------
MERGE (:Concept {name: 'Entity', kind: 'root'});
MERGE (:Concept {name: 'Actor', kind: 'class'});
MERGE (:Concept {name: 'PersonConcept', kind: 'class'});
MERGE (:Concept {name: 'InstitutionalRole', kind: 'class'});
MERGE (:Concept {name: 'ManagerConcept', kind: 'class'});
MERGE (:Concept {name: 'BudgetManagerConcept', kind: 'class'});
MERGE (:Concept {name: 'FinanceDirectorConcept', kind: 'class'});
MERGE (:Concept {name: 'ProcurementManagerConcept', kind: 'class'});
MERGE (:Concept {name: 'HRDirectorConcept', kind: 'class'});
MERGE (:Concept {name: 'InstitutionalAction', kind: 'class'});
MERGE (:Concept {name: 'PaymentApprovalConcept', kind: 'class'});
MERGE (:Concept {name: 'ContractApprovalConcept', kind: 'class'});
MERGE (:Concept {name: 'ContractReviewConcept', kind: 'class'});
MERGE (:Concept {name: 'HRRecordAccessConcept', kind: 'class'});
MERGE (:Concept {name: 'InstitutionalResource', kind: 'class'});
MERGE (:Concept {name: 'InvoiceConcept', kind: 'class'});
MERGE (:Concept {name: 'VendorContractConcept', kind: 'class'});
MERGE (:Concept {name: 'EmployeeRecordConcept', kind: 'class'});

// ---------- Ontology Hierarchy ----------
MATCH (c1:Concept {name: 'Actor'}), (c2:Concept {name: 'Entity'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'PersonConcept'}), (c2:Concept {name: 'Actor'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'InstitutionalRole'}), (c2:Concept {name: 'Entity'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'ManagerConcept'}), (c2:Concept {name: 'InstitutionalRole'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'BudgetManagerConcept'}), (c2:Concept {name: 'InstitutionalRole'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'FinanceDirectorConcept'}), (c2:Concept {name: 'InstitutionalRole'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'ProcurementManagerConcept'}), (c2:Concept {name: 'InstitutionalRole'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'HRDirectorConcept'}), (c2:Concept {name: 'InstitutionalRole'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'InstitutionalAction'}), (c2:Concept {name: 'Entity'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'PaymentApprovalConcept'}), (c2:Concept {name: 'InstitutionalAction'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'ContractApprovalConcept'}), (c2:Concept {name: 'InstitutionalAction'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'ContractReviewConcept'}), (c2:Concept {name: 'InstitutionalAction'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'HRRecordAccessConcept'}), (c2:Concept {name: 'InstitutionalAction'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'InstitutionalResource'}), (c2:Concept {name: 'Entity'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'InvoiceConcept'}), (c2:Concept {name: 'InstitutionalResource'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'VendorContractConcept'}), (c2:Concept {name: 'InstitutionalResource'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);
MATCH (c1:Concept {name: 'EmployeeRecordConcept'}), (c2:Concept {name: 'InstitutionalResource'})
MERGE (c1)-[:SUBCLASS_OF]->(c2);

// ---------- Aliases (LLM Interpretation Layer) ----------
MERGE (:Alias {phrase: 'manager'});
MERGE (:Alias {phrase: 'budget owner'});
MERGE (:Alias {phrase: 'finance lead'});
MERGE (:Alias {phrase: 'push this through'});
MERGE (:Alias {phrase: 'sign off'});
MERGE (:Alias {phrase: 'greenlight'});
MERGE (:Alias {phrase: 'take care of'});
MERGE (:Alias {phrase: 'see employee file'});

MATCH (a:Alias {phrase: 'manager'}), (c:Concept {name: 'ManagerConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'budget owner'}), (c:Concept {name: 'BudgetManagerConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'finance lead'}), (c:Concept {name: 'FinanceDirectorConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'push this through'}), (c:Concept {name: 'ContractApprovalConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'sign off'}), (c:Concept {name: 'PaymentApprovalConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'greenlight'}), (c:Concept {name: 'PaymentApprovalConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'take care of'}), (c:Concept {name: 'ContractReviewConcept'})
MERGE (a)-[:MAPS_TO]->(c);
MATCH (a:Alias {phrase: 'see employee file'}), (c:Concept {name: 'HRRecordAccessConcept'})
MERGE (a)-[:MAPS_TO]->(c);

// ---------- Instance-to-Concept Mapping ----------
MATCH (r:Role {name: 'Manager'}), (c:Concept {name: 'ManagerConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Role {name: 'BudgetManager'}), (c:Concept {name: 'BudgetManagerConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Role {name: 'FinanceDirector'}), (c:Concept {name: 'FinanceDirectorConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Role {name: 'ProcurementManager'}), (c:Concept {name: 'ProcurementManagerConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Role {name: 'HRDirector'}), (c:Concept {name: 'HRDirectorConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);

MATCH (a:Action {name: 'ApprovePayment'}), (c:Concept {name: 'PaymentApprovalConcept'})
MERGE (a)-[:INSTANCE_OF]->(c);
MATCH (a:Action {name: 'ApproveContract'}), (c:Concept {name: 'ContractApprovalConcept'})
MERGE (a)-[:INSTANCE_OF]->(c);
MATCH (a:Action {name: 'ReviewContract'}), (c:Concept {name: 'ContractReviewConcept'})
MERGE (a)-[:INSTANCE_OF]->(c);
MATCH (a:Action {name: 'ViewEmployeeRecord'}), (c:Concept {name: 'HRRecordAccessConcept'})
MERGE (a)-[:INSTANCE_OF]->(c);

MATCH (r:Resource {resource_id: 'Invoice_A113'}), (c:Concept {name: 'InvoiceConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Resource {resource_id: 'Invoice_B210'}), (c:Concept {name: 'InvoiceConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Resource {resource_id: 'Contract_C201'}), (c:Concept {name: 'VendorContractConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);
MATCH (r:Resource {resource_id: 'EmployeeRecord_E77'}), (c:Concept {name: 'EmployeeRecordConcept'})
MERGE (r)-[:INSTANCE_OF]->(c);

// ---------- Constraints ----------
MERGE (:Constraint {
  constraint_id: 'C001',
  type: 'amount_threshold',
  operator: '>',
  value: 100000,
  unit: 'USD'
});

MERGE (:Constraint {
  constraint_id: 'C002',
  type: 'amount_threshold',
  operator: '>',
  value: 50000,
  unit: 'USD'
});

MERGE (:Constraint {
  constraint_id: 'C003',
  type: 'classification_equals',
  operator: '=',
  value: 'confidential',
  unit: 'classification'
});

MERGE (:Constraint {
  constraint_id: 'C004',
  type: 'role_limit',
  operator: '<=',
  value: 50000,
  unit: 'USD'
});

MERGE (:Constraint {
  constraint_id: 'C005',
  type: 'role_limit',
  operator: '<=',
  value: 100000,
  unit: 'USD'
});

MATCH (r:Role {name: 'Manager'}), (c:Constraint {constraint_id: 'C004'})
MERGE (r)-[:HAS_LIMIT]->(c);
MATCH (r:Role {name: 'BudgetManager'}), (c:Constraint {constraint_id: 'C005'})
MERGE (r)-[:HAS_LIMIT]->(c);

// ---------- Policies ----------
MERGE (:Policy {
  policy_id: 'P001',
  name: 'HighValuePaymentPolicy',
  description: 'Payments above $100,000 require FinanceDirector approval.',
  active: true
});

MERGE (:Policy {
  policy_id: 'P002',
  name: 'ContractApprovalPolicy',
  description: 'Contracts above $50,000 require ProcurementManager approval.',
  active: true
});

MERGE (:Policy {
  policy_id: 'P003',
  name: 'HRAccessPolicy',
  description: 'Confidential employee records require HRDirector access.',
  active: true
});

MATCH (p:Policy {policy_id: 'P001'}), (a:Action {name: 'ApprovePayment'})
MERGE (p)-[:GOVERNS]->(a);
MATCH (p:Policy {policy_id: 'P002'}), (a:Action {name: 'ApproveContract'})
MERGE (p)-[:GOVERNS]->(a);
MATCH (p:Policy {policy_id: 'P003'}), (a:Action {name: 'ViewEmployeeRecord'})
MERGE (p)-[:GOVERNS]->(a);

MATCH (p:Policy {policy_id: 'P001'}), (c:Constraint {constraint_id: 'C001'})
MERGE (p)-[:HAS_CONSTRAINT]->(c);
MATCH (p:Policy {policy_id: 'P002'}), (c:Constraint {constraint_id: 'C002'})
MERGE (p)-[:HAS_CONSTRAINT]->(c);
MATCH (p:Policy {policy_id: 'P003'}), (c:Constraint {constraint_id: 'C003'})
MERGE (p)-[:HAS_CONSTRAINT]->(c);

MATCH (p:Policy {policy_id: 'P001'}), (r:Role {name: 'FinanceDirector'})
MERGE (p)-[:APPLIES_TO]->(r);
MATCH (p:Policy {policy_id: 'P002'}), (r:Role {name: 'ProcurementManager'})
MERGE (p)-[:APPLIES_TO]->(r);
MATCH (p:Policy {policy_id: 'P003'}), (r:Role {name: 'HRDirector'})
MERGE (p)-[:APPLIES_TO]->(r);

MATCH (c:Constraint {constraint_id: 'C001'}), (a:Action {name: 'ApprovePayment'})
MERGE (c)-[:LIMITS]->(a);
MATCH (c:Constraint {constraint_id: 'C002'}), (a:Action {name: 'ApproveContract'})
MERGE (c)-[:LIMITS]->(a);
MATCH (c:Constraint {constraint_id: 'C003'}), (r:Resource {resource_id: 'EmployeeRecord_E77'})
MERGE (c)-[:LIMITS_RESOURCE]->(r);

// ---------- Outcomes ----------
MERGE (:Outcome {outcome_id: 'O001', name: 'Approved', impact: 'positive'});
MERGE (:Outcome {outcome_id: 'O002', name: 'Escalated', impact: 'neutral'});
MERGE (:Outcome {outcome_id: 'O003', name: 'Denied', impact: 'negative'});
MERGE (:Outcome {outcome_id: 'O004', name: 'ReviewedOnly', impact: 'neutral'});

// ---------- Decisions (Learning Layer Seed) ----------
MERGE (:Decision {
  decision_id: 'D001',
  timestamp: datetime('2026-03-01T09:00:00'),
  status: 'escalated',
  reason: 'Manager exceeds approval threshold for high-value payment.',
  request_text: 'Can John approve the ACME invoice for $120,000?'
});

MERGE (:Decision {
  decision_id: 'D002',
  timestamp: datetime('2026-03-03T10:30:00'),
  status: 'escalated',
  reason: 'BudgetManager exceeds approval threshold for high-value payment.',
  request_text: 'Can Emily sign off on the ACME invoice for $120,000?'
});

MERGE (:Decision {
  decision_id: 'D003',
  timestamp: datetime('2026-03-04T14:45:00'),
  status: 'denied',
  reason: 'Confidential employee records require HRDirector access.',
  request_text: 'Can Sarah see employee file E77?'
});

MERGE (:Decision {
  decision_id: 'D004',
  timestamp: datetime('2026-03-06T08:15:00'),
  status: 'approved',
  reason: 'FinanceDirector is authorized for high-value payment approvals.',
  request_text: 'Can Maria approve the ACME invoice for $120,000?'
});

MATCH (d:Decision {decision_id: 'D001'}), (p:Person {name: 'John Smith'})
MERGE (d)-[:MADE_BY]->(p);
MATCH (d:Decision {decision_id: 'D001'}), (a:Action {name: 'ApprovePayment'})
MERGE (d)-[:ABOUT_ACTION]->(a);
MATCH (d:Decision {decision_id: 'D001'}), (r:Resource {resource_id: 'Invoice_A113'})
MERGE (d)-[:ABOUT_RESOURCE]->(r);
MATCH (d:Decision {decision_id: 'D001'}), (o:Outcome {outcome_id: 'O002'})
MERGE (d)-[:RESULTED_IN]->(o);
MATCH (d:Decision {decision_id: 'D001'}), (p:Policy {policy_id: 'P001'})
MERGE (d)-[:TRIGGERED_POLICY]->(p);

MATCH (d:Decision {decision_id: 'D002'}), (p:Person {name: 'Emily Stone'})
MERGE (d)-[:MADE_BY]->(p);
MATCH (d:Decision {decision_id: 'D002'}), (a:Action {name: 'ApprovePayment'})
MERGE (d)-[:ABOUT_ACTION]->(a);
MATCH (d:Decision {decision_id: 'D002'}), (r:Resource {resource_id: 'Invoice_A113'})
MERGE (d)-[:ABOUT_RESOURCE]->(r);
MATCH (d:Decision {decision_id: 'D002'}), (o:Outcome {outcome_id: 'O002'})
MERGE (d)-[:RESULTED_IN]->(o);
MATCH (d:Decision {decision_id: 'D002'}), (p:Policy {policy_id: 'P001'})
MERGE (d)-[:TRIGGERED_POLICY]->(p);

MATCH (d:Decision {decision_id: 'D003'}), (p:Person {name: 'Sarah Lee'})
MERGE (d)-[:MADE_BY]->(p);
MATCH (d:Decision {decision_id: 'D003'}), (a:Action {name: 'ViewEmployeeRecord'})
MERGE (d)-[:ABOUT_ACTION]->(a);
MATCH (d:Decision {decision_id: 'D003'}), (r:Resource {resource_id: 'EmployeeRecord_E77'})
MERGE (d)-[:ABOUT_RESOURCE]->(r);
MATCH (d:Decision {decision_id: 'D003'}), (o:Outcome {outcome_id: 'O003'})
MERGE (d)-[:RESULTED_IN]->(o);
MATCH (d:Decision {decision_id: 'D003'}), (p:Policy {policy_id: 'P003'})
MERGE (d)-[:TRIGGERED_POLICY]->(p);

MATCH (d:Decision {decision_id: 'D004'}), (p:Person {name: 'Maria Chen'})
MERGE (d)-[:MADE_BY]->(p);
MATCH (d:Decision {decision_id: 'D004'}), (a:Action {name: 'ApprovePayment'})
MERGE (d)-[:ABOUT_ACTION]->(a);
MATCH (d:Decision {decision_id: 'D004'}), (r:Resource {resource_id: 'Invoice_A113'})
MERGE (d)-[:ABOUT_RESOURCE]->(r);
MATCH (d:Decision {decision_id: 'D004'}), (o:Outcome {outcome_id: 'O001'})
MERGE (d)-[:RESULTED_IN]->(o);
MATCH (d:Decision {decision_id: 'D004'}), (p:Policy {policy_id: 'P001'})
MERGE (d)-[:TRIGGERED_POLICY]->(p);

// ---------- Learning Events ----------
MERGE (:LearningEvent {
  event_id: 'L001',
  name: 'RepeatedHighValuePaymentEscalation',
  count: 2,
  pattern_type: 'repeated_escalation',
  recommendation: 'Consider clarifying payment authority language or revising approval routing for requests above $100,000.'
});

MERGE (:LearningEvent {
  event_id: 'L002',
  name: 'AmbiguousApprovalLanguage',
  count: 3,
  pattern_type: 'semantic_ambiguity',
  recommendation: 'Normalize phrases like sign off and push this through into canonical action intents before policy checking.'
});

MATCH (l:LearningEvent {event_id: 'L001'}), (d:Decision {decision_id: 'D001'})
MERGE (l)-[:DERIVED_FROM]->(d);
MATCH (l:LearningEvent {event_id: 'L001'}), (d:Decision {decision_id: 'D002'})
MERGE (l)-[:DERIVED_FROM]->(d);
MATCH (l:LearningEvent {event_id: 'L001'}), (p:Policy {policy_id: 'P001'})
MERGE (l)-[:SUGGESTS_CHANGE_TO]->(p);

MATCH (l:LearningEvent {event_id: 'L002'}), (p:Policy {policy_id: 'P001'})
MERGE (l)-[:SUGGESTS_CHANGE_TO]->(p);
MATCH (l:LearningEvent {event_id: 'L002'}), (p:Policy {policy_id: 'P002'})
MERGE (l)-[:SUGGESTS_CHANGE_TO]->(p);

// ---------- Optional demo issue node: incomplete operational record ----------
// This node intentionally exists without a direct role linkage to show Demo 1 fragility.
MERGE (:Person {person_id: 'P999', name: 'John Placeholder', status: 'active'});

RETURN 'Institutional Intelligence Architecture demo graph seeded successfully.' AS status;
