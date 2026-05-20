---
description: File-based kanban skill for vibe coding — persistent task system across LLM sessions with milestone/epic/task hierarchy, append-only decision logs, and minimal shell tooling.
tags:
  - kanban
  - project-management
  - vibe-coding
  - productivity
---

# kanban — a file-based kanban skill for vibe coding

A Claude Code skill that gives the LLM a persistent task system across sessions. Tasks live as Markdown files with YAML front matter; the board emerges from the filesystem.

## Why

Vibe coding sessions are stateless: the LLM forgets between sessions. The kanban gives it somewhere to write down what it learned, why it chose this approach over that one, and what's still on its plate. Without it, every session rediscovers the same problems and sometimes reverses past decisions.

The board is optimized for the LLM, not human dashboards. The user trusts the LLM to keep it accurate; git history is the only ground-truth audit trail.

## Install

### Dependencies

The shell scripts need `jq`:

- macOS: `brew install jq`
- Debian/Ubuntu: `sudo apt install jq`

### As a Claude Code skill (per-project)

Place this folder at `.claude/skills/kanban/` in your repo:

```
your-repo/
├── .claude/
│   └── skills/
│       └── kanban/
│           ├── SKILL.md
│           ├── references/
│           └── scripts/
└── .tasks/        # created by the LLM when you ask for the first feature
```

Restart Claude Code. The skill will load automatically when relevant.

### As a global skill (all your projects)

Place this folder at `~/.claude/skills/kanban/` instead. Then it's available in every project. Be aware the convention assumes `.tasks/` at the repo root.

## How it works

### Folder layout

```
.tasks/
├── M1-auth/                    # milestone
│   ├── oauth/                  # epic
│   │   ├── doc.md              # epic brief
│   │   ├── TASK-001.md         # task
│   │   └── TASK-002.md
│   └── session/
│       ├── doc.md
│       └── TASK-003.md
└── M2-billing/
    └── ...
```

### Task file

```yaml
---
id: TASK-042
title: Implement refresh token rotation
description: Add silent refresh flow for expired access tokens.
milestone: M1-auth
epic: oauth
status: in_progress
priority: high
blocked_by: []
branch: task/TASK-042-refresh-rotation
---
```

Body has two sections:

- `## Todo` — checkboxes (`[ ]` open, `[x]` done, `[!]` blocked)
- `## Discussion` — append-only log of design decisions, dated

### Scripts

Two commands in `scripts/task.sh`:

```bash
./scripts/task.sh status               # overview of all milestones
./scripts/task.sh dump <milestone>     # JSON of tasks in a milestone
```

To read a specific task, `cat .tasks/M1-auth/oauth/TASK-042.md` — no dedicated command. To update a field, edit the YAML block directly.

## Usage

You don't drive the kanban yourself. Tell Claude Code what you want and let the skill do the work:

- "Add a feature for OAuth login" → triggers the new-feature workflow (milestone/epic/task decomposition, validated by you before any file is created).
- "What should I work on?" → triggers the task-selection workflow.
- "Continue with TASK-042" → triggers the working-on-task workflow.
- "Where were we?" → starts with `task.sh status` and continues from there.

The LLM updates checkboxes, logs decisions in Discussion, and transitions statuses as work progresses. You audit via git history if you want — every change to `.tasks/` is in the commit log.

## Structure of this skill

```
kanban/
├── SKILL.md                            # entry point: concept + routing table
├── references/
│   ├── structure.md                    # file format, front matter, checkboxes
│   ├── scripts.md                      # CLI usage
│   ├── creating-feature.md             # full feature decomposition workflow
│   ├── creating-task.md                # adding a task to an existing epic
│   ├── selecting-task.md               # picking the next thing to work on
│   ├── working-on-task.md              # execution workflow
│   ├── discussion-protocol.md          # when and how to log decisions
│   ├── handling-blockers.md            # blocker states and resolution
│   ├── closing-task.md                 # marking a task done
│   └── ending-session.md               # session pause without losing context
└── scripts/
    ├── task.sh                         # dispatcher
    ├── status.sh                       # overview implementation
    └── dump.sh                         # JSON dump implementation
```

The SKILL.md is short and just routes to the right reference. References are loaded only when relevant — progressive disclosure keeps context lean.

## Design notes

A few deliberate choices, in case you want to fork or extend:

- **No `commits:` field in front matter.** Git history can be rewritten (rebase, squash); a cached commit list goes stale silently. The `branch:` field is enough — `git log <branch>` reconstructs the commit list on demand.
- **No `show` or `sync` commands.** `cat` reads a task; direct file editing updates fields. Less surface area, fewer ways to misuse.
- **Global task IDs, not per-milestone.** A file can be moved between epics or milestones without renumbering.
- **Append-only Discussion.** History is the value. Reversed decisions get new dated entries, not edits.
- **No git hooks (yet).** Could be added later as an additive layer: pre-push verification that `done` tasks have all checkboxes ticked, branch name matches front matter, etc.

## License

Do whatever you want with this.
