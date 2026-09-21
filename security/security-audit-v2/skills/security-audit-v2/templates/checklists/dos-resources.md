# Checklist: Application Denial of Service (DoS/DDoS) & Resource Exhaustion (OWASP A04, API4)

## 1. Application-Layer DDoS & Connection Starvation (CWE-400)
- [ ] **HTTP Server Timeout Configurations (Slowloris Resistance)**:
  - In Go: verify `http.Server` explicitly configures `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, and `IdleTimeout`. Missing timeouts allow an attacker to hold thousands of connections open with minimal bandwidth (Slowloris attack), exhausting server connection pools and file descriptors.
  - In Node.js / Python / Java: verify reverse proxy or application servers configure strict request body and keep-alive timeouts.
- [ ] **Rate Limiting on Critical & Expensive Endpoints**:
  - Verify presence of rate limiting middleware (token bucket, leaky bucket, Redis-backed rate limiting) on publicly exposed APIs, login routes, search endpoints, and compute-heavy endpoints.
  - Check whether rate limiters can be bypassed via header spoofing (`X-Forwarded-For`, `X-Real-IP`, `Client-IP`) if the reverse proxy trust configuration is misconfigured.
- [ ] **Connection & Worker Pool Exhaustion**:
  - Audit database connection pool settings (`MaxOpenConns`, `MaxIdleConns`) and background worker queues. Ensure incoming request surges cannot monopolize all DB connections and block critical healthcheck or read paths.

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
- [ ] **XML Entity Expansion (Billion Laughs / XXE)**: Verify XML parsers explicitly disable external entity resolution (`DOH_DISABLE_DTD_LOAD`, `resolve_entities=False`) and external DTDs.

## 5. Database Query & Pagination Limits (API4:2023)
- [ ] **Unbounded Query Results**: Check all endpoints returning lists/collections (`GET /api/items`). Ensure pagination is mandatory and the user-supplied `limit` parameter is strictly capped on the server (e.g. `limit = min(requestedLimit, 100)`).
- [ ] **Unindexed Queries & Heavy Filter Combinations**: Check search and filter endpoints allowing users to query arbitrary fields. Ensure expensive wildcard queries (`ILIKE '%...%'`) or queries on unindexed columns cannot be abused to lock database CPUs.

## 6. Algorithmic Complexity & ReDoS (CWE-1333)
- [ ] **Catastrophic Backtracking in Regular Expressions**: Audit regex patterns used on user input. Look for nested quantifiers (e.g. `(a+)+$`, `(a|aa)+$`, `([a-zA-Z]+)*`). Ensure regexes either use linear-time engines (like Go's `regexp` / RE2) or execute with strict timeouts.
- [ ] **Hash Collision Denial of Service**: If custom hash maps or user-controlled keys are inserted into hash tables in languages vulnerable to SipHash/hash collision attacks, verify collision protections.
