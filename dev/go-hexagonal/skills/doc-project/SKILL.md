---
name: doc-project
description: Project map — read this before scanning the codebase. Provides bounded
  context inventory, entity relationships, infrastructure wiring, and conventions.
  Always check this first — it's faster than grep.
invoke: agent
trigger: description
---

# Project Map

<!-- This file is the table of contents. It is updated by go-finish after each feature.
     Context details live in contexts/<name>.md — read them for entity/endpoint/event details.
     Conventions live in conventions.md — read it for project-wide patterns.

     IMPORTANT: This file is a singleton. Only ONE go-finish should update it at a time.
     Features MUST be built sequentially to avoid merge conflicts on this file.
     go-product-manager enforces this — it drives features one at a time in dependency order. -->

## Bounded Contexts

| Context | Entities | Endpoints | Events | Doc |
|---------|----------|-----------|--------|-----|
<!-- Rows added by go-finish as contexts are created -->

## Infrastructure
<!-- Populated by go-bootstrap, updated as infrastructure evolves -->

## Conventions
<!-- Summary with links to conventions.md for details -->

## Latest Migration
<!-- Updated by go-finish after each feature -->

## Recent Features (last 5)
<!-- Updated by go-finish — most recent first -->
