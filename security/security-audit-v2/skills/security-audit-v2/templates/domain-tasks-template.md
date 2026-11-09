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
  - **Trace**: Are request body readers bounded (`io.LimitReader`)? Are pagination limits strictly capped, and does max page size × max item size fit the pod memory? Do non-streaming routes keep a deadline when streaming ones disable the timeout middleware? Are filter sizes bounded?
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

---

### Group 4: Identity Sources & Call Chain
- [ ] **TASK-{{DOMAIN_SHORT}}-09**: Map where every identity attribute and scope selector of this domain comes from.
  - **Targets**: Context/actor extraction, auth middleware, library helpers at the pinned version.
  - **Trace**: Claim, header, URL segment, body or environment default? Does an empty claim fall back to a client header? Is any partitioning key (app, workspace, project) taken from the URL without being bound to the principal? Run `templates/checklists/identity-call-chain.md`.
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

- [ ] **TASK-{{DOMAIN_SHORT}}-10**: Verify the trust claims (`00-trust-claims.md`) that concern this domain.
  - **Targets**: Every `C-xx` naming a control this domain relies on (authentication, rate limit, isolation, header stripping).
  - **Trace**: Is the control in the code or in the related repos? If it is only in the docs, file a `needs-confirmation` finding with a `settle_with` command.
  - **Status**: `[ ]`
  - **Notes / Finding ID**: 

---

## Sprint Completion Checklist
- [ ] Every task above is marked either `[x]` (verified safe) or `[!]` (vulnerable).
- [ ] For every `[!]` task, a structured finding object has been written to `findings.json`.
- [ ] For every confirmed finding, a failing PoC test file has been verified and saved to `poc-tests/`, built on the production middleware chain for identity and access findings.
- [ ] Every finding names its `hop` and `call_chain_status`; every `needs-confirmation` one has a `settle_with` command.
- [ ] A brief summary note has been written to `domain-notes.md` ending with:
  - `Coverage: <list of files and flows reviewed>`
  - `Not covered: <items outside budget or needing follow-up>`
