# Checklist: CI/CD, Pipeline Security & Infrastructure Exposure (OWASP A05, A08)

## 1. GitHub Actions & CI/CD Pipeline Injection
- [ ] **Workflow Expression Injection**: Audit `.github/workflows/*.yml`. Search for untrusted GitHub context expressions evaluated directly inside inline shell scripts (`run:`):
  - `${{ github.event.issue.title }}`
  - `${{ github.event.issue.body }}`
  - `${{ github.event.pull_request.title }}`
  - `${{ github.head_ref }}`
  - `${{ github.event.comment.body }}`
  Ensure untrusted values are passed via environment variables (`env: TITLE: ${{ github.event.issue.title }}`), not inlined into the bash script string.
- [ ] **Dangerous `pull_request_target` Triggers**: Check if workflows triggered by `pull_request_target` check out the untrusted fork's code (`ref: ${{ github.event.pull_request.head.sha }}`) and then run build scripts or tests. This grants the untrusted PR fork full access to repo secrets.
- [ ] **Unpinned Third-Party Actions**: Check that third-party actions are pinned to an immutable full commit SHA (e.g. `actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11`), not a mutable tag (`@v3` or `@main`), preventing supply chain tampering.
- [ ] **Default `GITHUB_TOKEN` Permissions**: Ensure workflows declare explicit least-privilege `permissions:` block at top-level or job-level, rather than inheriting default read/write permissions.

## 2. Debug Endpoints & Administrative Interfaces (A05:2021)
- [ ] **Runtime Profilers in Production**:
  - Go: Ensure `net/http/pprof` (`/debug/pprof`) is NOT mounted on public HTTP servers (allows heap dumps, goroutine traces, CPU profiling).
  - Java/Spring: Verify Spring Boot Actuator (`/actuator`, `/actuator/env`, `/actuator/heapdump`) is disabled or secured behind internal network guards.
  - Python: Verify debug toolbar and interactive consoles (Werkzeug `/console`) are strictly disabled in production configs.
- [ ] **Exposed API Documentation & Test Consoles**: Ensure Swagger UI / OpenAPI test playgrounds (`/swagger`, `/docs`) with interactive "Try it out" buttons do not expose private administrative APIs or bypass authentication in production.

## 3. Container & Docker Security
- [ ] **Root User Execution**: Check Dockerfiles to ensure applications switch to a non-root user (`USER nonroot` or `USER 1000:1000`) before starting the process.
- [ ] **Secrets in Build Layers**: Verify `.dockerignore` excludes `.env`, private keys, and git folders. Check that build secrets are passed via `RUN --mount=type=secret`, not as plain `ARG` or `ENV` which persist in layer metadata.
