---
description: "Claude Code subagents meant to run through claudeproxy (https://github.com/JLugagne/claudeproxy): low-cost implementers on DeepSeek V4.1 Flash and GLM 5.3, and a Kimi 3.1 Pro agent, for delegating grunt work and well-specified plan steps."
tags:
  - claude-code
  - claudeproxy
  - sub-agents
  - deepseek
  - glm
  - kimi
  - delegation
---

# claudeproxy agents

A set of agents to be used with [claudeproxy](https://github.com/JLugagne/claudeproxy).

## Contents

| Agent | Model | Description |
|-------|-------|-------------|
| `deepseek-flash` | `deepseek-v4.1-flash[1m]` | Fast, low-cost implementer for grunt work and well-specified plan steps |
| `glm-5.3` | `glm-5.3` | Same implementer profile, running on GLM 5.3 |
| `kimi-3.1-pro` | `kimi-k3.1-pro` | General agent that follows instructions, high effort |

## Install

```bash
mct add jlugagne/claude-skills@tools/claudeproxy
```

This installs the agents from `agents/` into `~/.claude/agents/`.

## Usage

Use the implementer agents for mechanical refactors, boilerplate, bulk edits, tests for defined behavior, and running builds or tests. Keep architecture, ambiguous specs, subtle debugging and security-sensitive work in the main session.
