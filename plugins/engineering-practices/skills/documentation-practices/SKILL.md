---
name: documentation-practices
description: Modern documentation style and practices — docstrings/doc comments, README structure, API documentation, and inline comment discipline. Use whenever writing or reviewing documentation, docstrings, README files, API docs, or the user mentions documenting a project or function.
---

# Documentation Style and Practices

Documentation exists to answer a question someone will have without needing to read the entire implementation or ask the original author. Write for that reader, not as a formality.

Document the system as it is now. Do not narrate its history: no commentary on past bugs that were fixed, past issues that were resolved, or the reasoning behind a decision that was made along the way. That history belongs in commit messages and pull request descriptions, not in docstrings, comments, READMEs, or API docs — a reader trying to understand current behavior shouldn't have to wade through a changelog of what used to be wrong or why an earlier choice was made.

## Docstrings / doc comments

Document the *contract*: what it does, its parameters, return value, and the failure modes a caller must handle — not a restatement of the function name in sentence form.

```python
def apply_discount(order: Order, percent: float) -> Order:
    """Return a new Order with total_cents reduced by the given percentage.

    Args:
        order: The order to discount. Not mutated.
        percent: Discount fraction in [0, 1). Values outside this range raise ValueError.

    Returns:
        A new Order instance with the discounted total. The original is unchanged.

    Raises:
        ValueError: If percent is not in [0, 1).
    """
```

```java
/**
 * Charges the customer's default payment method for the given order total.
 *
 * @param order the order to charge; must have a non-zero total
 * @return the result of the charge attempt, including a decline reason if unsuccessful
 * @throws PaymentGatewayUnavailableException if the gateway cannot be reached after retries
 */
ChargeResult charge(Order order) throws PaymentGatewayUnavailableException;
```

```typescript
/**
 * Debounces a value, only propagating the latest value after `delayMs`
 * of no further changes.
 *
 * @param value - the live value to debounce
 * @param delayMs - quiet period required before the debounced value updates
 * @returns the debounced value, lagging `value` by up to `delayMs`
 */
function useDebouncedValue<T>(value: T, delayMs: number): T
```

Skip docstrings on trivial private helpers whose name and body are self-evident; require them on every public/exported function, every function with non-obvious side effects, and every function whose failure modes aren't visible from the signature alone.

## Inline comments: why, not what

- A comment restating the next line in English ("increment counter") is noise — delete it.
- A comment earns its place by explaining something the code can't say for itself: a business rule or a non-obvious constraint that shapes the logic below it.

```go
// Retry with jitter to avoid a thundering herd against the payment
// gateway when many requests fail simultaneously during an outage.
delay := baseDelay + time.Duration(rand.Int63n(int64(baseDelay)))
```

## README structure for a project/service

A README should let a new engineer get from zero to a running local instance without asking anyone a question. Minimum sections:

1. **What this is** — one paragraph, plain language, no jargon a new hire wouldn't know yet.
2. **Prerequisites** — exact tool versions, not "recent version of X."
3. **Setup** — copy-pasteable commands, in order, that work on a clean checkout.
4. **Running it** — how to start it locally, how to run the test suite.
5. **Architecture** — a short overview or a pointer to `/docs/architecture.md` for anything beyond a single-file script.
6. **Where things live** — a one-line map of the top-level directories if the layout isn't self-evident.

## API documentation

- Generate from source annotations (OpenAPI/Swagger from code annotations, or a schema-first contract) rather than hand-maintaining a separate document that drifts from the implementation.
- Document error responses with the same rigor as success responses — status codes, error body shape, and what a client should do about each one.
- Include a runnable example request/response for every endpoint, not just a schema — schemas alone leave ambiguity about realistic values.

## Common pitfalls

- Documentation that duplicates the code ("this function adds two numbers") instead of documenting intent, constraints, and failure modes.
- A README that's accurate for the state of the project six months ago — treat doc updates as part of the same PR as the code change that invalidates them, not a follow-up task that never happens.
- API docs hand-written separately from the actual request/response schema, drifting out of sync silently.
- Comments left in place after the code they describe has changed, now actively misleading.
- Commentary on past bugs, past issues, or the history behind a decision left in docstrings, comments, or READMEs — belongs in commit/PR history, not in documentation describing current behavior.
