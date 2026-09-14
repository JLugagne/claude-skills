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

Two things this audit must produce, and they are different deliverables:

- a **finding list** — what is wrong, proved;
- a **deployment verdict** — for each finding, what a *correctly configured* deployment of this
  project would have to do for the finding to be live, or to be closed. Many findings in a library
  are only reachable through a specific wiring; a report that omits the wiring requirement is
  misleading in the direction that matters (it reads as "your code is unsafe" when the honest
  answer is "this configuration is").

**Leave the repository untouched.** Every change you make lives in `.security-audit/<run>/` or in a
git worktree that Phase 0.5 tears down. Do not commit to the user's branch, do not push, do not
modify tracked files outside a worktree. If you find something you want to fix, write it in the
report as a remediation, not as an edit.

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

4. **Establish which code actually ships.** Record the reviewed ref (commit SHA and branch) and
   answer three questions in the profile:
   - Are there unmerged branches whose names or recent commits suggest security work? A fix that
     exists only on an unmerged branch is a live finding on `main`, and the audit should say so
     rather than let it be discovered later.
   - What do the last ~50 commits touch? Any area churning during the audit window deserves the
     hot-path budget (below).
   - If this is a monorepo or multi-module repo, list the modules and which CI job exercises each.
     A module with no CI is a coverage finding in its own right.
5. **Separate the production surface from the development surface, and inventory the guards in
   front of it.** This decides what the rest of the audit is even allowed to report, so do it before
   dispatching anyone. Three things to establish and write into the profile:

   - **What is not shipped at all.** Examples, demos, seed/dev fixtures, `_test` helpers, generated
     code, and anything behind a build tag or a dev-only module. A defect that exists only in an
     example or a test helper is a documentation or coverage note, not a vulnerability — unless the
     project tells consumers to copy it, in which case it is a finding *about the documented
     deployment* and must be labelled that way.
   - **What is gated by configuration.** Enumerate every switch that can make a code path
     reachable or unreachable: environment variables, feature flags, config-file keys, build tags,
     constructor options, and "enabled only when X is set" branches. Record, for each, whether the
     production default is **safe** (absent ⇒ off) or **unsafe** (absent ⇒ on). This list is what
     turns "there is a debug endpoint" into either a finding or a non-finding.
   - **What the project itself calls dev-only.** Quote the source: a README warning, an `Insecure*`
     option name, a `// dev only` comment. Where the code and the documentation disagree about
     whether something is development-only, that disagreement is itself worth recording — it is how
     a development surface ships to production by accident.

   The profile entry for each gated path must state: the guard, its default, and what happens when
   the guard is unset.
6. **Build the composition inventory.** List, from the profile, the *nominal end-to-end flows* the
   project is built to support — for a web service: signup → login → refresh → logout; for a
   library: the wiring a consumer is told to write. Include where each flow's entry points live and
   which constructors compose them. Phase 1.5 is driven by this list, so derive it from real entry
   points rather than from the directory tree.
7. **Set the search budget.** For each category agent, state a bounded effort (e.g. "hot paths
   first, then one pass over the rest; stop when two consecutive areas yield only hygiene"). The
   goal is a short list of things that matter, not an exhaustive inventory of style-adjacent
   weaknesses. A long tail of Medium findings hiding one High is a failed audit.

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

Check the build and test environment **before** dispatching, in one worktree, and record the exact
commands in the profile:

- Does a test run work at all, and how long does a cold run take? Agents that each rediscover a
  broken toolchain waste their whole budget on setup.
- Is there a writable build cache? Sandboxes frequently make the default one read-only, which turns
  every test invocation into a full recompile. Find a working cache location and put it in the
  profile.
- Record any capability that is *present but unexpected* (a working Docker daemon, network access)
  and any that is *absent but assumed* — the brief's safety rail differs from reality often enough
  that agents should be told what this run actually has.

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

These agents are scoped by *category*. Each one sees a slice. None of them owns the assembled
system, which is what Phase 1.5 adds — dispatch it **in parallel with Phase 1**, not after, since it
does not depend on the category agents' output. Two things to tell every Phase 1 agent so Phase 1.5
gets useful input:

- If you find a defect whose exploit needs a *second* component to be wired a particular way, say
  so explicitly in `deployment_preconditions`. That is how the composition agent knows where to look.
- If a nominal flow of this project has **no** test covering it end to end, record it as a coverage
  note (not a finding). Phase 1.5 will often confirm why it mattered.

### Instructions given to every subagent

- Work only inside your assigned worktree.
- Focus on **your category only** in this codebase; don't duplicate other agents' scope.
- For every candidate issue, before reporting it:
  - Determine if it's real by tracing actual data flow from an untrusted source to a
    sensitive sink. A theoretical pattern match without a plausible attacker-controlled
    input is not a finding.
  - **Show that the sink is reachable in production.** Trace the path as a *deployed* instance
    reaches it, not as the source tree presents it. If the path is behind a guard from the Phase 0
    inventory — an environment variable, a feature flag, a non-default constructor option, a build
    tag — then say which guard, and report the finding only in the form the guard allows:
    - guard **absent ⇒ off** (the safe default): the code is not reachable as shipped. Either drop
      it, or report it as a hardening note about what happens when the switch is turned on, with
      confidence `theoretical`. Never as a live vulnerability.
    - guard **absent ⇒ on** (the unsafe default): the path is live in a default deployment — this is
      a finding, and the guard's default belongs in `deployment_preconditions`.
    - guard **set by the operator** and the docs tell them to set it: treat the documented value as
      the production value and audit that. If a *plausible* misconfiguration is dangerous, report it
      under "valid configurations that are unsafe" rather than as an exploit against correct
      configuration.
  - **Do not report defects that exist only in development surfaces** — examples, demos, seed
    fixtures, test helpers, generated code, or anything excluded from the shipped artifact. Their
    place is your `.md` coverage note. The one exception: if the project's documentation tells
    consumers to copy, deploy, or mount that code, it is part of the production surface by
    instruction, and a defect in it is a finding *about the documented deployment* — label it that
    way and name the doc that points at it.
  - Write a proof-of-concept **unit, integration, or e2e test** that demonstrates the
    issue (e.g. a failing test showing the injection succeeds, the auth check is
    bypassed, the secret is readable). Run the test. If you cannot make it fail in a
    way that demonstrates real impact, downgrade it to "theoretical" or drop it.
  - **Write PoCs fail-to-prove.** The test must FAIL while the vulnerability is present and PASS
    once it is fixed. A test that passes while demonstrating the issue is worthless as a regression
    test and actively misleading to anyone who later skims for `FAIL`, so if you take that shape,
    say so loudly in the finding's evidence and in your `.md` note.
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
  - UUIDs assumed unguessable; logging of URLs (assumed safe unless URL contains secret)
  - Anything requiring physical/local-machine access as the threat model, unless the
    project profile says otherwise
  - **A missing test, a coverage gap, or a defect in a guard/registry/inventory test that itself
    proves nothing about a running system.** These belong in your `.md` coverage note, not the
    finding list. A finding must name a data flow an attacker can drive.
- **End your `.md` note with two required lines**: `Coverage: <what you examined>` and
  `Not covered: <what you ran out of budget for>`. The second line is as valuable as the first —
  an audit that reports only what it looked at cannot be distinguished from one that looked
  everywhere.

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
  "remediation": "string",
  "deployment_preconditions": "string or null",
  "requires_wiring": "string or null",
  "production_reachable": "yes | only-if-configured | no"
}
```

- `deployment_preconditions` — what a real deployment must look like for this to be exploitable, or
  for it to be *closed*. Be specific: "requires a tenant resolver that can return an empty string";
  "reachable only when WithRedirectURL is unset". `null` when the finding is unconditional.
- `requires_wiring` — the one-line configuration change, if any, that closes it: "pass
  WithX(svc) on LoginHandler". `null` when the library closes it on its own.

- `production_reachable` — whether the affected code is reachable in a deployed instance:
  - `yes` — a default production deployment reaches it, with no switch to turn on.
  - `only-if-configured` — reachable only once an operator sets a guard (env var, flag, option,
    build tag). Name the guard in `deployment_preconditions` and say whether its default is safe.
  - `no` — development surface only (example, demo, test helper, non-shipped target). This must come
    with the reason it is not shipped, and the finding should normally be a hardening note or a
    documentation finding rather than a vulnerability.

These fields exist because for a library, "is this exploitable?" is usually "it depends on the
consumer's wiring, and on whether this code ships at all" — and that answer must be in the
machine-readable output, not only in prose. The verification pass checks `production_reachable`
against the source, so a claim of `yes` that rests on a development-only path is a downgrade.

## Phase 1.5 — Composed-system agent

Dispatch **one additional agent in parallel with Phase 1**, in its own worktree. It is not a
category agent: its scope is the system as *assembled*, and specifically the seams between modules
that no category owns.

Its reason to exist: a defect that only appears once two components are wired together is invisible
to a category agent (which sees one module) and usually invisible to the unit suites (which test
modules in isolation). Treat a clean Phase 1 plus a broken composition as the expected failure mode,
not an unlikely one.

### Instructions given to the composed-system agent

- Work only inside your assigned worktree. You may add test files freely; do not modify library code.
- **Assemble the system the project intends a user to run in production.** Prefer, in order: the
  production wiring its docs prescribe; the project's own documented example/reference wiring; a
  test harness it provides. If the only runnable composition the project ships is a development one —
  it sets an `Insecure*` option, skips a required key, or disables a control — say so, then assemble
  the **production** form from the docs and audit that, using the dev form only to see what the
  author had in mind. If the project ships no runnable composition at all, **that is your first
  finding** — record it, then build the composition from the docs.
- **A guard you have to switch on is not a control you have.** If a path is only reachable when an
  operator sets an environment variable or a flag, report it as `only-if-configured` with the guard
  named, and check the guard's default rather than assuming the operator sets it. Assess the
  composition as it is *documented to be deployed*, and treat "the docs never mention this switch" as
  a finding about the deployment story.
- **Walk every nominal flow from the Phase 0 composition inventory, end to end, over the real
  interface.** For an HTTP service or library that mounts handlers: drive it over HTTP with a real
  cookie jar (not `httptest.NewRecorder` per handler — that hides exactly the cross-request state this
  phase exists to find). For a CLI or worker: invoke it as a user would. Cover at least:
  - the primary authentication flow, and every *additional* login path the project offers (alternative
    providers, passwordless, machine credentials) — each must reach an equivalent state;
  - the session lifecycle: refresh, rotation, logout, and expiry, including what a client holds at
    each stage;
  - account recovery and any step-up / second-factor ceremony, in both the success and the failure
    direction;
  - whatever the profile says is the product's core feature.
- **At every stage, assert what the caller is allowed to do, not only that the call succeeded.**
  The bug class this phase catches is a state that is *reached* but should not be, or a state
  *destroyed* that should have survived. Ask at each hop: what does the client hold now, and what can
  it do with it that it could not before?
- **Look specifically for:**
  - a route that clears, rotates, or invalidates state belonging to a *different* stage of a flow;
  - a control that a module applies on one path and the composition fails to apply on another path to
    the same outcome (the module is consistent, the wiring is not);
  - an option whose absence changes a security property silently, where the example or the docs omit
    it (the runnable composition is itself a claim about how to deploy; if following it yields a
    weaker posture than the prose implies, that is a finding);
  - a flow that only works because a test fixture disables a control, or that breaks when the control
    is on;
  - two modules that each validate a shared value differently (tenant id, origin, audience, expiry),
    so the composition accepts what both would reject.
- **Prove each issue with a failing test** against the composed system, following the same
  fail-to-prove and safety-rail rules as Phase 1. Your PoC is usually an integration test that
  registers, logs in, and walks the flow with a cookie jar — that is expected and is the point.
- If a nominal flow **cannot** be exercised at all (no example, no harness, undocumented wiring),
  record that as a finding about the project with confidence `likely` and an honest description: an
  unexercisable core flow is a real risk, but it is a risk of the deployment story rather than a
  demonstrated exploit.
- Report in the same JSON schema, with `"category": "composed-system"`, and the same `.md` note
  including the `Coverage:` / `Not covered:` lines. Do not duplicate a category agent's finding: if
  you confirm the same root cause, say so and cite it, and spend your budget on the *composition*
  consequence (which path is affected, which consumer wiring is affected).

Output: `.security-audit/<run>/findings/composed-system.json` and `.security-audit/<run>/findings/composed-system.md`.

## Phase 2 — Attack chain analysis

After all subagents complete, spawn one final subagent (not worktree-isolated — it
only reads the findings, doesn't touch code) whose sole job is chain analysis:

- Load every finding from `findings/*.json`, including `theoretical` ones — a weak
  link can still complete a chain.
- **Also load the `deployment_preconditions` / `requires_wiring` fields.** Two findings whose
  preconditions cannot hold simultaneously do not chain; two findings where one is only open because
  the other's mitigation is unset usually do.
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
- **Score each chain honestly against its preconditions.** A chain that needs a precondition the
  project's own documentation forbids (or that only occurs in a configuration the project calls
  unsupported) is not a high-severity chain; say what it needs, in the narrative and in the score.
  Padding a chain's severity is the single easiest way to make an audit untrustworthy.
- Save to `.security-audit/<run>/attack-chains.md`. If no viable chains exist, say so
  explicitly rather than omitting the section. Also record the combinations you **considered and
  rejected**, with the reason — that section is what shows the search was real.

## Phase 3 — Consolidation, verification & cleanup

1. Merge all `findings/*.json` into one list. Where two subagents reported
   essentially the same underlying issue (same file/sink, same root cause), merge
   them into a single finding and note which categories flagged it.
2. Copy any PoC test files worth keeping out of their worktrees into
   `.security-audit/<run>/poc-tests/`, and write a short `poc-tests/README.md` giving, for each,
   the exact command to run it and the working directory it needs. A PoC nobody can re-run is not
   evidence.
3. Remove all worktrees created in Phase 0.5.
4. **Verify, do not only merge.** Before the reports are written, dispatch a **verification agent**
   whose job is adversarial review of the finding list itself:

   - Re-execute every `confirmed` finding's PoC from the merged `poc-tests/`, from a clean worktree,
     using the commands you recorded. A PoC that does not reproduce, does not compile, or whose
     assertion polarity is inverted means the finding is **not** `confirmed`.
   - For each finding, check the claim against the source rather than the prose: does the cited line
     actually do what the description says? Is the untrusted input actually attacker-controlled?
   - Check the merged list for internal contradictions: two findings that assert opposite behaviour
     of the same code path cannot both be right.
   - Downgrade or drop what does not survive. Record what you changed and why — the audit's value
     depends on `confirmed` meaning something.
   - Verify that no finding depends on a *fixture* rather than on product code (an all-zero key the
     tests use, a control a test harness disables) without saying so.
   - **Check every `production_reachable` claim against the source.** A `yes` whose path is only
     reachable through a development surface, an example, or a guard that defaults to off is a
     downgrade — to `only-if-configured` with the guard named, or to a hardening note. This is the
     claim most likely to be wrong, because it is the one no PoC can prove: a PoC shows the code
     path works, never that a deployed instance reaches it.

   Write the outcome to `.security-audit/<run>/verification.md`: what was re-run, what reproduced,
   what was downgraded, and any discrepancy between two agents' outputs. This file is the audit's
   own audit trail.

## Phase 4 — Reports

Produce exactly two report files in `.security-audit/<run>/`:

### `full-report.md`

Start the file with an **index table**, before any detailed findings, covering both
individual findings and attack chains together, sorted by CVSS score descending
(chains use the combined severity assessment from Phase 2 as their score). Columns:

| Title | CVSS | Reachable | Description |
|---|---|---|---|
| [Short finding/chain title](#anchor-slug) | 9.1 (Critical) | default deploy | One sentence, plain language |

The **Reachable** column is the finding's `production_reachable` in plain words — `default deploy`,
`only if configured` (name the guard in the detail section), or `dev only`. It is there because a
reader triaging the table needs to know which rows describe an instance they are actually running.

- Use standard markdown heading anchors (e.g. a finding titled "SQL Injection in
  `/api/search`" gets heading `## SQL Injection in /api/search` and table link
  `[SQL Injection in /api/search](#sql-injection-in-apisearch)`), so the link jumps
  straight to that finding's full detail section further down the file.
  **Verify the anchors resolve** before finishing: headings containing `→`, `/`, `:` or other
  punctuation produce slugs that are easy to get wrong. If a heading's slug is ambiguous, add an
  explicit `<a id="...">` and link to that instead.
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

Two further sections are required, because they carry a large share of the report's real value:

- **"Valid configurations that are unsafe"** — for each finding (or cluster) where the library
  behaves as designed but a *plausible, documented-looking* configuration is dangerous, spell out
  the configuration, what makes it dangerous, and the one-line change that closes it. This is often
  the most actionable section for a consumer, and it is where a "your code is fine, your wiring is
  not" result lives. Everything marked `only-if-configured` belongs here, and so does every
  development-only path that a deployment could accidentally expose in production (a debug route
  switched on by an environment variable, a dev default left in place). For each, state the guard,
  its default, and what an operator sees when they turn it on.
- **"Coverage and what was not examined"** — the per-agent `Coverage:`/`Not covered:` lines, plus
  the verification outcome. State plainly which areas got the hot-path budget and which got a
  single pass. An audit's credibility rests on this section as much as on its findings.

Each finding's detail must state its `deployment_preconditions` and `requires_wiring` explicitly —
as a labelled line, not buried in prose.

### `summary.md`
Human-skimmable, under ~1 page. Must include:
- One-line project profile (stack + entry points)
- Counts by severity and by confidence level
- Top 3–5 findings that matter most (by CVSS × confidence × whether they're part of
  a chain), one sentence each with a pointer into `full-report.md`
- One-line note on attack chains (count found, or "none identified")
- One-line note on CI/CD dependency scanning status, if flagged in Phase 1

- One line on the composed-system result: does the project's own example/reference wiring produce
  the posture the docs claim, yes or no?
- One line naming the single highest-value **wiring** change a consumer must make, if the report
  contains any `requires_wiring`.

Do not put remediation code blocks or full CVSS vectors in `summary.md` — that's
what `full-report.md` is for. This file should be readable in under two minutes.

## Final output

Print to chat: the path to `summary.md`, total findings by severity, and whether any
attack chains were found. Do not paste the full report inline — point to the file.

Also print, in three lines or fewer: the composed-system verdict (does following the project's own
documented wiring yield the posture the docs claim?), whether the verification pass downgraded
anything, and the one wiring change that matters most to a consumer. Those three lines are what a
reader needs before deciding whether to keep reading.
