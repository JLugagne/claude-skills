---
name: mct-cli
description: >
  Reference guide for mct (claude-mercato), a Git-based package manager for Claude agent and skill
  definitions. Use this skill whenever the user asks how to use mct, asks about mct commands, wants
  to install/update/search/export agents or skills, asks about markets, drift, sync, pinning,
  import/export, or any other mct workflow. Also trigger when the user is looking for skills or agents
  to add to their project, wants to find a skill for a specific task, asks "is there a skill for X",
  "find me a skill that does Y", "what skills are available", or wants to browse or discover available
  Claude skills and agents. Trigger even if the user says "claude-mercato", "mct add", "mct sync", or
  just asks "how do I install an agent from a market?"
---

# mct — Claude Agent & Skill Package Manager

`mct` manages Claude agent and skill markdown files distributed through Git repositories called **markets**. No central registry. No server. Just Git.

---

## Core Concepts

| Term | What it is |
|------|-----------|
| **Market** | A Git repo containing agent/skill `.md` files in `agents/` and/or `skills/` |
| **Entry** | A single `.md` file (agent or skill) from a market |
| **Ref** | Unique entry ID: `market/path/to/file.md` |
| **Profile** | A directory grouping within a market (e.g. `mymarket/dev/go`) |
| **Drift** | Local modifications to an installed file (detected via MD5 checksum) |
| **Managed skill** | A skill auto-installed as a dependency of an agent |

State files (never edit manually):
- Config: `~/.config/mct/config.yml`
- Checksums: `~/.cache/mct/mct.checksums.json`
- Sync state: `~/.cache/mct/mct.state.json`
- Market clones: `~/.cache/mct/{market-name}/`

---

## Global Flags

```
--config       path to config file
--cache        cache directory
--offline      disable all network operations
--verbose      detailed log output
--quiet        suppress output except errors
--no-color     disable ANSI colors
--ci           non-interactive mode
```

Most commands also support `--json` for machine-readable output.

---

## Markets

Register and manage Git repositories as markets.

```bash
mct market add <name> <url>        # Register a Git repo as a market
  --branch string   branch to track (default: main)
  --trusted         skip breaking-change confirmation prompts
  --read-only       index only, never install from it
  --no-clone        register without cloning immediately

mct market list                    # List all registered markets (alias: mct markets)
mct market info <name>             # Detailed market info (entries, last sync, etc.)
mct market rename <old> <new>      # Rename a market
mct market set <name> <key> <val>  # Update a market property
mct market remove <name>           # Unregister a market
  --force       skip installed-entries check
  --keep-cache  keep the local clone
```

Market names must be kebab-case, 2–64 characters.

---

## Installing & Removing Entries

```bash
mct add <ref>          # Install an entry (alias: mct install)
  --pin <sha>       pin to a specific commit SHA
  --no-deps         skip auto-installing required skills
  --dry-run         preview without making changes
  --accept-breaking accept breaking-change flag without prompt

mct remove             # Remove an installed entry
  --ref <ref>   (required)
```

`mct add` automatically installs skill dependencies listed in the entry's frontmatter `requires_skills` field, and marks them as managed by the agent.

---

## Sync & Updates

```bash
mct refresh            # Fetch latest from all markets (no local changes)
mct update             # Apply pending upstream changes to installed files
  --ref <ref>       only update this entry
  --market <name>   filter to one market
  --dry-run
  --agents-only / --skills-only
  --all-keep        keep all local changes
  --all-delete      discard all local changes
  --all-merge       merge all changes
  --accept-breaking

mct sync               # refresh + update in one step
  --market, --dry-run, --accept-breaking, --all-merge
```

---

## Status & Drift

```bash
mct check              # Show status of all installed entries (alias: mct status)
  --market <name>   filter
  --short           one-line summary
```

Status indicators:

| Symbol | Meaning |
|--------|---------|
| `ok` | Clean — up to date, no local changes |
| `up` | Update available (no local changes) |
| `~` | Drift — locally modified, no update |
| `!` | Both drift and update available |
| `x` | Deleted from upstream |
| `+` | New in registry (not installed) |
| `o` | Orphaned — market removed |
| `?` | Unknown state |

---

## Search & List

```bash
mct search <query>     # BM25 full-text search across all markets
  --limit int       max results (default: 10)
  --type agent|skill
  --market <name>   scope search to a single market
  --category <cat>
  --installed / --not-installed
  --include-deleted

mct list               # List all installed entries
```

Results are grouped by profile. Use `--market` to narrow results when multiple markets are registered.

---

## Version Pinning & Diff

```bash
mct pin --ref <ref> --sha <sha>    # Lock entry to a specific commit
mct diff --ref <ref>               # Open external difftool: local vs. upstream
```

---

## Pruning Deleted Entries

When an upstream entry is deleted it becomes **tombstoned** (still exists locally, flagged as deleted).

```bash
mct prune
  --ref <ref>       specific entry
  --all-keep        keep all locally (stop tracking)
  --all-remove      delete all locally
```

---

## Import / Export

Portable JSON format for sharing setups across machines.

```bash
mct export [file]      # Export all markets + installed profiles to JSON
                       # (omit file to write to stdout)

mct import <file>      # Import markets and entries from JSON
  --dry-run            preview without changes
  --yes                auto-confirm adding markets not registered locally
                       (without --yes, unknown markets are skipped in --json
                        mode, or prompted interactively otherwise)
```

---

## Configuration

```bash
mct config get [key]   # Show config value(s)
mct config set <key> <value>
```

Settable keys: `ssh_enabled`, `local_path`, `conflict_policy`, `drift_policy`, `difftool`, `stale_after`, `namespace_dirs`.

---

## Other Commands

```bash
mct init               # Initialize mct in the current project
mct conflicts          # Show all conflicts (ref collisions, dep issues)
mct sync-state         # Print raw sync state for all markets
mct index              # Index operations
  --bench              measure indexing performance
  --dump               dump index as JSON
mct tui                # Interactive terminal UI (bubbletea)
mct lint [dir]         # Check a local directory as a market (default: current dir)
                       # Reports profile count, agent/skill counts, and issues:
                       #   error  invalid/missing frontmatter, unknown type
                       #   warn   missing README.md, missing tags, empty profile
```

---

## Entry Frontmatter Reference

Fields mct reads from `.md` files in markets:

```yaml
---
description: "..."    # required: short description
author: "..."         # optional
breaking_change: true # optional: flag for breaking changes
deprecated: true      # optional
requires_skills:      # optional: skill dependencies
  - file: skills/go-test.md
    pin: abc123       # optional: pin this dep to a SHA
---
```

Fields mct **injects** when installing (do not add these manually — mct will reject the file):

```yaml
mct_ref: mymarket/dev/go/agents/go-developer.md
mct_version: "abc1234 2024-01-15"
mct_market: mymarket
mct_installed_at: "2024-01-15T10:30:00Z"
```

---

## Market Repository Layout

A market is a Git repo with this structure:

```
<namespace>/<profile>/
  README.md              # optional but recommended — frontmatter: tags, description
  agents/
    my-agent.md
  skills/
    my-skill.md
```

Example: `dev/go-hexagonal/agents/go-architect.md` → ref `mymarket/dev/go-hexagonal/agents/go-architect.md`

See `MARKET.md` in this repo for the full market authoring guide.
