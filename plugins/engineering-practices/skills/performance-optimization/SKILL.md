---
name: performance-optimization
description: Performance and runtime complexity optimization — Big O analysis, profiling before optimizing, algorithmic vs. constant-factor improvements, caching strategy, and database/network performance patterns. Use whenever analyzing or improving performance, discussing time/space complexity, deciding whether code is "fast enough," or the user mentions optimization, latency, or Big O.
---

# Performance and Runtime Complexity Optimization

Performance work follows a strict order: measure, find the actual bottleneck, fix the bottleneck, measure again. Optimizing without profiling almost always improves the wrong thing.

## The rule: profile before you optimize

- Never optimize based on intuition about what "should" be slow — real bottlenecks are frequently in unexpected places (a logging call, a serialization step, an N+1 query) rather than the algorithm you'd guess.
- Use a profiler appropriate to the runtime (JVM: async-profiler/JFR; Python: `cProfile`/`py-spy`; Node: `--prof`/Chrome DevTools; Go: `pprof`; browser: DevTools Performance tab) to get a flame graph before changing anything.
- Establish a baseline measurement first, so "optimized" is a comparison against a number, not a feeling.

## Complexity analysis — know what you're actually paying for

| Complexity | Example | Note |
|---|---|---|
| O(1) | Hash map lookup, array index | Ideal for hot paths |
| O(log n) | Binary search, balanced tree operations | Scales well |
| O(n) | Single pass over a collection | Usually fine; watch for it inside another loop |
| O(n log n) | Efficient sort, divide-and-conquer | The practical ceiling for large n |
| O(n²) | Nested loop over the same collection, naive duplicate-check | Fine for small n, a liability once n grows |
| O(2^n) | Naive recursive Fibonacci, exhaustive subset search | Needs memoization/DP or a different algorithm entirely |

The most common real-world complexity bug is an accidental O(n²) hiding inside code that looks like two separate O(n) operations:

```python
# O(n * m) — a linear scan inside a loop over another collection
def enrich_orders(orders, customers):
    return [
        {**o, "customer": next(c for c in customers if c["id"] == o["customer_id"])}
        for o in orders
    ]

# O(n + m) — build an index once, then O(1) lookups
def enrich_orders(orders, customers):
    by_id = {c["id"]: c for c in customers}
    return [{**o, "customer": by_id[o["customer_id"]]} for o in orders]
```

## Where the real cost usually is (in order of frequency)

1. **Database access** — N+1 queries, missing indexes, fetching more columns/rows than needed. Almost always the first thing to check in a slow web request; see the `sql-design` skill for indexing.
2. **Network calls** — sequential calls that could be parallelized (`Promise.all`/`asyncio.gather`), missing timeouts causing tail latency, no connection pooling/reuse.
3. **Serialization** — large JSON payloads parsed/stringified repeatedly, or serializing more data than the caller needs.
4. **Algorithmic complexity** — an accidental O(n²)/O(n³) as above; usually the actual "Big O" problem people think of first, but often not the biggest real-world cost compared to 1-3.
5. **Allocation pressure / GC** — excessive short-lived object creation in a hot loop, in GC'd languages.

## Caching strategy

- Cache at the layer where recomputation/refetching is most expensive and the data changes least — a computed aggregate, a slow external API's response, an expensive query's result.
- Choose an explicit invalidation strategy up front (TTL, event-driven invalidation on write, or cache-aside with versioned keys) — an unbounded cache with no invalidation plan becomes a source of stale-data bugs.
- Cache at the right granularity — caching an entire page/response is simpler but coarser; caching individual expensive sub-computations is more precise but adds complexity. Start coarse, narrow only where profiling shows it's needed.

```python
from functools import lru_cache

@lru_cache(maxsize=1024)
def compute_shipping_zone(postal_code: str) -> str:
    # Pure function of postal_code — safe to memoize, bounded cache size
    ...
```

## Concrete optimization techniques, roughly in order of effort-to-payoff

1. Add a missing database index / fix an N+1 query.
2. Batch or parallelize independent network calls.
3. Replace an O(n²) pattern with an indexed/hash-based O(n) equivalent.
4. Add caching for expensive, repeatable, low-churn computations.
5. Reduce payload size (pagination, field selection, compression).
6. Algorithmic rewrite (a fundamentally better algorithm/data structure) — highest payoff, highest effort; reserve for a confirmed bottleneck that survives the above.
7. Low-level/constant-factor tuning (avoiding allocations, SIMD, language-specific micro-optimizations) — last resort, for a hot path that's already algorithmically optimal.

## Common pitfalls

- "Optimizing" a function that profiling shows accounts for 0.1% of runtime, while the real 40% bottleneck goes untouched.
- Adding a cache without an invalidation strategy, trading a performance bug for a correctness bug.
- Premature micro-optimization (manual loop unrolling, avoiding a clear abstraction for a theoretical speed gain) that makes code harder to maintain with no measured benefit.
- Benchmarking in a non-representative environment (no realistic data volume, no concurrent load, a warm JIT/cache state that production won't have).
- Ignoring tail latency (p95/p99) in favor of average latency — a system can have a great average and a terrible worst case that dominates user-perceived performance.
