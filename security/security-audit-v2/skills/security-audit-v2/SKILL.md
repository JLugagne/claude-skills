---
name: security-audit-v2
description: Perform a comprehensive, domain-driven white-box security audit of a codebase — upfront interactive scope negotiation (including the related gateway and deployment repos), functional domain slicing with sprint task backlogs, an identity source map and hop-by-hop call-chain analysis, verification of the security claims the docs make, multi-agent scaling rules, isolated git worktrees, failing PoC tests for proof, settle commands for findings that depend on another hop, attack chain analysis, and state-of-the-art HTML and Markdown executive reports under .security-audit/.
author: JLugagne
---

# Security Audit v2 — Domain-Driven Security Assessment Engine

## Objective

Perform a rigorous, structured white-box security audit of a codebase. Identify real, exploitable
vulnerabilities — not theoretical static analysis noise — and prove each finding with a failing test
before reporting it.

Key deliverables produced for each run:
1. **Scope & Preconditions Agreement** (`00-scope.md`): negotiated upfront with the user to filter noise (secrets, dev configs, etc.) and to list the related repos of the call chain. **Trust claims** (`00-trust-claims.md`): every security statement the docs make, verified against the code.
2. **Domain Sprint Backlogs & Notes** (`domains/<domain>/tasks.md`): exhaustive checklist-driven verification per functional domain.
3. **Structured Finding List & PoCs** (`poc-tests/`, `findings.json`): proven vulnerabilities with CVSS v3.1 scores, reproducibility state, and reachability.
4. **State-of-the-Art HTML Report** (`report.html`): executive-grade, interactive, filterable report with KPIs, CVSS tables, reproducibility badges, and Mermaid attack chains.
5. **Full Markdown Report** (`full-report.md`) and **Executive Summary** (`summary.md`).

**Golden Rule:** Leave the repository untouched, and the related repos too (read-only). `settle_with` commands are written for the user to run, never executed against a deployed stack. Every artifact lives in `.security-audit/<run>/` or in isolated git worktrees torn down upon completion. Never commit to the user's branch or modify tracked files outside a worktree.

---

## Phase 0 — Setup & Upfront Scope Negotiation

### 1. Run Initialization
1. Create a timestamped output directory at `.security-audit/<YYYY-MM-DD-HHMM>/`. Never overwrite previous runs.
2. Identify the project profile: languages, frameworks, entry points (REST, gRPC, CLI, queue consumers), authentication mechanisms, storage, and external integrations.
3. Record the reviewed ref (commit SHA, branch) and the recent commit history (~50 commits) in `00-profile.md`.
4. **Identity source map** (in `00-profile.md`): for tenant, user, team/group, role and every scope
   selector (app, workspace, project), record where the code takes it from — signed claim, header, URL
   segment, body, environment default — down to the library helpers at the exact versions in the module
   file. A pseudo-version missing from the module cache is recorded as such: findings that depend on it
   are `needs-confirmation`, not assumed safe.
5. **Trust claims** (`00-trust-claims.md`): extract every security statement the project makes about
   itself or its neighbors from `CLAUDE.md` (every level), `AGENTS.md`, README, architecture and API docs:
   who authenticates, which headers are trusted, who rate-limits, which isolation is promised ("documents
   never cross apps"), network exposure, limits. Number them (`C-01`...). Each one is verified in Phase
   1.5; a claim the code contradicts is a finding, because the next reviewer will skip the control it
   names.
6. **Audit target, decisions and earlier runs** (`00-decisions.md`). Every run aims to be the last: a
   real service needed five review rounds because two runs audited a branch two rounds behind the MR
   branch, decided items were filed again each round, and each run filed one instance of a class whose
   siblings the next run found.
   - **Stale target check.** List every other local and remote branch that shares the audited branch's
     merge base with the target, is newer than HEAD and changes at least half of the same files
     (`git for-each-ref refs/heads refs/remotes`, `git merge-base`, `git diff --name-only`), and the open
     MRs/PRs with their source branches (`glab mr list` / `gh pr list`). If a newer branch carries the
     same work, ask in the scope negotiation which branch to audit and recommend the MR's source. Never
     audit the older copy "with a caveat".
   - **Decision sources.** Read `.review/*.md`, answered question files (`.questions/*.md`), ADRs,
     `REVIEW*.md` and the README's accepted risks. Number each settled item `D-01`... An accepted risk
     with an owner, or a mechanism the project states is never used in any deployment (an environment
     fallback variable no deployment sets, a feature flag never enabled), is not filed: list it under
     **Decided** in `summary.md`. File it only if the code or the deployment configuration you can read
     contradicts the decision.
   - **Earlier runs.** Load previous `.security-audit/*/` findings and the user's triage of them; tag
     each new finding `round: new | repeat | regression`.
   - **Documentation is not exposure.** A README or config comment warning "X must never be set" is a
     claim to verify against the deployment configuration, not evidence that X is set. Without a
     deployment that sets it, there is no finding.

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
4. **Call Chain & Related Repositories**:
   - Which components sit in front of this service (edge proxy, gateway, forwarder) and which repos for
     them, and for the deployment topology (Helm/Kustomize, `NetworkPolicy`, generated configs), are
     available locally? They are read, never modified.
   - Unavailable hops are not assumed safe: findings that depend on them get `call_chain_status:
     "needs-confirmation"` and a `settle_with` command the user can run against a deployed stack.
5. **Domain Inclusions / Exclusions**:
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
  - `identity-call-chain.md` (identity sources, claim-to-header fallbacks, scope selectors from the URL,
    hop-by-hop trust, direct reachability bypassing the gateway, claims vs. reality). Always assigned to
    the domain that owns request identity (usually `auth`), and to the Phase 1.5 call-chain agent.

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
   - A PoC about identity or access must go through the **production middleware chain** (the real context
     or auth handler). If the project's e2e harness replaces that middleware, build the PoC on the real one
     and record the harness gap in `notes.md`: no existing test covers identity extraction.
   - Name the **hop** where the flaw lives (`hop`: this service, or the gateway/proxy name). A reader
     who checks the wrong hop dismisses a real finding as a false alarm.
   - When the flaw or its mitigation lives in another hop, an in-repo PoC may be impossible: set
     `reproducibility: likely-trace`, fill `call_chain_status`, and give `settle_with`, the exact command
     (curl with the relevant headers, a request with a hand-set `Accept-Encoding`, a call from another pod)
     that proves or refutes it in one run against a deployed stack.
4. **Sibling sweep — exhaust the class**: before filing, search your domain (and name the other domains
   to check in `notes.md`) for every instance of the same weakness: every listener for a missing
   timeout, every constructor for a missing input rule, every parser for an uncharged expansion path,
   every route the framework registers by itself. List every site with its reachability; the
   remediation fixes the class. A finding filed with one example is re-opened by the next round.
5. **Read the decisions**: every agent receives `00-decisions.md` and never files a settled item.
6. **Output Requirements**:
   - Update `tasks.md` with status (`[x]` or `[!]`).
   - Write structured findings to `domains/<domain>/findings.json` complying with `templates/finding-schema.json`.
   - Write a human-readable note in `domains/<domain>/notes.md` ending with:
     - `Coverage: <files and flows audited>`
     - `Not covered: <items skipped due to budget>`

---

## Phase 1.5 — Composed-System, Call-Chain & Claims Agents

Dispatch these agents in parallel, each in its own worktree:

1. **Composed system** (`wt-composed-system`) — audit the system as **assembled**:
   - Test end-to-end nominal flows across domain seams (e.g. `signup -> login -> payment checkout -> webhook callback -> data access`).
   - Check for cross-domain inconsistencies (e.g. domain A validates tenant ID differently than domain B).
   - Walk flows with real HTTP client / cookie jar, testing session lifecycles, state transitions, and step-skipping.
   - Output: `findings/composed-system.json` and `findings/composed-system.md`.
2. **Call chain** (`wt-call-chain`) — audit each hop between the client and the service, reading the
   related repos agreed in Phase 0 (read-only):
   - Build the hop table in `findings/call-chain.md`: for each hop, what it authenticates, which headers
     it strips and adds, whether it rebuilds headers from a client-influenced context, rate limits,
     timeouts, body limits, compression, and the versions of shared middleware libraries.
   - Check direct reachability that bypasses the gateway (network policies, internal DNS names, tools
     calling the service URL directly).
   - For every finding of the domain agents, set `call_chain_status`: `unmitigated`,
     `mitigated-upstream` (only when the mitigation was read in the upstream code or configuration),
     `partially-mitigated`, `needs-confirmation`, or `not-applicable`.
   - Output: `findings/call-chain.json` for hop-level findings.
3. **Claims** (`wt-claims`) — verify every `C-xx` of `00-trust-claims.md` against the code and the related
   repos. A false claim becomes a finding (CWE-1059 or the CWE of the control it pretends exists), with
   the claim quoted. Output: `findings/claims.json`.

---

## Phase 2 — Attack Chain Analysis

Spawn a read-only agent to analyze combinations of findings:
- Load all findings from `domains/*/findings.json` and `findings/*.json` (composed system, call chain, claims), including theoretical ones — a weak link can complete a chain.
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
   - Validate every `mitigated-upstream` status: the mitigation must be quoted from the upstream code or
     configuration. A mitigation known only from documentation becomes `needs-confirmation`.
   - Every finding with `call_chain_status: needs-confirmation`, or `reproducibility` other than
     `confirmed-poc` because of another hop, must carry a `settle_with` command; add it or downgrade the
     finding to `theoretical`.
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
  - CWE, OWASP, Domain, CVSS Vector, Reachability, **Hop** and **Call-chain status**.
  - Description, Impact, and Source-to-Sink Dataflow.
  - PoC Box: exact reproduction command and test code snippet.
  - Preconditions and Required Wiring.
  - **Settle with** box when `settle_with` is set.
  - Remediation with code diff.
- Fill the **Call Chain** section (`{{CALL_CHAIN_TABLE}}`) with the hop table from `findings/call-chain.md`
  and the claims verdicts (`C-xx`: confirmed / contradicted / not verifiable).
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
Human-skimmable executive brief (< 1 page) with counts by severity/confidence, top 3–5 critical findings, highest-value wiring recommendations, a **Settle first** list: every finding whose verdict depends on another hop, with its `settle_with` command, the `new` / `repeat` / `regression` counts, and a **Decided** list (one line per settled item checked and set aside, with its `D-xx`). A stale-target warning, if any, opens the brief.

Before writing any deliverable, merge findings that share one root cause and one remediation across domains into a single finding listing every site, and drop those matching a `D-xx`.

---

## Phase 5 — Final Output

Print to chat:
- Direct paths to `report.html`, `attack-chains.html`, and `summary.md`.
- Summary table of findings by severity and reproducibility status (`confirmed`, `likely`, `theoretical`).
- Number of attack chains identified and the single highest-impact wiring change.
