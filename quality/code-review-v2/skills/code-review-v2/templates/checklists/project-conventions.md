# Checklist: Project Conventions (Rules the Project Wrote Down)

The project's own documented rules beat any generic style guide. This checklist is generated per run
from `00-project-rules.md`, which Phase 0 extracts from `CLAUDE.md` (every level: user, project,
nested), `AGENTS.md`, `CONTRIBUTING.md`, linter configs and architecture docs. **Burden of proof**:
quote the rule (with its source file) and the violating `file:line`. Report every violation, including
old code the rule predates: the user decides what to fix, not the reviewer.

## 1. Test Rules
- [ ] **Test structure rules**: table-driven tests, maximum number of cases per test function, at least
  one success and one failure case, test package naming (`_test`, `_internal_test.go`), build tags for
  container-backed tests. Check every test function, end-to-end tests included; count the cases.
- [ ] **Mock rules**: e.g. hand-written function mocks whose unset functions panic instead of returning
  zero values.
- [ ] **Test-first rules for bug fixes**: recent `fix` commits without a test added in the same commit.
- [ ] **Real-instance check tools** the project documents (smoke runners, chain checks under `tools/`):
  behaviors added or fixed since their last update that they do not exercise.

## 2. Code Rules
- [ ] **Error handling rules**: e.g. `errors.Join(errors.New("context"), err)` instead of `%w`, typed
  domain errors mapped in one place.
- [ ] **Comment rules**: no comments in function bodies, doc comments only on exported symbols and only
  when they carry what the signature cannot, comment language.
- [ ] **Layering and placement rules**: which package may import which, where SQL lives, schema
  qualification, transactions only through the unit of work.

## 3. Documentation Rules
- [ ] **Statements in the instruction files that the code contradicts**: the documented call chain,
  security controls (who authenticates, who rate-limits), limits, defaults. An instruction file that is
  wrong misleads every future agent; treat it as a defect of the file, with the code as evidence.
