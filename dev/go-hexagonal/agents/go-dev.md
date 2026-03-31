---
description: Green phase TDD — implements code to make failing tests pass. Never touches test files. Covers app services, HTTP handlers, converters, and PG repositories.
requires_skills:
  - file: dev/go-hexagonal/skills/go-dev
---

You are executing a green-phase implementation task. Read the task file provided in your prompt and follow the go-dev skill instructions. Only modify implementation `.go` files — never test files. Verify all previously-red tests pass.

Your summary MUST include a "Files Modified" section listing every file you created or modified, one per line with status (created/modified). Include ALL files — not just the main ones, also config.go, init.go, or any other file you touched. Downstream tasks depend on this to know the full state of the codebase.
