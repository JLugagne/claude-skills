# Structure

The schema everything else builds on. Read this before creating or editing any task file, milestone, or epic.

## Folder layout

```
.tasks/
├── M1-<milestone-slug>/
│   ├── <epic-slug>/
│   │   ├── doc.md              # epic brief
│   │   ├── TASK-001.md
│   │   └── TASK-002.md
│   └── <epic-slug>/
│       ├── doc.md
│       └── TASK-003.md
├── M2-<milestone-slug>/
│   └── ...
└── .next-id                    # plain text file: last assigned task number
```

Rules:

- Root is always `.tasks/` at the repo root.
- Milestones are prefixed `M<N>-` with `N` a 1-indexed integer, so they sort chronologically by filename.
- Milestone and epic slugs are kebab-case (`auth`, `billing`, `admin-ui`).
- Task IDs are global (not per-milestone): `TASK-001`, `TASK-002`, etc. Zero-padded to 3 digits.
- Task filename is exactly the ID: `TASK-042.md`.
- Each epic folder contains a `doc.md` (the epic brief) plus its task files.
- `.next-id` holds the highest assigned ID so far, as a plain integer (e.g. `42`). Used by scripts to allocate the next ID.

## Task front matter

Every `TASK-NNN.md` starts with this exact YAML block:

```yaml
---
id: TASK-042
title: Implement refresh token rotation
description: Add silent refresh flow for expired access tokens, with rotation on every refresh.
milestone: M1-auth
epic: oauth
status: todo
priority: normal
blocked_by: []
branch: ""
---
```

Field reference:

| Field         | Required | Values / Format                                                          |
| ------------- | -------- | ------------------------------------------------------------------------ |
| `id`          | yes      | `TASK-NNN` (zero-padded 3 digits). Must match filename.                  |
| `title`       | yes      | One-line summary. No markdown.                                           |
| `description` | yes      | 1-3 sentence elaboration. Used in `dump` output for search/selection.    |
| `milestone`   | yes      | Folder name, e.g. `M1-auth`. Must match the file's parent's parent dir.  |
| `epic`        | yes      | Folder name, e.g. `oauth`. Must match the file's parent dir.             |
| `status`      | yes      | One of: `backlog`, `todo`, `in_progress`, `blocked`, `done`, `cancelled` |
| `priority`    | yes      | One of: `low`, `normal`, `high`                                          |
| `blocked_by`  | yes      | List of task IDs that must be `done` before this can start. `[]` if none.|
| `branch`      | yes      | Git branch name when in progress. `""` until task is started.            |

Status semantics:

- `backlog` — defined but not ready to work on (future milestone, or unrefined)
- `todo` — ready to start, all blockers resolved
- `in_progress` — actively being worked on (branch should exist)
- `blocked` — was in progress, now waiting on external dep
- `done` — all checkboxes `[x]`, code shipped
- `cancelled` — abandoned, kept for history

## Task body

Exactly two sections, in this order:

```markdown
## Todo

- [ ] First concrete action
- [ ] Second concrete action
- [!] Migrate existing tokens (blocked by TASK-040)
- [x] Sketch the API surface

## Discussion

### 2026-05-20 — Choice of OAuth library
Decision: use `oauth4webapi` rather than `openid-client`.
Rationale: smaller bundle, no Node-only deps, works in edge runtimes we'll need later.
Alternatives considered: `openid-client` (more battle-tested but heavier),
hand-rolling (rejected, too much spec to implement).

### 2026-05-20 — Refresh token storage
Decision: encrypted in DB, not in httpOnly cookies.
Rationale: rotation requires server-side state anyway, and cookies leak into logs.
```

### Todo section

Checkbox states:

- `[ ]` — open, not started
- `[x]` — done
- `[!]` — blocked. Always include the cause in parentheses: `- [!] Foo (waiting on TASK-040)` or `- [!] Bar (upstream API down)`.

Items should be concrete and verifiable. Prefer "Add zod validation to signup handler" over "Add input validation". A task isn't `done` until every item is `[x]` (or moved to a follow-up task).

Aim for 3-8 items per task. If you find yourself writing 12+ items, the task is too big — split it.

### Discussion section

Append-only. Each entry is an `###` sub-header with date and short title, followed by structured prose:

```markdown
### YYYY-MM-DD — Short decision title
Decision: what was decided.
Rationale: why.
Alternatives considered: what was rejected and why.
```

Rules:

- Never edit or delete past entries. If a decision is reversed, add a new entry that supersedes the old one.
- Date format is `YYYY-MM-DD`, always.
- Add an entry whenever a non-trivial design choice is made — library, architecture, data model, API shape, error handling strategy. See `discussion-protocol.md` for the trigger heuristic.
- Don't log trivia (e.g. "renamed variable foo to bar"). Discussion is for choices a future session would have to re-make if forgotten.

## Epic doc.md

Every epic folder has a `doc.md` describing the epic's intent. Created when the epic is created. Sections:

```markdown
# Epic: <slug>

## Objective
What this epic delivers, in 2-4 sentences. Business or technical outcome.

## Constraints
Technical or business constraints that apply to all tasks in this epic.
Examples: target browsers, compliance, latency budget, existing API contracts.

## Design decisions
High-level architectural choices that apply across the epic.
Format same as task Discussion entries: dated, with rationale.

## Open questions
Things deferred or unresolved. Update as they're answered.
```

The epic `doc.md` is read at the start of any task within the epic (see `working-on-task.md`). Decisions made here don't need to be repeated in each task's Discussion — the epic doc is authoritative for the epic level.

## Milestone

No file per milestone — the folder itself is the milestone. The folder name (`M1-auth`) is its identifier, and the set of epics inside defines its scope.

If a milestone needs a brief (rare), it can live at `M1-auth/README.md`, but this is optional and not parsed by any script.

## Validation invariants

The skill assumes these hold. The LLM should preserve them when editing:

1. Filename equals `id` field (`TASK-042.md` ↔ `id: TASK-042`).
2. `milestone` field equals the grandparent folder name.
3. `epic` field equals the parent folder name.
4. `status: done` ⇒ all Todo items are `[x]`.
5. Any ID in `blocked_by` refers to a task that exists somewhere in `.tasks/`.
6. `branch` is non-empty when `status` is `in_progress`, `blocked`, or `done`.
