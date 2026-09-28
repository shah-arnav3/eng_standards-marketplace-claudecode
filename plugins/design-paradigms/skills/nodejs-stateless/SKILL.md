---
name: nodejs-stateless
description: Modern stateless Node.js service architecture — request-scoped state, avoiding module-level mutable singletons, async/await patterns, the event loop and backpressure, horizontal scalability, and 12-factor-aligned service design. Use whenever writing, reviewing, or architecting a Node.js/Express/Fastify/NestJS backend service, an API gateway, or a worker process, or when the user mentions Node scalability, statelessness, or horizontal scaling.
---

# Node.js Stateless Service Architecture

Node's single-threaded event loop makes statelessness not just a scaling preference but a correctness requirement: any module-level mutable state is shared across every concurrent request handled by that process.

## Core principle: no state survives a request except in an external store

A stateless service instance can be killed and replaced at any moment without losing anything that matters. Concretely:

- No in-memory session storage, in-memory caches of user-specific data, or module-level counters that represent business state.
- All durable state lives in a database, Redis, or a message queue — never in a process-local variable.
- Any process-local cache (e.g., a compiled regex, a config value) must be safe to lose and rebuild, and must not vary per-request.

```javascript
// WRONG — module-level mutable state shared across all concurrent requests
let requestCount = 0;
let currentUserCache = {};

app.get("/profile", (req, res) => {
  requestCount++;                       // race condition, and lost on restart
  currentUserCache[req.user.id] = req.body; // leaks across users, unbounded growth
  res.json(currentUserCache[req.user.id]);
});
```

```javascript
// RIGHT — all state is request-scoped or externalized
app.get("/profile", async (req, res, next) => {
  try {
    const profile = await profileRepository.findById(req.user.id); // externalized store
    await metrics.increment("profile.requests");                    // externalized counter
    res.json(profile);
  } catch (err) {
    next(err);
  }
});
```

## Request-scoped context instead of globals

Use `AsyncLocalStorage` for per-request context (correlation IDs, auth principal) instead of attaching to a shared object or relying on argument threading through every function:

```javascript
const { AsyncLocalStorage } = require("node:async_hooks");
const requestContext = new AsyncLocalStorage();

function contextMiddleware(req, res, next) {
  const store = { correlationId: req.headers["x-correlation-id"] ?? crypto.randomUUID() };
  requestContext.run(store, next);
}

function logger(message) {
  const ctx = requestContext.getStore();
  console.log(JSON.stringify({ correlationId: ctx?.correlationId, message }));
}
```

This keeps every downstream function pure with respect to request identity — nothing needs a `req` object threaded through it just to log a correlation ID.

## Async patterns

- **async/await over raw promise chains or callbacks** for anything with sequential steps; reserve `Promise.all`/`Promise.allSettled` for genuine parallelism.
- **Always handle rejection.** An unhandled promise rejection crashes the process by default in modern Node. Wrap route handlers so thrown errors reach the error middleware:

```javascript
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

router.get("/orders/:id", asyncHandler(async (req, res) => {
  const order = await orderService.get(req.params.id); // throws -> caught -> next(err)
  res.json(order);
}));
```

- **Backpressure with streams.** For large payloads (file uploads, large query results), use Node streams with `pipeline()` rather than buffering entire payloads into memory:

```javascript
const { pipeline } = require("node:stream/promises");

await pipeline(
  fs.createReadStream(sourcePath),
  csvParser(),
  transformRows(),
  fs.createWriteStream(destPath)
);
```

- **Never block the event loop.** CPU-heavy work (image processing, large JSON parsing, cryptographic hashing at scale) belongs in a `worker_threads` pool or a separate service, not inline in a request handler.

## Horizontal scalability checklist

A service is safely horizontally scalable when all of these hold:

1. Any instance can serve any request — no sticky sessions required (or sessions are externalized to Redis if session affinity is unavoidable).
2. Startup does not depend on being "the only" instance (no assumptions about being first to run, no in-memory leader election for correctness-critical work).
3. Shutdown is graceful: the process stops accepting new connections, drains in-flight requests, then exits (`server.close()` + `SIGTERM` handler), so a rolling deploy causes zero dropped requests.
4. Configuration comes from environment variables / a config service, not from files baked into a specific instance (12-factor config).
5. Logs go to stdout/stderr for the platform to collect — never to a local file that only one instance can see.

```javascript
process.on("SIGTERM", async () => {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref(); // hard exit if drain hangs
});
```

## Layering (Express/Fastify/NestJS-agnostic)

```
routes/         HTTP layer only — parse request, call a service, shape response
services/       business logic — pure where possible, orchestrates repositories
repositories/   data access — the only layer that talks to the DB/cache
```

Route handlers should be thin: validate input, call one service method, map the result to a response. Business logic that ends up in a route handler is invisible to unit tests and impossible to reuse from a queue worker.

## Common pitfalls

- Module-level `let cache = {}` used as a "quick" per-user cache — becomes a memory leak and a cross-request data leak the moment there is more than one concurrent user.
- Using `process.env` scattered through the codebase instead of a single validated config module loaded once at startup.
- Missing timeouts on outbound HTTP/DB calls — one slow dependency can exhaust the event loop's capacity for everyone.
- Synchronous JSON.parse/stringify or crypto calls on large payloads inline in a hot path, stalling the event loop for all concurrent requests.
- Treating `worker_threads` state as shared — each worker has its own isolated heap; share only via message passing or `SharedArrayBuffer` when truly needed.
