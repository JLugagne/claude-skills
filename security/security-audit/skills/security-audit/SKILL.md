---
description: Perform a comprehensive white-box security audit of a codebase — dispatch per-category subagents in isolated git worktrees, confirm each exploitable finding with a failing proof-of-concept test, analyze attack chains, and produce CVSS-scored full and summary reports under .security-audit/.
author: JLugagne
---

# Security Audit

## Objective

Perform a comprehensive security audit of this codebase. Identify real, exploitable
vulnerabilities — not theoretical concerns — and prove each one with a failing test
before reporting it. This is a white-box audit: you have full access to source, config,
and CI/CD context.

## Phase 0 — Setup

1. Identify the run: create a timestamped output folder at
   `.security-audit/<YYYY-MM-DD-HHMM>/`. Never overwrite a previous run.
2. Identify the project type(s): language(s), frameworks, entry points (web server,
   API, CLI, worker/queue consumer, etc.), auth model, and how it talks to external
   systems (DB, third-party APIs, filesystem, subprocess/shell, LLM calls if any).
3. Write this project profile to `.security-audit/<run>/00-profile.md`. This profile
   determines which subagents get spawned in Phase 1 — don't spawn a subagent for a
   category that doesn't apply (e.g. no SSRF agent for a CLI tool with no outbound
   HTTP).

## Phase 0.5 — Isolation via git worktree

Before spawning subagents, create an isolated git worktree per subagent so they can
independently modify code, add test files, and run tests without stepping on each
other or on the user's working directory:

```
git worktree add .security-audit/<run>/wt-<agent-name> HEAD
```

Each subagent operates only inside its assigned worktree. At the end of Phase 3,
tear down all worktrees (`git worktree remove`) after extracting findings and any
proof-of-concept test files worth keeping (copy those into the run's report folder,
not left behind in a worktree).

## Phase 1 — Subagent dispatch

Spawn one subagent per relevant category, scoped to the project profile. Standard
categories to consider (adapt to what Phase 0 found):

- **Injection** — SQL/NoSQL, command/shell injection, template injection, path
  traversal, deserialization of untrusted data
- **Auth & session** — broken authentication, authorization/IDOR, privilege
  escalation, JWT/session handling, password/reset flows
- **Input validation & data exposure** — SSRF, XXE, mass assignment, sensitive
  data exposure in responses/logs, insecure direct object references
- **Secrets** — hardcoded credentials, API keys, tokens in code, config files,
  git history, or CI/CD workflow files
- **Web-specific** (if applicable) — XSS, CSRF, insecure CORS, clickjacking,
  cookie/security header misconfiguration
- **Config & infra surface** — Dockerfiles, CI/CD workflow permissions
  (e.g. overly broad `GITHUB_TOKEN` scopes, unpinned actions), IaC manifests
  (Terraform/Kubernetes), exposed debug endpoints, default credentials
- **AI/LLM-specific** (if the project calls or embeds an LLM) — prompt injection
  via untrusted input, unsanitized model output used in code paths, tool-calling
  permission scope, cost/rate abuse

Do **not** spawn a dependency/SCA scanning agent — this is already covered by the
project's CI/CD pipeline (govulncheck, OSV, Trivy). If you notice the CI/CD
config for this scanning is missing, misconfigured, or not actually gating
merges, flag that as a single **process** finding, but do not re-run SCA yourself.

### Instructions given to every subagent

- Work only inside your assigned worktree.
- Focus on **your category only** in this codebase; don't duplicate other agents' scope.
- For every candidate issue, before reporting it:
  - Determine if it's real by tracing actual data flow from an untrusted source to a
    sensitive sink. A theoretical pattern match without a plausible attacker-controlled
    input is not a finding.
  - Write a proof-of-concept **unit, integration, or e2e test** that demonstrates the
    issue (e.g. a failing test showing the injection succeeds, the auth check is
    bypassed, the secret is readable). Run the test. If you cannot make it fail in a
    way that demonstrates real impact, downgrade it to "theoretical" or drop it.
  - **Safety rail**: PoC tests must run only against local processes, local test
    databases, or mocked endpoints. Never run a PoC against any staging or production
    URL, real third-party service, or perform a destructive action (no real data
    deletion, no real emails sent, no real external network calls beyond localhost/mocks).
- For each confirmed finding, record:
  - Title, affected file(s)/line(s)
  - CWE ID and OWASP Top 10:2021/2025 category
  - CVSS v3.1 base score and vector string
  - **Confidence**: `confirmed` (PoC test demonstrates real impact) /
    `likely` (strong evidence, PoC inconclusive or environment-limited) /
    `theoretical` (plausible pattern, no working PoC)
  - Path to the PoC test file (relative to repo root, copied out of the worktree)
  - Concrete remediation: the actual fix — specific function/library/config change
    for this stack, not generic advice
- Exclude from reporting (these are not findings):
  - Rate-limiting gaps, missing audit logs, issues only in documentation/markdown files
  - Regex-based DoS ("ReDoS") unless the regex is attacker-suppliable and unbounded
  - Untrusted content passed into an LLM system prompt, by itself (that's expected;
    only flag if the model's output is then used unsanitized in a sensitive sink)
  - UUIDs assumed unguessable; logging of URLs (assumed safe unless URL contains secrets)
  - Anything requiring physical/local-machine access as the threat model, unless the
    project profile says otherwise

Each subagent writes its raw findings to
`.security-audit/<run>/findings/<category>.json` (structured, one object per finding,
schema below) plus a short human-readable note in
`.security-audit/<run>/findings/<category>.md`.

```json
{
  "id": "string, short unique slug",
  "title": "string",
  "category": "string",
  "cwe": "CWE-XXX",
  "owasp": "A0X:2021 or 2025 category name",
  "cvss_score": 0.0,
  "cvss_vector": "CVSS:3.1/...",
  "confidence": "confirmed | likely | theoretical",
  "files": ["path:line"],
  "description": "string",
  "poc_test_path": "string or null",
  "remediation": "string"
}
```

## Phase 2 — Attack chain analysis

After all subagents complete, spawn one final subagent (not worktree-isolated — it
only reads the findings, doesn't touch code) whose sole job is chain analysis:

- Load every finding from `findings/*.json`, including `theoretical` ones — a weak
  link can still complete a chain.
- Identify combinations where 2+ findings together produce impact greater than any
  finding alone (e.g. an information-disclosure bug that leaks a token consumed by
  an IDOR elsewhere; an SSRF that reaches an internal admin endpoint with broken auth).
- For each chain found, write a short narrative: entry point → each step → final
  impact, referencing the finding IDs involved, plus a combined severity assessment.
- For each chain, also produce a Mermaid **sequence diagram** showing the attacker,
  the system components involved, and each step of the chain in order — one
  participant per component/actor (e.g. `Attacker`, `API Gateway`, `Auth Service`,
  `Database`), with each message labeled by the action taken and, where useful, a
  `Note` on the receiving participant naming which finding ID that step exploits.
  Use `sequenceDiagram` syntax, e.g.:

  ```mermaid
  sequenceDiagram
      participant A as Attacker
      participant W as Web App
      participant D as Database
      A->>W: Submit crafted search query (F-003)
      W->>D: Unsanitized query forwarded
      D-->>W: Full user table returned
      Note over W: Broken authz on export endpoint (F-007)
      W-->>A: CSV export with all user records
  ```

  Keep diagrams to the actual chain steps only — no extra branches or alternate
  paths; if a step is conditional, a simple `alt`/`else` block is fine but don't
  over-elaborate.
- Save to `.security-audit/<run>/attack-chains.md`. If no viable chains exist, say so
  explicitly rather than omitting the section.

## Phase 3 — Consolidation & cleanup

1. Merge all `findings/*.json` into one list. Where two subagents reported
   essentially the same underlying issue (same file/sink, same root cause), merge
   them into a single finding and note which categories flagged it.
2. Copy any PoC test files worth keeping out of their worktrees into
   `.security-audit/<run>/poc-tests/`.
3. Remove all worktrees created in Phase 0.5.

## Phase 4 — Reports

Produce exactly two report files in `.security-audit/<run>/`:

### `full-report.md`

Start the file with an **index table**, before any detailed findings, covering both
individual findings and attack chains together, sorted by CVSS score descending
(chains use the combined severity assessment from Phase 2 as their score). Columns:

| Title | CVSS | Description |
|---|---|---|
| [Short finding/chain title](#anchor-slug) | 9.1 (Critical) | One sentence, plain language |

- Use standard markdown heading anchors (e.g. a finding titled "SQL Injection in
  `/api/search`" gets heading `## SQL Injection in /api/search` and table link
  `[SQL Injection in /api/search](#sql-injection-in-apisearch)`), so the link jumps
  straight to that finding's full detail section further down the file.
- Prefix chain rows' titles with "Chain: " so they're visually distinguishable from
  single findings at a glance, and link to their entry in the attack-chains section.
- The description column is one plain-language sentence — no CWE/OWASP codes, no
  file paths, just what the issue is and why it matters.

After the index table, include every finding in full detail, grouped by severity
(Critical → High → Medium → Low → Informational, using CVSS score to bucket). Each
entry includes everything from the schema above, in readable form, plus a link/path
to its PoC test, under a heading matching the anchor used in the index table. Include
the full attack-chain section, each chain under a heading matching its index table
anchor, with its Mermaid sequence diagram rendered directly beneath the narrative. Include a short "excluded / considered but not findings" appendix listing
anything a subagent investigated and ruled out, so it's clear what was checked, not
just what was found.

### `summary.md`
Human-skimmable, under ~1 page. Must include:
- One-line project profile (stack + entry points)
- Counts by severity and by confidence level
- Top 3–5 findings that matter most (by CVSS × confidence × whether they're part of
  a chain), one sentence each with a pointer into `full-report.md`
- One-line note on attack chains (count found, or "none identified")
- One-line note on CI/CD dependency scanning status, if flagged in Phase 1

Do not put remediation code blocks or full CVSS vectors in `summary.md` — that's
what `full-report.md` is for. This file should be readable in under two minutes.

## Final output

Print to chat: the path to `summary.md`, total findings by severity, and whether any
attack chains were found. Do not paste the full report inline — point to the file.
