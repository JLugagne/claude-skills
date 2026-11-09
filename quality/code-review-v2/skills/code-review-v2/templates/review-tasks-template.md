# Review Tasks: `{{UNIT_NAME}}`

## Unit Information
- **Unit Name**: `{{UNIT_NAME}}`
- **Scope Mode**: `{{SCOPE_MODE}}` (full-project domain / MR diff slice)
- **Worktree**: `{{WORKTREE_PATH}}`
- **Assigned Subagent**: `agent-{{UNIT_NAME}}`
- **Files In Scope**:
{{FILES_IN_SCOPE}}

---

## Sprint Objectives & Rules
1. **Be Adversarial**: assume the code is guilty until you've traced it and found it innocent. A task
   is only `[x]` once actually verified, not skimmed.
2. **Stay Strictly Inside Your Unit**: only review the files listed above (plus the context reading
   needed to judge a diff correctly in MR scope).
3. **Burden of Proof**: every finding needs the evidence described in its dimension's checklist before
   it can be filed as `[!]`. No evidence, no finding — mark `[x]` instead.
4. **Task Status Legend**:
   - `[ ]` Not started
   - `[-]` In progress
   - `[x]` Verified clean
   - `[!]` Finding filed & written to `findings.json`

---

## Tasks Backlog

### Group 1: Memory Usage
- [ ] **TASK-{{UNIT_SHORT}}-MEM-01**: Run `templates/checklists/memory-usage.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 2: Comment Verbosity
- [ ] **TASK-{{UNIT_SHORT}}-CMT-01**: Run `templates/checklists/comments-verbosity.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 3: Naming
- [ ] **TASK-{{UNIT_SHORT}}-NAME-01**: Run `templates/checklists/naming.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 4: Architecture
- [ ] **TASK-{{UNIT_SHORT}}-ARCH-01**: Run `templates/checklists/architecture.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 5: Dead Code
- [ ] **TASK-{{UNIT_SHORT}}-DEAD-01**: Run `templates/checklists/dead-code.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 6: Missing Tests
- [ ] **TASK-{{UNIT_SHORT}}-TMISS-01**: Run `templates/checklists/tests-missing.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 7: Unnecessary Tests
- [ ] **TASK-{{UNIT_SHORT}}-TUNN-01**: Run `templates/checklists/tests-unnecessary.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 8: Adversarial Correctness
- [ ] **TASK-{{UNIT_SHORT}}-ADV-01**: Run `templates/checklists/adversarial-correctness.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 9: Persistence
- [ ] **TASK-{{UNIT_SHORT}}-PERS-01**: Run `templates/checklists/persistence.md` against the files in scope (queries, migrations, repository and unit-of-work code).
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 10: Resilience
- [ ] **TASK-{{UNIT_SHORT}}-RES-01**: Run `templates/checklists/resilience.md` against the files in scope (routers, middleware, config, adapters calling other services).
  - **Status**: `[ ]`
  - **Notes / Finding ID**:

### Group 11: Project Conventions
- [ ] **TASK-{{UNIT_SHORT}}-CONV-01**: Run `templates/checklists/project-conventions.md` against the files in scope.
  - **Status**: `[ ]`
  - **Notes / Finding ID**:
{{PROJECT_RULE_TASKS}}

---

## Sprint Completion Checklist
- [ ] Every in-scope group above is marked `[x]` (clean) or `[!]` (finding filed).
- [ ] For every `[!]` task, a structured finding object with `suggested_comment` and `proposed_action`
      has been written to `findings.json`.
- [ ] For every group without a finding, `notes.md` lists the checklist items actually traced and how
      (a zero is evidence, not a skip).
- [ ] A summary note has been written to `notes.md` ending with:
  - `Coverage: <files and dimensions audited>`
  - `Not covered: <items outside budget or needing follow-up>`
