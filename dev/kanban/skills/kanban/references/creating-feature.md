# Creating a new feature

The most delicate workflow. A new feature means decomposing it into milestone → epics → tasks *before any code is written*. The user is doing vibe coding and trusts you to structure the work, but the structure must be validated explicitly before files hit disk.

**Prerequisites:** read `references/structure.md` for the exact file format and folder layout.

## Checklist

```
- [ ] Clarify scope if genuinely ambiguous (max 3 questions, only if blocking)
- [ ] Propose a milestone name (kebab-case, M<N>- prefix with N = next free integer)
- [ ] Propose 2-5 epics that decompose the feature
- [ ] For each epic, list 3-8 candidate tasks with one-line descriptions
- [ ] Present the full structure as a tree to the user
- [ ] WAIT for explicit validation before creating any files
- [ ] On validation: create folder structure, doc.md per epic, task files
- [ ] Set the very first task to status: todo, all others to status: backlog
- [ ] Confirm structure was created; do NOT start coding yet
```

## Sizing heuristics

- **Epic** = a coherent deliverable, roughly 1-3 days of work. Anything bigger should split into multiple epics.
- **Task** = one focused session of work, typically a single module/endpoint/component. If a task would have more than ~8 Todo items, it's too big — split it.
- **Milestone** = a meaningful project phase (e.g. "auth", "billing core", "admin UI"). Usually 2-5 epics. If the feature is small enough to fit in a single epic, it doesn't need its own milestone — just add the epic to an existing one.

## Naming

- Milestone: `M<N>-<kebab-slug>` where `N` is one greater than the highest existing `M<N>-` folder. Slug describes the phase: `M1-auth`, `M2-billing`, `M3-admin-ui`.
- Epic: kebab-case slug under the milestone folder: `oauth/`, `session/`, `password-reset/`.
- Task ID: read `.tasks/.next-id`, increment, zero-pad to 3 digits: `TASK-042`, `TASK-043`. Update `.tasks/.next-id` after allocating.

## Presenting the structure for validation

Use a compact tree. Example:

```
M2-billing/
├── core/
│   ├── TASK-042: Define Subscription and Invoice domain models
│   ├── TASK-043: Wire Stripe webhook receiver with signature validation
│   ├── TASK-044: Persist subscription state transitions
│   └── TASK-045: Reconciliation job for stuck subscriptions
├── checkout/
│   ├── TASK-046: Build hosted checkout redirect flow
│   ├── TASK-047: Handle success/cancel callback routes
│   └── TASK-048: Send confirmation email on completed checkout
└── billing-portal/
    ├── TASK-049: Customer portal session creation
    └── TASK-050: Embed portal link in account settings
```

Then ask: "Does this decomposition look right? Any epics to add, merge, or rename? Any tasks missing or out of scope?"

Do not list Todo items at this stage — they'll be drafted when each task is opened.

## Dependencies

Identify hard dependencies between tasks (where B genuinely cannot start until A is done) and populate `blocked_by` accordingly. Only hard dependencies. "It would be nicer to do X first" is *not* a `blocked_by` — it's just a priority signal.

If a dependency crosses epic boundaries within the milestone, that's fine. If it crosses milestone boundaries, flag it to the user — usually it means the milestone decomposition needs adjustment.

## On validation

When the user says "yes" / "looks good" / "go ahead":

1. Create the milestone folder.
2. For each epic, create its folder and a `doc.md` (use the template in `structure.md`). Fill in Objective from the user's stated intent, Constraints from anything they mentioned, and leave Design decisions / Open questions empty or with placeholders.
3. For each task, create `TASK-NNN.md` with full front matter and an empty `## Todo` / `## Discussion` body. Title and description as proposed.
4. Set the first task (usually the lowest-numbered in the first epic without blockers) to `status: todo`. All others stay `status: backlog`.
5. Update `.tasks/.next-id` to the highest ID used.
6. Run `task.sh status` to confirm the new milestone shows up correctly.
7. Tell the user: "Structure created. Ready to start on TASK-NNN whenever you are." Do not begin coding yet.

## What not to do

- Don't create files before validation, even partially.
- Don't fill in Todo items for tasks at this stage. The Todo of each task is drafted when the task is opened (see `working-on-task.md`).
- Don't propose more than 5 epics or more than ~25 tasks for one feature. If the feature is that big, it's actually multiple features — push back and ask the user to scope it down.
- Don't invent constraints. If something isn't specified, leave it for the Discussion of the relevant task when it comes up.
