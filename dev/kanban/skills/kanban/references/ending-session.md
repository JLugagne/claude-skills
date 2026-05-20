# Ending a session mid-task

Used when the session is ending but the current task isn't done. Critical for vibe coding because the next session (maybe days later) will have zero memory of the current state.

**Prerequisites:** read `references/structure.md`.

## Why this matters

Mid-task state lives in the LLM's working memory: what was just tried, what the next step was going to be, what subtle issue was just spotted. None of that survives the session unless it's written down. If you leave the task in an ambiguous state, the next session will either re-do work or get stuck guessing what was meant.

## Checklist

```
- [ ] Update every Todo checkbox to its true current state ([ ], [x], or [!])
- [ ] Commit any uncommitted work on the branch (or note that it's uncommitted in Discussion)
- [ ] Add a Discussion entry: what was done this session, what's next, any pitfalls
- [ ] Leave status as in_progress (do not flip to done unless actually done)
- [ ] Confirm to the user what was saved and what's left
```

## The session-end Discussion entry

Format:

```markdown
### YYYY-MM-DD — Session pause
Done this session: brief summary of what's now in the code.
Next step: the very next concrete action when resuming.
Watch out for: any subtle issue, half-finished refactor, or non-obvious context.
```

Example:

```markdown
### 2026-05-22 — Session pause
Done this session: refresh endpoint wired (POST /auth/refresh), happy path tested.
Next step: add error handling for expired refresh tokens (returns 401 + clears cookie).
Watch out for: the test suite uses a clock fixture; new tests need to inherit from
TestCaseWithFrozenTime or token expiry checks will be flaky.
```

The "Watch out for" line is gold. It's the kind of thing that's obvious to you right now and completely invisible to a future session. Write it down even if it feels small.

## What "next step" should look like

Concrete and immediately actionable. Not "continue the implementation" — that's useless. Instead: "implement the error case for expired refresh tokens: return 401, clear the session cookie, log the event with reason=refresh_expired."

A future session should be able to read the next step and start typing code, not re-derive what to do.

## On uncommitted work

Strong preference: commit before ending the session, even if the commit is `WIP: ...`. A WIP commit on the task branch is easy to amend or squash later.

If for some reason you must leave uncommitted changes, note this explicitly in the Discussion entry:

```markdown
### 2026-05-22 — Session pause (uncommitted)
... [as above] ...
Uncommitted: changes in src/auth/refresh.ts and tests/auth/refresh.test.ts.
Run `git status` on branch task/TASK-042-refresh-rotation to see them.
```

This makes resuming explicit rather than surprising.

## What stays in_progress

The task stays `status: in_progress` when the session ends. The branch is still active. The next session will see `in_progress` in `task.sh status` and know exactly where to resume.

Do NOT set `status: blocked` just because the session is ending. `blocked` is for external dependencies, not for "I have to log off." If the work is genuinely blocked, see `handling-blockers.md`.

## When the user just stops

If the user ends the conversation without explicit signal ("ok thanks bye", or just goes quiet), still go through this checklist mentally:

- Are Todo checkboxes accurate? If yes, fine.
- Is there uncommitted work? If yes, mention it.
- Was there a non-trivial decision made this session? If yes and not yet logged, log it.

It's OK to skip the full session-pause Discussion entry if very little happened — but always update checkbox states. The mismatch between checkbox state and reality is the #1 source of confusion in the next session.
