# Checklist: Payment, Billing & Financial Logic (OWASP A04, API6, API10)

## 1. Concurrency, Race Conditions & Double-Spending
- [ ] **TOCTOU Balance & Quota Check**: Trace where balance/credits/inventory are checked versus where they are deducted. Verify atomic operations, DB row locking (`SELECT ... FOR UPDATE`), or serializable transactions prevent race conditions allowing double withdrawal/spending.
- [ ] **Concurrent Voucher / Discount Code Application**: Check if sending multiple simultaneous requests with the same single-use promo code or gift card redeems it multiple times before it is marked used.
- [ ] **Refund & Cancellation Races**: Check whether rapid concurrent cancellation/refund requests can trigger multiple payouts for a single order.

## 2. Numerical Precision, Currencies & Amount Manipulation
- [ ] **Floating Point Math in Financial Logic**: Verify all monetary calculations use integer cents, fixed-point decimals, or arbitrary-precision types (`big.Int`, `Decimal`), never standard floating point floats (`float32`/`float64`) which suffer from rounding errors.
- [ ] **Negative Amounts & Quantities**: Check if API endpoints accept negative quantities, zero amounts, or negative price overrides to reduce the total cart value or generate negative balances (credit generation).
- [ ] **Integer Overflow / Underflow**: Verify that summing item costs or quantities cannot overflow the integer boundary and wrap around to negative or small numbers.
- [ ] **Multi-Currency Rounding Arbitrage**: Check if switching currencies midway through a transaction or converting between currencies introduces rounding vulnerabilities that can be exploited.

## 3. Webhooks, Callbacks & Third-Party Gateway Integration (API10:2023)
- [ ] **Webhook Signature Verification**: Verify that incoming webhooks (Stripe, PayPal, Adyen, etc.) strictly validate the cryptographic signature (HMAC-SHA256) using the raw request body before parsing JSON/payload.
- [ ] **Webhook Replay Protection**: Check that webhook event IDs or timestamps are tracked in a database and deduplicated, preventing an attacker from replaying a captured successful payment webhook.
- [ ] **Tolerance Windows on Timestamps**: Verify that webhook timestamp tolerance windows are strictly enforced (e.g., max 5 minutes drift) to prevent stale event replay.
- [ ] **Blind Trust in Callback Parameters**: Ensure fulfillment logic relies on server-to-server gateway confirmation or database state, never solely on parameters in client browser redirects (`/payment/success?status=paid&order_id=123`).

## 4. Idempotency & Workflow Integrity
- [ ] **Idempotency Key Enforcement**: Verify that payment initiation and charge APIs implement idempotency keys, with keys tied to the authenticated user and request payload hash to prevent key hijacking.
- [ ] **Checkout Step Skipping**: Check state machine transitions to ensure steps (address -> shipping -> payment authorization -> capture) cannot be bypassed by directly calling the finalization endpoint.
- [ ] **Client-Side Price / Plan Tampering**: Verify that price, tier, discount, or subscription plan IDs cannot be supplied or modified by the client request; they must be resolved strictly from server-side database records.
