---
name: kanban
description: Manage a local file-based kanban for software projects worked on with an LLM. Use this skill whenever the user wants to add a feature, work on an existing task, see project status, decide what to do next, or resume work mid-task. Also use it when the user mentions milestones, epics, tasks, "the kanban", "the board", or asks "what's next" / "where were we". Persists context across sessions through Markdown files with YAML front matter, append-only decision logs, and verifiable Definition of Done.
---

# Kanban

A local, file-based task system designed for vibe coding: the LLM is the primary user of the board, not the human. The board's main purpose is to keep context alive between sessions — what's done, what's next, *why* past decisions were made, and *how* we verify each task is genuinely complete.

## Concept

Three nested levels, encoded directly in the filesystem:

```
.tasks/
├── M1-auth/                    # milestone (kebab-case, M<N>- prefix)
│   ├── PRD.md                  # milestone product brief + acceptance scenarios
│   ├── oauth/                  # epic
│   │   ├── doc.md              # epic brief (objective, constraints, acceptance criteria)
│   │   ├── TASK-001.md         # task
│   │   └── TASK-002.md
│   └── session/
│       ├── doc.md
│       └── TASK-003.md
└── M2-billing/
    ├── PRD.md
    └── ...
```

Each task file has YAML front matter (id, status, milestone, epic, branch, priority, blocked_by, type, title, description) and a Markdown body with **three** sections:

- **`## Actions`** — checkboxes describing concrete coding actions: `[ ]` open, `[x]` done, `[!]` blocked
- **`## Definition of Done`** — checkboxes describing **verifiable** acceptance criteria (tests passing, wired integrations, end-to-end scenarios). All must be `[x]` before the task can close.
- **`## Discussion`** — append-only log of design decisions, dated

Task IDs are global (`TASK-001`, `TASK-002`, ...) so files can be moved between epics without renumbering. The folder path encodes the milestone/epic hierarchy.

For exact file formats and field semantics, read `references/structure.md` before creating or editing any task file.

## Why this exists

Vibe coding sessions are stateless: the LLM forgets between sessions. The kanban gives the LLM somewhere to write down what it learned, why it chose this approach over that one, and what's still on its plate. Without it, every session rediscovers the same problems and sometimes reverses past decisions.

**The Definition of Done section solves a second failure mode**: LLMs (especially smaller ones running autonomously) tend to mark tasks `done` as soon as code compiles, without verifying integration. The DoD makes "done" mechanically checkable. No DoD checkbox = no `done` status, ever.

The board is therefore optimized for the LLM's reading patterns, not human dashboards. The user trusts the LLM to keep it accurate; git history is the only ground-truth audit trail.

## Tooling

Shell commands live in `scripts/` (run via the `task.sh` dispatcher). They are intentionally minimal — the LLM does the filtering and reasoning, the scripts just expose the filesystem efficiently and enforce the few mechanical invariants:

| Command                            | Purpose                                      |
| ---------------------------------- | -------------------------------------------- |
| `task.sh status [--json]`          | Overview of all milestones (counts per status). Always run this at session start. `--json` for machine-readable output. |
| `task.sh dump <milestone>`         | JSON of all tasks in a milestone, including DoD progress. Used to pick a task, search, or plan. |
| `task.sh check <task-path>`        | Verify a task is safe to close: all Actions+DoD `[x]`, plus any `\| run:` verification commands pass. |
| `task.sh new <ms> <epic> "<t>"`    | Scaffold a valid task file and allocate its ID. Use `-` for the epic to put a standalone chore directly under the milestone. |
| `task.sh validate [milestone]`     | Structural integrity check: ids match filenames, fields match folders, `blocked_by`/`verifies` references exist. |

The scripts ship executable; if they aren't, `chmod +x scripts/*.sh`. To read a specific task's full content, use `cat` (or the `view` tool) on the path returned by `dump` — no dedicated `show` command, the LLM already has file-reading tools.

To capture the branch associated with a task, write it directly to the `branch:` front matter field when moving the task to `in_progress`. `git log <branch>` reconstructs the commit list on demand, fresh — no need to cache commits in the front matter (a rebase or squash-merge would make any cached list lie).

Read `references/scripts.md` for exact usage, output formats, and gotchas.

## When to read what

The skill is split across multiple reference files so only what's relevant gets loaded into context. Consult the right one based on what the user is asking for:

| If the user...                                              | Read                                |
| ----------------------------------------------------------- | ----------------------------------- |
| asks for a new feature / "build X" / "add support for Y"    | `references/creating-feature.md` (and `milestone-planning.md`) |
| wants to add a task to an existing epic, or a one-off chore/fix | `references/creating-task.md`    |
| wants to verify the board's structural integrity (`task.sh validate`) | `references/scripts.md`    |
| asks "what should I work on" / "what's next" (no specific task) | `references/selecting-task.md`  |
| names a task to work on (or you've just selected one)       | `references/working-on-task.md`     |
| is about to make a non-trivial design or architectural choice | `references/discussion-protocol.md` |
| is about to write or review Definition of Done items        | `references/definition-of-done.md`  |
| hits a blocker or a dependency comes up                     | `references/handling-blockers.md`   |
| has finished a task and wants to close it                   | `references/closing-task.md`        |
| stops mid-task or session is ending without completion      | `references/ending-session.md`      |
| is creating or updating a milestone PRD                     | `references/milestone-planning.md`  |
| asks about the file format, front matter, or folder layout  | `references/structure.md`           |
| needs a reminder on a shell command                         | `references/scripts.md`             |

When in doubt, start with `structure.md` — it's the schema everything else builds on.

## Universal rules

A handful of invariants apply across every workflow. Internalize these even when no reference file is loaded:

1. **Always run `task.sh status` at the start of a session.** It costs almost nothing and orients everything that follows. Skip it only if the user gives a fully explicit instruction like "work on TASK-042" with no ambiguity.

2. **The `## Discussion` section is append-only.** Never edit or delete past entries. If a decision is reversed, add a *new* entry dated today that supersedes the old one. Past entries are history, not draft.

3. **Checkboxes must reflect reality.** Don't mark `[x]` items that aren't actually done. Don't leave `[ ]` items that are done. Use `[!]` for items genuinely blocked, with the cause in parentheses: `- [!] Migrate tokens (waiting on TASK-042)`.

4. **A task isn't `done` until every Action AND every Definition of Done item is `[x]`.** If something is genuinely out of scope, remove the item or move it to a follow-up task — don't fake-check it. **No DoD = no done.** This rule is non-negotiable; if you find yourself wanting to close a task with unchecked DoD items, stop and re-read `references/closing-task.md`.

5. **The `branch:` field is set when the task moves to `in_progress`.** Don't store commit lists — they go stale on rebase/squash. If you need to see what commits belong to a task, run `git log <branch>` on demand.

6. **Never code on a feature before the user has validated the milestone/epic/task structure AND the milestone PRD.** Always present the proposed decomposition + PRD first and wait for explicit approval. See `creating-feature.md` and `milestone-planning.md`.

7. **Every DoD item must be mechanically verifiable.** "Code looks clean" is not a DoD; "test `TestX` passes" or "function `Y` is called from `Z` (verified by grep or test)" is. See `references/definition-of-done.md`.

8. **Integration-verify tasks exist to close gaps between unit deliverables.** At the end of each epic (and sometimes mid-epic), include a task with `type: integration-verify` whose only job is to prove the previous tasks work together. See `references/definition-of-done.md`.

9. **Make DoD items executable whenever possible.** Append `| run: <command>` to a DoD item and `task.sh check` runs it, refusing to close on a non-zero exit. This turns honest closing from a discipline into a machine-enforced guarantee — use it for tests, builds, vet/lint, and grep-based wiring checks. See `references/definition-of-done.md`.

10. **An agent never closes its own task, and the reviewer is adversarial.** The author prepares the close (boxes honest, `task.sh check` green, committed) but a *different* agent/model — or, failing that, the user — runs the close audit and flips `status: done`. Self-marked homework is the board's core trust gap. The reviewer's mindset is **refute-first**: its job is not to confirm the task is done but to try to *prove it is not* — hunt for missing files/features/wiring, run the target language's linters, write red-tests to attack the gaps, and nitpick the diff hard (useless comments, incomprehensible code, architecture smells). It closes only when every attempt to disprove completeness has failed. If no reviewer is available, tell the user the task is ready for review rather than self-closing. See `references/closing-task.md`.

## Communication style

The user is doing vibe coding — they don't want to read long task plans aloud or audit every decision. Keep status updates terse. When presenting decompositions or asking for validation, use compact trees or tables, not prose paragraphs. When logging a decision in `## Discussion`, be explicit and concrete (the LLM in a future session needs to understand it cold).

When showing DoD progress, show counts: `TASK-042: 5/5 actions, 2/3 DoD` is enough — the user can ask for details.
