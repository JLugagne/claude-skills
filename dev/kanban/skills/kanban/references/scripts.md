# Scripts

Five commands, positional arguments plus a couple of flags. Designed so the LLM can't easily mis-invoke them.

| Command                            | Purpose                                                        |
| ---------------------------------- | ------------------------------------------------------------- |
| `task.sh status [--json]`          | Overview of all milestones (counts per status).               |
| `task.sh dump <milestone>`         | JSON of all tasks in a milestone, including DoD progress.     |
| `task.sh check <task-path>`        | Verify a task is safe to close (boxes + `run:` verification). |
| `task.sh new <ms> <epic> "<t>"`    | Scaffold a valid task file and allocate its ID.               |
| `task.sh validate [milestone]`     | Structural integrity check (ids, folders, references).        |

The scripts ship executable. If you cloned the skill and they aren't, run `chmod +x scripts/*.sh` once.

## `task.sh status`

Overview of the whole board.

**Usage:**
```bash
./scripts/task.sh status          # text
./scripts/task.sh status --json   # machine-readable
```

**Output (text, default):**

```
M1-auth         12 tasks   8 done, 2 in_progress, 1 todo, 1 blocked, 0 backlog
M2-billing       8 tasks   2 done, 0 in_progress, 5 todo, 1 blocked, 0 backlog
M3-admin-ui     15 tasks   0 done, 0 in_progress, 0 todo, 0 blocked, 15 backlog
```

**Output (`--json`):** an array of `{milestone, total, done, in_progress, todo, blocked, backlog, cancelled}` objects — stable for scripting and subagent consumption.

Sorted by milestone folder name (so chronological if you've used `M1-`, `M2-` prefix).

**When to use:**
- Always at the start of a session.
- Whenever the user asks "where are we", "what's the state", "show me the board".

**What to do with it:**
- If a milestone has `in_progress > 0`, that's almost certainly where to continue.
- If a milestone has only `done`, skip ahead to the next.
- If everything is `backlog`, the project hasn't really started — ask the user what to focus on.

## `task.sh dump <milestone>`

Dump all tasks of a milestone as JSON.

**Usage:**
```bash
./scripts/task.sh dump M1-auth
```

The milestone argument must match a folder name exactly (including the `M<N>-` prefix).

**Output:**

```json
[
  {
    "id": "TASK-001",
    "path": ".tasks/M1-auth/oauth/TASK-001.md",
    "title": "Set up OAuth client",
    "description": "Configure the OAuth client with our IdP, including redirect URIs and scopes.",
    "milestone": "M1-auth",
    "epic": "oauth",
    "status": "done",
    "priority": "high",
    "type": "feature",
    "blocked_by": [],
    "branch": "task/TASK-001-oauth-client",
    "action_stats": {"done": 5, "open": 0, "blocked": 0},
    "dod_stats": {"done": 4, "open": 0, "blocked": 0}
  }
]
```

Tasks that live directly under a milestone (no epic — see `structure.md`) report `"epic": ""`.

`action_stats` and `dod_stats` are computed on the fly by counting `[x]`, `[ ]`, and `[!]` checkboxes within the `## Actions` and `## Definition of Done` sections respectively. **Both must be fully `done` (all `[x]`, no `open` or `blocked`) before the task can be marked `status: done`.**

**When to use:**
- After `status`, to pick the next task (filter by `status: in_progress` or `todo`, sort by `priority`).
- For semantic search across tasks (load all titles + descriptions, reason about which match a user query).
- For planning (see what's in `backlog` to decide what to promote next).

**What to do with it:**
- Filter by `status`, `epic`, or `priority` in your head — no need for CLI flags.
- To load a specific task's full body, use the `path` field with `cat` or the file-reading tool.

## Reading a task body

There is no `task.sh show` command on purpose. To read a task's full Markdown:

```bash
cat .tasks/M1-auth/oauth/TASK-002.md
```

Or use the file-reading tool with the `path` from `dump` output.

## `task.sh check <task-path>`

Verify a task is safe to close. This is the mechanical safety net before flipping `status: done`. It does two things:

1. **Counts checkboxes** — every Actions and DoD item must be `[x]` (no `[ ]`, no `[!]`).
2. **Runs verification commands** — any DoD or Actions item carrying a `| run: <command>` suffix on a `[x]` line is *executed*. A non-zero exit makes the task NOT CLOSEABLE.

**Usage:**
```bash
./scripts/task.sh check .tasks/M1-auth/oauth/TASK-002.md
```

**Output (passing):**
```
Task:   TASK-002 - Implement refresh token rotation
Type:   feature
Status: in_progress
Actions: 5/5 done (0 open, 0 blocked)
DoD:     4/4 done (0 open, 0 blocked)
Verification (run: commands on [x] items):
  [PASS] go test ./internal/auth/... -run TestRefresh
  [PASS] grep -rq RefreshHandler.Refresh internal/

OK: task is closeable
```

Exit code 0.

**Output (failing run):**
```
DoD:     4/4 done (0 open, 0 blocked)
Verification (run: commands on [x] items):
  [PASS] go test ./internal/auth/... -run TestRefresh
  [FAIL] grep -rq RefreshHandler.Refresh internal/
        (command output, up to 10 lines, indented)

NOT CLOSEABLE:
  - DoD verification failed: 1 run: command(s) exited non-zero
```

Exit code 1.

### The `run:` syntax

Attach a runnable check to any DoD (or Actions) item by appending `| run: <command>`:

```markdown
- [ ] `go vet ./...` is clean | run: go vet ./...
- [ ] Test `TestRefresh` passes | run: go test ./internal/auth -run TestRefresh
- [ ] Handler is wired | run: grep -rq "RefreshHandler.Refresh" internal/
```

- The command is everything after `| run:` (pipes inside the command are fine — only the first `| run:` is the delimiter).
- Commands run from the current working directory (the repo root, where you run `check`).
- Only `[x]` lines are executed — an item still `[ ]` already fails the box-count, so its command is skipped.
- Items without `run:` stay manual: the LLM re-verifies them honestly during the closing audit (see `closing-task.md`).
- **Security note:** `check` executes arbitrary shell from the task file. That's the point (machine-checked DoD), but it means task files are trusted input.

Prefer a `run:` command whenever the DoD item is mechanically checkable — it turns "honest closing" from a discipline into a guarantee. See `definition-of-done.md` for patterns.

**Rules enforced:**
- Every Actions item must be `[x]` (no `[ ]`, no `[!]`).
- Every DoD item must be `[x]` (no `[ ]`, no `[!]`).
- `feature`, `integration-verify`, and `bugfix` tasks must have at least 1 DoD item.
- Every `run:` command on an `[x]` item must exit 0.

**When to use:**
- Always before flipping a task to `status: done` (see `closing-task.md`).
- In CI as a pre-merge check on PRs that touch `.tasks/`.

## `task.sh new <milestone> <epic> "<title>"`

Scaffold a new task file with valid front matter and empty `## Actions` / `## Definition of Done` / `## Discussion` sections. Allocates the next ID from `.tasks/.next-id` and writes it back — no manual ID bookkeeping.

**Usage:**
```bash
./scripts/task.sh new M1-auth oauth "Implement refresh token rotation" --type feature --priority high
./scripts/task.sh new M1-auth - "Pin CI Go version" --type chore
```

- `<epic>` of `-` (or `.`) places the task **directly under the milestone**, with no epic — appropriate for standalone `chore`/`bugfix` work (see `structure.md`). The `epic:` field is left empty.
- If the epic folder doesn't exist it's created (with a warning to add a `doc.md`).
- Flags: `--type` (default `feature`), `--priority` (default `normal`), `--status` (default `todo`).

After scaffolding, fill the description and draft the DoD then Actions (see `working-on-task.md`). The generator deliberately does **not** invent Actions/DoD — that's a reasoning step.

## `task.sh validate [milestone]`

Structural integrity check over the whole board (or one milestone). Catches dependency and layout mistakes before they cause confusion.

**Usage:**
```bash
./scripts/task.sh validate            # whole board
./scripts/task.sh validate M1-auth    # one milestone
```

**Checks:**
- Filename matches the `id` field.
- `milestone` field matches the enclosing milestone folder.
- `epic` field matches the parent folder (empty when the task is directly under a milestone).
- Every id in `blocked_by` and `verifies` refers to a task that exists somewhere on the board.
- Any epic folder that contains tasks also has a `doc.md`.
- Every milestone folder has a `PRD.md`.

Exit 0 if clean, 1 if problems are found (each listed), 2 on error. Run it after a planning/decomposition pass and before starting a batch of work.

## Writing front matter / updating fields

`task.sh new` stamps the initial file. To update a field afterward (e.g. moving a task to `in_progress` and setting its branch), edit the YAML block directly with the file-editing tool. The format is fixed (see `structure.md`), so a string replacement on `status: todo` → `status: in_progress` is reliable. There is no `task.sh set-status` — direct editing is simpler and avoids a fragile CLI.

## Reducing permission prompts (agent-driven use)

When an agent drives these scripts, allowlist them once in the project's `.claude/settings.json` to avoid a prompt per call:

```json
{
  "permissions": {
    "allow": [
      "Bash(./.claude/skills/kanban/scripts/task.sh:*)"
    ]
  }
}
```

Note that `task.sh check` spawns the `run:` commands as subprocesses of that already-approved invocation — they are not separately gated, so only allowlist `task.sh` in repos where you trust the task files.

## Gotchas

- `task.sh dump` and `validate <milestone>` error if the milestone folder doesn't exist. Check `status` output first if unsure.
- `action_stats`/`dod_stats` only count checkboxes inside their named sections. Checkboxes elsewhere (including `## Discussion`) are ignored — intended behavior.
- The scripts assume `.tasks/` exists at the current working directory. Run them from the repo root.
- The scripts use `jq` for JSON output. If `jq` isn't installed, they error with an install hint.
- Tasks created before the v2 schema (with `## Todo` instead of `## Actions` + `## Definition of Done`) show `action_stats` based on their `## Todo` section if present, and `dod_stats` of zero. Migrate them when convenient.
