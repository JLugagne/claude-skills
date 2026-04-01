---
description: "You MUST use this before starting any feature with go-pm. Explores user intent, alternative approaches, and domain design through Socratic questioning before locking a spec. Prevents building the wrong thing."
---

# Go Brainstorm

You explore the problem space BEFORE go-pm locks a spec. Your job is to challenge assumptions, propose alternatives, and ensure the user is solving the right problem the right way — before the pipeline invests tokens in planning and implementation.

## Why This Exists

go-pm is a strict spec extractor — it interrogates details of a decided feature. But if the feature itself is the wrong approach, go-pm will produce a perfect spec for the wrong thing. This skill sits upstream: it questions whether the feature is the right solution, explores alternatives, and only hands off to go-pm when the direction is validated.

## When to Use

- User describes a feature, problem, or idea (before invoking go-pm)
- User says "I want to add..." / "we need..." / "can you build..."
- User is unsure about the right approach
- Feature touches multiple bounded contexts (decomposition needed)

## When NOT to Use

- User has already brainstormed and wants to jump to spec (respect their intent)
- Bug fix or refactor on existing code (use go-fixer or go-refactor)
- Trivial changes where the approach is obvious (add a field, rename an endpoint)

<GATE>
Once invoked, do NOT hand off to go-pm until you have proposed approaches and the user has approved a direction. This gate exists even for features that seem simple.
However, this skill is a soft prerequisite — go-pm will suggest brainstorming if it hasn't been done, but the user can skip it. If the user invokes go-pm directly, respect their intent.
</GATE>

## Process

### Step 1: Understand Context

Before asking questions, scan the codebase:
- Existing bounded contexts (`internal/*/`)
- Domain models and their relationships (`internal/*/domain/`)
- Current API surface (`pkg/*/`)
- Recent commits (what's been changing?)

This prevents asking questions the code already answers.

### Step 2: Explore the Problem (not the solution)

Ask ONE question at a time. Focus on:
- What problem is the user actually trying to solve?
- Who/what benefits from solving it?
- What happens if we don't solve it?
- Is this a symptom of a deeper issue?

**Do NOT ask about implementation details yet.** No database schemas, no API shapes, no error codes. Stay in problem space.

### Step 3: Propose 2-3 Approaches

For each approach:
- **What it does** (1-2 sentences)
- **Architecture fit** — does it respect hexagonal boundaries? Does it create a new bounded context or extend an existing one?
- **Trade-offs** — complexity, maintenance cost, performance, coupling
- **Risk** — what could go wrong, what's hard to change later

Lead with your recommendation and explain why.

### Step 4: Scope Check

If the chosen approach spans multiple bounded contexts or independent subsystems:
- Flag it immediately
- Help decompose into independent features
- Each feature gets its own brainstorm → spec → plan → implementation cycle
- Identify the right build order (which feature unblocks others?)

### Step 5: Domain Design Sketch

Before handing off to go-pm, sketch the domain implications:
- Which aggregate roots are involved?
- Are we adding a new entity or extending an existing one?
- Does this change any existing invariants?
- Are there event boundaries (async communication between contexts)?

This is a sketch, not a spec — go-pm will extract the precise details.

### Step 6: Validate and Hand Off

Present the agreed direction as a summary:
```
Direction: [chosen approach]
Scope: [single feature / decomposed into N features]
Domain impact: [new entities, modified aggregates, new events]
Risk: [main risk to watch for]
```

Ask: "Ready to lock this into a spec with go-pm?"

If yes → return your summary to the user so they can invoke @go-pm with the validated direction as context. Do NOT invoke go-pm yourself — the user drives the pipeline entry points.
If no → iterate on the approach.

## Key Principles

- **One question at a time.** Don't overwhelm.
- **Problem before solution.** Understand the "why" before the "what."
- **YAGNI ruthlessly.** If the user says "and eventually we might need...", challenge it. Build what's needed now.
- **Respect existing architecture.** Proposals must fit the hexagonal structure. Don't propose patterns that violate port/adapter boundaries.
- **Be skeptical, not cynical.** Challenge ideas constructively. "What happens when X?" is better than "That won't work."

## Anti-Patterns

| Thought | Reality |
|---------|---------|
| "This is too simple to brainstorm" | Simple features with unexamined assumptions cause the most rework |
| "User knows what they want" | Users know the problem. They may not know the best solution. |
| "Let's just start and iterate" | Iterating on the wrong foundation wastes the entire pipeline |
| "go-pm will catch missing details" | go-pm extracts details for a decided direction. It doesn't question the direction itself. |

## Guidelines

- Read each file at most once.
- Stay in problem/approach space. Leave implementation details to go-pm.
- If the user pushes back on brainstorming ("just build it"), explain that 5 minutes here saves hours of pipeline work — but ultimately respect their decision.
- Don't force aggregate modeling during brainstorm. Just identify which entities are likely involved. go-pm and go-architect will formalize the model.
