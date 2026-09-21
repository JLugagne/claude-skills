# Checklist: Web, API & Protocol Security (OWASP A03, A05, A10, API3, API7, API8, API9)

## 1. Server-Side Request Forgery (SSRF) & Cloud Metadata (A10:2021, API7:2023)
- [ ] **Outbound HTTP / Fetch Requests**: Identify all functions making outbound network requests based on user-supplied URLs (webhooks, avatar imports, PDF generation, link previews).
- [ ] **Cloud Metadata Service Protection (IMDS)**: Ensure outbound requests strictly forbid connections to cloud metadata IP addresses: `169.254.169.254` (AWS IMDSv1/v2, GCP, Azure, DigitalOcean) and Alibaba metadata `100.100.100.200`.
- [ ] **Private / Loopback IP Blocking**: Verify that private IP ranges (`127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `::1`, `fc00::/7`) are resolved and blocked at the socket/dialer level (post-DNS resolution) to prevent DNS rebinding attacks.
- [ ] **Protocol & Scheme Whitelisting**: Ensure only `http` and `https` schemes are accepted; reject dangerous schemes like `file://`, `gopher://`, `dict://`, `ftp://`, `ldap://`.
- [ ] **Parser Differentials & Open Redirect Bypasses**: Test if URL parsers can be tricked by userinfo (`http://google.com@127.0.0.1/`), backslashes, or if outbound clients automatically follow 302 redirects to internal resources.

## 2. Injection Flaws: SQL, NoSQL & Query Languages (A03:2021)
- [ ] **SQL Injection (SQLi)**: Trace all database queries. Verify that all queries use parameterized statements / prepared queries. Check for raw SQL strings concatenated with user input, dynamic `ORDER BY` clauses, or raw fragments in ORM calls (`db.Where("name = " + input)`).
- [ ] **NoSQL Injection**: For MongoDB / document databases, verify that user input is type-checked and cannot inject operator objects (e.g. `{"$gt": ""}` or `{"$ne": null}`) to bypass authentication or extract data.
- [ ] **LDAP & XPath Injection**: If querying directories or XML, ensure user inputs are sanitized and escaped against LDAP filters and XPath syntax.

## 3. Cross-Site Scripting (XSS) & Content Security (A03:2021)
- [ ] **Reflected & Stored XSS**: Check all web responses rendering user input into HTML, JavaScript contexts, or attribute contexts. Verify context-aware contextual escaping is applied.
- [ ] **Markdown & Rich-Text Parsers**: If the application renders user-supplied Markdown or HTML, verify that an aggressive HTML sanitizer (e.g. DOMPurify, bluemonday) strips `<script>`, `<iframe>`, `javascript:`, `data:` URLs, and dangerous event handlers (`onerror`, `onload`).
- [ ] **Client-Side Framework Vulnerabilities**: Check for `v-html` (Vue), `dangerouslySetInnerHTML` (React), or Angular bypasses of security trusts.

## 4. Cross-Site Request Forgery (CSRF) & CORS (A01:2021, API8:2023)
- [ ] **CSRF Protection on State-Changing Actions**: Verify that cookie-authenticated state-changing endpoints (`POST`, `PUT`, `DELETE`, `PATCH`) require anti-CSRF tokens or enforce `SameSite=Strict`/`SameSite=Lax` cookies.
- [ ] **CORS Misconfiguration**: Verify `Access-Control-Allow-Origin` does not blindly reflect the incoming `Origin` header with `Access-Control-Allow-Credentials: true`. Verify that origin validation does not use weak regexes (e.g. `.*example\.com` matching `attacker-example.com`).

## 5. API Property Level Auth: Mass Assignment & Data Exposure (API3:2023)
- [ ] **Mass Assignment / Parameter Binding**: Verify that incoming JSON or form payloads are deserialized into strict Data Transfer Objects (DTOs) with whitelisted fields, preventing attackers from overwriting internal properties (`is_admin`, `role`, `verified`, `balance`).
- [ ] **Excessive Data Exposure**: Verify API responses return tailored view models/DTOs rather than dumping raw database entities that expose password hashes, internal IDs, MFA secrets, or PII.

## 6. Protocols: GraphQL, gRPC & WebSockets (API4, API8, API9:2023)
- [ ] **GraphQL Introspection & Depth**: Verify introspection is disabled in production. Ensure query complexity/depth limiting and query timeouts prevent recursive DoS queries.
- [ ] **gRPC Auth Interceptors**: Verify all gRPC service handlers are protected by authentication/authorization interceptors and do not expose unauthenticated methods by omission.
- [ ] **Cross-Site WebSocket Hijacking (CSWSH)**: Verify that the HTTP upgrade handshake for WebSockets validates the `Origin` header against an authorized origin whitelist.
