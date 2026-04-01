# Patches pour les skills existants go-hexagonal

Ce document décrit les modifications à appliquer aux skills existants pour intégrer
les nouveaux skills (go-brainstorm, go-debugger, go-verify, go-finish) dans le pipeline.

---

## 1. PATCH: `agents/go-pm.md`

### Modification du prompt agent

**Avant :**
```
You are a strict product manager. Interrogate the user about their feature request,
write .plan/<feature-slug>/FEATURE.md when the spec is GREEN, then hand off to
go-architect (via Agent) to produce TASKS.md and task files. Once planning is done,
launch a single go-runner agent to execute all tasks.
```

**Après :**
```
You are a strict product manager. Interrogate the user about their feature request,
write .plan/<feature-slug>/FEATURE.md when the spec is GREEN, then hand off to
go-architect (via Agent) to produce TASKS.md and task files. Once planning is done,
launch a single go-runner agent to execute all tasks.

IMPORTANT: If the user hasn't already validated the direction with go-brainstorm,
ask: "Have you explored alternative approaches for this feature?" If not, suggest
running @go-brainstorm first. Don't block — if the user insists on proceeding, proceed.
But flag it: "Skipping brainstorm — proceeding with spec extraction as requested."
```

### Raison
go-pm est excellent pour extraire des specs, mais il ne questionne jamais la direction.
Ce patch ajoute un soft gate qui suggère go-brainstorm sans bloquer le workflow.

---

## 2. PATCH: `skills/go-runner/SKILL.md`

### Ajout d'une section "Verification Protocol"

**Ajouter après la section "CRITICAL — summary format requirement:" :**

```markdown
## Verification Protocol

After each GREEN task, the validation MUST follow go-verify standards:

1. Run `go build ./...` — report exit code
2. Run `go test ./... -count=1 -race` — report full output
3. Only mark task complete if BOTH pass with evidence

Do NOT mark a task as done based on:
- The subagent's verbal claim ("tests pass")
- A previous test run (stale)
- Partial test execution (only the specific package)

The full suite with `-race` and `-count=1` is the minimum. Report actual output
in the task summary.

After ALL tasks complete, invoke go-finish to handle feature closure.
Do NOT present integration options yourself — go-finish handles verification,
acceptance criteria, cleanup, and integration choice.
```

### Ajout d'une section "Debugging Escalation"

**Ajouter après "Circuit Breaker" concepts in the existing runner:**

```markdown
## Debugging Escalation

If a subagent reports CIRCUIT_BREAK and go-fixer also fails:
1. Do NOT retry with another go-fixer
2. Dispatch go-debugger with the full error context:
   - Original task description
   - All error messages from both the original agent and go-fixer
   - List of files involved
   - What was already tried (from go-fixer summary)
3. go-debugger will perform systematic root cause investigation
4. If go-debugger escalates to user, stop the pipeline and relay the debug report
```

### Raison
Le runner actuel valide avec `go build` et `go test` mais sans standard strict.
Le patch impose go-verify et ajoute go-debugger comme escalade au-delà du circuit breaker.

---

## 3. PATCH: `skills/go-dev/SKILL.md`

### Modification de la section "Verification"

**Avant :**
```markdown
## Verification

After implementing, run:

1. `go build ./...` — passes
2. `go test ./... -run <TestPattern> -count=1 -v` — all previously red tests are now green
3. `go test ./... -count=1` — full suite passes (no regressions introduced)
```

**Après :**
```markdown
## Verification

After implementing, run ALL of these and report the actual output:

1. `go build ./...` — report exit code
2. `go test ./... -run <TestPattern> -count=1 -v -race` — report which tests pass/fail
3. `go test ./... -count=1 -race` — report full suite results

CRITICAL: Always include `-race` flag. Always include `-count=1` (no cache).
Report the actual command output, not a summary. "Tests pass" without output
is a claim, not evidence. The orchestrator needs evidence.

If any step fails, do NOT claim the task is done. Report the actual failure
in your summary. The orchestrator will decide next steps.
```

### Raison
go-dev actuel ne requiert pas `-race` systématiquement et ne demande pas de preuves
dans le summary. Le patch aligne avec go-verify.

---

## 4. PATCH: `skills/go-test-writer/SKILL.md`

### Ajout de la vérification red phase

**Ajouter à la fin de la section de vérification existante :**

```markdown
## Red Phase Verification (mandatory)

After writing tests, you MUST verify the red phase:

```bash
# 1. Tests compile
go build ./...

# 2. Tests FAIL (not error)
go test ./internal/<context>/... -run TestNewPattern -count=1 -v
```

Report in your summary:
- Which tests were written
- That they COMPILE (build passes)
- That they FAIL for the RIGHT reason (feature not implemented)
- The actual failure message

A test that errors (import failure, syntax error) is NOT a valid red.
A test that passes is NOT a valid red (you're testing existing behavior).

Only a test that compiles, runs, and fails because the feature is missing is a valid red.
```

### Raison
Le test-writer actuel ne vérifie pas explicitement que les tests sont "red for the right
reason". Ce patch impose la validation que Superpowers applique dans son cycle TDD.

---

## 5. PATCH: `skills/go-fixer/SKILL.md`

### Ajout de l'escalade vers go-debugger

**Ajouter après la section "Guidelines" :**

```markdown
## Escalation to go-debugger

If after reading the code and attempting a fix, you STILL can't resolve the issue:

1. Do NOT attempt a second fix based on guessing
2. Return a summary starting with `NEEDS_INVESTIGATION:` including:
   - What you read and understood
   - What you tried
   - Why it didn't work
   - Which hexagonal layer you believe the root cause is in (or "unknown")

The orchestrator will dispatch go-debugger for systematic root cause investigation.
go-debugger has a structured 4-phase methodology that's more thorough than
fresh-perspective fixing.

The distinction:
- go-fixer = "fresh eyes on a known problem" (quick recovery)
- go-debugger = "structured investigation of an unknown problem" (deep analysis)
```

### Raison
go-fixer est un "fresh perspective" agent — bon pour les problèmes simples mais
limité quand le root cause est non-évident. Le patch ajoute une escalade vers
go-debugger plutôt que de boucler.

---

## 6. PATCH: `skills/go-reviewer/SKILL.md`

### Ajout de la double review (spec compliance séparée)

**Ajouter avant "## Summary Output" :**

```markdown
## Two-Pass Review

The review runs in two logical passes within the single review task:

### Pass 1: Spec Compliance
Read `.plan/<feature-slug>/FEATURE.md` and check:
- Every acceptance criterion has at least one task that addresses it
- Every API endpoint in the spec has an e2e test task
- Every business rule has a unit or contract test task
- Every security consideration has a test + implementation task pair
- No extra functionality was added beyond the spec (scope creep)

If spec compliance fails, create task files to close the gaps BEFORE doing Pass 2.

### Pass 2: Code Quality
Only after spec compliance passes, review code quality:
- Architecture checklist (existing)
- Security checklist (existing)
- Data layer checklist (existing)
- Performance checklist (existing)

This ordering matters: fixing code quality issues on code that doesn't match the spec
is wasted effort.
```

### Raison
Le reviewer actuel fait tout en un pass sans distinguer "est-ce qu'on a construit ce
qu'on a dit?" (spec compliance) et "est-ce que c'est bien construit?" (code quality).
Superpowers sépare ces deux concerns. Ce patch ajoute la distinction sans casser le
format single-agent.

---

## 7. PATCH: `README.md` du profil

### Nouveau pipeline avec les additions

**Remplacer le diagramme de pipeline par :**

```
go-brainstorm (Opus)    — explores problem space, proposes approaches, validates direction
  └── go-pm (Opus)      — interrogates user, writes FEATURE.md
        └── go-architect (Opus)
              ├── go-api-designer (Sonnet)  — HTTP routes, request/response types
              ├── writes TASKS.md + task-N.md (security constraints embedded)
              └── go-runner (Sonnet)        — thin dispatcher, never writes code
                    ├── go-scaffolder        — stubs, interfaces, mocks
                    ├── go-test-writer       — red phase (unit, contract, e2e) [+ red verification]
                    ├── go-dev               — green phase (implementation) [+ go-verify evidence]
                    ├── go-reviewer          — two-pass: spec compliance then code quality
                    ├── go-fixer (Opus)      — circuit breaker recovery
                    ├── go-debugger (Opus)   — systematic root cause (escalation from fixer)
                    └── go-finish            — verification, acceptance criteria, cleanup, integration
```

### Nouvelle table d'agents

**Ajouter les nouveaux agents :**

| Name | Model | Role |
|------|-------|------|
| `go-brainstorm` | opus | Problem exploration, approach validation, scope check |
| `go-debugger` | opus | Systematic root cause investigation through hexagonal layers |

**Modifier le rôle existant de go-runner :** ajouter "invokes go-finish after all tasks"

### Nouvelle section "Key Practices > Verification"

```markdown
### Verification
- **Evidence before claims**: every completion claim must include actual command output
  (go build, go test with -race and -count=1). No stale runs, no verbal claims.
- **Two-pass review**: spec compliance checked before code quality.
- **Systematic debugging**: root cause investigation before fixes. go-debugger escalation
  when go-fixer circuit breaker isn't enough.
- **Feature closure**: go-finish verifies acceptance criteria line-by-line against
  FEATURE.md before integration.
```
