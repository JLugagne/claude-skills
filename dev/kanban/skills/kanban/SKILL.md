---
name: kanban
description: Manage a local file-based kanban for software projects worked on with an LLM. Use this skill whenever the user wants to add a feature, work on an existing task, see project status, decide what to do next, or resume work mid-task. Also use it when the user mentions milestones, epics, tasks, "the kanban", "the board", or asks "what's next" / "where were we". Persists context across sessions through Markdown files with YAML front matter and append-only decision logs.
---

# Kanban

A local, file-based task system designed for vibe coding: the LLM is the primary user of the board, not the human. The board's main purpose is to keep context alive between sessions — what's done, what's next, and *why* past decisions were made.

## Concept

Three nested levels, encoded directly in the filesystem:

```
.tasks/
├── M1-auth/                    # milestone (kebab-case, M<N>- prefix)
│   ├── oauth/                  # epic
│   │   ├── doc.md              # epic brief (objective, constraints, design decisions)
│   │   ├── TASK-001.md         # task
│   │   └── TASK-002.md
│   └── session/
│       ├── doc.md
│       └── TASK-003.md
└── M2-billing/
    └── ...
```

Each task file has YAML front matter (id, status, milestone, epic, branch, priority, blocked_by, title, description) and a Markdown body with two sections:

- **`## Todo`** — checkboxes: `[ ]` open, `[x]` done, `[!]` blocked
- **`## Discussion`** — append-only log of design decisions, dated

Task IDs are global (`TASK-001`, `TASK-002`, ...) so files can be moved between epics without renumbering. The folder path encodes the milestone/epic hierarchy.

For exact file formats and field semantics, read `references/structure.md` before creating or editing any task file.

## Why this exists

Vibe coding sessions are stateless: the LLM forgets between sessions. The kanban gives the LLM somewhere to write down what it learned, why it chose this approach over that one, and what's still on its plate. Without it, every session rediscovers the same problems and sometimes reverses past decisions.

The board is therefore optimized for the LLM's reading patterns, not human dashboards. The user trusts the LLM to keep it accurate; git history is the only ground-truth audit trail.

## Tooling

Two shell commands live in `scripts/`. They are intentionally minimal — the LLM does the filtering and reasoning, the scripts just expose the filesystem efficiently:

| Command                         | Purpose                                      |
| ------------------------------- | -------------------------------------------- |
| `task.sh status`                | Overview of all milestones (counts per status). Always run this at session start. |
| `task.sh dump <milestone>`      | JSON of all tasks in a milestone, including their file paths. Used to pick a task, search, or plan. |

To read a specific task's full content, use `cat` (or the `view` tool) on the path returned by `dump`. No dedicated `show` command — the LLM already has file-reading tools.

To capture the branch associated with a task, write it directly to the `branch:` front matter field when moving the task to `in_progress`. `git log <branch>` reconstructs the commit list on demand, fresh — no need to cache commits in the front matter (a rebase or squash-merge would make any cached list lie).

Read `references/scripts.md` for exact usage, output formats, and gotchas.

## When to read what

The skill is split across multiple reference files so only what's relevant gets loaded into context. Consult the right one based on what the user is asking for:

| If the user...                                              | Read                                |
| ----------------------------------------------------------- | ----------------------------------- |
| asks for a new feature / "build X" / "add support for Y"    | `references/creating-feature.md`    |
| wants to add a task to an existing epic                     | `references/creating-task.md`       |
| asks "what should I work on" / "what's next" (no specific task) | `references/selecting-task.md`  |
| names a task to work on (or you've just selected one)       | `references/working-on-task.md`     |
| is about to make a non-trivial design or architectural choice | `references/discussion-protocol.md` |
| hits a blocker or a dependency comes up                     | `references/handling-blockers.md`   |
| has finished a task and wants to close it                   | `references/closing-task.md`        |
| stops mid-task or session is ending without completion      | `references/ending-session.md`      |
| asks about the file format, front matter, or folder layout  | `references/structure.md`           |
| needs a reminder on a shell command                         | `references/scripts.md`             |

When in doubt, start with `structure.md` — it's the schema everything else builds on.

## Universal rules

A handful of invariants apply across every workflow. Internalize these even when no reference file is loaded:

1. **Always run `task.sh status` at the start of a session.** It costs almost nothing and orients everything that follows. Skip it only if the user gives a fully explicit instruction like "work on TASK-042" with no ambiguity.

2. **The `## Discussion` section is append-only.** Never edit or delete past entries. If a decision is reversed, add a *new* entry dated today that supersedes the old one. Past entries are history, not draft.

3. **Checkboxes must reflect reality.** Don't mark `[x]` items that aren't actually done. Don't leave `[ ]` items that are done. Use `[!]` for items genuinely blocked, with the cause in parentheses: `- [!] Migrate tokens (waiting on TASK-042)`.

4. **A task isn't `done` until all its checkboxes are `[x]`.** If something is genuinely out of scope, remove the item or move it to a follow-up task — don't fake-check it.

5. **The `branch:` field is set when the task moves to `in_progress`.** Don't store commit lists — they go stale on rebase/squash. If you need to see what commits belong to a task, run `git log <branch>` on demand.

6. **Never code on a feature before the user has validated the milestone/epic/task structure.** Always present the proposed decomposition first and wait for explicit approval. See `creating-feature.md`.

## Communication style

The user is doing vibe coding — they don't want to read long task plans aloud or audit every decision. Keep status updates terse. When presenting decompositions or asking for validation, use compact trees or tables, not prose paragraphs. When logging a decision in `## Discussion`, be explicit and concrete (the LLM in a future session needs to understand it cold).
