# Checklist: Memory Safety, Low-Level Execution & Concurrency (CWE-415, CWE-416, CWE-119, CWE-362)

## 1. Memory Safety Vulnerabilities (C, C++, Rust Unsafe, Go cgo/unsafe)
- [ ] **Double Free (CWE-415)**: Trace dynamic memory deallocation (`free()`, custom allocators, object destructors). Check if memory pointers can be freed more than once without setting the pointer to `NULL`/`nil`, leading to heap metadata corruption and potential arbitrary code execution.
- [ ] **Use-After-Free (UAF - CWE-416)**: Inspect pointers accessed after their referenced object has been deallocated or cleared from memory. Check async callbacks or event loops holding dangling references to freed structures.
- [ ] **Buffer Overflows & Out-of-Bounds Access (CWE-120, CWE-122, CWE-125, CWE-787)**:
  - Check unbounded memory copies (`memcpy`, `strcpy`, `sprintf`, `gets` or manual pointer arithmetic).
  - Verify buffer length checks before writing data into stack or heap buffers.
  - Check for off-by-one errors in loop termination and slice/array boundaries.
- [ ] **Integer Overflow / Underflow / Truncation (CWE-190, CWE-191, CWE-197)**: Check integer arithmetic used in buffer size calculations, allocation sizes, or array indices. Ensure casting between integer types (e.g. `size_t` to `int32`, `int64` to `int`) cannot truncate values and bypass bounds checks.

## 2. Unsafe Language Features & Native Interoperability
- [ ] **Go `unsafe` Package Usage**:
  - Audit all imports of `unsafe`: check `unsafe.Pointer` conversions, `uintptr` arithmetic (converting `uintptr` back to `unsafe.Pointer` after garbage collector moves the object), and direct slice header manipulation.
  - Verify that pointers passed across goroutines or memory boundaries do not escape memory safety guarantees.
- [ ] **Cgo & Foreign Function Interfaces (FFI)**:
  - Verify memory ownership across the C/Go boundary: check which side is responsible for freeing memory (`C.free`).
  - Verify string conversions (`C.CString` must be followed by `defer C.free(unsafe.Pointer(cStr))`).
  - Check if C code can throw unhandled signals or corrupt Go heap memory.
- [ ] **Rust `unsafe` Blocks**: Audit every `unsafe` block in Rust code. Verify raw pointer dereferences, FFI calls, and mutable static variables strictly maintain Rust's safety invariants.

## 3. Concurrency, Data Races & Goroutine Safety (CWE-362)
- [ ] **Data Races on Shared State**:
  - Run or test with race detection (`go test -race`).
  - Audit shared maps, slices, and structs accessed across concurrent goroutines/threads without mutexes (`sync.Mutex`, `sync.RWMutex`) or atomic operations (`sync/atomic`).
  - Check for concurrent map read/write (causes immediate unrecoverable process crash in Go).
- [ ] **Goroutine / Thread Leaks**: Verify that goroutines or worker threads spawned on incoming requests have terminating conditions, context cancellation handling (`ctx.Done()`), and bounded channels to prevent unbounded memory growth over time.
- [ ] **Deadlocks & Lock Inversion**: Check multi-lock acquisition order across functions to ensure no cyclic locking can cause deadlocks that freeze request processing.
