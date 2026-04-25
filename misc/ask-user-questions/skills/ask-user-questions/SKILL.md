---
name: ask-user-questions
description: Use whenever you need clarifications, decisions, or preferences from the user before proceeding on a task. Instead of asking inline in chat, materialize the questions as a structured QCM markdown file in `.questions/` at the project root. The user answers by editing the file (replacing `[-]` with `[x]` or `[ ]`). Trigger on any ambiguity, missing decision, technical choice, or "should I do A or B" moment — especially during planning, triage, or before sprint kickoff. Do NOT use for trivial confirmations or for questions the project context already answers.
---

# Ask User Questions — Structured QCM Workflow

## Why this exists

When you (the agent) need clarifications, asking inline in chat is unreliable: long responses get skimmed, formats vary, and answers are lost in the conversation. Instead, you write a structured QCM markdown file grouped by theme. The user reviews it in their editor, marks their choices, optionally adds notes, saves. You re-read the file and continue.

This is more stable, traceable (the files live in `.questions/`, gitignored), and lets the user answer at their own pace without breaking flow. It also works well for batch-asking (e.g., a triage at the start of a phase).

## When to use this skill

**Use it when:**
- You face an ambiguity that materially affects the result (architecture choice, naming convention, library selection, scope boundary).
- You need a preference (style, tradeoff, priority) that you cannot infer from existing context.
- You're triaging a phase or sprint and have several decisions to surface at once.
- You'd otherwise have to guess and risk wasted work.

**Do NOT use it when:**
- The answer is already in `CONTEXT.md`, the codebase, or the recent conversation. Re-read first.
- It's a trivial yes/no the user just answered moments ago.
- The task is purely mechanical and unambiguous.

If in doubt, prefer asking via this skill over guessing silently.

## Setup (first time in a project)

If `.questions/` does not exist at the project root:

1. Create the directory: `.questions/`.
2. Create `.questions/.gitignore` with the single line `*` so the whole directory is ignored by git, but the directory itself can stay tracked. Alternative: add `.questions/` to the project's root `.gitignore`. Pick whichever is cleaner.
3. Optionally create `.questions/CONTEXT.md` and tell the user it exists. They can fill it with project-level info (stack, conventions, constraints) that you'll auto-read before composing every question. Don't fill it yourself unless asked.

After setup, proceed normally.

## How to ask questions

### 1. Read the context first

Before composing questions, read `.questions/CONTEXT.md` if it exists. Use that information to:
- Avoid asking things already answered there.
- Frame questions in terms the user has already established.

Do not include the contents of `CONTEXT.md` in the question file. The user already knows what's there.

### 2. Group questions by theme or phase

Prefer **one file per batch of related questions** rather than one file per question. Group by:
- **Phase or sprint** (e.g., `Q-phase1-triage`, `Q-sprint03-kickoff`).
- **Component or area** (e.g., `Q-auth-design`, `Q-db-migrations`).
- **A coherent decision moment** (e.g., `Q-deployment-stack`).

A file should contain between 2 and ~10 questions. Less than 2 is not really a batch — ask in chat. More than 10 means you're trying to make too many decisions at once — split into multiple files or rethink the scope.

If a single question is genuinely standalone and urgent, it's fine to make a one-question file.

### 3. Create the question file

Filename format: `YYYY-MM-DD-slug.md` where `slug` is a short kebab-case description of the topic.

Examples:
- `.questions/2026-04-25-phase1-triage.md`
- `.questions/2026-04-25-cache-strategy.md`
- `.questions/2026-04-25-sprint03-kickoff.md`

If a file with the same name already exists for today, append a short suffix: `2026-04-25-cache-strategy-2.md`.

### 4. Use the question template

See `templates/question.md` for the canonical format and `templates/example.md` for a fully filled real example. The structure is:

```markdown
---
id: Q-<derived-from-filename-slug>
phase: <prep | sprint01 | sprint02 | design | research | release | ...>
raised_by: <role(s) that need this answered, e.g. pm + architect>
raised_on: <YYYY-MM-DD>
references: [<component-or-file>, <component-or-file>, ...]
blocking_scope: <what is blocked: feature-DoR | sprint-kickoff | release | none>
---
# <Batch title — typically "<Phase or theme> — open questions">

Mark `[x]` on the option you want. `[-]` is the preselected recommendation; `[ ]` is an alternative. Add free-form notes under any question if needed.

---

## Q1 — <Question title>
Affects: `<component-or-file>`, `<component-or-file>`.

- [ ] <Option A — short label.> <Optional one-line tradeoff/comment.>
- [-] <Option B — short label.> <Optional one-line tradeoff/comment.> (recommended)
- [ ] <Option C — short label.> <Optional one-line tradeoff/comment.>
Notes:

---

## Q2 — <Question title>
Affects: `<component>`.

- [-] <Option A.>
- [ ] <Option B.>
Notes:

---

## Q<N> — Anything else?
Free-form. Things you want to flag that aren't in the list above.
```

### 5. Frontmatter — all fields are required

Every file MUST start with a YAML frontmatter block containing:

- **`id`** — derived from the filename slug, prefixed with `Q-`. For `2026-04-25-phase1-triage.md` → `id: Q-phase1-triage`. Drop the date prefix; keep just the slug.
- **`phase`** — current phase or sprint label. Use the project's actual labels if known (read `CONTEXT.md` and recent conversation). Fall back to descriptive labels: `prep`, `design`, `research`, `sprintNN`, `release`.
- **`raised_by`** — the role(s) that need this answered, e.g. `pm`, `architect`, `pm + architect`, `dev`. This is who asks, not who answers.
- **`raised_on`** — today's date in `YYYY-MM-DD`.
- **`references`** — YAML list of components, files, or modules affected. Use the project's vocabulary (read existing files in `.architecture/` or similar to find the right names). Empty list `[]` is allowed only if truly nothing specific is referenced.
- **`blocking_scope`** — what this batch blocks. Common values: `feature-DoR`, `sprint-kickoff`, `release`, `none`. If unsure, use `none`.

If you don't know a value, do your best from context; don't leave fields out. The user will correct it if needed.

### 6. Question conventions

- **`[-]`** marks the option you (the agent) recommend. Use it on **exactly one** option per question. The user accepts it (turn it into `[x]`), rejects it (turn it into `[ ]` and pick another), or writes notes.
- **`[ ]`** is an unchecked option the user may select.
- **`[x]`** is what the user uses to mark their choice.
- Put 2 to 4 options per question. Fewer than 2 isn't a question. More than 4 means you're not narrowing the problem enough — split the question or rethink.
- **Tradeoffs go on the option line itself**, not in a separate paragraph. One short sentence per option, after the label. Example: `- [ ] Sequential ids — simpler, but two parses with reordered blocks produce diverging ids.`
- **`Affects:`** comes right under the question title and lists the components/files in backticks. Use the project's vocabulary.
- **`Notes:`** appears at the end of every question. Leave it as just `Notes:` (empty). The user fills it if they want.
- **No "Other" option.** If the user wants something not listed, they reject all options and write in `Notes:`.
- **Last question** of every file is `Q<N> — Anything else?` with free-form prose only (no options, no `Notes:` sub-label since the whole question is freetext).

### 7. Mark blockers explicitly

If a question must be answered before a specific milestone (sprint kickoff, release, etc.), add a sentence in the question body like:
> This is a **planning blocker** — needs an answer before SPRINT_001 kickoff.

This is in addition to `blocking_scope` in the frontmatter — it makes the urgency visible inline.

### 8. Tell the user

After creating the file, send a short message in chat:

> I've created `.questions/2026-04-25-phase1-triage.md` with N questions. Recommendations are marked `[-]`. Edit the file, mark your choices with `[x]`, and let me know when done.

Do not paste the file content in chat — it's redundant and the user will read it in their editor.

### 9. Wait for the user

Stop work that depends on the answers. You may continue independent work, but be explicit about what you're doing while waiting.

## How to read the answer

When the user signals they've answered (or when you re-check):

### Detecting completion

A question is **answered** when **none of its options is `[-]` anymore**. That is: every `[-]` has been replaced by `[x]` (chosen) or `[ ]` (rejected).

The whole file is **complete** when **all questions are answered** as defined above. The final "Anything else?" question has no options — it's complete by virtue of the user having signaled done.

If any `[-]` remains, the file is still pending. Do not act on partial answers unless the user explicitly tells you to.

### Parsing the answer

For each question:
- Selected options: lines starting with `- [x]`. Usually one, but multi-select is allowed if the question asked for it.
- `Notes:` content: everything between `Notes:` and the next `---` separator. Trim whitespace. If empty, treat as no notes.

If the user wrote in `Notes:` but didn't tick any option, the notes ARE the answer — read carefully.

If the user ticked an option AND added notes, treat the notes as additional context or nuance on top of the choice.

For `Q<N> — Anything else?`: read everything between the heading and end of file (or next `---`) as freetext.

### After reading

1. Do NOT modify the answer file in place — the user's marks are the source of truth.
2. Acknowledge briefly in chat what you understood (one short line per question) so the user can correct misreadings before you act.
3. Proceed with the work.

The file stays in `.questions/`. Since the directory is gitignored, it doesn't pollute the repo. Don't delete it — it's a local record.

## Edge cases

- **User answers in chat instead of in the file**: accept it, then update the file to reflect their answer (mark the chosen `[x]`, add their words to `Notes:`) so the record stays consistent.
- **User ticks no option but writes notes**: that's a valid answer. Their notes are the truth.
- **User asks a counter-question instead of answering**: drop the file workflow, answer them in chat, then either update or scrap the question file based on what they said.
- **You realize mid-wait that you don't need an answer anymore**: tell the user, and either delete the file or mark the affected questions clearly in chat.
- **The question turns out to be wrong/badly framed after the user reads it**: don't try to edit the existing file in place. Create a new one with a clearer slug and tell the user to ignore the previous one.
- **A field in frontmatter is genuinely unknowable** (e.g., no phase concept in this project): use a sensible fallback (`phase: design`, `blocking_scope: none`) rather than omitting the field.

## CONTEXT.md (optional, user-maintained)

If `.questions/CONTEXT.md` exists, read it before composing every question file. It typically contains:
- Tech stack and versions
- Coding conventions and style preferences
- Project vocabulary for `references` and component names
- Phase/sprint labels currently in use
- Things the user has already decided and doesn't want to be re-asked

Never write to `CONTEXT.md` yourself. It's the user's file. You may suggest additions in chat if you notice you're being asked the same thing across multiple sessions.
