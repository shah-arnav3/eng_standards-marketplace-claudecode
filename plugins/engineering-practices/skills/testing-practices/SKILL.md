---
name: testing-practices
description: Modern testing procedures and practices — the test pyramid, unit vs. integration vs. e2e boundaries, test doubles (mocks/stubs/fakes), test-driven workflows, coverage as a signal not a target, and framework patterns (JUnit/xUnit/pytest/Jest/Go testing/Rust built-in). Use whenever writing tests, reviewing test quality, designing a test strategy, or the user mentions unit tests, mocking, TDD, or test coverage.
---

# Testing Procedures and Practices

Tests are a design tool as much as a safety net: code that's hard to test is usually code with a design problem (hidden dependencies, mixed concerns, unclear boundaries).

## The test pyramid — proportion, not exclusion

```
        /  E2E  \        few — slow, brittle, high confidence in real user flows
       /----------\
      / Integration \    some — verify components work together (DB, HTTP, queues)
     /----------------\
    /   Unit Tests      \  many — fast, isolated, verify logic in isolation
   /______________________\
```

Most bugs should be caught by unit tests because they run in milliseconds and can cover every branch cheaply. Integration tests verify the seams (does this repository actually work against a real database). E2E tests verify a handful of critical user journeys end-to-end — not every edge case, which belongs at a lower level.

## What makes a good unit test

- **Fast** — milliseconds, no network/disk/sleep.
- **Isolated** — no shared mutable state between tests, no dependency on test execution order.
- **Deterministic** — no reliance on wall-clock time, randomness, or external services without controlling them explicitly.
- **One logical assertion focus per test** — a test name should describe one behavior; if you need "and" to describe it, split it.
- **Arrange-Act-Assert structure**, clearly separated.

```python
# pytest
def test_apply_discount_reduces_total_by_percentage():
    # Arrange
    order = Order(id=1, items=("widget",), total_cents=10_000)

    # Act
    discounted = apply_discount(order, percent=0.1)

    # Assert
    assert discounted.total_cents == 9_000
```

```java
// JUnit 5 + Mockito
@Test
void placeOrder_chargesPaymentGatewayForOrderTotal() {
    var repository = mock(OrderRepository.class);
    var gateway = mock(PaymentGateway.class);
    when(gateway.charge(any())).thenReturn(ChargeResult.success());
    var service = new OrderService(repository, gateway);

    service.place(new OrderRequest("sku-1", 2));

    verify(gateway).charge(argThat(amount -> amount.equals(new Money(BigDecimal.valueOf(20), USD))));
}
```

## Test doubles — pick the right one

| Double | Use for |
|---|---|
| **Stub** | Returns canned data; used when the collaborator's output matters, not the interaction |
| **Mock** | Verifies a specific interaction happened (a method was called with certain args) — use sparingly, only when the interaction itself is the behavior under test |
| **Fake** | A lightweight working implementation (in-memory repository instead of a real DB) — often better than a mock for testing code that reads back what it wrote |
| **Spy** | Wraps a real object and records calls while delegating — useful for partial verification without fully replacing behavior |

Over-mocking is the most common testing anti-pattern: a test that mocks every collaborator's every method call becomes a change-detector for implementation details rather than a check on behavior. Prefer fakes for anything with meaningful internal behavior (a repository, a cache).

## TDD workflow (when using it)

1. **Red** — write a failing test that expresses the next small piece of desired behavior.
2. **Green** — write the minimum code to pass it, no more.
3. **Refactor** — clean up duplication/structure with the safety net of the passing test, without changing behavior.

TDD is a design technique, not a mandate for every line of code — apply it where the behavior is well-understood enough to specify up front (business logic, algorithms); exploratory/spike code can be tested after the shape stabilizes.

## Integration and contract tests

- Integration tests should hit a real (containerized, ephemeral) instance of the dependency — Testcontainers for a real Postgres/Kafka in CI, not a hand-rolled in-memory substitute that can drift from real behavior.
- For service-to-service boundaries, use contract tests (Pact or equivalent) so a provider can't break a consumer without the break showing up in CI on either side.

```javascript
// Jest + Testcontainers-style integration test
test("repository persists and retrieves an order", async () => {
  const repo = new PostgresOrderRepository(testDbPool);
  const order = { id: "o1", total: 4200 };

  await repo.save(order);
  const found = await repo.findById("o1");

  expect(found).toEqual(order);
});
```

## Coverage: a diagnostic signal, not a target

- Coverage percentage tells you what's *never executed* by tests, not what's *correctly tested*. 100% coverage with weak assertions gives false confidence.
- Use coverage reports to find untested branches (especially error paths), not as a gate to hit an arbitrary number by writing low-value tests.
- Prioritize coverage of business logic and error handling over generated code, simple getters/setters, or framework glue.

## Framework quick reference

- **Java**: JUnit 5 + Mockito/AssertJ; `@ParameterizedTest` for table-driven cases.
- **C#**: xUnit or NUnit + Moq/NSubstitute; `[Theory]`/`[InlineData]` for parameterized cases.
- **Python**: pytest, with `pytest.mark.parametrize`, fixtures for setup/teardown, `unittest.mock` or `pytest-mock` for doubles.
- **Node/TypeScript**: Jest or Vitest; `describe`/`it` blocks named as behavior sentences, not method names.
- **Go**: built-in `testing` package, table-driven tests as the idiomatic pattern (`for _, tc := range cases`), `testify` for assertions if the team prefers them.
- **Rust**: built-in `#[test]` + `#[cfg(test)] mod tests`, `assert_eq!`/`assert!`; integration tests in `tests/` compiled as separate crates.

## Common pitfalls

- Tests that assert on implementation details (private method calls, internal field values) instead of observable behavior — they break on every refactor even when behavior is unchanged.
- Shared mutable fixtures across tests causing order-dependent failures.
- Sleeping (`Thread.sleep`, `time.sleep`) to "wait" for async behavior instead of polling/awaiting a condition — flaky and slow.
- Testing a mock's behavior instead of the system under test's behavior (asserting the mock was configured correctly, not that the code responded correctly).
- No tests for error paths — only the happy path is covered, and the exception handling is the part that actually breaks in production.
