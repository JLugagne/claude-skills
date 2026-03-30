# claude-skills

A [claude-mercato](https://github.com/JLugagne/claude-mercato) market — a collection of Claude agent and skill definitions organized into profiles.

## Available Profiles

| Profile | Description |
|---------|-------------|
| [`dev/go-hexagonal`](dev/go-hexagonal/README.md) | Go hexagonal architecture — TDD pipeline, security-first review, structured feature planning |

## Installation

Register this repo as a market with `mct`:

```bash
mct market add claude-skills https://github.com/JLugagne/claude-skills.git
```

Then browse and install:

```bash
mct search "go hexagonal"
mct add claude-skills/dev/go-hexagonal/agents/go-pm.md
```

---

## Adding a New Profile

A profile is a `<category>/<name>/` directory containing a `README.md`, an `agents/` directory, and/or a `skills/` directory.

### 1. Choose a path

Profiles follow the pattern `<category>/<name>/`. Examples:
- `dev/go-hexagonal/`
- `dev/python-fastapi/`
- `ops/kubernetes/`
- `data/spark-streaming/`

### 2. Create the directory structure

```
<category>/<name>/
├── README.md         # Profile description (required)
├── agents/
│   └── my-agent.md
└── skills/
    └── my-skill.md
```

### 3. Write the profile README

The `README.md` must have YAML frontmatter with at minimum a `description` and `tags`:

```yaml
---
description: Short description shown in mct search results.
tags:
  - tag1
  - tag2
---

# Profile Title

Longer description, usage examples, etc.
```

### 4. Write agents

Each agent file needs `type: agent` and `description`. If the agent relies on a skill, declare it with `requires_skills` so `mct` auto-installs it:

```yaml
---
type: agent
description: What this agent does and when to use it.
requires_skills:
  - file: <category>/<name>/skills/my-skill.md
---

Agent prompt content here...
```

### 5. Write skills

Each skill file needs `type: skill` and `description`:

```yaml
---
type: skill
description: What this skill provides to agents that use it.
---

Skill content here — reference material, patterns, examples...
```

### 6. Verify with mct

After pushing, register the market locally and confirm `mct` indexes your profile:

```bash
mct market add claude-skills https://github.com/JLugagne/claude-skills.git
mct search "<your profile name>"
mct list  # after installing an entry
```

### Notes

- Files must be `.md` and live under an `agents/` or `skills/` directory to be indexed by `mct`
- The first two path segments form the profile (e.g. `dev/go-hexagonal`)
- Do not add `mct_ref`, `mct_version`, `mct_market`, or `mct_installed_at` to your files — `mct` injects these on install and will reject files that already contain them
- An optional `pin` on a `requires_skills` entry locks the dependency to a specific commit SHA
