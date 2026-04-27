---
name: markers
description: "Use this skill whenever you need the exact format, lifecycle, or strict rules for the agile-team-v2 code markers — `// AC: <criterion>` + `// TODO(impl-<feature-slug>, ac-<NNN>)` + `panic(\"not implemented\")` (inlined by the architect during scaffolding above each scaffolded function body that maps to an acceptance criterion) and `// SCENARIO: <narrative>` + `// TODO(impl-<feature-slug>, scenario-<NNN>)` + `t.Skip(\"not implemented\")` (inlined by the PM in passe 2 inside business test skeletons under `pm_test_territories`). Covers the strict marker format that `check.sh` enforces (kebab-case feature-slug, three-digit zero-padded NNN, exact `ac-` or `scenario-` prefix), the `pm_test_territories` glob block declared in `.architecture/CONVENTIONS.md` (where `// SCENARIO:` markers may live), the seven-step marker lifecycle (architect scaffolds → PM passe 2 → red → green → e2e-tester → reviewer pass 2 → TODO removed when feature done while `// AC:` stays as permanent record), and the marker-based task lookup procedure (`grep -rn TODO(impl-...)` to locate the scaffolded body or test skeleton — replaces v1 TASK.md/TASK-red.md/TASK-green.md/SCAFFOLD.md prose intermediaries). Loaded by every agent that touches markers in any way: architect (writes `// AC:`), PM (writes `// SCENARIO:`), red (locates AC and writes assertions), green (reads AC and removes TODO when done), e2e-tester (locates SCENARIO and writes e2e assertions), reviewer (Pass 2 verifies marker ↔ user-journey alignment), sprint-planner (lists tasks by code marker in SPRINT.md). Bug-detective is the only agent that does not load this skill — it reads `// AC:` from committed code post-mortem without needing the format spec."
---

# Code markers

The intent of every feature in agile-team-v2 lives in two marker conventions, declared in `.architecture/CONVENTIONS.md`. They are the contract between agents — replacing the v1 prose intermediaries (TASK.md, TASK-red.md, TASK-green.md, SCAFFOLD.md).

---

## `// AC:` — Acceptance Criterion

Inlined by the **architect** during scaffolding, immediately above each scaffolded function body that maps to an acceptance criterion derived from the user journey.

```go
// AC: <one-line description of the criterion>
// TODO(impl-<feature-slug>, ac-<NNN>)
func (s *LoginService) Authenticate(ctx context.Context, c Credentials) (Session, error) {
    panic("not implemented: auth-login/Authenticate")
}
```

- `<feature-slug>` matches the directory under `.features/<slug>/`.
- `<NNN>` is local to the feature, zero-padded to three digits, starting at `001`.
- Numbering is **stable** for the feature's lifetime — never re-number, even after deletes.

For purely structural symbols (DTOs, error vars, enums) that do not represent a user-observable acceptance criterion, do not inline `// AC:` — minimal godoc only.

---

## `// SCENARIO:` — User-journey scenario

Inlined by the **PM in passe 2** (skipped if `mechanical: true`), inside business test skeletons that the architect scaffolded under `pm_test_territories`.

```go
func TestLogin_ValidCredentials(t *testing.T) {
    // SCENARIO: Marie logs in with valid credentials and lands on her dashboard
    // TODO(impl-auth-login, scenario-001)
    t.Skip("not implemented")
}
```

- `<NNN>` zero-padded, local to the feature, starting at `001`. Stable.
- The PM contributes only these three lines — no assertions, no fixtures, no helpers.
- The reviewer's pass 2 verifies every `// SCENARIO:` traces to a passage of `# User journey` in FEATURE.md.

---

## `pm_test_territories` — where SCENARIO markers may live

Declared in `.architecture/CONVENTIONS.md` as a YAML glob block:

```yaml
pm_test_territories:
  - tests/e2e-api/
  - tests/contract/
  - "**/usecase/*_test.go"
  - "**/usecases/*_test.go"
```

`check.sh` reads this block and rejects `// SCENARIO:` markers outside the territories — at pre-commit and CI. If you think a scenario belongs in a non-territory file, raise a `.questions/` entry for the architect to extend the territories — do not bypass.

---

## Lifecycle of a marker

| Step | Actor | What happens |
|------|-------|--------------|
| 1. Scaffolding | architect | Adds `// AC:` + `// TODO(impl-<slug>, ac-<NNN>)` + `panic("not implemented: ...")`. AC marker present, body panics. |
| 2. PM passe 2 | product-manager | Adds `// SCENARIO:` + `// TODO(impl-<slug>, scenario-<NNN>)` + `t.Skip("not implemented")` in business test skeletons (skipped if `mechanical: true`). |
| 3. Red | red | Locates `TODO(impl-<slug>, ac-<NNN>)`, writes failing assertions in the matching test file. For business tests, replaces only the `t.Skip` line — keeps `// SCENARIO:` and `// TODO(impl-...)` comments above. |
| 4. Green | green | Replaces `panic("not implemented: ...")` with implementation. `// AC:` comment stays in place. |
| 5. E2E-tester | e2e-tester | Locates `TODO(impl-<slug>, scenario-<NNN>)`, replaces `t.Skip` with real e2e assertions. `// SCENARIO:` and `// TODO(impl-...)` stay. |
| 6. Reviewer pass 2 | reviewer | Verifies every `// SCENARIO:` traces to a `# User journey` passage; every `# User journey` passage that warrants coverage has a `// SCENARIO:`. |
| 7. Once feature is `done` | reviewer (verifies) | All `TODO(impl-<slug>, ...)` lines must be **removed** from code (the implementation is in; the TODO is no longer accurate). `check.sh --mode ci` rejects a `done` feature with leftover `TODO(impl-<slug>, ...)`. |

Note step 7: **the `// AC:` comment stays**; only the `TODO(impl-...)` line is removed once the feature is done. The `// AC:` comment is a permanent record of the criterion that the function implements — the reviewer and bug-detective rely on it.

---

## Tasks are listed by code marker (no TASK*.md files)

In v2, every red/green/e2e task corresponds to one `TODO(impl-<slug>, ac-<NNN>)` or `TODO(impl-<slug>, scenario-<NNN>)` marker in the code. The agent locates its work via:

```bash
grep -rn "TODO(impl-auth-login, ac-001)" .
```

The match points at:
- For an `ac-` marker: the scaffolded body in production code, with `// AC:` immediately above. The corresponding test file is a sibling `*_test.go` (the pair red/green works on).
- For a `scenario-` marker: a business test skeleton in `pm_test_territories` with `// SCENARIO:` immediately above (the e2e-tester's task).

There are **no** `TASK.md`, `TASK-red.md`, `TASK-green.md`, `SCAFFOLD.md`, or per-feature `TASKS.md` files. Anyone tempted to create one should stop — the v2 convention is markers in code, not prose intermediaries. Spec isolation between red and green is preserved by **discipline**, not by separate files.

---

## Marker format — strict

The pre-commit hook and `check.sh` reject malformed markers. The accepted forms are:

```
TODO(impl-<feature-slug>, ac-<NNN>)
TODO(impl-<feature-slug>, scenario-<NNN>)
```

Where:

- `<feature-slug>` — kebab-case, matches the directory under `.features/<slug>/`.
- `<NNN>` — exactly three digits, zero-padded.
- `ac-` or `scenario-` — exactly these two prefixes; nothing else (no `criterion-`, no `s-`, no abbreviations).

A malformed marker is a pre-commit block.
