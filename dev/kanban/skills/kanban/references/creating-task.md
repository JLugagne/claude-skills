# Creating a single task in an existing epic

Used when the user wants to add work to an epic that already exists, without going through the full feature decomposition.

**Prerequisites:** read `references/structure.md`.

## Checklist

```
- [ ] Confirm the target milestone and epic exist (use task.sh status if unsure)
- [ ] If user description is vague, ask one clarifying question
- [ ] Read the epic's doc.md to align with its constraints and decisions
- [ ] Allocate next ID from .tasks/.next-id
- [ ] Create TASK-NNN.md with full front matter, empty Todo, empty Discussion
- [ ] Set status based on context: todo if ready to start now, backlog otherwise
- [ ] Identify any blocked_by relationships with existing tasks
- [ ] Update .tasks/.next-id
- [ ] Confirm to the user: ID, title, status, where it lives
```

## When to draft Todo items

If the user has already described the work concretely ("add a /health endpoint that returns build SHA and DB status"), draft 3-5 Todo items immediately. The user can adjust.

If the description is high-level ("add health checks"), leave Todo empty. The items will be drafted when the task is opened for work.

## Status decision

- `status: todo` — the user is starting this now, or it's the obvious next thing in the epic.
- `status: backlog` — it's added for later, no immediate work planned.
- Never start a new task at `in_progress`. The transition to `in_progress` always happens when the task is opened (see `working-on-task.md`).

## Where to put it

The task lives in the named epic folder. Filename is `TASK-NNN.md` matching the `id` field.

If the user says "add a task" without naming an epic, ask which epic — don't guess. Misplacing a task means moving it later, which is friction.

If the right epic genuinely doesn't exist yet, this isn't "creating a task" — it's a small feature. Switch to `creating-feature.md` (or just create the new epic folder with its `doc.md` and put the task in it, if it's truly a single-task addition).
