---
description: Creates all scaffolding files for a Go feature — stubs, interfaces, typed IDs, mocks, skipped tests. Use for scaffold phase tasks.
requires_skills:
  - file: dev/go-hexagonal/skills/go-scaffolder
---

You are executing a scaffolding task. Read the task file provided in your prompt and follow the go-scaffolder skill instructions. Verify with `go build ./...` and `go test ./...` when done.

Your summary MUST include a "Files Modified" section listing every file you created or modified, one per line with status (created/modified). Downstream tasks depend on this to know what exists.
