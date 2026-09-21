# Checklist: Business Logic, State Integrity & Workflow Bypasses (OWASP A04, API6)

## 1. Workflow & State Machine Bypasses
- [ ] **Step Skipping in Multi-Step Wizards**: In complex workflows (signup onboarding, KYC verification, checkout, password reset), verify that the server validates that all preceding steps were completed and marked verified in the database before allowing subsequent steps.
- [ ] **Illegal State Transitions**: Map out entity states (e.g. Order: `created` -> `paid` -> `shipped` -> `delivered` / `refunded`). Ensure endpoints do not allow illegal direct transitions (e.g. from `created` directly to `shipped` or modifying an already `completed` or `cancelled` order).
- [ ] **State Rollback & Re-entrance**: Check if cancelling or reverting an action returns resources or credits without properly resetting the dependent state.

## 2. Parameter Tampering & Business Constraints
- [ ] **Tampering with Read-Only Business Fields**: Check if submitting additional fields in update requests allows modifying fields intended to be server-computed (e.g. `tier`, `discount_rate`, `reputation_score`, `verified_email: true`).
- [ ] **Time & Date Manipulation**: In time-sensitive features (trial periods, discounts, expiration dates), verify timestamps are generated strictly from trusted server time, not derived from client requests or headers.
- [ ] **Usage Quota & Tier Limit Bypasses**: Test if rate limits, usage quotas (e.g. free tier max 5 projects), or storage caps can be bypassed by parallel requests or sub-resource creation.

## 3. Anti-Automation & Automated Abuse (API6:2023)
- [ ] **Inventory & Seat Scalping**: In booking or purchase flows, check if items can be held in a cart indefinitely without reservation timeouts, enabling competitor denial of inventory.
- [ ] **Coupon & Referral Stacking**: Verify that referral bonuses or coupons cannot be applied repeatedly to the same account or chained via self-referrals.
