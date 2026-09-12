---
description: White-box security audit skill for Claude Code — dispatches per-category subagents in isolated git worktrees, proves each exploitable finding with a failing PoC test, analyzes multi-finding attack chains, and produces CVSS-scored reports under .security-audit/.
tags:
  - security
  - audit
  - appsec
  - vulnerabilities
  - cvss
  - owasp
  - white-box
  - sub-agents
---

# security-audit — a white-box security audit skill

A Claude Code skill that turns the agent into a security auditor: it profiles the
codebase, dispatches one subagent per applicable vulnerability category in an isolated
git worktree, and **requires each finding to be proven with a failing test** before it
is reported. It then looks for attack chains, consolidates everything into a
CVSS-scored report, and cleans up after itself.

## Why

Most automated security passes are pattern matchers: they flag a suspicious call, a
`.env` in the repo, or a missing header, and call it a vulnerability. That produces
noise, not signal — the human still has to triage every candidate by hand.

This skill flips the burden of proof. A subagent may only report an issue as a real
finding after it has traced an attacker-controlled input to a sensitive sink **and**
written a PoC test that fails because of it. Theoretical matches are explicitly
downgraded or dropped, and every report carries a confidence level alongside its CVSS
score, so you know what is actually exploitable.

## How it works

Five phases, all outputs under `.security-audit/<YYYY-MM-DD-HHMM>/` (one folder per
run, never overwritten):

1. **Setup** — profile the project (languages, entry points, auth model, external
   systems) into `00-profile.md`. This decides which categories apply.
2. **Isolation** — `git worktree add` one worktree per subagent so they can edit,
   add tests, and run them without colliding with each other or your working tree.
3. **Dispatch** — one subagent per relevant category (injection, auth & session,
   data exposure, secrets, web-specific, config & infra, AI/LLM). Each writes
   `findings/<category>.json` + `.md`. Dependency/SCA scanning is deliberately left
   to the existing CI/CD pipeline.
4. **Attack chains** — a final read-only subagent combines findings into higher-impact
   chains, each with a narrative and a Mermaid sequence diagram, saved to
   `attack-chains.md`.
5. **Reports & cleanup** — dedupe findings, archive PoC tests, remove worktrees, then
   emit two files: `full-report.md` (index table + full detail, grouped by severity)
   and `summary.md` (under one page).

### Output layout

```
.security-audit/<run>/
├── 00-profile.md              # project profile + categories in scope
├── findings/
│   ├── <category>.json        # structured findings (schema in SKILL.md)
│   └── <category>.md          # human-readable notes
├── attack-chains.md           # multi-finding chains + Mermaid diagrams
├── full-report.md             # full detail, sorted and grouped by severity
├── summary.md                 # one-page executive summary
└── poc-tests/                 # archived proof-of-concept tests
```

### Finding schema

Every finding carries an id, CWE, OWASP Top 10 category, CVSS v3.1 score and vector,
a confidence level (`confirmed` / `likely` / `theoretical`), affected files, the path
to its PoC test, and concrete stack-specific remediation.

### Safety rail

PoC tests run only against local processes, local test databases, or mocked
endpoints. They never touch staging/production, real third-party services, or
perform destructive actions.

## Install

### As a Claude Code skill (per-project)

Place this folder at `.claude/skills/security-audit/` in your repo:

```
your-repo/
└── .claude/
    └── skills/
        └── security-audit/
            └── SKILL.md
```

Restart Claude Code. The skill loads automatically when you ask for a security audit.

### As a global skill (all your projects)

Place it at `~/.claude/skills/security-audit/` instead so it is available everywhere.

## Usage

Ask the agent to audit the codebase, e.g.:

```
Run a security audit of this repository using the security-audit skill.
```

The agent works through the phases and finishes by printing the path to `summary.md`,
the finding counts by severity, and whether any attack chains were found.

## Structure

```
security-audit/
└── skills/
    └── security-audit/
        └── SKILL.md    # full workflow: phases, finding schema, report formats
```

## License

Do whatever you want with it.
