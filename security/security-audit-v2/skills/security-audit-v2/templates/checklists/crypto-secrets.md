# Checklist: Cryptography, Secrets & Data Protection (OWASP A02, A09)

## 1. Cryptographic Algorithms & Primitives (A02:2021)
- [ ] **Weak Hashing Algorithms**: Verify that password hashing uses robust, memory-hard key derivation functions (Argon2id, bcrypt, PBKDF2, or scrypt) with adequate work factors, never raw or fast hashes (MD5, SHA-1, SHA-256).
- [ ] **Cipher Mode & Padding**: Audit symmetric encryption implementations (AES, ChaCha20). Verify authenticated encryption modes (AES-GCM, ChaCha20-Poly1305) are used. Reject insecure modes like AES-ECB or CBC without HMAC.
- [ ] **IV & Nonce Generation**: Ensure initialization vectors (IVs) and nonces are generated using cryptographically secure random sources (`crypto/rand`) and are NEVER reused with the same key (nonce reuse in AES-GCM destroys confidentiality and authenticity).

## 2. Insecure Randomness (CWE-330)
- [ ] **Pseudo-Random Number Generators (PRNG)**: Audit all generation of tokens, session IDs, password reset keys, salt, or cryptographic identifiers. Ensure `crypto/rand` is used, never pseudo-random generators (`math/rand` in Go, `random` in Python, `Math.random()` in JS).
- [ ] **Static or Predictable Seeds**: Verify PRNGs are not seeded with predictable values like `time.Now().UnixNano()` or constant seeds.

## 3. Timing Attacks & Constant-Time Comparisons (CWE-208)
- [ ] **Secret & Signature Comparison**: Audit comparisons of HMAC signatures, webhook signatures, authentication tokens, or password hashes. Ensure comparisons use constant-time functions (e.g. `subtle.ConstantTimeCompare` in Go, `hmac.compare_digest` in Python) to prevent timing side-channel attacks.

## 4. Sensitive Data Logging & Log Injection (A09:2021)
- [ ] **Secrets & PII in Application Logs**: Audit logging statements. Verify that passwords, raw API keys, bearer tokens, credit card numbers, or personal identifiable information (PII) are redacted or filtered before logging.
- [ ] **Log Injection (CRLF)**: Verify that user-supplied input written to logs is sanitized of newline characters (`\r`, `\n`) to prevent log forging or injection of fake audit entries.

## 5. Hardcoded Secrets & Key Management (A02:2021)
- [ ] **Hardcoded Credentials**: Check for hardcoded private keys, API tokens, JWT signing secrets, or database passwords in shipping source code.
- [ ] **Default Secret Fallbacks**: Check if configuration loaders fall back to known, default, or insecure secrets if an environment variable is missing (e.g. `JWT_SECRET = os.Getenv("JWT_SECRET") || "secret123"`).
