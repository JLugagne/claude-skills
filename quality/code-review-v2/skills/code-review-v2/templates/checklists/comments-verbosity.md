# Checklist: Comment Quality & Verbosity (AI-Generated Comment Bloat)

## 1. Filler Comments
- [ ] **Restates-the-code comments**: flag any comment that just restates the function/variable name
  or the line beneath it in prose (`// increment counter` above `counter++`). If removing the comment
  wouldn't confuse a reader, it's filler.
- [ ] **Padded doc comments**: exported symbol doc comments that only restate the name
  (`// UserID is the user ID.`) instead of carrying information the signature can't (why it exists,
  caller guarantees, error conditions, units, lifetime, thread-safety).
- [ ] **Multi-paragraph docstrings for simple symbols**: flag docstrings longer than the complexity of
  the symbol warrants — a one-liner would do.

## 2. Narration Instead of Structure
- [ ] **Step-by-step narration**: comments like `// now loop through items` / `// check if valid` /
  `// return the result` that narrate control flow instead of relying on clear naming and structure.
  These should be rewritten (better names, extracted functions), not left as comments.
- [ ] **Inline comments inside function bodies**: flag any inline comment explaining *what* a line does
  rather than *why* — the code needing the comment should usually be rewritten instead.

## 3. Staleness & Redundancy
- [ ] **Stale/contradicting comments**: verify every comment against current behavior; flag ones that
  no longer match the code (renamed parameters, changed return semantics, removed branches).
- [ ] **Commented-out code blocks**: dead code left as a comment instead of relying on git history —
  flag for deletion.
- [ ] **Orphaned TODO/FIXME**: TODOs with no owner or ticket reference, or referencing issues already
  fixed elsewhere in the codebase.

## 4. The Opposite Failure Mode
- [ ] **Missing WHY on genuinely non-obvious code**: under-commenting is also a defect. Flag places
  with a hidden constraint, subtle invariant, or workaround for a specific bug that has *no* comment
  explaining why it's there. Don't only report over-commenting — report the absence of a comment where
  one is earned.

## 5. Convention Consistency
- [ ] **Language/style convention violations**: comments not following the project's documented
  comment conventions (language, doc-comment format, placement rules) if such conventions exist in
  CLAUDE.md/CONTRIBUTING/linter config — flag deviations against the project's own stated rules, not
  against a generic external style guide.
