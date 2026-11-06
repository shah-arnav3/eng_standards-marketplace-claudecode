---
name: api-design
description: Modern API contract design — resource modeling, HTTP semantics, REST vs. gRPC vs. GraphQL selection, error formats, pagination, idempotency, and versioning/backward compatibility. Use whenever designing or reviewing an HTTP/gRPC/GraphQL API, writing an OpenAPI or protobuf schema, adding or changing an endpoint, or the user mentions REST, API versioning, breaking changes, or API contracts.
---

# API Design

An API is a contract that outlives its implementation: clients you don't control will depend on every field, status code, and quirk you ship. Design the contract first, make it consistent, and change it only in backward-compatible ways.

## Choosing the style

| Situation | Default |
|---|---|
| Public or partner-facing API, broad client variety, cacheable reads | REST over HTTP with an OpenAPI spec |
| Internal service-to-service, low latency, streaming, polyglot codegen | gRPC with protobuf |
| Many client screens each needing different shapes of a rich graph | GraphQL, with query depth/cost limits |
| Async events between services | A message schema (AsyncAPI, protobuf, JSON Schema) on a queue/topic, not an HTTP callback chain |

Pick one style per API surface. A REST API with a few RPC-style `POST /doThing` endpoints mixed in is harder to learn than either style alone.

## Contract first

- Write the schema (OpenAPI, `.proto`, GraphQL SDL) before the handler, review it like code, and generate server stubs, clients, and docs from it. A hand-maintained doc drifts from the implementation within weeks.
- Run a breaking-change check against the previous schema in CI (`oasdiff`, `buf breaking`, `graphql-inspector`).

## REST resource modeling and HTTP semantics

- Resources are plural nouns (`/orders`, `/orders/{id}/items`); actions are HTTP methods. Nest at most one level deep; beyond that, link by id.
- Use methods for their defined semantics: `GET` is safe and cacheable, `PUT` and `DELETE` are idempotent, `PATCH` is a partial update, `POST` creates or performs a non-idempotent action.
- Status codes carry the outcome: `201` with `Location` for creates, `204` for success with no body, `400` malformed input, `401` unauthenticated, `403` authenticated but not allowed, `404` not found (or not visible to this caller), `409` state conflict, `422` well-formed but semantically invalid, `429` rate-limited with `Retry-After`. Never return `200` with an error in the body.
- One naming convention for fields across the whole API (`snake_case` or `camelCase`), timestamps in RFC 3339 UTC, money as integer minor units plus a currency code — never a float.

## Errors

Use one error shape everywhere. RFC 9457 Problem Details is the standard for HTTP:

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient funds",
  "status": 422,
  "detail": "Account balance is 1200; the charge requires 5000.",
  "instance": "/payments/req-7f3a",
  "errors": [{ "field": "amount", "code": "exceeds_balance" }]
}
```

- A stable, machine-readable `type`/code that clients branch on; human-readable `detail` that they don't.
- Never leak stack traces, SQL, or internal hostnames in error bodies (see `backend-security`).
- gRPC: use the canonical status codes plus `google.rpc.ErrorDetails`, not a custom code inside an `OK` response.

## Pagination, filtering, and large collections

- Every list endpoint is paginated from day one; adding pagination later is a breaking change.
- Prefer cursor pagination (`?cursor=...&limit=50`, returning `next_cursor`) over offset pagination: it's stable under concurrent inserts and doesn't degrade on deep pages.
- Enforce a server-side maximum `limit`. Filtering and sorting use explicit, documented parameters (`?status=open&sort=-created_at`), not a free-form query language passed to the database.

## Idempotency and retries

- Clients and proxies retry. Any non-idempotent operation with a side effect that matters (payment, order placement, email send) accepts an `Idempotency-Key` header; the server stores the first result under that key and replays it for duplicates.
- Support conditional requests for concurrent updates: return an `ETag`, require `If-Match` on `PUT`/`PATCH`, and reply `412` on mismatch instead of silently applying last-write-wins.

## Versioning and evolution

Additive changes are safe; everything else is breaking.

| Safe (non-breaking) | Breaking |
|---|---|
| Add an optional request field or a new response field | Remove or rename a field, or change its type |
| Add a new endpoint or a new optional query parameter | Make an optional request field required |
| Add an enum value — only if clients were told to tolerate unknown values | Change a status code, error `type`, or default behavior |
| Relax a validation rule | Tighten a validation rule |

- Version in the URL path (`/v1/`) for public REST APIs: it's visible, cacheable, and easy to route. In protobuf, never reuse or renumber a field tag; mark removed tags `reserved`.
- Clients must ignore unknown response fields. State this in the API docs so additive changes stay safe.
- Deprecate before removing: announce, add `Deprecation` and `Sunset` headers, measure remaining usage per client, then remove. A new major version runs alongside the old one until usage drops to zero or the sunset date passes.

## Common pitfalls

- Exposing database tables one-to-one as resources, which leaks the schema into the contract and couples every client to it.
- Chatty APIs that need N calls to render one screen; design around client use cases, or offer an `?expand=` parameter.
- Booleans that later need a third state (`is_active` → `status: active | suspended | closed`). Prefer an enum from the start when a state might grow.
- Unbounded responses: list endpoints without a limit, or payloads that embed whole related collections.
- Authorization checked at the route but not per object (IDOR) — see `backend-security`.

## Review checklist

- [ ] Schema written and reviewed before implementation; a breaking-change check runs in CI
- [ ] Consistent naming, timestamp, and money conventions across every endpoint
- [ ] Correct methods and status codes; no `200` responses carrying errors
- [ ] One error format, with stable machine-readable codes
- [ ] Every list endpoint paginated, with a server-enforced max page size
- [ ] Idempotency keys on side-effecting `POST`s; `ETag`/`If-Match` on concurrent updates
- [ ] Change classified as additive or breaking; breaking changes go through a new version and a deprecation window
