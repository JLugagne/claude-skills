# Checklist: Dead Code & Unused Artifacts

**Burden of proof**: every finding in this checklist MUST include the exact reference-search command
run (grep, `go-surgeon find_references`, IDE/LSP find-usages, or language equivalent) and its empty or
zero-hit result as evidence. Never flag dead code from visual inspection alone — dynamic dispatch,
reflection, DI containers, and test-only call sites are easy to miss by eye.

## 1. Unused Symbols
- [ ] **Unused functions/methods/types/constants/variables**, exported or not — confirmed with a
  whole-repo reference search including tests and any reflection-based or string-based dynamic call
  sites (route registries, plugin loaders, serialization tags).
- [ ] **Unused imports/dependencies**: declared in the module manifest (`go.mod`, `package.json`, etc.)
  but never referenced anywhere in the source tree.

## 2. Unreachable Logic
- [ ] **Unreachable branches**: conditions that can never be true (redundant checks after an early
  return, dead `else` following an unconditional return in the `if`).
- [ ] **Orphaned feature-flagged code**: the flag is permanently off, removed, or hardcoded — leaving a
  code path that can never execute.

## 3. Duplication & Orphans
- [ ] **Duplicate implementations**: two functions doing the same thing where one is provably never
  called, or copy-pasted logic where the original was superseded but never removed.
- [ ] **Orphaned files**: files not imported or referenced from anywhere in the build graph — confirm
  with a search, not just because the filename looks old.
- [ ] **Dead test helpers/fixtures**: helper functions or fixtures no longer exercised by any test.
