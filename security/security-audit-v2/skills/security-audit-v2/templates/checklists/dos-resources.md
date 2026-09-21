# Checklist: Resource Exhaustion & Application Denial of Service (OWASP A04, API4)

## 1. Memory & Payload Limits (CWE-400, CWE-770)
- [ ] **Unbounded Request Body Ingestion**: Identify where incoming request bodies are read. In Go, verify `io.ReadAll(r.Body)` is wrapped in `io.LimitReader(r.Body, maxBytes)` or `http.MaxBytesReader(w, r.Body, maxBytes)` to prevent an attacker from sending gigabytes of data and exhausting RAM (OOM crash).
- [ ] **JSON / XML Parser Max Depth & Size**: Ensure JSON, XML, or Protobuf decoders have maximum payload size limits and maximum nesting depth limits to prevent stack overflow or heap exhaustion.
- [ ] **File Upload Buffer Size**: Verify multipart form parsing specifies a reasonable memory threshold (`ParseMultipartForm(maxMemory)`), with excess data spilled to disk or rejected.

## 2. Decompression Bombs & Entity Expansion (CWE-409, CWE-776)
- [ ] **Zip / Tar / Gzip Decompression Bombs**: Check code that uncompresses archives or streams. Verify that total uncompressed size is tracked and bounded during extraction; reject streams exceeding a safe limit (e.g. 100MB) to prevent tiny archives expanding into terabytes.
- [ ] **XML Entity Expansion (Billion Laughs / XXE)**: Verify XML parsers explicitly disable external entity resolution (`DOH_DISABLE_DTD_LOAD`, `resolve_entities=False`) and external DTDs.

## 3. Database Query & Pagination Limits (API4:2023)
- [ ] **Unbounded Query Results**: Check all endpoints returning lists/collections (`GET /api/items`). Ensure pagination is mandatory and the user-supplied `limit` parameter is strictly capped on the server (e.g. `limit = min(requestedLimit, 100)`).
- [ ] **Unindexed Queries & Heavy Filter Combinations**: Check search and filter endpoints allowing users to query arbitrary fields. Ensure expensive wildcard queries (`ILIKE '%...%'`) or queries on unindexed columns cannot be abused to lock database CPUs.

## 4. Algorithmic Complexity & ReDoS (CWE-1333)
- [ ] **Catastrophic Backtracking in Regular Expressions**: Audit regex patterns used on user input. Look for nested quantifiers (e.g. `(a+)+$`, `(a|aa)+$`, `([a-zA-Z]+)*`). Ensure regexes either use linear-time engines (like Go's `regexp` / RE2) or execute with strict timeouts.
- [ ] **Hash Collision Denial of Service**: If custom hash maps or user-controlled keys are inserted into hash tables in languages vulnerable to SipHash/hash collision attacks, verify collision protections.
