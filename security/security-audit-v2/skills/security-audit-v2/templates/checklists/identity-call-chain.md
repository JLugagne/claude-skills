# Checklist: Identity Sources, Trust Boundaries & Call Chain (OWASP A01, A04, A05, A07, API2, API8)

A service behind a gateway inherits every assumption the gateway makes and every gap it leaves. Audit
each hop separately: a mitigation on one hop does not cover another, and a header stripped on the way in
can be rebuilt on the way out. **Burden of proof**: name the hop, the identity the attacker holds, the
value they control, and what it reaches. When a hop lives in a repo outside the scope, file the finding
with `call_chain_status: "needs-confirmation"` and a `settle_with` command; never assume the other hop
mitigates it because a document says so.

## 1. Identity Source Map
- [ ] **Where each identity attribute comes from**: for tenant, user, team/group, role, and any scope
  selector (app, workspace, project, client), write down the source used by the code: signed claim,
  header, URL segment, body field, environment default. Read the helper functions down to the library
  (`TenantID(ctx)`, `UserID(ctx)`), at the exact version in the module file.
- [ ] **Claim-to-header fallback**: helpers returning the token claim when present and a request header
  (`X-Tenant-Id`, `X-User-Id`, `X-Team-Id`) when the claim is empty. A valid token without the claim
  then lets the caller pick the value. Check which claims the token minter always sets.
- [ ] **Environment fallbacks**: default tenant or user variables that let a request without any token
  through, or fill a missing claim. A finding only when a deployment configuration you can read sets the
  variable (or, without the deployment repo, `needs-confirmation` with a `settle_with` that shows it set).
  A variable no deployment sets, or one `00-decisions.md` records as never set, is not a finding — and a
  README warning against setting it is not evidence that it is set.
- [ ] **Scope selectors not bound to the principal**: an app, project or workspace taken from the URL
  and only checked against a name pattern, while the documentation promises isolation between them
  ("documents never cross apps"). Probe: the same user calls the routes of another value.
- [ ] **Token validation strength**: signature verified against the right key set, expected algorithm
  enforced, and `exp`/`nbf` checked; libraries that parse without verifying expiry, or log a warning and
  continue.

## 2. Hop-by-Hop Trust
- [ ] **Per-hop table**: for every hop (edge proxy, gateway, forwarder, service), record: what it
  authenticates, which headers it strips, which it adds, whether it rebuilds headers from a context the
  client influenced, rate limits, timeouts, body limits, compression, and the version of each shared
  middleware library. Differences between hops are where findings live.
- [ ] **Strip-then-rebuild**: a gateway deleting client identity headers after its context handler
  already read them, then writing the context back to the outgoing request. The client's header reaches
  the service for every claim the token leaves empty.
- [ ] **Direct reachability**: can any workload reach the service without the gateway (Kubernetes
  `NetworkPolicy` admitting a whole tier, ClusterIP DNS names, internal tools or scripts calling the
  service URL directly)? Every gateway mitigation is void for those callers.
- [ ] **Same library, different versions across hops**: a middleware bug fixed in one service (e.g. a gzip
  handler keeping the uncompressed `Content-Length`, truncating every compressed response) still present
  in the hop in front. Compare module files of every hop.

## 3. Claims vs. Reality
- [ ] **Security controls attributed to another component**: documentation or agent instruction files
  saying "the gateway authenticates / rate-limits / validates X". Verify each in that component's code or
  configuration; a false claim is a finding in itself, because the next reviewer will skip the control.
- [ ] **Test harnesses replacing the identity middleware**: when the end-to-end setup swaps the real
  context handler for one reading headers, no test exercises identity extraction. PoCs for this checklist
  must go through the production middleware chain.
