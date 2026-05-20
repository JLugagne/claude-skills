# Working on a task

Used once a task is identified (either by the user or via `selecting-task.md`). Covers loading context, transitioning to `in_progress`, executing, and updating the file as work progresses.

**Prerequisites:** read `references/structure.md` for the file format. Optionally read `references/discussion-protocol.md` if you'll be making design decisions.

## Checklist: opening the task

```
- [ ] cat the task file to load full context (front matter + Todo + Discussion)
- [ ] cat the epic's doc.md to load epic-level constraints and decisions
- [ ] If the task has blocked_by IDs, verify each blocker is actually done
- [ ] If Todo is empty, draft 3-8 concrete items
- [ ] Confirm scope with user if Todo was just drafted
- [ ] If status was todo: create git branch task/TASK-NNN-<slug>
- [ ] Update status to in_progress and set branch field
- [ ] Begin coding
```

## Branch naming

Pattern: `task/<ID>-<short-slug>` where the slug is 2-4 kebab-case words from the title.

Examples:
- TASK-042 "Implement refresh token rotation" → `task/TASK-042-refresh-rotation`
- TASK-045 "Add session revocation endpoint" → `task/TASK-045-session-revocation`

Write the exact branch name into the `branch:` field of the front matter at the moment you create the branch. If the branch already exists (resuming work), just confirm it matches the front matter.

## Checklist: while working

```
- [ ] As checkbox items are completed, change [ ] to [x] in the Todo section
- [ ] If a sub-item hits a blocker, change [ ] to [!] and note the cause in parentheses
- [ ] If a non-trivial design choice comes up, add a ## Discussion entry (see discussion-protocol.md)
- [ ] If the scope grew or shrank meaningfully, update Todo items honestly
- [ ] Commit early and often with messages prefixed by the task ID: "TASK-042: ..."
```

## Checkbox discipline

The checkboxes are the truth of what's been done. Two failure modes to avoid:

- **Marking [x] prematurely** ("the code is there, tests are next"). Don't. Mark [x] only when the item is genuinely done as written.
- **Leaving [ ] after work is done** ("I'll update the file later"). Don't. Update the checkbox immediately after finishing, before moving on.

If an item turns out to be out of scope, *remove it* or move it to a follow-up task. Don't pretend it's done.

## When scope changes

Sometimes you discover the task needs more work than the Todo list captured, or less. Both are normal.

- **More work**: add Todo items as you discover them. Keep them concrete.
- **Less work**: remove items that are no longer relevant, with a Discussion entry explaining what changed.
- **A whole new sub-problem emerges**: if it's truly out of scope for this task, create a follow-up task (see `creating-task.md`) rather than expanding the current one.

## Commit messages

Prefix all commits with the task ID: `TASK-042: add refresh endpoint handler`. This lets `git log` reconstruct what work belongs to which task without any cached metadata. If a commit touches multiple tasks (rare), pick the primary one.

## When to stop and write to Discussion

Don't log every micro-decision. Log when:
- You chose between two or more genuinely different approaches.
- You hit a constraint or surprise that changed the plan.
- You made a tradeoff that someone in a future session would want to know about.

See `discussion-protocol.md` for the full heuristic and format.

## When the task is done

All Todo items are `[x]`, code is committed, you believe the work is shipped. Move to `references/closing-task.md`.
