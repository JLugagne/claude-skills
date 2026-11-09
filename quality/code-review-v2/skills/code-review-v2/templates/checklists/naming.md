# Checklist: Naming Logic & Consistency

## 1. Clarity
- [ ] **Ambiguous / non-descriptive names**: flag generic identifiers (`data`, `tmp`, `val`, `obj`,
  `handleStuff`, `process()`, `DoWork()`) that give no clue about content or purpose from the name alone.
- [ ] **Misleading names**: the name promises behavior the code doesn't deliver — a `GetUser` that also
  mutates state, an `IsValid` that panics instead of returning a bool, a `Close` that doesn't release
  anything.
- [ ] **Boolean naming**: booleans not phrased as predicates (`enabled` vs. `status`), or double
  negatives (`disableNotEnabled`) that force the reader to mentally invert logic.

## 2. Consistency
- [ ] **Inconsistent terminology for the same concept**: the same entity called by different names
  across the codebase (`customer` / `client` / `account` for the same domain object) — confirm via a
  cross-file search before flagging.
- [ ] **Convention violations against the language's own idioms**: casing mismatches (Go exported vs.
  unexported casing, acronym casing — `Id` vs `ID`, `Url` vs `URL`), or mixing conventions within the
  same package.
- [ ] **Drift from the codebase's own established pattern**: new code introduces a different naming
  scheme than the rest of the package/domain uses for equivalent concepts, without justification.

## 3. Structure
- [ ] **Generic package/module names hiding real responsibility**: `util`, `common`, `helpers`, `base`
  used as a dumping ground instead of a name describing what the package actually does.
- [ ] **Interface naming**: single-method interfaces not named by capability (`-er` suffix convention
  where the language uses it), or interfaces named so generically (`Manager`, `Service`, `Handler`)
  that the name gives no signal about what's being managed/handled.
- [ ] **Magic values without named constants**: literal numbers or strings with implicit meaning that
  should be a named constant or enum value.
