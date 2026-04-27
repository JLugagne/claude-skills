---
name: tdd-pattern
description: "Use this skill whenever you are running as the `red` or `green` agent on an agile-team-v2 task. Covers the discipline-based spec isolation between red and green (no private TASK*.md files exist; the only handoff is committed code/tests), the in-scope vs out-of-scope rules of the red/green pattern (applies to standard and architectural complexity features only — mechanical maintenance is a mono-agent task), the mono-assistant safeguard when one Claude instance must wear both hats sequentially (commit red first, fresh session before reading green-side material — `check.sh` audits this at sprint review), and the marker-based task lookup procedure (grep for `TODO(impl-<slug>, ac-<NNN>)` to locate the scaffolded body and its sibling test file). Loaded only by `red` and `green`. Other agents (architect, PM, sprint-planner, e2e-tester, reviewer, bug-detective) operate outside the live red/green isolation flow and do not need these rules."
---

# TDD pattern — red and green discipline

The strict TDD workflow paired teammates run for `standard` and `architectural` complexity features in agile-team-v2. This skill captures the rules that *only* apply to red and green, so they can be removed from the global `agile-project` skill (which every agent loads).

If you are reading this and you are not red or green: stop. You don't need this skill. The high-level "Red/Green pattern — ABSOLUTE RULE" stub in the `agile-project` skill is enough for context.

---

# Spec isolation — by discipline, not by file

In v2 there are no `TASK.md`, `TASK-red.md`, or `TASK-green.md` files. Both red and green find their work via the inline marker `TODO(impl-<slug>, ac-<NNN>)` in the production code, looked up via `grep`. There is no private spec for either side; isolation is preserved by **discipline**, audited by `check.sh` and by the reviewer's pass DoD post-mortem.

## What red reads

- The `// AC: <description>` comment immediately above the scaffolded body that the architect inlined.
- The scaffolded function or method signature itself (parameters, return types, receiver).
- For business tests (when the matching test skeleton in `pm_test_territories` carries a `// SCENARIO:` marker placed by the PM): that scenario line.
- Applicable DECISIONS and ADRs listed in FEATURE.md `## Relevant decisions`.
- FEATURE.md `# User journey` for context (when `// AC:` or `// SCENARIO:` on its own is too short).
- Existing test files in the same package — for fixture and pattern continuity (table-driven style, mock setup, helper conventions).
- `.architecture/CONVENTIONS.md` — `pm_test_territories` glob, marker format.

What red **does not** read:

- Anything green has not yet committed. No drafts, no live working tree, no out-of-band coordination.
- Other markers' tasks in the sprint, unless an explicit dependency is documented in `SPRINT.md`.

If red believes information needed to write a test exists only in green's head, the contract is incomplete — raise a dispute (decision A — architect revises) instead of trying to read green-side material.

## What green reads

- The `// AC:` description on the scaffolded body.
- The scaffolded signature.
- **Red's committed test assertions** — this is the single exception to "only your own contract." The committed tests are your behavioural target.
- Applicable DECISIONS and ADRs.
- FEATURE.md `# User journey` for context.
- Existing production code in the same package — for pattern continuity (error handling style, logging, transactional patterns).
- `.architecture/CONVENTIONS.md`.

What green **does not** read:

- Red's in-flight work — only red's committed tests.
- Any "task spec" file — none exists.

If green believes red's intent cannot be inferred from the committed tests, the test code is too sparse — raise a dispute against red, not a private peek.

## The handoff is exactly two commits

Red → green: red commits failing tests under `Task: <slug>-T<NNN>-red`. Nothing else. No teammate message can leak design intent that was not first committed.

Green → reviewer/e2e: green commits the implementation under `Task: <slug>-T<NNN>-green`. Red's tests now pass.

If anything beyond these two commits crosses between red and green during the live phase, the discipline is broken. The reviewer flags it at pass DoD.

---

# In scope vs out of scope of the red/green pattern

The pattern applies to **production-code feature work** at `standard` or `architectural` complexity. It does **not** apply to mechanical maintenance, where there is a unique correct answer and no design decision worth a paired pass.

| In scope (the rule applies)                                           | Out of scope (rule does not apply)                              |
|-----------------------------------------------------------------------|-----------------------------------------------------------------|
| `complexity: standard` features                                       | Rename a local symbol with no API change                        |
| `complexity: architectural` features                                  | `gofmt`, `goimports`, linter auto-fixes                         |
| Bug fixes that change observable behaviour                            | Dependency bump with no API impact                              |
| New exported APIs, signatures, types                                  | Comment / log message / error string fixes                      |
| Behaviour changes covered by `// AC:` markers                         | Regenerating mocks after an interface change already decided    |
|                                                                       | `complexity: mechanical` features (mono-agent task — no red/green pair) |

When in doubt, classify **upward** (`standard` over `mechanical`). Under-classification is corrected by an in-flight upgrade dispute (type G); over-classification only wastes one cheap pair.

If the sprint-planner mistakenly assigns you to a mechanical task that should have been a mono-agent assignment, raise a dispute (escalation E or F) rather than running through the full red/green ceremony for plumbing.

---

# Mono-assistant safeguard

If the same Claude instance must be both red and green for the same task — typical when agent teams aren't enabled and you're working solo — the discipline is not enforced by the runtime, only by your own resets.

The rule:

1. Complete the **red phase end-to-end**: write the failing tests, run them, confirm they fail for the expected reason (panic from scaffold), and **commit** under `Task: <slug>-T<NNN>-red`.
2. **Start a fresh session** before reading anything green-side. In Claude Code: `/clear` or open a new conversation. The session reset is what purges `// AC:`-side context, your own internal test design rationale, and any partial implementation thoughts you may have had during red.
3. The new session reads only the green inputs: `// AC:` description, the scaffolded signature, **the test files committed in step 1**, and any source files referenced. It must **not** consult any in-memory recollection of "why I wrote the test that way."
4. The red commit is the only handoff. If, while in green, you find yourself thinking "I need to know why red wrote test X," that thought is a signal the test code is too sparse — open a dispute against red (your past self, but the dispute is on the public artifact). Amend the test in a follow-up red commit, then continue green.

`check.sh` audits at sprint review: for every task where red and green were the same assistant, `git log` must show **at least one commit** between the red and green work — i.e., the `Task: <slug>-T<NNN>-red` commit is mandatory before any `Task: <slug>-T<NNN>-green`. A task whose red and green files appear in a single combined commit is treated as an isolation violation and blocks the sprint REVIEW.

This rule does **not** prohibit a single assistant from doing red and green on the same task. It just makes the boundary explicit, observable, and machine-checkable.

---

# Locating your task — the marker lookup procedure

In v2 every red/green/e2e task corresponds to one `TODO(impl-<slug>, ac-<NNN>)` (red/green) or `TODO(impl-<slug>, scenario-<NNN>)` (e2e — out of scope for this skill) marker in the code. The agent locates its work via `grep`.

## Red lookup

```bash
# Given your assignment in SPRINT.md:
#   - [ ] red — TODO(impl-auth-login, ac-001)

grep -rn "TODO(impl-auth-login, ac-001)" .
```

The match points at:

- The scaffolded production body in the production code, with the `// AC:` description immediately above and `panic("not implemented: ...")` below.
- For business tests: a sibling `*_test.go` skeleton in `pm_test_territories` carrying the matching `// SCENARIO:` marker placed by the PM (with `t.Skip("not implemented")` to be replaced).

For non-business tests (adapter, repository, parser, helper), the test file is in the same package as the production code; you create a fresh `func TestXxx(t *testing.T)` (or table entry) that exercises the AC.

For business tests: locate the scaffolded test skeleton (already present, scaffolded by the architect, with `// SCENARIO:` line already added by the PM) and replace **only** the `t.Skip("not implemented")` line with your assertions. Keep `// SCENARIO:` and `// TODO(impl-...)` comments intact above — the reviewer's pass 2 needs them.

## Green lookup

```bash
# Given your assignment in SPRINT.md:
#   - [ ] green — TODO(impl-auth-login, ac-001)

grep -rn "TODO(impl-auth-login, ac-001)" .
```

The match points at the same scaffolded production body with `// AC:` and `panic("not implemented: ...")`. Your job is to replace the `panic` with the implementation that makes red's committed tests pass.

To find red's committed tests for the same marker:

```bash
grep -rn "TODO(impl-auth-login, ac-001)" -- '*_test.go'
```

Or by package convention (sibling test file in the same directory).

The committed tests are your contract. Read them with `go-surgeon symbol`; do not look at any uncommitted state.

---

# Anti-patterns

- **Reading the other side's working tree.** Forbidden. Only committed artifacts cross between red and green.
- **Coordinating design intent over teammate messages outside of dispute files.** Disputes are public artifacts; private chat is not. If something needs to be said between red and green that the planner might need at arbitration, say it in `.disputes/SPRINT_00X/<TASK_ID>.md`.
- **Combining red and green commits.** One commit per phase, in order. The reviewer's pass DoD blocks combined commits.
- **Skipping the session reset in mono-assistant mode.** The reset is not optional — it's what makes the discipline auditable.
- **Running the red/green pattern on a `complexity: mechanical` task.** That should be a mono-agent assignment. Raise a dispute if the sprint-planner queued you incorrectly.
- **Modifying scaffolded signatures or `// AC:` comments.** Forbidden for both red and green. If the contract is wrong, raise a dispute (decision A — architect revises).
- **Adding a new exported symbol from green.** Forbidden — that's the architect's territory. Green may add private (unexported) helpers, logged in `RETRO.md helpers_added:`.

---

# Commit format reminder (red and green only)

Red:

```
red: assertions for <feature-slug>/<short-name>

Feature: <feature-slug>
Task: <feature-slug>-T<NNN>-red
```

Green:

```
green: implement <feature-slug>/<short-name>

Feature: <feature-slug>
Task: <feature-slug>-T<NNN>-green
[Authored-By: green]   <-- only if .decisions/ touched (R2 tactical DECISION)
```

The full commit format spec lives in the `agile-project` skill. The above is the daily case.
