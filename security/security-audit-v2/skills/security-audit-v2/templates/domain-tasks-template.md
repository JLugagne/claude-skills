# Sprint Security Tasks: Domain `{{DOMAIN_NAME}}`

## Domain Information
- **Domain Name**: `{{DOMAIN_NAME}}`
- **Worktree**: `wt-{{DOMAIN_NAME}}`
- **Assigned Subagent**: `agent-{{DOMAIN_NAME}}`
- **Files In Scope**:
{{FILES_IN_SCOPE}}

---

## Sprint Objectives & Rules
1. **Stay Strictly Inside Your Domain**: Only review the files listed above. Do not wander into unrelated packages.
2. **Execute Every Task**: Work sequentially through the tasks below. Do not mark a task as completed without verifying the actual dataflow.
3. **Burden of Proof**: A vulnerability MUST have a failing PoC test (`poc-tests/`) demonstrating real exploitability before being flagged as `[!]`. Otherwise, if code is safe or mitigated, mark `[x]`.
4. **Task Status Legend**:
   - `[ ]` Not started
   - `[-]` In progress (actively tracing source-to-sink)
   - `[x]` Verified safe / properly mitigated
   - `[!]` Vulnerability confirmed & proven (Finding ID referenced)

---

## Tasks Backlog

### Group 1: Access Control & Trust Boundaries
- [ ] **TASK-{{DOMAIN_SHORT}}-01**: Verify Object-Level Authorization (BOLA/IDOR) on all domain entity IDs.
  - **Targets**: `{{DOMAIN_PRIMARY_FILES}}`
  - **Trace**: User-supplied IDs in routes/requests -> Database queries. Are tenant/user ownership checks strictly enforced?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-02**: Verify Function-Level Authorization (BFLA) and role validation.
  - **Targets**: Administrative / elevated endpoints in this domain.
  - **Trace**: Role checks on entry points. Can an unprivileged user invoke these actions?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

---

### Group 2: Input Validation, Injections & Ingestion
- [ ] **TASK-{{DOMAIN_SHORT}}-03**: Check for Path Traversal, Zip Slip & Unsafe Filesystem Operations.
  - **Targets**: Endpoints handling file paths, uploads, downloads, archive extractions.
  - **Trace**: File inputs -> `filepath.Join`, `os.Open`, `os.Create`. Are `../` and symlink escapes prevented?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-04**: Check for Injections (SQL, NoSQL, OS Command, SSTI).
  - **Targets**: Database access methods and process execution sinks.
  - **Trace**: String formatting/concatenation into SQL queries or shell commands (`exec.Command`).
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-05**: Check for SSRF & Unsafe Outbound Requests.
  - **Targets**: HTTP clients, webhook dispatchers, URL fetchers.
  - **Trace**: User-supplied URLs -> HTTP dialers. Are private IPs (RFC 1918) and cloud metadata (`169.254.169.254`) blocked post-DNS resolution?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

---

### Group 3: Domain-Specific Logic & Concurrency
- [ ] **TASK-{{DOMAIN_SHORT}}-06**: Concurrency & Race Conditions (TOCTOU, Double-Spending, State Desync).
  - **Targets**: State updates, balances, quotas, vouchers, status transitions.
  - **Trace**: Can concurrent parallel requests trigger double operations before DB rows are locked?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-07**: Mass Assignment & Excessive Data Exposure.
  - **Targets**: Request payload decoders and response serializers.
  - **Trace**: Are incoming requests bound to strict DTOs without sensitive fields? Are sensitive fields stripped from JSON responses?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-08**: Resource Limits & Denial of Service.
  - **Targets**: Request body readers, unbounded array allocations, query pagination.
  - **Trace**: Are request body readers bounded (`io.LimitReader`)? Are pagination limits strictly capped?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

---

## Sprint Completion Checklist
- [ ] Every task above is marked either `[x]` (verified safe) or `[!]` (vulnerable).
- [ ] For every `[!]` task, a structured finding object has been written to `findings.json`.
- [ ] For every confirmed finding, a failing PoC test file has been verified and saved to `poc-tests/`.
- [ ] A brief summary note has been written to `domain-notes.md` ending with:
  - `Coverage: <list of files and flows reviewed>`
  - `Not covered: <items outside budget or needing follow-up>`
