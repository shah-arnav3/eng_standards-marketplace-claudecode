---
name: code-quality
description: Coding style fundamentals — immutability, error handling strategy, input validation, and general code quality standards that apply across languages. Use whenever writing or reviewing any code for correctness and maintainability, deciding how to validate input or handle errors, or the user mentions code quality, clean code, or defensive programming.
---

# Coding Style: Immutability, Error Handling, Input Validation, Code Quality

These are the cross-language defaults to apply to every piece of code regardless of paradigm or language skill in use.

## Immutability by default

Prefer values that cannot change after construction; treat mutation as something you opt into for a specific, justified reason (a hot loop with a measured allocation cost, a genuine state machine).

- Mark things immutable at the language level whenever available: `final`/`readonly` (Java/C#), `const`/`Object.freeze` (JS, sparingly — shallow), `frozen=True` dataclasses (Python), values by default (Rust — `let` is immutable unless `mut`).
- Return new values instead of mutating arguments — a function that mutates its input silently is a common source of action-at-a-distance bugs.
- Immutable data structures are inherently thread-safe and safe to share/cache without defensive copying.

```typescript
// Prefer returning a new object over mutating the input
function markShipped(order: Order): Order {
  return { ...order, status: "shipped", shippedAt: new Date().toISOString() };
}
```

## Error handling strategy

1. **Fail fast at the boundary.** Validate input as early as possible so invalid data never propagates deep into the system where the failure becomes hard to trace back to its cause.
2. **Distinguish expected failures from bugs.** A user submitting invalid input is expected and should produce a clear, typed error/result — not a stack trace. A null pointer from a coding mistake is a bug and should surface loudly in development/staging, not be silently caught.
3. **Never swallow an error silently.** An empty `catch` block, an ignored return code, or a caught exception with no logging/rethrow is a bug factory — the failure still happens, but now invisibly.
4. **Handle errors at the level that can do something about it.** A low-level function that can't meaningfully recover should propagate (throw, return `Err`/`Result`) rather than log-and-continue with corrupted state.
5. **Attach context, don't just rethrow a generic message.** Wrap/annotate with what operation was being attempted and relevant identifiers (order id, user id) so the eventual log line is actionable.

```python
# WRONG — swallows the error, continues with a business-invalid state
try:
    order.total = calculate_total(order)
except Exception:
    pass

# RIGHT — fails where it can't safely continue, with context
try:
    order.total = calculate_total(order)
except PricingServiceError as e:
    raise OrderProcessingError(f"could not price order {order.id}") from e
```

## Input validation

- Validate at every trust boundary: HTTP request bodies, CLI arguments, file contents, messages consumed from a queue, environment variables at startup. Never trust that "the frontend already validated this."
- Validate structure first (types, required fields), then business rules (ranges, cross-field invariants) — separate concerns so error messages are precise about which layer failed.
- Prefer schema-based validation (JSON Schema, Zod/Yup on the frontend, Pydantic/Bean Validation/FluentValidation on the backend) over scattered manual `if` checks — one source of truth for the shape of valid data, and it doubles as documentation.

```typescript
import { z } from "zod";

const CreateOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(z.object({ sku: z.string(), quantity: z.number().int().positive() })).min(1),
});

function handleCreateOrder(body: unknown) {
  const result = CreateOrderSchema.safeParse(body);
  if (!result.success) {
    return { status: 400, body: { errors: result.error.flatten() } };
  }
  return createOrder(result.data); // downstream code can trust the shape completely
}
```

- Whitelist, don't blacklist: define what valid input looks like (allowed characters, allowed enum values, max length) rather than trying to enumerate every invalid case.
- Sanitize/validate separately from escaping for output context (SQL, HTML, shell) — validation confirms correctness of the data; escaping/parameterization at the output boundary prevents injection regardless of whether validation missed something (see the `backend-security` and `frontend-security` skills for the injection-specific detail).

## General code quality checklist

- **Naming**: a name should make a comment unnecessary. `daysUntilExpiry` beats `d` with a comment explaining what `d` is.
- **Function size and single responsibility**: if you can't describe a function in one sentence without "and", split it.
- **No magic numbers/strings**: named constants or enums, always, even for "obvious" values — `MAX_RETRIES = 3` beats a bare `3` at three different call sites that all mean different things.
- **Guard clauses over nested conditionals**: return/raise early for the invalid/edge case, keep the happy path unindented.

```java
// Guard clause style — flat, easy to scan
public BigDecimal calculateDiscount(Order order) {
    if (order == null) throw new IllegalArgumentException("order is required");
    if (order.getItems().isEmpty()) return BigDecimal.ZERO;
    if (!order.isEligibleForDiscount()) return BigDecimal.ZERO;

    return order.getTotal().multiply(DISCOUNT_RATE);
}
```

- **DRY, but not prematurely**: two similar-looking pieces of code aren't necessarily the same abstraction — wait for a third occurrence, or a clear shared invariant, before extracting a shared helper; premature abstraction is as costly as duplication.
- **Comments explain why, not what**: the code already says what it does; a comment earns its place by explaining a non-obvious reason (a workaround for a specific bug, a business rule that isn't derivable from the code alone).

## Common pitfalls

- Returning `null`/`None` to mean "not found," "invalid," and "not yet computed" all in the same function — callers can't distinguish the cases; use a typed result or `Optional`/`Option` with a documented meaning.
- Validating on the frontend only, trusting the backend never receives malformed input directly.
- Catching a broad exception type to "handle errors" in one place, masking which specific failure occurred.
- Deeply nested `if/else` pyramids instead of guard clauses or early returns.
- Mutating a shared/cached object because "it's faster," without measuring whether the mutation is actually on a hot path.
