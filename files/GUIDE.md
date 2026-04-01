# Go-Hexagonal Optimisé — Guide d'intégration

## Vue d'ensemble

Ce document décrit les améliorations apportées au profil `dev/go-hexagonal`
en intégrant les meilleures pratiques de Superpowers (obra) qui manquaient
au pipeline original.

## Diagnostic : ce qui manquait

| Lacune | Impact | Source Superpowers |
|--------|--------|--------------------|
| Pas d'exploration du problème en amont | On construit parfois la mauvaise chose | `brainstorming` |
| Pas de debugging systématique | Quand go-fixer échoue, on boucle | `systematic-debugging` |
| Verification non standardisée | Claims sans preuves, `-race` optionnel | `verification-before-completion` |
| Pas de clôture structurée | Pas de check acceptance criteria, pas de cleanup | `finishing-a-development-branch` |
| Review en un seul pass | Spec compliance mélangée avec code quality | `requesting-code-review` (double review) |

## 4 nouveaux skills créés

### `go-brainstorm` — En amont du pipeline
- Se place AVANT go-pm
- Explore le problème, pas la solution
- Propose 2-3 approches avec trade-offs
- Détecte les features trop larges (décomposition)
- Esquisse l'impact domaine avant de locker une spec
- Hard gate : pas de go-pm tant qu'une direction n'est pas validée

### `go-debugger` — Escalade au-delà du circuit breaker
- Se place APRÈS go-fixer quand celui-ci échoue
- 4 phases : investigation root cause → analyse de patterns → hypothèse → implémentation
- Adapté aux couches hexagonales (trace inbound → app → domain → outbound)
- Table de diagnostic par layer avec symptômes et fichiers à vérifier
- Escalade structurée : 1 fix → 2 fix → 3+ fix = problème architectural → user

### `go-verify` — Standard de preuve
- Utilisé par TOUS les agents avant de déclarer un travail terminé
- Matrice de vérification par type de claim (build, red, green, e2e, refactor)
- Séquences spécifiques par rôle (go-dev, go-test-writer, go-runner, go-fixer)
- Impose `-race` et `-count=1` systématiquement
- Format de rapport avec output réel, pas des résumés

### `go-finish` — Clôture de feature
- Se place APRÈS que go-runner a terminé toutes les tâches
- Vérification finale complète (build + tests + race)
- Check acceptance criteria ligne par ligne contre FEATURE.md
- Rapport de synthèse (fichiers créés, findings du reviewer)
- Cleanup des artefacts .plan/
- Options d'intégration (merge, PR, keep, discard)

## 6 skills existants modifiés

| Skill | Modification | Pourquoi |
|-------|-------------|----------|
| `go-pm` | Soft gate vers go-brainstorm | Suggère d'explorer avant de spécifier |
| `go-runner` | Protocole go-verify + escalade go-debugger + handoff go-finish | Standardise la validation, ajoute un filet de sécurité, structure la clôture |
| `go-dev` | Exige `-race`, `-count=1`, output réel dans summary | Aligne avec go-verify |
| `go-test-writer` | Vérifie que le red est "red for the right reason" | Évite les faux red (erreurs de compilation vs failures) |
| `go-fixer` | Escalade vers go-debugger si le fix ne marche pas | Évite les boucles de fix aveugles |
| `go-reviewer` | Two-pass : spec compliance PUIS code quality | Évite de polir du code qui ne match pas la spec |

## Pipeline optimisé

```
                                ┌─────────────────┐
                                │  go-brainstorm   │  ← NOUVEAU
                                │  (explore)       │
                                └────────┬─────────┘
                                         │ direction validée
                                ┌────────▼─────────┐
                                │     go-pm        │  ← MODIFIÉ (soft gate)
                                │  (spec FEATURE)  │
                                └────────┬─────────┘
                                         │ spec GREEN
                                ┌────────▼─────────┐
                                │  go-architect    │
                                │  (TASKS + tasks) │
                                └────────┬─────────┘
                                         │
                                ┌────────▼─────────┐
                                │   go-runner      │  ← MODIFIÉ (verify + debug + finish)
                                └────────┬─────────┘
                                         │
              ┌──────────┬───────────────┼───────────────┬──────────┐
              │          │               │               │          │
        ┌─────▼────┐ ┌──▼───────┐ ┌─────▼────┐ ┌───────▼──┐ ┌────▼─────┐
        │scaffolder│ │test-write│ │  go-dev  │ │ reviewer │ │  fixer   │
        │          │ │← MODIFIÉ │ │← MODIFIÉ │ │← MODIFIÉ │ │← MODIFIÉ │
        └──────────┘ └──────────┘ └─────┬────┘ └──────────┘ └────┬─────┘
                                        │                         │
                                   go-verify                      │ si échec
                                   (evidence)                     │
                                                           ┌──────▼──────┐
                                                           │ go-debugger │ ← NOUVEAU
                                                           │ (root cause)│
                                                           └─────────────┘

              Après toutes les tâches :
                                ┌─────────────────┐
                                │   go-finish     │  ← NOUVEAU
                                │ (accept + close)│
                                └─────────────────┘
```

## Structure de fichiers à ajouter

```
dev/go-hexagonal/
├── agents/
│   ├── go-brainstorm.md          ← NOUVEAU
│   ├── go-debugger.md            ← NOUVEAU
│   └── ... (existants inchangés)
├── skills/
│   ├── go-brainstorm/SKILL.md    ← NOUVEAU
│   ├── go-debugger/SKILL.md      ← NOUVEAU
│   ├── go-verify/SKILL.md        ← NOUVEAU
│   ├── go-finish/SKILL.md        ← NOUVEAU
│   └── ... (existants à patcher selon PATCHES.md)
```

## Ce qui n'a PAS été intégré (et pourquoi)

| Skill Superpowers | Raison de non-intégration |
|-------------------|--------------------------|
| `using-superpowers` | Bootstrap/dispatcher — go-hexagonal a son propre pipeline câblé |
| `using-git-worktrees` | Orthogonal — peut être ajouté indépendamment sans modifier le pipeline |
| `writing-plans` | go-architect remplit déjà ce rôle avec plus de spécificité (task-N.md, security embeddée) |
| `writing-skills` | Méta-skill — utile mais hors scope du pipeline de dev |
| `executing-plans` | go-runner remplit ce rôle |
| `dispatching-parallel-agents` | go-runner gère déjà le parallélisme (red tasks en batch) |
| `receiving-code-review` | go-reviewer couvre déjà, enrichi avec le two-pass |
| `requesting-code-review` | Intégré dans le patch de go-reviewer |
