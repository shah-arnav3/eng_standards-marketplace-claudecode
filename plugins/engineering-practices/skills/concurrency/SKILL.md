---
name: concurrency
description: Handling concurrency correctly across languages — threads vs. async I/O, locks and lock-free patterns, race conditions, deadlock avoidance, and language-specific concurrency primitives (Java/C# threads and async, Python asyncio/GIL, Node event loop, Go goroutines/channels, Rust Send/Sync). Use whenever writing or reviewing concurrent/parallel code, diagnosing a race condition or deadlock, or the user mentions threads, async, locks, goroutines, or thread safety.
---

# Handling Concurrency

Concurrency bugs are the most expensive class of bug to find after the fact because they are often non-deterministic. Design them out structurally rather than relying on testing to catch them.

## First question: concurrency or parallelism, and I/O-bound or CPU-bound?

- **I/O-bound** (network calls, disk, DB queries) → async/await or an event loop model. You want many in-flight operations without many OS threads.
- **CPU-bound** (hashing, image processing, heavy computation) → real parallelism across cores: threads/processes/goroutines actually executing simultaneously, not just interleaved.
- Using the wrong tool is the most common concurrency mistake: spinning up a thread pool for I/O-bound work wastes memory on blocked threads; trying to get parallel speedup from Python's default threading for CPU-bound work does nothing because of the GIL.

## Shared mutable state is the root cause

Every concurrency bug — race condition, deadlock, torn read — traces back to two or more execution contexts touching the same mutable state without coordination. Eliminate the sharing before reaching for coordination primitives:

1. **Prefer immutable data passed between contexts** over shared mutable objects.
2. **Prefer message passing** (channels, queues, actor-style) over shared memory + locks where the language supports it well (Go channels, Rust `mpsc`, Erlang/Elixir actors).
3. **Only when 1 and 2 aren't viable**, protect shared mutable state with the narrowest lock that's correct.

## Locking discipline

- Lock scope should be as small as possible — acquire, do the minimal protected operation, release. Never hold a lock across an I/O call or another lock acquisition.
- Always acquire multiple locks in a globally consistent order across the whole codebase to prevent deadlock; document the order where more than one lock type exists.
- Prefer higher-level concurrent primitives (concurrent collections, atomic types, `ReadWriteLock` for read-heavy workloads) over raw mutexes when the language provides them.

```java
// Java — narrow lock scope, no I/O inside the critical section
private final Object lock = new Object();
private final Map<String, Integer> counts = new HashMap<>();

public void increment(String key) {
    synchronized (lock) {
        counts.merge(key, 1, Integer::sum);   // fast, in-memory, nothing blocking
    }
}
```

```go
// Go — prefer channels over shared state + mutex when the shape fits
func worker(jobs <-chan Job, results chan<- Result) {
    for job := range jobs {
        results <- process(job)   // ownership of the job transfers through the channel
    }
}

func RunAll(jobs []Job, workerCount int) []Result {
    jobCh := make(chan Job, len(jobs))
    resultCh := make(chan Result, len(jobs))
    for i := 0; i < workerCount; i++ {
        go worker(jobCh, resultCh)
    }
    for _, j := range jobs {
        jobCh <- j
    }
    close(jobCh)
    results := make([]Result, 0, len(jobs))
    for range jobs {
        results = append(results, <-resultCh)
    }
    return results
}
```

## Language-specific notes

- **Java/C#**: use structured concurrency where available (Java virtual threads + `StructuredTaskScope`, C# `Task`/`async`/`await` with `CancellationToken` threaded through every call) rather than raw `Thread`/`ThreadPool` management. Always propagate cancellation tokens so a client disconnect actually stops downstream work.
- **Python**: the GIL means threads don't parallelize CPU-bound work — use `multiprocessing` or a native extension for that. Use `asyncio` for I/O-bound concurrency; never mix blocking calls (`requests`, blocking DB drivers) inside an `async def` without offloading them to a thread pool (`asyncio.to_thread`).
- **Node.js**: the event loop is single-threaded — concurrency here means overlapping I/O, not parallel execution. CPU-heavy work must go to `worker_threads`, not `Promise.all` over synchronous computation, which blocks the loop for everyone.
- **Go**: goroutines are cheap but not free — an unbounded `go func()` per request/item without a worker pool or semaphore can exhaust memory/file descriptors under load. Always have a plan for goroutine lifetime (context cancellation, `sync.WaitGroup` to know when they're done).
- **Rust**: the compiler enforces `Send`/`Sync` at compile time — a type that isn't `Send` cannot cross a thread boundary, which eliminates a large class of races before runtime. Prefer `tokio::sync::Mutex` only when the critical section includes an `.await`; use `std::sync::Mutex` for purely synchronous critical sections (cheaper, no async overhead).

## Race condition checklist when reviewing concurrent code

- Is every piece of state that's read-then-written (check-then-act) protected atomically, or is there a window between the check and the act where another thread can interleave?
- Are locks released on every exit path, including exceptions (`try/finally`, `defer`, RAII/`Drop`)?
- Is there a consistent lock acquisition order everywhere more than one lock is taken?
- Does any callback/continuation capture a mutable variable by reference that changes before the callback runs (classic closure-in-a-loop bug)?
- Are shared collections truly thread-safe, or is it a plain `HashMap`/`dict`/`Array` being accessed from multiple threads?

## Common pitfalls

- Double-checked locking done incorrectly without proper memory barriers/atomics — looks correct, isn't.
- Using a global lock for unrelated pieces of state, serializing work that never needed to be serialized.
- Fire-and-forget async tasks with no error handling — an exception in a detached task silently disappears.
- Assuming increment/decrement (`counter++`) is atomic — it almost never is without an explicit atomic type.
- Testing concurrent code only under low contention — race conditions often only surface under load or with artificial delays/stress testing.
