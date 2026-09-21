---
description: White-box security audit skill for Claude Code with domain-driven subagent sprints, upfront scope negotiation, exhaustive vulnerability checklists, multi-agent scaling rules, and state-of-the-art HTML & Markdown reports.
tags:
  - security
  - audit
  - appsec
  - vulnerabilities
  - cvss
  - owasp
  - white-box
  - sub-agents
  - domain-driven
  - html-report
---

# security-audit-v2 — Domain-Driven Security Assessment Engine

A white-box security assessment skill for Claude Code that turns the agent into a rigorous security auditor. 
The codebase is partitioned into **functional and architectural domains**, assigned structured **sprint task backlogs** based on pre-established checklists, audited in isolated git worktrees, and **requires every vulnerability to be proven with a failing test** before being reported.

Assessment deliverables include an executive **State-of-the-Art HTML report** (`report.html`), a dedicated **Attack Chains interactive HTML report** (`attack-chains.html`), and comprehensive Markdown reports under `.security-audit/<run>/`.

---

## Scope: What Is Tested vs Not Tested

To maximize signal and eliminate false positives, the audit operates under clear, deterministic boundaries established during Phase 0:

### What Is Tested (In-Scope Verification Categories)

* **Access Control & Multi-Tenancy (OWASP A01, API1, API5)**:
  * Broken Object Level Authorization (BOLA / IDOR) on database entities and API paths.
  * Broken Function Level Authorization (BFLA) and horizontal/vertical privilege escalation.
  * Multi-tenancy isolation: enforcement of `tenant_id` filters across queries and shared cache namespaces.
* **Authentication & Session Management (OWASP A07, API2)**:
  * JWT flaws: algorithm confusion (`none`, HMAC with RSA public key), `kid` header injection, signature validation, expiration/revocation.
  * Session fixation, missing cookie security attributes (`HttpOnly`, `Secure`, `SameSite`), MFA/2FA ceremony bypasses, password reset host-header poisoning.
* **Path Traversal, Filesystem & File Uploads (OWASP A01, A03)**:
  * Directory traversal (`../`, URL-encoded, double-encoded, null-byte bypasses) in path resolution.
  * Zip Slip / Tar Slip archive extraction vulnerabilities.
  * Arbitrary file read, arbitrary file write/overwrite, and arbitrary file deletion.
  * Unrestricted file uploads: extension whitelist bypasses, MIME/magic byte spoofing, execution within webroot.
* **Remote Code Execution (RCE) & Injection (OWASP A03, A08)**:
  * OS command injection and argument/flag injection (`exec`, `system`, `popen`, `sh -c`).
  * Insecure deserialization: Python `pickle`, PyYAML unsafe load, Java ObjectInputStream, PHP unserialize, Go `gob`/interface unmarshaling.
  * Server-Side Template Injection (SSTI) in Jinja2, Twig, Go templates, Pebble, etc.
  * Dynamic code evaluation (`eval()`, script engines, un-sandboxed Lua/JS).
* **Payment, Billing & Financial Logic (OWASP A04, API6, API10)**:
  * Concurrency & race conditions: TOCTOU double-spending, balance depletion, coupon/voucher stacking.
  * Floating-point precision and rounding errors in monetary math.
  * Negative amounts, zero quantities, and client-side price/plan tampering.
  * Webhook integrations: cryptographic HMAC signature bypass, replay attacks, timestamp tolerance drift.
* **Web, API & Protocol Security (OWASP A03, A05, A10, API3, API7, API8, API9)**:
  * Server-Side Request Forgery (SSRF): loopback/private IP bypasses, Cloud Metadata access (AWS IMDSv1/v2, GCP, Azure), DNS rebinding.
  * Cross-Site Request Forgery (CSRF) and Cross-Origin Resource Sharing (CORS) misconfigurations.
  * SQL Injection (SQLi) and NoSQL Injection (MongoDB query operators).
  * Cross-Site Scripting (XSS): Reflected, Stored, DOM-based, unescaped HTML/Markdown rendering.
  * Broken Object Property Level Authorization: Mass Assignment and Excessive Data Exposure.
  * Modern Protocols: GraphQL recursion/introspection DoS, gRPC auth interceptors, Cross-Site WebSocket Hijacking (CSWSH).
* **Memory Safety, Low-Level Execution & Concurrency**:
  * Double-Free (CWE-415), Use-After-Free (UAF - CWE-416), and buffer overflows (heap/stack).
  * Integer overflow/underflow leading to memory corruption or bounds bypass.
  * Go `unsafe.Pointer` conversions, Cgo memory leaks/FFI boundaries, Rust `unsafe` blocks.
  * Concurrency data races on shared maps/slices (`go test -race`), goroutine leaks, and deadlocks.
* **Resource Exhaustion & Application Denial of Service (OWASP A04, API4)**:
  * Unbounded request body reads (`io.ReadAll` without `io.LimitReader`).
  * Decompression bombs (Zip bombs, XML Billion Laughs).
  * Unbounded database queries and uncapped pagination parameters.
  * Regular Expression Denial of Service (ReDoS) on user input.
* **Cryptography, Secrets & Information Exposure (OWASP A02, A09)**:
  * Weak algorithms (MD5, SHA-1, DES, ECB mode) and insecure PRNG (`math/rand`).
  * Timing attacks on secret comparisons (lack of constant-time comparison).
  * Sensitive data leakage in application logs and CRLF log injection.
  * Hardcoded production credentials and insecure default fallbacks.
* **Business Logic & State Integrity (OWASP A04, API6)**:
  * Workflow bypass and step skipping in multi-step processes.
  * Illegal state machine transitions (e.g. order status manipulation).
* **AI & LLM Integration (OWASP Top 10 for LLM)** *(Conditional)*:
  * Direct and indirect prompt injection.
  * Insecure output handling (model output routed unsanitized into shell, SQL, or HTML).
  * Excessive agency: unbounded tool/function calling without server-side authorization.
* **CI/CD & Infrastructure Surface** *(Conditional upon scope agreement)*:
  * GitHub Actions workflow injection (`${{ github.event.issue.title }}` inside `run:`).
  * Dangerous `pull_request_target` checkouts, unpinned third-party actions.
  * Exposed runtime profilers (`/debug/pprof`, Spring Actuator, interactive debug consoles).

---

### What Is NOT Tested / Deliberately Excluded (Noise Elimination)

* **Dependency SCA Scanning**: Automated scanning of vulnerable third-party package versions (`govulncheck`, `trivy`, `npm audit`, `pip-audit`) is left to existing CI/CD pipelines. (The presence and gating of SCA in CI/CD is checked as a process note, but dependencies are not rescanned to avoid redundant noise).
* **Purely Theoretical Pattern Matches**: Regex matches or linter flags without an attacker-controlled input reaching a sensitive sink are discarded.
* **Development & Test Fixtures**:
  * Mocks, unit test helpers (`*_test.go`, `tests/`), seed fixtures, and local example codes are excluded unless project documentation instructs operators to deploy them in production.
  * Test credentials, dummy JWTs, and local `.env.example` placeholders are not reported as secret leaks.
* **Volumetric Network DDoS (L3/L4)**: Bandwidth saturation, SYN floods, and UDP amplification are infrastructure concerns managed by CDN/WAF layers and outside the scope of application source code auditing.
* **Physical & Host Compromise**: Physical machine access, root server compromise, or compromised hypervisors are excluded from the threat model unless specifically requested.
* **UUID Guessability**: High-entropy UUIDs (v4) are assumed unguessable; missing authorization checks on them are flagged as BOLA, not random guessability.
* **Static Internal Regexes**: ReDoS is only investigated when user-supplied input is matched against regexes with demonstrable catastrophic backtracking.

---

## Architecture & How It Works

```
Phase 0: Profiling & Upfront Interactive Scope Negotiation (00-scope.md, 00-profile.md)
   │
Phase 0.5: Domain Slicing, Scaling Rules & Backlog Generation (domains/<domain>/tasks.md)
   │
Phase 1: Domain-Isolated Subagent Execution (wt-<domain>, failing PoC tests)
   │     └── Phase 1.5: Composed-System & Inter-Domain Seam Agent (parallel)
   │
Phase 2: Multi-Stage Attack Chain Analysis (attack-chains.md)
   │
Phase 3: Adversarial PoC Verification & Worktree Cleanup (verification.md)
   │
Phase 4: Deliverables Generation (report.html, attack-chains.html, full-report.md, summary.md)
```

### Multi-Agent Scaling & Duplication Rule

To maintain deep focus and prevent context exhaustion, Phase 0 profiles the codebase and applies automatic scaling thresholds:
* If a domain exceeds **> 20 source files**, **> 5,000 LOC**, or **> 10 checklist tasks**, it is automatically partitioned into disjoint sub-domains (e.g., `auth-tokens` and `auth-rbac`).
* File ownership between subagents is strictly disjoint: no two agents inspect the same files.
* Each subagent operates within its own dedicated git worktree (`wt-<domain>`) and executes its assigned `tasks.md` sprint backlog.

### Burden of Proof: Failing PoC Tests

A finding cannot be classified as confirmed based solely on static code analysis. Subagents must write a unit or integration test that **FAILS** while the vulnerability is present and **PASSES** once remediated (`fail-to-prove`).

---

## Output Layout

All deliverables are generated within `.security-audit/<YYYY-MM-DD-HHMM>/`:

```
.security-audit/<run>/
├── 00-scope.md                # Agreed scope boundaries & noise exclusions
├── 00-profile.md              # Project tech stack, entry points, and Git ref
├── domains/
│   ├── auth/
│   │   ├── domain-profile.md  # Domain boundaries & files in scope
│   │   ├── tasks.md           # Sprint checklist backlog
│   │   ├── findings.json      # Structured findings (schema-validated)
│   │   └── notes.md           # Domain audit notes & coverage
│   ├── payment/
│   │   ├── domain-profile.md
│   │   ├── tasks.md
│   │   ├── findings.json
│   │   └── notes.md
│   └── traversal-filesystem/...
├── findings/
│   ├── composed-system.json   # Inter-domain & seam findings
│   └── composed-system.md
├── attack-chains.md           # Multi-finding attack chains narrative
├── attack-chains.html         # Dedicated interactive HTML report for attack chains
├── verification.md            # Adversarial PoC re-execution audit trail
├── poc-tests/                 # Archived proof-of-concept tests
│   └── README.md              # Reproduction commands & test runners
├── report.html                # Official State-of-the-Art interactive HTML report
├── full-report.md             # Complete Markdown report
└── summary.md                 # 1-page executive brief
```

---

## Finding Schema & Reproducibility States

Each finding in `findings.json` strictly conforms to `templates/finding-schema.json`:
* **CVSS v3.1 Base Score & Vector String**: e.g., `9.8` (`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`).
* **Reproducibility State**:
  * `confirmed-poc`: Verified with an automated failing unit/integration PoC test.
  * `likely-trace`: Validated through source-to-sink data flow, but environment-restricted from running live.
  * `theoretical-pattern`: Static pattern match without proven reachability.
* **Production Reachability**:
  * `yes`: Reachable in default production deployment.
  * `only-if-configured`: Reachable only when a non-default configuration or environment flag is set.
  * `no`: Present only in development, testing, or mock surfaces.

---

## Safety Rails

PoC tests execute strictly against localhost, local test mocks, or isolated local test databases. They **never** interact with staging/production URLs, external third-party services, or perform destructive real-world actions.

---

## Installation

### As a Claude Code skill (per-project)
Place this folder in your project's `.claude/skills/` directory:

```bash
your-repo/
└── .claude/
    └── skills/
        └── security-audit-v2/
            ├── SKILL.md
            └── templates/
```

### As a global skill (all projects)
Place it at `~/.claude/skills/security-audit-v2/`.

---

## Usage

Invoke the skill within Claude Code:

```
Run a security audit of this codebase using the security-audit-v2 skill.
```

The orchestrator will prompt you for the audit scope before initiating domain-partitioned subagent sprints.
