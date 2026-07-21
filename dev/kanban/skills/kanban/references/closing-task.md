# Closing a task

Used when work on a task is finished and it should be marked `done`. The closing process is the **last safety net** against marking a task done prematurely.

**The reviewer's mindset is adversarial: refute-first.** The reviewer's job is *not* to confirm the task is done — it is to try, actively and in good faith, to **prove it is *not* done**. Assume the work is incomplete until you have genuinely tried and failed to break it. Hunt for the missing file, the feature that was scoped but never built, the code that exists but is never called, the test that passes without actually exercising the feature, the error path nobody handled. A reviewer that sets out to confirm "done" will always find a way to confirm it; a reviewer that sets out to disprove "done" is the only one that catches premature closure. You concede `done` only when your attempts to disprove it have failed.

**Prerequisites:** read `references/structure.md` and `references/definition-of-done.md`.

## Hard rule

**A task cannot transition to `status: done` until every Actions checkbox AND every Definition of Done checkbox is `[x]`.** This is non-negotiable. No exceptions for "I'll fix it in the next task" or "the DoD was wrong anyway."

**Second hard rule: the close audit must be run by a *different* agent/model than the one that did the work.** An agent marking its own homework is the core trust gap of an autonomous board (see SKILL.md). The author runs `task.sh check` and prepares the close, but flipping `status: done` requires a separate reviewer to run the audit below and confirm. See "The separate-reviewer requirement" below for how this works in practice.

If you find yourself wanting to close with unchecked items, you have three options and only three:

1. **Finish them.** Do the remaining work.
2. **Move them to a follow-up task.** Create a new task explicitly, link via `blocked_by` or in Discussion, remove the item from this task (with a Discussion entry).
3. **Mark this task as `cancelled`.** If the premise was wrong, cancel honestly. Don't fake-close.

## Checklist

```
- [ ] (author) Run `task.sh check <path-to-task.md>` — must exit 0 (boxes + run: commands pass)
- [ ] (author) All code is committed on the task branch
- [ ] (author) Add a Discussion entry: "ready for review" + how to verify each DoD item
- [ ] (reviewer — a DIFFERENT agent/model) Re-run `task.sh check`
- [ ] (reviewer) Try to prove work is MISSING: enumerate files/features/wiring the task implies and look for each — see "Try to prove it's not done" below
- [ ] (reviewer) Run the target language's linters / static analysis, even if the DoD didn't ask for it (see "Run the linters")
- [ ] (reviewer) Write red-tests that attack the gaps — a test that SHOULD pass if the task is done; try to make it fail (see "Write red-tests")
- [ ] (reviewer) Nitpick the diff — useless/lying comments, incomprehensible code, architecture smells; be the picky reviewer nobody wants (see "Nitpick code quality")
- [ ] (reviewer) Every Actions checkbox is [x] (no [ ] or [!])
- [ ] (reviewer) Every Definition of Done checkbox is [x] (no [ ] or [!])
- [ ] (reviewer) Attack each DoD item: don't re-confirm it, try to break it — re-run the test, re-grep the code, re-run the scenario with adversarial input
- [ ] (reviewer) If ANY attempt to disprove succeeded: run `task.sh reject <path> "why"`, record findings in Discussion, and hand to a fixer — do NOT fix-and-close yourself (see "When the reviewer refutes")
- [ ] (reviewer) Add the closing Discussion entry confirming the audit AND what you tried to break
- [ ] (reviewer) Update status from in_progress to done (ONLY if every attempt to disprove failed)
- [ ] Tell the user the task is closed, with the branch name and a one-line summary
```

`task.sh check` is the mechanical safety net: it counts checkboxes and refuses to pass if anything is still `[ ]` or `[!]`. **Run it first.** If it exits non-zero, you don't need to do the rest of the audit — the task isn't closeable yet.

## The separate-reviewer requirement

The agent that wrote the code is the worst-placed to judge whether it's done — it shares every blind spot and every optimistic assumption that produced the code. So closing is split into two roles:

- **Author** — does the work, keeps checkboxes honest, runs `task.sh check` until it's green, commits, and then *hands off*. The author does **not** flip `status: done`. Instead it leaves a Discussion entry saying "ready for review" and listing how each DoD item can be verified.
- **Reviewer** — a *different* agent or model — runs the pre-close audit below from scratch with an adversarial goal: **disprove "done"**. It tries to prove work is missing, runs the language's linters, writes red-tests to attack the gaps, and attacks each DoD claim rather than re-confirming it. It flips `status: done` and writes the closing Discussion entry **only when every attempt to disprove completeness has failed**. When it *does* find a defect, it does not fix it — it runs `task.sh reject`, records the findings, and hands back to a fixer (see "When the reviewer refutes: the rework loop").
- **Fixer** — an author pass triggered by a rejection: a *different* agent than the reviewer, it reads the reviewer's findings, reworks the code, and hands back for a fresh review. The same "never mark your own homework" rule applies — the fixer never closes the task it just fixed.

How to satisfy "different agent/model" in practice, strongest first:

1. **A separate review pass with a stronger model** (e.g. author = Haiku/Flash, reviewer = Sonnet/Opus). This is the recommended setup for autonomous runs — it also catches the subtle "marked `[x]` but doesn't actually verify" failures that `task.sh check` can't see. See the SKILL.md "Use a different model for reviewing" prompt.
2. **A fresh agent instance / new session** acting as reviewer, even on the same model — a clean context re-derives the verification instead of trusting working memory.
3. **The human user** as reviewer, when no second agent is available.

If you are a single agent with no reviewer available and the user hasn't taken that role, do not silently self-close. Run `task.sh check`, prepare everything, and **tell the user the task is ready for review and needs a second pass before it can close**. A board where agents mark their own homework is exactly the failure this requirement prevents.

`run:`-backed DoD items (see `definition-of-done.md`) are the author's best friend here: the more of the DoD that `task.sh check` executes automatically, the less the reviewer has to take on trust.

## Pre-close audit (the critical part)

Before flipping `status: done`, go through the audit. Do not skip it even if you're confident. Run it as an attempt to **disprove** completeness, not to confirm it. Every step below is phrased as an attack — the task only closes if the attack fails.

### Step 1: Try to prove work is MISSING

Start here, before touching the checkboxes. Read the task title, description, DoD, and the epic/PRD it feeds, then enumerate everything the task *implies* should now exist and go hunting for the gap:

- **Missing files.** Does every file the task should have created/modified actually exist? A handler with no route file, a model with no migration, a feature with no test file — list what's expected and `ls`/grep for each.
- **Missing features.** Break the task's scope into the smallest observable behaviors. For each, find the concrete code path that implements it. If you can't point at the code, the feature is missing — regardless of what the checkbox says.
- **Missing wiring.** New code that nothing calls is dead code (also Step 4). Search for callers of every new public symbol.
- **Missing edge/error cases.** What happens on empty input, nil, timeout, duplicate, permission denied, upstream 5xx? If the task is user-facing or stateful and none of these are handled, the task is not done.

Write down what you looked for and whether you found it — this goes in the closing Discussion entry. If you find a genuine gap, **the task cannot close**: change the relevant box back to `[ ]`, and either fix it or open a follow-up (Discussion entry + remove the item).

### Step 2: Run the linters and static analysis

Detect the target language(s) of the changed code and run its standard tooling **even if the DoD didn't ask for it**. The DoD's `| run:` commands are the floor, not the ceiling. Examples (use what fits the project — check the repo's config/CI for the canonical set, prefer current tools over deprecated ones):

| Language        | Run (non-exhaustive)                                                   |
| --------------- | ---------------------------------------------------------------------- |
| Go              | `go vet ./...`, `golangci-lint run`, `go build ./...`, `gofmt -l .`    |
| TypeScript / JS | `tsc --noEmit`, `eslint .`, `prettier --check .`                       |
| Python          | `ruff check .`, `mypy .`, `pytest -q`                                  |
| Rust            | `cargo clippy -- -D warnings`, `cargo fmt --check`, `cargo test`       |

Any new lint/type error, warning, or format drift introduced by this task is a defect. It does not have to fail `task.sh check` to block the close — the reviewer applies judgment: pre-existing warnings unrelated to the task are noted, not blocking; anything the task introduced is blocking until fixed or explicitly deferred with a Discussion entry.

### Step 3: Write red-tests to attack the gaps

Don't only re-run the author's tests — the author wrote those to pass. Add **red-tests**: tests you *expect the feature to satisfy if it is truly done*, written specifically to expose the gaps you suspect from Step 1. The goal is to make them fail.

- Write a test for the edge/error case the author likely skipped. If it fails, you found real missing work.
- Write a test that asserts the observable end-to-end behavior from the outside (not the internals the author already covered). If the feature isn't wired, it fails.
- **The removal test:** if you delete or no-op the code the task added, does the author's test suite still pass? If yes, their tests don't actually exercise the feature — the "test passes" DoD is functionally meaningless. Reinstate the code and note the weak coverage.

A red-test that *fails* is a finding: the task is not done — reopen it (or file a bugfix/follow-up). A red-test that *passes* after honest effort to break the feature is evidence the task really is complete — keep it, it strengthens the suite. Either way, the red-tests you wrote go into the branch and are mentioned in the closing Discussion entry.

### Step 4: Attack the Actions section

For each Actions item:

- Is it `[x]`? If `[ ]` or `[!]`, **the task cannot close**.
- Is the `[x]` honest? Did the author actually do this, or mark it optimistically as they went? Assume the latter until you've re-checked.
- Re-check by running the code or reading the file — don't take the box on trust.

If you find any item that was incorrectly marked, change it back. Then either finish it, drop it (Discussion entry + remove), or move it to follow-up.

### Step 5: Attack the Definition of Done — the most important step

For each DoD item, try to break the claim rather than confirm it. Don't trust the checkbox state from earlier:

- Is it `[x]`? If `[ ]` or `[!]`, **the task cannot close**.
- **"Test X passes"** → re-run the test yourself. Then ask whether it would still pass if the feature were broken (Step 3's removal test). Do not trust memory.
- **"Function X is called from Y"** → re-grep. If grep returns zero matches, the DoD is false.
- **"End-to-end scenario"** → re-run it with adversarial input, not the happy path the author used. Don't assume.
- **"Migration applied"** → check the DB or migration history. Don't assume.
- **"No regression"** → re-run the full test suite.

If any DoD item turns out to actually not pass: change it back to `[ ]` and **do not close the task**. Either fix the underlying issue, or open a follow-up task and remove this DoD item with a Discussion entry explaining the discovery.

### Step 6: Attack the integration

This is the audit that catches the most subtle failures. Ask, adversarially:

- **Is the code actually wired into the application?** Search for callers. If new functions exist but nothing calls them, the task is not done — the code is dead.
- **Does the task's claimed contribution to the PRD actually exist?** Re-read the relevant Success criterion or Integration contract scenario. Can you trace it through real code paths from input to output? If you can't, assume it doesn't.
- **If I removed the test the author added, would the feature still appear to work?** If yes, the test isn't testing the feature — it's testing something tangential. "Test passes" might be technically true but functionally meaningless.

### Step 7: Nitpick code quality — be the reviewer nobody wants

This is where the reviewer is deliberately, professionally *insufferable*. A task can be functionally complete and still be a mess. Go through every line the task changed (the diff, not the whole repo) and pick at it. Assume something is wrong on every line until it proves itself clean. Be the picky reviewer everyone dreads — the point is to catch what a polite reviewer waves through.

- **Useless / lying comments.** Flag comments that restate the code (`i++ // increment i`), comments that describe what the code *used* to do, commented-out dead code, TODO/FIXME/XXX left behind, and comments that no longer match the code they sit above (a comment that lies is worse than none). If this project's conventions forbid comments on code, *any* such comment is a defect.
- **Incomprehensible code.** Single-letter names outside tight loops, functions that don't say what they do, deeply nested conditionals, a 200-line function that should be five, clever one-liners that take a minute to read, magic numbers with no name. If you have to read a block twice to understand it, that's a finding — write it down.
- **Architecture / design smells.** Layering violations (a handler reaching into the DB directly, business logic in a transport adapter), duplicated logic that should be shared, a new abstraction that has exactly one caller, tight coupling to a concrete type where an interface was the pattern everywhere else, global mutable state, error handling that swallows or logs-and-continues, inconsistency with the patterns the surrounding code already established.
- **Dead ends & sloppiness.** Unused variables/imports/params, copy-paste with a stale name, inconsistent formatting the linter didn't catch, misleading names (`getUser` that also mutates), missing error wrapping/context, resources never closed.

Every nit gets recorded. For each, decide its weight:

- **Blocking** — anything that will bite maintenance or hides a bug (misleading name, swallowed error, layering violation, incomprehensible core logic). The task does **not** close until it's fixed or explicitly deferred with a Discussion entry and a follow-up task.
- **Non-blocking nit** — pure style/taste that the linter didn't own. Note it in the Discussion entry so it's on record; don't hold the close hostage to it, but don't stay silent either.

The reviewer's reputation here is a feature, not a bug: a task that survives a genuinely picky pass is one the next session can trust.

### Step 8: Audit the title and description

- Does the title still accurately describe what was shipped? If the work drifted, either rewrite the title (with a Discussion entry explaining the drift), or acknowledge that the original task isn't what got built and open a more honest replacement.
- Does the description still match? Same question.

### Step 9: Audit the Discussion

- Glance through the Discussion entries. Would a future session understand the decisions?
- If a non-trivial choice was made during this task but never logged, log it now (with today's date) — better late than never.
- If a DoD item was changed during the task, is the change documented in Discussion?

## When the reviewer refutes: the rework loop

If any step above found a real defect — missing work, a failing red-test, a blocking nit — the task does **not** close. It enters a rework loop.

**The reviewer does not fix the code itself and then close.** If it patched the problem and flipped `status: done`, it would be marking its own homework — the exact trust gap the author/reviewer split exists to prevent. The reviewer's job ends at *finding and recording*; fixing is a fresh author pass.

The loop, one cycle:

```
reviewer refutes ──▶ task.sh reject <path> "why"   (status → in_progress, review_rejections++)
                          │
                          ▼
      fixer agent picks up the diff + the reviewer's findings from ## Discussion,
      fixes them NOW, gets `task.sh check` green, commits, hands back "ready for re-review"
                          │
                          ▼
      a reviewer (DIFFERENT agent than the fixer) re-runs the full adversarial audit from scratch
                          │
              ┌───────────┴───────────┐
        validates                 refutes again ──▶ back to the top
        (closes the task)
```

Concretely:

1. **Reviewer:** run `task.sh reject <task-path> "one-line reason"`. It bumps `review_rejections`, sends the task back to `status: in_progress`, and (past the limit) stops the run — see the guard below. Then write the findings in full into `## Discussion` (dated), so the fixer knows exactly what to fix. The script moves state; you supply the detail.
2. **Fixer** (an author pass — must be a *different* agent than the reviewer, same as the original author-vs-reviewer rule): read the diff and the reviewer's `## Discussion` findings, fix them immediately, re-run `task.sh check` until green, commit on the task branch, and leave a "ready for re-review" entry.
3. **Reviewer** (again, different from the fixer): re-run the *entire* pre-close audit from scratch — not just a spot-check of the fixed item. A fix often breaks something the first pass had cleared.
4. Repeat until the reviewer validates and closes, or the guard trips.

### The anti-looping guard

An autonomous loop can thrash: fix, reject, fix, reject, forever. The guard caps it. `task.sh reject` counts rejections in `review_rejections`, and **once a task has been rejected more than twice (the 3rd rejection), the script sets `status: blocked`, exits with code `3`, and the kanban STOPS.** That is a hard escalation: do not start another fix attempt. Tell the user the task can't be closed automatically — the rework loop isn't converging and it needs a human decision (rescope, split, change of approach, or accept a known limitation). Two automated rework cycles is the ceiling; a third failure means the problem is not one more patch away.

- The counter accumulates for the life of the task; a successful rework does not reset it. This is deliberate — a task that keeps limping past review shouldn't be able to reset its way around the limit.
- `MAX_REJECTS` defaults to 2. It can be overridden per run (`MAX_REJECTS=3 task.sh reject ...`) but the default exists to force the escalation; prefer raising it only when the user asks.

### Reject vs. follow-up: which one

Not every finding feeds the reject loop.

- **In-scope defect** (the task's own DoD/scope isn't actually met — missing wiring, unhandled error the task owned, a blocking nit in the task's diff) → `task.sh reject` + rework. This is what the loop is for.
- **Out-of-scope or large** (the finding is real but belongs to different work — a pre-existing bug the task merely touched, a refactor the task shouldn't grow to include) → open a **follow-up task** (`bugfix` with a regression test, or a new feature task) linked via `blocked_by`, and don't spend a reject on it. Use judgment; when in doubt, reject and rework rather than defer.

## The closing Discussion entry

After the audit passes, add a final entry that wraps up the task. Format:

```markdown
### YYYY-MM-DD — Task closed
Shipped: brief summary of what now exists in the codebase as a result.
DoD verified: confirm that each DoD item was re-checked just now (and how).
Tried to break it: what the adversarial pass attacked — gaps hunted, linters run,
  red-tests written, nits found — and why each attack failed (or what it forced you to fix).
Branch: task/TASK-NNN-<slug>
Follow-ups: any tasks created as a result of this work (with IDs), or "none".
```

Example:

```markdown
### 2026-05-25 — Task closed
Shipped: silent OAuth refresh with token rotation on every call. Refresh
tokens stored encrypted in the sessions table with a 30-day TTL.
DoD verified:
  - TestRefreshHappyPath: re-run, passes
  - TestRotatedTokenReuseFails: re-run, passes
  - grep "RefreshHandler.Refresh" in internal/ → 2 matches in auth/middleware.go
  - migration 004_refresh_tokens applied (verified via \d refresh_tokens)
  - All previously-passing tests still pass (go test ./... exit 0)
Tried to break it:
  - Hunted for a missing revoke path — found none; rotation covers it.
  - golangci-lint run: clean; go vet: clean.
  - Red-test TestConcurrentRefreshRacesToOne: written to force a double-rotation,
    failed to break it (exactly one succeeds). Kept in the suite.
  - Removal test: no-op'd Refresh() → TestRefreshHappyPath fails as expected, so
    the test really exercises the feature.
  - Nit: comment "// refresh the token" above Refresh() was noise → removed.
Branch: task/TASK-042-refresh-rotation
Follow-ups: TASK-051 (token cleanup cron), TASK-052 (admin UI to revoke sessions).
```

The "DoD verified" and "Tried to break it" lines are the critical addition — they prove the audit happened adversarially, not just claimed.

This closing entry is what a future session reads first when looking back at the task. Make it useful.

## Merging the branch

The skill itself does not dictate merge workflow — that's the user's choice (PR, direct merge, squash-merge, etc.). But:

- Don't delete the branch on its own. Leave that to the user / their normal git workflow. The `branch:` field still references it, and even after deletion, `git log` from a parent branch can find the commits if needed.
- Keep the `branch:` field populated in the closed task — it's the record of where the work happened, useful for archaeology later.

## When to NOT close

- If anything is genuinely deferred to "later", make a follow-up task. The current task is `done` only for what was actually finished. Don't leave a `done` task with a hopeful `[ ]` still hanging — anywhere.
- If the work revealed that the task's premise was wrong (e.g. the feature doesn't make sense the way it was scoped), use `status: cancelled` instead of `done`, with a Discussion entry explaining why.
- If a DoD item turns out to be impossible to satisfy with the current architecture, that's a strong signal. Either the architecture needs to change (which is a bigger conversation with the user) or the DoD was overspecified (also a conversation). Do not close with the DoD item silently dropped.

## After closing an integration-verify task

Integration-verify tasks closing successfully is the strongest signal a milestone is on track. After closing one:

- Check whether all tasks in the verified epic are now `done` (not just the integration-verify task itself).
- If yes, the epic is effectively complete. Mention this to the user.
- Update the epic's `doc.md` Open questions section if anything got resolved by the integration testing.

If an integration-verify task **doesn't** close (DoD items fail), do not close it. The failure means the verified tasks are not actually done. Open bugfix tasks against them. This is exactly the behavior the integration-verify pattern is meant to produce — it surfaces premature `done` markings on prior work.

## After closing

After closing, the natural follow-up is usually one of:

- The next task in the same epic (run `task.sh dump <milestone>`, find next `todo`).
- A follow-up task you just created.
- The integration-verify task for this epic (if you just closed the last feature task).
- Stopping for the session.

Mention the natural next step to the user briefly, but don't auto-load it — let them decide.

## A note on the temptation to close

When working autonomously (especially with a small model), there is a strong pull toward closing tasks because closing feels like progress. Resist this pull. **Slow closing is correct closing.** The audit is not bureaucratic overhead; it is the mechanism that makes the kanban produce trustworthy "done" states. Without honest closing, the board lies, and a lying board is worse than no board at all.

If the audit reveals an issue, you have not "failed to close" — you have **succeeded at catching premature closure**. That is the system working as designed.
