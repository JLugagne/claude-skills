---
name: doc-project
description: Project map for [project-name]. Read this before scanning the codebase.
  Provides bounded context inventory, entity relationships, infrastructure wiring,
  and conventions. Always check this first — it's faster than grep.
invoke: agent
trigger: description
---

# Project Map: [project-name]

## Bounded Contexts

| Context | Entities | Endpoints | Events | Doc |
|---------|----------|-----------|--------|-----|
| identity | Tenant, User, Team, APIKey | 12 HTTP | tenant.created, user.invited | [details](contexts/identity.md) |
| ingestion | Scan, SBOM, Component | 3 HTTP, 2 NATS consumers | scan.completed | [details](contexts/ingestion.md) |
| inventory | Manifest, Version, Dependency | 8 HTTP | version.archived | [details](contexts/inventory.md) |
| vulnerabilities | CVE, Advisory, Impact | 5 HTTP, 1 cron | cve.new_impact | [details](contexts/vulnerabilities.md) |

## Infrastructure
- Postgres 17 (partitioned by tenant_id) — [details](infrastructure.md)
- NATS JetStream (scan ingestion, impact fan-out) — [details](infrastructure.md)
- Redis (inventory cache) — [details](infrastructure.md)
- Zitadel (SSO/OIDC) — [details](infrastructure.md)

## Conventions
- IDs: UUID v7, typed (`type TenantID string`) — [details](conventions.md)
- Errors: `domainerror.New(code, message)` — [details](conventions.md)
- Mocks: function-based with panic on unset — [details](conventions.md)
- Scoping: all repo methods take scopeID first after ctx — [details](conventions.md)

## Latest Migration: 042_add_impact_analysis_index.sql

## Recent Features
- Feature 5 (policies) merged 2026-04-01 — added PolicyRule, PolicyEngine
- Feature 4 (vulnerabilities) merged 2026-03-28 — added CVE, Advisory, Impact
