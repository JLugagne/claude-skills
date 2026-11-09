---
name: code-review-v2
description: Perform a rigorous, adversarial non-security code review of a codebase — upfront scope negotiation (full project vs. MR/diff only, related repos), quality-dimension checklists (memory usage, comment verbosity, naming, architecture, dead code, missing tests, unnecessary tests, adversarial correctness, persistence, resilience, project conventions), cross-cutting passes on docs, test harness fidelity and query cost, optional runtime verification on a disposable database, isolated git worktrees, and an interactive HTML triage report where every finding can be validated, invalidated, delayed, and have its comment text and proposed action edited.
author: JLugagne
---

# Code Review v2 — Adversarial Quality Assessment Engine

## Objective

Perform a rigorous, structured review of a codebase's **quality**, not its security. Identify real,
defensible issues — not generic linter noise — across eleven dimensions: memory usage, comment
verbosity, naming, architecture, dead code, missing tests, unnecessary tests, general adversarial
correctness, persistence (database cost and transaction edges), resilience (deadlines, bounds,
proxies), and the project's own written conventions. Every finding must be proven (a reference search, a trace, a quoted assertion) before it
is reported, and every finding must ship with an editable review comment and an editable proposed
action so the user can triage it directly in the report.

Key deliverables produced for each run:
1. **Scope Agreement** (`00-scope.md`): negotiated upfront — full project or MR/diff only, plus the
   related repos read for context. **Project Rules** (`00-project-rules.md`): every rule the project
   wrote down, turned into checks.
2. **Unit Sprint Backlogs & Notes** (`units/<unit>/tasks.md`): exhaustive checklist-driven verification per domain (full project) or per diff slice (MR).
3. **Structured Finding List** (`comments.json`): every issue, schema-validated, each carrying a `suggested_comment` and a `proposed_action`.
4. **Interactive HTML Triage Report** (`report.html`): every finding can be validated, invalidated, delayed, or edited in place, with autosave and export.
5. **Full Markdown Report** (`full-report.md`) and **Executive Summary** (`summary.md`).

**Golden Rule:** Leave the repository untouched. This skill is read-only and advisory. Every artifact
lives in `.code-review/<run>/` or in isolated git worktrees torn down on completion. Never commit to
the user's branch, never modify tracked files outside a worktree, and never apply a fix automatically
— fixes are proposed text for the user to accept or edit, not code changes.

**No shortcuts rule:** Never offer a "quick" or "sampling" review mode, and never cap the number of
findings or checklist iterations to save time. Thoroughness is the only mode this skill has.

**Last-round rule:** every run aims to be the last one. Fixing its findings must leave nothing for a
next run: the same dimensions re-run on the fixed code should come back empty. A real case this rule
exists for: one service needed five review rounds, because (1) two runs reviewed a branch two rounds
behind the MR branch and re-filed findings already fixed there, (2) items the team had decided were
filed again every round, and (3) each run filed one instance of a defect class, so the next run found
its siblings (text validation, then bidi, then another constructor; one timeout, then another listener).
Phase 0 step 6, the sibling sweep and the Phase 2 grouping rule below exist to prevent each of these.

---

## Phase 0 — Setup & Upfront Scope Negotiation

### 1. Run Initialization
1. Create a timestamped output directory at `.code-review/<YYYY-MM-DD-HHMM>/`. Never overwrite previous runs.
2. Identify the project profile: languages, frameworks, module/package layout, test tooling, linters already configured.
3. Record the reviewed ref (commit SHA, branch) in `00-profile.md`.
4. **Extract the project rules** into `00-project-rules.md`: read every instruction and convention file
   (`CLAUDE.md` at user, project and nested levels, `AGENTS.md`, `CONTRIBUTING.md`, `.golangci.yml` and
   other linter configs, `docs/architecture*`). Number each rule (`R-01`...) with its source file and
   quote it. Separate **rules** (test structure, error wrapping, comment policy, layering, mock
   behavior) from **claims** (statements of fact about the system: who authenticates, who rate-limits,
   which limits apply, how requests reach the service). Rules feed the `project-conventions` checklist;
   claims are verified in Phase 1.5.
5. **Inventory the verification tools**: unit, integration and end-to-end suites, and any tool that
   drives a deployed instance (smoke runners, chain checks under `tools/`). Record what each one wires
   and what it replaces compared with production. The review judges these tools too.
6. **Review target, decisions and earlier rounds** (before the scope question, results in
   `00-decisions.md`):
   - **Stale target check.** List every other local and remote branch that shares the reviewed branch's
     merge base with the target, is newer than HEAD, and changes at least half of the same files:
     ```bash
     mb=$(git merge-base HEAD <target>); mine=$(git diff --name-only "$mb" HEAD | sort)
     for b in $(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes | grep -v '/HEAD$'); do
       [ "$(git merge-base <target> "$b")" = "$mb" ] || continue
       git merge-base --is-ancestor "$b" HEAD && continue
       [ "$(git log -1 --format=%ct "$b")" -gt "$(git log -1 --format=%ct HEAD)" ] || continue
       echo "$b shares $(comm -12 <(echo "$mine") <(git diff --name-only "$mb" "$b" | sort) | grep -c .) files, differs from HEAD in $(git diff --name-only HEAD "$b" | wc -l)"
     done
     ```
     Also list open MRs/PRs (`glab mr list` / `gh pr list`) and their source branches. If a newer branch
     carries the same work, or the open MR's source branch is not HEAD, ask in the scope question which
     branch to review, and recommend the MR's source. Never review the older copy "with a caveat": every
     finding it produces on already-fixed code costs the author a round.
   - **Decision sources.** Read `.review/*.md`, answered question files (`.questions/*.md`), ADRs
     (`docs/adr/`, `docs/decisions/`), `REVIEW*.md`, and the accepted risks of the README. Number each
     settled item `D-01`... with its source. A settled item is never filed as a finding: list it under
     **Decided** in `summary.md`. The only exception is code that contradicts a decision, filed as
     "decision not applied" with its `D-xx` — and only once the stale target check passed, since on an
     old branch the decision is usually applied elsewhere.
   - **Earlier rounds.** Load previous runs (`.code-review/*/comments.json`, exported triage JSON):
     findings the user invalidated or delayed, with their `reviewer_note`, are decisions too. Tag every
     new finding `round: new | repeat | regression` (repeat = filed before and still present). A run made
     mostly of repeats means the fixes are not landing: say so at the top of `summary.md`.

### 2. Mandatory Scope Question
**MANDATORY STEP**: Before dispatching any subagent, ask the user:

> **What is the scope of this review?**
> 1. **Full Project** — review the whole codebase, partitioned into functional domains.
> 2. **MR / Diff Only** — review only the changes on this branch against a base ref.

If **MR / Diff Only** is chosen, also ask:
- The base ref to diff against (default: `git merge-base HEAD <target-branch>`, target branch defaults to the repo's main branch).
- Optionally, an MR/PR number or URL if the user wants its description/discussion pulled in for context (via `gh`/`glab` if available — never fetch external URLs otherwise).

Then ask about **related systems**:
- Which sibling repositories are available locally and may be read (gateway, reverse proxy, deployment
  topology, the services calling this one)? Many defects only exist across a hop: a header stripped on
  one side but rebuilt on the other, a timeout disabled on every hop, a compression middleware that
  breaks `Content-Length`. Read them read-only; never edit them.
- May the review start disposable containers (e.g. a throwaway PostgreSQL) for the runtime
  verification of Phase 1.6? It never touches the user's databases.

Findings that depend on a system that is not available are filed with `confidence:
"needs-confirmation"` and a `settle_with` command, never dropped.

Then ask which dimensions to include (default: **all eleven**, listed below). Only exclude a dimension
if the user explicitly asks — do not pre-filter for speed.

1. `memory-usage` — allocation patterns, leaks, unbounded growth, resource cleanup.
2. `comments-verbosity` — restates-the-code filler, especially AI-generated over-commenting.
3. `naming` — clarity, consistency, convention adherence.
4. `architecture` — layering, coupling, module depth, SRP.
5. `dead-code` — unused/unreachable code, proven by reference search.
6. `tests-missing` — untested critical paths, error branches, edge cases.
7. `tests-unnecessary` — low-value, tautological, mock-only, or flaky-by-design tests.
8. `adversarial-correctness` — general logic/correctness bugs found by trying to break the code,
   including the order in which refusals are checked.
9. `persistence` — query cost per call, index fit, writes rewriting large columns, transaction edges,
   pool and migration settings.
10. `resilience` — deadlines, bounds on input and per-request memory, proxy and header assumptions,
    configuration drift.
11. `project-conventions` — violations of the rules in `00-project-rules.md`, and instruction files
    contradicted by the code.

Record the agreed boundaries in `.code-review/<run>/00-scope.md`. Every subagent dispatched below is
bound by this scope.

---

## Phase 0.5 — Slicing, Scaling Rules & Sprint Backlog

### 1. Full Project Scope: Functional Domain Identification
Partition the codebase into functional/architectural domains exactly as in a white-box security audit
(`auth`, `payment`, `api`, `core-engine`, etc. — derive from the actual codebase structure). Each domain
agent will run **every in-scope dimension's checklist** against its own slice.

**Scaling & Splitting Rules** (identical thresholds to security-audit-v2, applied per domain):
- **File Count**: domain exceeds **> 20 source files** (excluding vendor).
- **Code Volume**: domain exceeds **> 5,000 LOC** of core logic.
- **Backlog Size**: generated checklist exceeds **> 10 verification tasks**.

Split into disjoint sub-domains with strictly non-overlapping file lists; keep each sub-agent's backlog
between **5 and 8 tasks** per dimension group.

### 2. MR / Diff Scope: Diff Slicing
1. Compute `git diff --name-only <base-ref>...<head>` for the changed files.
2. Dispatch **one agent per in-scope dimension** (not per domain) — all working on the same diff, in
   parallel, mirroring a refute-first specialist review. A diff is small enough that dimension-per-agent
   gives deeper focus than domain-per-agent.
3. If the diff itself is large (**> 20 changed files** or **> 2,000 changed LOC**), split it by
   directory/package into disjoint diff slices and re-apply the per-dimension dispatch to each slice.
4. Each agent must read enough surrounding, unchanged context (callers, interfaces, existing tests) to
   judge the change correctly — it is not limited to reading only the diff hunks.
5. For every finding in MR scope, record `introduced_by_mr`: `yes` (the diff created this issue), `no`
   (pre-existing, merely touched), or `unknown`. Findings on code the diff didn't touch are out of scope
   — do not review untouched files just because they're nearby.

### 3. Sprint Folder & Backlog Generation
For each unit (domain, or diff slice), create `.code-review/<run>/units/<unit>/`:
- `unit-profile.md`: boundaries, files in scope, scope mode (full-project domain vs. MR diff slice).
- `tasks.md`: generated from `templates/review-tasks-template.md`, populated with the relevant checks
  from `templates/checklists/`:
  - `memory-usage.md`
  - `comments-verbosity.md`
  - `naming.md`
  - `architecture.md`
  - `dead-code.md`
  - `tests-missing.md`
  - `tests-unnecessary.md`
  - `adversarial-correctness.md`
  - `persistence.md`
  - `resilience.md`
  - `project-conventions.md`, extended with one task per rule of `00-project-rules.md` that applies to
    the unit's files (e.g. "R-07 tests are table-driven with at most 3 cases: count the cases of every
    test function in scope").

### 4. Git Worktree Isolation
```bash
git worktree add .code-review/<run>/wt-<unit> HEAD          # full-project domain
git worktree add .code-review/<run>/wt-mr <head-ref>         # MR/diff scope, shared worktree
```

---

## Phase 1 — Isolated Subagent Execution (Sprint Tracks)

Dispatch one subagent per unit, operating strictly inside its worktree.

### Subagent Rules of Engagement
1. **Adversarial by default**: assume every function, comment, and test is guilty until you've actually
   traced it and found it innocent. A checklist item is only `[x]` once you've verified it, not skimmed
   it. Do not rubber-stamp.
2. **Work Strictly Within Your Unit**: full-project domain agents stay inside their assigned files; MR
   agents stay inside the diff (plus the context reading needed to judge it correctly).
3. **Execute the Sprint Backlog** sequentially through `tasks.md`.
4. **Burden of Proof** — a finding cannot be filed on a hunch:
   - `dead-code`: must include the exact reference-search command run and its empty result.
   - `tests-missing`: must name the exact function/branch and confirm no existing test reaches it.
   - `tests-unnecessary`: must quote the low-value assertion or mock-only setup.
   - `persistence`: must quote the query and give either an `EXPLAIN` plan from Phase 1.6 or a written
     trace of rows visited per call as a function of data size.
   - `resilience`: must name the input or condition, the resource consumed, and the missing bound (or
     the number that exceeds the deployment limit).
   - `project-conventions`: must quote the rule with its `R-xx` id and source file, and the violating
     `file:line`. Old code that predates a rule is still reported.
   - all others: must cite exact `file:line` and a one-sentence reason a reviewer would agree with on sight.
5. **Confidence**:
   - `verified`: proven inside the repo (search, trace, quoted assertion, plan, failing probe).
   - `opinion`: a judgment call for the user to weigh.
   - `needs-confirmation`: depends on something outside the reviewed repo (a sibling service, the
     deployment, a library version not in the module cache). It MUST carry `settle_with`: the exact
     command, request or test that proves or refutes it in one run (e.g. `curl -sv -H 'Accept-Encoding:
     gzip' <url> | wc -c` compared with `Content-Length`). Multi-hop findings get dismissed as false
     alarms when the reader only checks one hop; the settle command prevents that.
6. **Severity follows impact, not size**: `Critical`/`Major` for wrong results, data loss, outages or a
   broken documented contract; a refactor that removes duplication or a leak of structure with no
   observable bug is `Minor` at most, however large the change.
7. **Sibling sweep — exhaust the class**: before filing a finding, search the whole scope for the same
   defect class (the same missing check, unbounded input, untested branch, doc overstatement, in every
   constructor, listener, adapter or route of the same kind) and list every site in `files` and
   `evidence`, with a table when there are more than three. The `proposed_action` fixes the class, not
   the cited line. A finding filed with one example is a finding the next round re-opens. In MR scope,
   siblings outside the diff are listed with `introduced_by_mr: "no"` rather than dropped when the same
   fix covers them.
8. **Read the decisions**: every agent receives `00-decisions.md` and never files a settled item.
9. **A zero is evidence, not a skip**: when a dimension yields no finding for a unit, `notes.md` lists
   the checklist items actually traced and how (search, read, plan).
10. **Output Requirements**:
   - Update `tasks.md` with status (`[x]` clean, `[!]` finding filed).
   - Write structured findings to `units/<unit>/findings.json`, schema-validated against
     `templates/finding-schema.json`. Every finding MUST include a `suggested_comment` (the exact text
     a reviewer would leave) and a `proposed_action` (the concrete fix or next step) — both will be
     user-editable in the final report, but must start populated and specific, never generic
     boilerplate like "please fix this".
   - Write `units/<unit>/notes.md` ending with:
     - `Coverage: <files and dimensions audited>`
     - `Not covered: <items skipped due to budget, with reason>`

---

## Phase 1.5 — Cross-Cutting Passes

Some defects only exist in the composed system. Dispatch these read-only agents in parallel, each in
its own worktree, each writing `findings/<pass>.json` with the same schema and `domain:
"cross-cutting"`:

1. **Architecture** (`wt-architecture`):
   - Module/package dependency graph: layering violations, circular dependencies, leaky abstractions
     crossing domain boundaries.
   - Consistency of architectural patterns across domains (e.g. one domain uses ports & adapters
     cleanly, another bypasses it with direct DB calls).
   - Storage choices leaking into ports and public contracts; write-capable dependencies reachable
     outside the unit of work.
   - For MR scope: whether the diff introduces a new architectural inconsistency relative to the rest of
     the codebase, not just relative to itself.
2. **Claims vs. code** (`wt-claims`): take every claim of `00-project-rules.md` and the API docs (status
   codes, defaults, limits, refusal order, call chain, security controls attributed to other services)
   and verify it against the code and, when in scope, the sibling repos. A wrong claim in an agent
   instruction file is a `project-conventions` finding; a wrong API doc is `adversarial-correctness`
   (contract mismatch).
3. **Harness fidelity** (`wt-harness`): diff each test harness and each real-instance tool against the
   production entry point (composition root, middleware chain, identity extraction, config loading).
   Every replaced or rebuilt piece is a blind spot; every behavior a single real user could observe
   that no tool checks is a `tests-missing` finding. Explicitly probe the refusal order of every write
   route.
4. **Persistence** (`wt-persistence`, when the project has a database): list every query per table with
   the index it relies on, every index with the queries that use it, and every write statement with
   the columns it rewrites. Unused indexes, unindexed hot paths, pages that enumerate the full set, and
   unbounded tables surface from this matrix, not from reading one file.

---

## Phase 1.6 — Runtime Verification (optional, with permission)

When Phase 0 allowed disposable containers and the project ships migrations:
1. Start a throwaway database container matching the production engine and major version.
2. Apply the project's migrations in order.
3. Seed data at the scale the code, docs or user state (e.g. one user with 50k documents, 200 teams
   sharing 5k each), using SQL `generate_series`, never production data.
4. Run `EXPLAIN (ANALYZE, BUFFERS)` on every hot query (lists, lookups by id, guarded updates) with the
   exact SQL the code builds, forcing a generic plan (`SET plan_cache_mode = force_generic_plan`) since
   drivers prepare statements.
5. Attach the relevant plan lines (index used, rows visited, time) to the matching `persistence`
   findings, and file new ones for plans that scan more than they return.
6. Stop and remove the container. Never connect to a database the user did not create for this step.

---

## Phase 2 — Consolidation & Triage Report Generation

1. **Merge**: combine every unit's `findings.json` plus every `findings/<pass>.json` into one array with
   globally unique IDs (e.g. `Q-NAMING-001`, `Q-DEADCODE-014`). Group by root cause: findings from
   different units or passes that share one cause and one fix become a single finding listing every
   site (two agents each reporting half of a class must not ship as two halves). Keep separate
   findings only when the fixes differ, and cross-reference them. Drop any finding that matches a
   `D-xx` of `00-decisions.md` and list it under **Decided** instead. Initialize every finding with
   `status: "pending"` and an empty `reviewer_note`.
2. Write the merged array to `.code-review/<run>/comments.json`. Every finding starts with
   `questions: []` — the question thread is populated by the user in the browser, never pre-filled by
   a subagent.
3. Generate `report.html` from `templates/report-template.html`:
   - Embed the findings array as the `{{FINDINGS_JSON}}` JSON literal.
   - Populate KPI, scope, and run-info placeholders.
   - The report is the deliverable the user triages: it supports **Validate / Invalidate / Delay**, and
     in-place editing of `suggested_comment` and `proposed_action` for every finding, with autosave to
     `localStorage` and JSON/Markdown export.
   - Every finding also has a **Copy Prompt** action that builds a ready-to-paste LLM prompt from the
     finding's fixed context (description, rationale, evidence) plus the current — possibly
     user-edited — `suggested_comment` and `proposed_action`, so the prompt always reflects the latest
     edits made in the report, not the original generated text.
   - Every finding has a **Questions** thread: the user can add a question, get a **Copy Prompt to
     Answer** (context + question, ready to paste into an LLM), and paste the reply back in — it
     appears as a threaded message (`role: "assistant"`) alongside the user's question
     (`role: "user"`). This is a manual round-trip (the static report has no live LLM connection); it
     does not change the finding's `status`.
   - Do not simplify or drop the triage controls, the Copy Prompt actions, or the Questions thread when
     populating this template.
4. Generate `full-report.md` (static Markdown mirror, grouped by dimension then severity) and
   `summary.md` (a skimmable executive brief under one page: counts by dimension/severity, top issues,
   a **Settle first** list of every `needs-confirmation` finding with its `settle_with` command, the
   counts of `new` / `repeat` / `regression` findings, and a **Decided** list: one line per settled item
   checked and set aside, with its `D-xx` source). If the stale target check found a newer branch, its
   warning opens both files.

---

## Phase 3 — Cleanup

Remove every git worktree created in Phase 0.5/1.5 (`git worktree remove`) and every container started
in Phase 1.6. Never leave a stray worktree or container behind.

---

## Phase 4 — Final Output

Print to chat:
- Direct paths to `report.html`, `full-report.md`, and `summary.md`.
- Summary table of findings by dimension and severity.
- A one-line reminder: open `report.html` in a browser to triage (validate/invalidate/delay, edit
  comments and proposed actions); use the **Export Triage JSON** button when done to keep a permanent
  record of the decisions, or **Export Validated as Markdown** to paste validated comments straight into
  an MR/PR.
