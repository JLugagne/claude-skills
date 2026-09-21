# Checklist: Authentication, Authorization & Access Control (OWASP A01, A07, API1, API2, API5)

## 1. Broken Object Level Authorization (BOLA / IDOR - API1:2023, A01:2021)
- [ ] **Direct Identifier Reference**: Check if user/tenant supplied IDs in path, query params, or body (`/api/users/{id}`, `/api/orders/{order_id}`) are queried without validating that the authenticated session owns that record.
- [ ] **Missing Tenant/Organization Isolation**: Ensure every database query in multi-tenant models filters by `tenant_id` / `org_id` derived from the session context, never relying solely on user input.
- [ ] **UUID / GUID Guessability vs Authz**: Even with unguessable UUIDs, verify explicit authorization checks exist on every retrieval, update, and deletion endpoint.
- [ ] **Composite Key Bypasses**: Where entities use composite keys (e.g., `account_id` + `sub_id`), verify both keys are checked against session ownership.

## 2. Broken Function Level Authorization (BFLA & Privilege Escalation - API5:2023, A01:2021)
- [ ] **Role / Permission Checks on Sensitive Endpoints**: Check that administrative, backoffice, or higher-tier endpoints (`/admin/*`, `/internal/*`, `/api/billing/plan`) enforce strict role verification on the server.
- [ ] **HTTP Method Flipping**: Check if switching HTTP methods (e.g. `GET` -> `POST`, `PUT`, `DELETE`, `OPTIONS`) bypasses authorization middleware.
- [ ] **Parameter-based Role Switching**: Check if passing hidden or undocumented params (e.g., `?role=admin`, `?is_admin=true`, `?debug=1`) elevates privileges.
- [ ] **Horizontal Privilege Escalation**: Verify that user A cannot perform actions on behalf of user B (e.g., updating user B's profile, changing user B's notification settings).

## 3. Token & Session Management Flaws (A07:2021, API2:2023)
- [ ] **JWT Algorithm Confusion**: Verify that JWT verification rejects the `none` algorithm and verifies explicit expected algorithm (e.g., preventing HMAC verification with an RSA public key).
- [ ] **JWT Key & Header Injection**: Check for `kid` (Key ID) header injection (directory traversal in `kid`, SQLi, or jku/x5u URL injection).
- [ ] **Token Expiration & Revocation**: Check that tokens cannot be used after logout, password reset, or token revocation. Verify claims `exp`, `nbf`, and `iat` are validated.
- [ ] **Session Fixation**: Verify that session identifiers (cookies or tokens) are regenerated upon login, privilege change, or password update.
- [ ] **Cookie Security Flags**: Ensure cookies containing session tokens are set with `HttpOnly`, `Secure`, and `SameSite=Lax` or `SameSite=Strict`.

## 4. Authentication Flows & Ceremony Flaws (A07:2021)
- [ ] **Password Reset Flaws**: Check for Host Header Poisoning in reset emails, predictable reset tokens, missing token expiration, or reset tokens usable more than once.
- [ ] **MFA / 2FA Bypass**: Verify that step-up or 2FA verification cannot be skipped by directly accessing post-MFA routes, dropping cookies, or manipulating the API response (`{"mfa_success": false}` -> `true`).
- [ ] **OAuth / OIDC Misconfigurations**: Verify strict validation of the `state` parameter (CSRF protection in OAuth), `redirect_uri` exact matching (no open redirect or regex bypass), and PKCE implementation for public clients.
- [ ] **Credential Stuffing & Brute Force Protections**: Verify account lockouts, progressive delays, or rate limiting on authentication attempts.
