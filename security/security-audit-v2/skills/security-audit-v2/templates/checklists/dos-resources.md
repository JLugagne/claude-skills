# Checklist: Application Denial of Service (DoS/DDoS) & Resource Exhaustion (OWASP A04, API4)

## 1. Application-Layer DDoS & Connection Starvation (CWE-400)
- [ ] **HTTP Server Timeout Configurations (Slowloris Resistance)**:
  - In Go: verify `http.Server` explicitly configures `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, and `IdleTimeout`. Missing timeouts allow an attacker to hold thousands of connections open with minimal bandwidth (Slowloris attack), exhausting server connection pools and file descriptors.
  - In Node.js / Python / Java: verify reverse proxy or application servers configure strict request body and keep-alive timeouts.
- [ ] **Rate Limiting on Critical & Expensive Endpoints**:
  - Verify presence of rate limiting middleware (token bucket, leaky bucket, Redis-backed rate limiting) on publicly exposed APIs, login routes, search endpoints, and compute-heavy endpoints.
  - Check whether rate limiters can be bypassed via header spoofing (`X-Forwarded-For`, `X-Real-IP`, `Client-IP`) if the reverse proxy trust configuration is misconfigured.
- [ ] **Timeouts Disabled Wholesale**: A timeout middleware turned off for a whole router because a few routes stream (uploads, downloads) leaves every JSON route without a deadline too. Verify non-streaming routes keep a context deadline, and check every hop: gateway proxy transport (`ResponseHeaderTimeout`), edge proxy route timeouts, database `statement_timeout`. Only one bounded hop on the path is not enough when other callers bypass it.
- [ ] **Deadlines Defeated by a Middleware Wrapper**: per-request deadlines set through `http.ResponseController` (`SetReadDeadline`, `SetWriteDeadline`) silently do nothing when a logging or metrics middleware wraps the writer without `Unwrap()`. Prove the deadline reaches the conn through the production chain, or require listener-level `ReadTimeout`/`WriteTimeout`. Check every listener, public and internal, for reads (uploads) and writes (downloads).
- [ ] **Slow-Trickle Uploads**: Streamed uploads without a deadline hold a goroutine, a connection and a pending multipart upload in object storage for as long as the client trickles bytes.
- [ ] **Connection & Worker Pool Exhaustion**:
  - Audit database connection pool settings (`MaxOpenConns`, `MaxIdleConns`) and background worker queues. Ensure incoming request surges cannot monopolize all DB connections and block critical healthcheck or read paths.
  - Driver defaults derived from the CPU count (pgxpool `MaxConns = max(4, NumCPU)`) read the node's cores in Kubernetes when no CPU limit or `GOMAXPROCS` is set: 64 connections per pod on a 64-core node.
  - Rate limits claimed by documentation but absent from the gateway configuration: verify in the gateway repo or configuration, never from the docs.

## 2. Computational & CPU Amplification Vectors
- [ ] **Asymmetric Cost / CPU Amplification**:
  - Identify endpoints where a tiny, cheap HTTP request triggers disproportionate CPU computation:
    - PDF generation / report rendering from user input.
    - Image resizing / video transcoding / avatar processing.
    - Cryptographic operations (e.g. expensive password hashing or RSA verification triggered without authentication or rate limits).
    - Complex mathematical or regex evaluations.
- [ ] **Query Amplification & N+1 Database Cascades**:
  - Identify API endpoints that perform un-batched database queries in loops (N+1 queries). Can a single request trigger hundreds or thousands of database queries, saturating the database connection pool?
- [ ] **Cache Stampede / Thundering Herd**:
  - For high-traffic cached endpoints, check if cache expiration causes simultaneous incoming requests to simultaneously hit the backend database to recalculate the same value. Verify probabilistic early expiration (XFetch) or mutex locking (`singleflight` in Go) is implemented.

## 3. Memory & Payload Limits (CWE-400, CWE-770)
- [ ] **Unbounded Request Body Ingestion**: Identify where incoming request bodies are read. In Go, verify `io.ReadAll(r.Body)` is wrapped in `io.LimitReader(r.Body, maxBytes)` or `http.MaxBytesReader(w, r.Body, maxBytes)` to prevent an attacker from sending gigabytes of data and exhausting RAM (OOM crash).
- [ ] **JSON / XML Parser Max Depth & Size**: Ensure JSON, XML, or Protobuf decoders have maximum payload size limits and maximum nesting depth limits to prevent stack overflow or heap exhaustion.
- [ ] **File Upload Buffer Size**: Verify multipart form parsing specifies a reasonable memory threshold (`ParseMultipartForm(maxMemory)`), with excess data spilled to disk or rejected.

## 4. Decompression Bombs & Entity Expansion (CWE-409, CWE-776)
- [ ] **Zip / Tar / Gzip Decompression Bombs**: Check code that uncompresses archives or streams. Verify that total uncompressed size is tracked and bounded during extraction; reject streams exceeding a safe limit (e.g. 100MB) to prevent tiny archives expanding into terabytes.
- [ ] **YAML Alias & Merge-Key Expansion, Measured**: YAML anchors, aliases and merge keys (`<<: *a`, repeated `<<` keys in one mapping, sequence-of-aliases and inline-mapping merges) expand like entities. Measure the worst-case heap per input byte with a test, check every expansion path is charged to the work budget, and check the memory budget counts the parsed form, not only the raw bytes.
- [ ] **Library Buffers Outside the Budget**: fixed per-call buffers allocated by dependencies (an object-storage client's upload part buffer per write) multiplied by the concurrency the memory budget allows.
- [ ] **XML Entity Expansion (Billion Laughs / XXE)**: Verify XML parsers explicitly disable external entity resolution (`DOH_DISABLE_DTD_LOAD`, `resolve_entities=False`) and external DTDs.

## 5. Database Query & Pagination Limits (API4:2023)
- [ ] **Unbounded Query Results**: Check all endpoints returning lists/collections (`GET /api/items`). Ensure pagination is mandatory and the user-supplied `limit` parameter is strictly capped on the server (e.g. `limit = min(requestedLimit, 100)`).
- [ ] **Per-Request Memory Against the Container Limit**: maximum page size × maximum item size × copies held at once (driver buffer, decode, re-encode) compared with the pod memory limit. One authenticated request with a large page of large documents can OOM-kill the pod.
- [ ] **Per-Row Operators With Attacker-Sized Operands**: JSON containment (`@>`), array containment, `LIKE '%..%'` and regex operators cost O(n·m) per row when the attacker controls both the stored values and the filter. Verify the filter size is bounded and a statement timeout exists.
- [ ] **Unindexed Queries & Heavy Filter Combinations**: Check search and filter endpoints allowing users to query arbitrary fields. Ensure expensive wildcard queries (`ILIKE '%...%'`) or queries on unindexed columns cannot be abused to lock database CPUs.

- [ ] **Platform Limits as Permanent DoS**: a legitimate or attacker-shaped state (an object shared with thousands of audiences) that makes one commit exceed the store's per-commit mutation limit (Spanner 80,000 incl. index entries) or a message size limit fails on every retry: the object can no longer be deleted or updated.

## 6. Algorithmic Complexity & ReDoS (CWE-1333)
- [ ] **Catastrophic Backtracking in Regular Expressions**: Audit regex patterns used on user input. Look for nested quantifiers (e.g. `(a+)+$`, `(a|aa)+$`, `([a-zA-Z]+)*`). Ensure regexes either use linear-time engines (like Go's `regexp` / RE2) or execute with strict timeouts.
- [ ] **Hash Collision Denial of Service**: If custom hash maps or user-controlled keys are inserted into hash tables in languages vulnerable to SipHash/hash collision attacks, verify collision protections.
