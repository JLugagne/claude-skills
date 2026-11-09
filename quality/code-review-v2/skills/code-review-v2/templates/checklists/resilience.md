# Checklist: Resilience & Operational Bounds

What happens when a request is slow, large, repeated, or goes through the proxies in front of the
service. These are quality defects even when no attacker is involved: a single slow query or large page
can take a pod down. **Burden of proof**: name the input or condition, the resource it consumes, and
the bound that is missing (or the number that exceeds the deployment limit). Read the deployment or
gateway configuration when the scope includes it; otherwise mark the finding `needs-confirmation` with
the command that would settle it.

## 1. Deadlines
- [ ] **Timeouts disabled wholesale for an exception**: a timeout middleware turned off for a whole
  router because a few routes stream, leaving every non-streaming route unbounded too.
- [ ] **No deadline anywhere on the path**: server read/write timeouts, handler deadlines, proxy
  response-header timeouts and database statement timeouts all absent, so a slow query or slow client
  holds a goroutine and a connection until the client gives up.
- [ ] **Deadlines that never reach the connection**: a per-request read or write deadline set through
  `http.ResponseController` is a silent no-op when a middleware wraps the writer without `Unwrap()`
  (logging and metrics wrappers often do; `SetWriteDeadline` returns `ErrNotSupported`). Prove the
  deadline applies through the production middleware chain; otherwise the listener's own
  `ReadTimeout`/`WriteTimeout` must bound it. Check EVERY listener (public and internal), reads AND
  writes: a stalled upload holds its memory reservation as long as a stalled download holds its conn.
- [ ] **Deadline expiry mapped to a generic 500** instead of a recognizable answer (`503`/`504` with a
  stable key), which hides timeouts in monitoring.

## 2. Input and Output Bounds
- [ ] **Unbounded user-controlled inputs** reaching expensive operations: filter objects, array sizes,
  query-string payloads, nesting depth, number of items in a batch.
- [ ] **Per-request memory above the container limit**: `max page size × max item size × copies`
  (driver buffer, decode, re-encode) compared with the pod memory limit; a single legitimate request
  must not be able to OOM the service.
- [ ] **Parser memory amplification, measured**: for every parser of untrusted input (YAML anchors,
  aliases and merge keys, JSON, XML, tar/zip, multipart), measure the worst-case heap per input byte
  with a test (`TotalAlloc`), and check every expansion path is charged to the budget (repeated keys,
  sequence and inline forms). A memory budget that counts raw bytes only, while the parsed form costs
  100× more, is not a bound.
- [ ] **Library buffers outside the budget**: fixed buffers a dependency allocates per call (an upload
  client's part buffer per write, a decoder's read-ahead) multiplied by the concurrency the budget
  allows.
- [ ] **No quota or rate limit where storage grows per call** (uploads, documents), or documentation
  claiming one exists upstream that the code or gateway does not show.

## 3. Proxies and Headers
- [ ] **Assumptions about the hop in front**: header stripping, compression, body limits, retries.
  Example: a gzip middleware that keeps the upstream `Content-Length` truncates every compressed
  response, and stripping `Accept-Encoding` on the forwarded request does not protect the client-facing
  hop. Verify each hop separately.
- [ ] **Missing cache directives** on authenticated or tenant-scoped responses
  (`Cache-Control: private, no-store`).
- [ ] **Streaming routes** (uploads, downloads) without a size limit, an interruption metric, or cleanup
  of partially written objects.

## 4. Configuration
- [ ] **Defaults defined in two places** (code and checked-in YAML) that can drift, or a checked-in
  config with debug-level logging of request URIs carrying business data.
- [ ] **Limits that are not configurable** where the deployment needs to tune them (timeouts, sizes).
- [ ] **Configuration accepted without validation**: unknown keys (typos) silently ignored, negative or
  inconsistent values (a budget below the per-item maximum, a write timeout shorter than the read
  timeout) replaced by defaults or accepted; the shipped config tree never loaded by any test.
- [ ] **Dev settings in the shipped artifact**: emulator endpoints, local buckets or credentials in the
  default config copied into the image; dev compose files publishing unauthenticated services on all
  interfaces instead of loopback.

## 5. Platform Limits
- [ ] **Store and broker hard limits reachable by normal use**: per-commit mutation limits (Spanner
  80,000 mutations including secondary-index entries; DynamoDB 100 items per transaction), request,
  row and message size limits, fan-out deletes or updates of a widely shared parent. An operation that
  exceeds the limit fails on every retry: the object becomes undeletable.
