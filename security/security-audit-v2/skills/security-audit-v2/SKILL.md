---
name: security-audit-v2
description: Perform a comprehensive, domain-driven white-box security audit of a codebase — upfront interactive scope negotiation, functional domain slicing with sprint task backlogs, multi-agent scaling rules, isolated git worktrees, failing PoC tests for proof, attack chain analysis, and state-of-the-art HTML and Markdown executive reports under .security-audit/.
author: JLugagne
---

# Security Audit v2 — Domain-Driven Security Assessment Engine

## Objective

Perform a rigorous, structured white-box security audit of a codebase. Identify real, exploitable
vulnerabilities — not theoretical static analysis noise — and prove each finding with a failing test
before reporting it.

Key deliverables produced for each run:
1. **Scope & Preconditions Agreement** (`00-scope.md`): negotiated upfront with the user to filter noise (secrets, dev configs, etc.).
2. **Domain Sprint Backlogs & Notes** (`domains/<domain>/tasks.md`): exhaustive checklist-driven verification per functional domain.
3. **Structured Finding List & PoCs** (`poc-tests/`, `findings.json`): proven vulnerabilities with CVSS v3.1 scores, reproducibility state, and reachability.
4. **State-of-the-Art HTML Report** (`report.html`): executive-grade, interactive, filterable report with KPIs, CVSS tables, reproducibility badges, and Mermaid attack chains.
5. **Full Markdown Report** (`full-report.md`) and **Executive Summary** (`summary.md`).

**Golden Rule:** Leave the repository untouched. Every artifact lives in `.security-audit/<run>/` or in isolated git worktrees torn down upon completion. Never commit to the user's branch or modify tracked files outside a worktree.

---

## Phase 0 — Setup & Upfront Scope Negotiation

### 1. Run Initialization
1. Create a timestamped output directory at `.security-audit/<YYYY-MM-DD-HHMM>/`. Never overwrite previous runs.
2. Identify the project profile: languages, frameworks, entry points (REST, gRPC, CLI, queue consumers), authentication mechanisms, storage, and external integrations.
3. Record the reviewed ref (commit SHA, branch) and the recent commit history (~50 commits) in `00-profile.md`.

### 2. Upfront Interactive Scope Negotiation (Noise Filter)
**MANDATORY STEP**: Before dispatching any subagent or generating domain tasks, the lead orchestrator MUST pause and query the user to establish the audit boundaries. Many automated passes generate excessive noise on harmless dev fixtures or test keys.

Ask the user the following specific scoping questions:
1. **Secrets Policy**:
   - `Exclude`: Ignore hardcoded secrets entirely (prevents noise from test tokens, mock credentials, local dev keys).
   - `Production-Only`: Only flag high-entropy credentials located strictly within shipped production code.
   - `Exhaustive`: Audit all files including `.env`, configs, and tests for credentials.
2. **Default & Development Configurations**:
   - `Production Surface Only`: Ignore `docker-compose.dev.yml`, test fixtures, seeds, local dev flags, and examples.
   - `Include Dev & IaC`: Audit local compose files, development flags, and container configurations.
3. **Infrastructure & CI/CD Pipelines**:
   - `Application Code Only`: Focus purely on business logic, APIs, and application code.
   - `Include CI/CD`: Audit GitHub Actions (`.github/workflows/`), Dockerfiles, and deployment manifests.
4. **Domain Inclusions / Exclusions**:
   - Present the detected functional domains (e.g. `auth`, `payment`, `api`, `core`) and ask if any specific module should be prioritized or excluded.

Record the agreed boundaries in `.security-audit/<run>/00-scope.md`. Every subagent dispatched in Phase 1 is bound by these rules.

---

## Phase 0.5 — Domain Slicing, Scaling Rules & Sprint Backlog

Instead of dispatching agents by arbitrary technical categories across the whole codebase (which causes context dispersion and duplicate work), the codebase is partitioned into **Functional & Architectural Domains**.

### 1. Functional Domain Identification
Derive domains from the codebase architecture:
- `auth`: authentication, session management, OAuth/OIDC, tokens, RBAC, authorization middleware.
- `payment` / `billing`: checkout, payment gateways, ledger, balances, refunds, webhooks, idempotency.
- `traversal-filesystem`: file upload/download, document exports, archive extraction, file storage.
- `api-integrations`: public/internal REST, GraphQL, gRPC endpoints, third-party integrations, SSRF vectors.
- `core-engine` / `data`: core business computation, state machines, parsers, DB queries, memory management.
- *Additional domains as detected* (e.g. `ai-llm`, `admin-backoffice`).

### 2. Multi-Agent Scaling & Splitting Rules
If a codebase or domain is too large, an agent will suffer from context exhaustion and shallow reviews.
**Apply the following threshold rules to split a domain into multiple sub-domains**:
- **File Count Threshold**: Domain exceeds **> 20 source files** (excluding tests/vendor).
- **Code Volume Threshold**: Domain exceeds **> 5,000 lines of code** of core logic.
- **Backlog Task Threshold**: Generated checklist exceeds **> 10 verification tasks**.
- **Multi-Protocol / Flow Separation**: Domain mixes distinct workflows (e.g., in `payment`: Checkout Gateway vs Webhooks & Ledger; in `auth`: Session Tokens vs RBAC/BOLA).

**Splitting Action**:
Subdivide into disjoint sub-domains (e.g. `domains/auth-tokens/` and `domains/auth-rbac/`).
- Assign strictly non-overlapping file lists to each sub-domain.
- Keep each sub-agent's backlog between **5 and 8 tasks**.

### 3. Sprint Folder & Backlog Generation
For each domain (or sub-domain), create:
`.security-audit/<run>/domains/<domain>/`
- `domain-profile.md`: boundaries, files in scope, entry points, trust assumptions.
- `tasks.md`: the sprint task backlog generated from `templates/domain-tasks-template.md` and populated with relevant checks from `templates/checklists/`:
  - `auth-access.md` (BOLA, BFLA, tokens, session, multi-tenancy)
  - `payment-financial.md` (race conditions, double-spend, webhooks, float precision)
  - `traversal-filesystem.md` (path traversal, Zip Slip, file read/write, uploads)
  - `rce-execution.md` (OS command injection, argument injection, deserialization, SSTI, eval)
  - `web-api-protocols.md` (SSRF/IMDS, CSRF, CORS, SQLi/NoSQLi, XSS, Mass Assignment, GraphQL)
  - `memory-concurrency.md` (double-free, UAF, buffer overflows, data races, unsafe blocks)
  - `dos-resources.md` (AppDoS, slowloris timeouts, amplification, query cascades, ReDoS, memory limits)
  - `predictability-enumeration.md` (sequential IDs, UUID v1 predictability, user harvesting, timing enumeration)
  - `crypto-secrets.md` (weak crypto, PRNG, timing attacks, log leaks)
  - `business-logic.md` (workflow bypass, state machine manipulation, quota bypass)
  - `ai-llm.md` (prompt injection, tool calling authorization, model-to-sink)
  - `cicd-infra.md` (workflow injection, pull_request_target, pprof/actuator)

### 4. Git Worktree Isolation
Create an isolated git worktree per domain agent:
```bash
git worktree add .security-audit/<run>/wt-<domain> HEAD
```

---

## Phase 1 — Domain-Isolated Subagent Execution (Sprint Tracks)

Dispatch one subagent per domain (or sub-domain), operating strictly inside its worktree `wt-<domain>`.

### Subagent Rules of Engagement
1. **Work Strictly Within Your Domain**: Focus exclusively on the files assigned in `domain-profile.md`. Do not audit code owned by other domain agents.
2. **Execute the Sprint Backlog**: Work sequentially through `tasks.md`. For each task:
   - Trace data flow from untrusted source to sensitive sink.
   - If proven safe or mitigated, mark `[x]` with notes.
   - If a vulnerability is found, prove it with a failing PoC test before marking `[!]`.
3. **Burden of Proof & PoC Tests**:
   - Write a unit or integration test that **FAILS** while the vulnerability exists and **PASSES** once patched.
   - Tests run strictly against localhost, mocks, or local test DBs. Never perform external network calls.
4. **Output Requirements**:
   - Update `tasks.md` with status (`[x]` or `[!]`).
   - Write structured findings to `domains/<domain>/findings.json` complying with `templates/finding-schema.json`.
   - Write a human-readable note in `domains/<domain>/notes.md` ending with:
     - `Coverage: <files and flows audited>`
     - `Not covered: <items skipped due to budget>`

---

## Phase 1.5 — Composed-System & Inter-Domain Seam Agent

Dispatch an independent agent in parallel in its own worktree `wt-composed-system` to audit the system as **assembled**:
- Test end-to-end nominal flows across domain seams (e.g. `signup -> login -> payment checkout -> webhook callback -> data access`).
- Check for cross-domain inconsistencies (e.g. domain A validates tenant ID differently than domain B).
- Walk flows with real HTTP client / cookie jar, testing session lifecycles, state transitions, and step-skipping.
- Output: `findings/composed-system.json` and `findings/composed-system.md`.

---

## Phase 2 — Attack Chain Analysis

Spawn a read-only agent to analyze combinations of findings:
- Load all findings from `domains/*/findings.json` and `composed-system.json`, including theoretical ones — a weak link can complete a chain.
- Load `deployment_preconditions` and `requires_wiring`. Findings whose preconditions are mutually exclusive cannot chain; findings where one opens the door to another usually do.
- Identify multi-stage combinations producing impact greater than any single issue (e.g. Info Leak of token -> used in BOLA/IDOR -> enables SSRF -> reaches internal admin RCE).
- For each viable chain, produce:
  - Narrative with step-by-step compromise: entry point -> pivot steps -> final impact.
  - Combined severity assessment and required preconditions.
  - Mermaid `sequenceDiagram` showing attacker, system components, and messages with finding references.
  - The single "break-the-chain" remediation that neutralizes the path at lowest cost.
- Explicitly record combinations **considered and rejected** with the reason (showing the search was real).
- Output: `.security-audit/<run>/attack-chains.md`.

---

## Phase 3 — Adversarial Verification & Cleanup

1. **Adversarial Verification Agent**:
   - Create a clean verification worktree.
   - Re-run every `confirmed` finding's PoC test. If a PoC does not compile or fail-to-prove, downgrade to `likely` or `theoretical`.
   - Validate `production_reachable` claims against the source:
     - `yes`: reachable in default production configuration.
     - `only-if-configured`: reachable only if non-default flag/env is set.
     - `no`: exists only in test/dev surface.
   - Write `.security-audit/<run>/verification.md`.
2. **Cleanup**:
   - Copy validated PoC tests to `.security-audit/<run>/poc-tests/`.
   - Remove all git worktrees (`git worktree remove`).

---

## Phase 4 — Deliverables Generation

The consolidation agent generates four official deliverables:

### 1. `report.html` (State-of-the-Art Executive Report)
Generate the main HTML report using `templates/report-template.html`:
- Populate executive KPI counters (Total, Critical, High, Medium, Confirmed PoCs).
- Summarize negotiated Phase 0 scope in the scope box.
- Generate the **Vulnerability Index Table**:
  - Columns: ID, Title & File, Domain, CVSS v3.1 Score (color badge), **Reproducibility Status** (`confirmed`, `likely`, `theoretical`), Reachability (`Default Deploy`, `Only If Configured`, `Dev Only`), Details Link.
  - Interactive client-side filters for severity and reproducibility.
- Generate **Detailed Finding Cards**:
  - CWE, OWASP, Domain, CVSS Vector, Reachability.
  - Description, Impact, and Source-to-Sink Dataflow.
  - PoC Box: exact reproduction command and test code snippet.
  - Preconditions and Required Wiring.
  - Remediation with code diff.
- Embed attack chain summary with a prominent button linking to `attack-chains.html`.
- Embed Domain Sprint checklist completion summary.

### 2. `attack-chains.html` (Dedicated Interactive Attack Chains Report)
Generate a separate, dedicated HTML report using `templates/attack-chains-template.html`:
- Top navigation with quick return link to `report.html`.
- Chain KPI metrics (viable chains count, max combined impact, findings involved).
- Dedicated interactive cards for each attack scenario:
  - Step-by-step narrative and precondition verification.
  - Dynamic Mermaid.js sequence diagram rendering.
  - Involved finding badges linking to finding IDs.
  - Targeted "break-the-chain" remediation strategy.
- Dedicated section detailing investigated combinations that were ruled out and why.

### 3. `full-report.md`
Markdown format with index table, detailed findings grouped by severity, attack chains, and coverage appendices.

### 4. `summary.md`
Human-skimmable executive brief (< 1 page) with counts by severity/confidence, top 3–5 critical findings, and highest-value wiring recommendations.

---

## Phase 5 — Final Output

Print to chat:
- Direct paths to `report.html`, `attack-chains.html`, and `summary.md`.
- Summary table of findings by severity and reproducibility status (`confirmed`, `likely`, `theoretical`).
- Number of attack chains identified and the single highest-impact wiring change.
