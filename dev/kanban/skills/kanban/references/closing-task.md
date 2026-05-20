# Closing a task

Used when work on a task is finished and it should be marked `done`.

**Prerequisites:** read `references/structure.md`.

## Checklist

```
- [ ] Every Todo item is [x] (no [ ] or [!] remaining)
- [ ] All code is committed on the task branch
- [ ] Add a final Discussion entry summarizing what shipped
- [ ] Update status from in_progress to done
- [ ] If any Todo items were dropped as out-of-scope: those went to a follow-up task, not faked-done
- [ ] Tell the user the task is closed, with the branch name and a one-line summary
```

## Pre-close audit

Before flipping `status: done`, verify:

1. **Every checkbox is `[x]`.** No `[ ]`, no `[!]`. If anything remains, either finish it, drop it (with a Discussion entry), or move it to a follow-up task. Never close with open items.
2. **The work matches the title.** If the implementation drifted from the original scope, either rewrite the title/description to match reality (with a Discussion entry explaining the drift), or split the off-scope work into a follow-up task.
3. **The Discussion captures what matters.** Glance through it: would a future session understand the decisions? If not, add a closing entry that summarizes.

## The closing Discussion entry

Add a final entry that wraps up the task. Format:

```markdown
### YYYY-MM-DD — Task closed
Shipped: brief summary of what now exists in the codebase as a result.
Branch: task/TASK-NNN-<slug>
Follow-ups: any tasks created as a result of this work (with IDs), or "none".
```

Example:

```markdown
### 2026-05-25 — Task closed
Shipped: silent OAuth refresh with token rotation on every call. Refresh tokens
are stored encrypted in the sessions table with a 30-day TTL.
Branch: task/TASK-042-refresh-rotation
Follow-ups: TASK-051 (add token cleanup job), TASK-052 (admin UI to revoke sessions).
```

This entry is the one a future session is most likely to read first when looking back at this task. Make it useful.

## Merging the branch

The skill itself does not dictate merge workflow — that's the user's choice (PR, direct merge, squash-merge, etc.). But:

- Don't delete the branch on its own. Leave that to the user / their normal git workflow. The `branch:` field still references it, and even after deletion, `git log` from a parent branch can find the commits if needed.
- Keep the `branch:` field populated in the closed task — it's the record of where the work happened, useful for archaeology later.

## When to NOT close

- If anything is genuinely deferred to "later", make a follow-up task. The current task is `done` only for what was actually finished. Don't leave a `done` task with a hopeful Todo item still hanging.
- If the work revealed that the task's premise was wrong (e.g. the feature doesn't make sense the way it was scoped), use `status: cancelled` instead of `done`, with a Discussion entry explaining why.

## After closing

After closing, the natural follow-up is usually one of:

- The next task in the same epic (run `task.sh dump <milestone>`, find next `todo`).
- A follow-up task you just created.
- Stopping for the session.

Mention the natural next step to the user briefly, but don't auto-load it — let them decide.
