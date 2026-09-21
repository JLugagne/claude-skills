# Checklist: Predictability, Guessability & Enumeration Flaws (CWE-330, CWE-340, CWE-200)

## 1. Predictable Resource Identifiers & Sequential Sequences (CWE-340, CWE-342)
- [ ] **Sequential Auto-Increment Database IDs**:
  - Check entities exposed in public or authenticated API URLs (`/api/users/{id}`, `/api/orders/{id}`, `/api/invoices/{id}`).
  - Identify where sequential auto-incrementing integer IDs are used: an attacker can trivially iterate through all records (scraping the entire dataset) or calculate business metrics (e.g. order growth rate, total registered customers).
  - Ensure entities use cryptographically secure random identifiers (UUID v4) or cryptographically masked public IDs (e.g. Hashids/sqids with private salts).
- [ ] **UUID Version Misuse (UUID v1 / UUID v2)**:
  - Audit UUID generation libraries. Verify whether UUID v1 (MAC address + 60-bit timestamp) is used instead of random UUID v4 or modern UUID v7.
  - In UUID v1, knowledge of one UUID leaks the host's MAC address and generation timestamp, allowing an adversary to predict or brute-force adjacent UUIDs generated within the same time window.
- [ ] **Low-Entropy or Predictable Voucher & Promo Codes**:
  - Check promo codes, gift cards, invitation codes, and discount vouchers. Are they short, sequential, or dictionary-based (e.g. `SUMMER2026`, `VIP1`, `VIP2`)?
  - Verify that promo and gift card codes have sufficient entropy (minimum 64 bits of entropy) or are strictly rate-limited against brute-force enumeration.
- [ ] **Predictable Order & Invoice Numbers**:
  - Check invoice, receipt, and reference numbering formats (e.g. `INV-2026-00123`). Verify that public access to documents requires a separate unguessable secret token or strict session ownership verification.

## 2. Token Predictability & Insecure PRNG (CWE-330, CWE-331)
- [ ] **Predictable Password Reset & Activation Tokens**:
  - Inspect generation of password reset tokens, email verification links, and invitation tokens.
  - Ensure tokens are generated using cryptographically secure random byte generators (`crypto/rand` in Go, `secrets` in Python, `crypto.randomBytes` in Node.js).
  - Verify tokens are NOT generated with pseudo-random generators (`math/rand`, `Math.random()`, `rand()`) or seeded with timestamps (`time.Now().UnixNano()`), which allows state reconstruction and token prediction.
- [ ] **Low-Entropy Verification PINs & OTPs**:
  - For 4-digit or 6-digit numeric codes (SMS OTP, email codes), verify strict attempt throttling (max 3–5 attempts) and short expiration windows (max 5–10 minutes) before invalidating the OTP, preventing brute-force enumeration.

## 3. Account Harvesting & User Enumeration (CWE-200, CWE-208)
- [ ] **Differentiated Error Messages**:
  - Test login, password reset, and registration endpoints.
  - Ensure error messages do not reveal account existence:
    - Insecure: "Email not found" vs "Incorrect password".
    - Secure: "Invalid email or password" or "If an account exists, instructions have been sent".
- [ ] **HTTP Status Code Differentials**:
  - Check if endpoints return different HTTP status codes for existing vs non-existing users (e.g. `404 Not Found` vs `401 Unauthorized` or `200 OK` vs `400 Bad Request`).
- [ ] **Timing-Based User Enumeration**:
  - Audit authentication and password verification functions.
  - If a user is not found in the database, does the function return immediately (e.g. 2ms), whereas a valid user triggers an expensive password hash check (Argon2/bcrypt taking 150–250ms)?
  - Verify that a dummy password hash computation is executed even when the user is not found, ensuring uniform response times and preventing timing-based account harvesting.
- [ ] **Unauthenticated User Lookup & Search Endpoints**:
  - Identify autocomplete, public directory, user search, or team invite APIs. Can an unauthenticated or low-privilege user query arbitrary email prefixes or phone numbers to enumerate the entire registered user directory?
