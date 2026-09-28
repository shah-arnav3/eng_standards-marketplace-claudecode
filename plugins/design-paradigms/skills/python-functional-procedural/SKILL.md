---
name: python-functional-procedural
description: Modern functional and procedural Python design — pure functions, immutable data with dataclasses/NamedTuple, composition over class hierarchies, generators and iterator pipelines, type hints, and when OOP is still the right call in Python. Use whenever writing, reviewing, or refactoring Python code, designing data pipelines, choosing between a class and a function, or the user mentions Python architecture, data processing, or "pythonic" style.
---

# Python Functional / Procedural Design

Python is multi-paradigm, but idiomatic modern Python leans functional/procedural for anything that is primarily data transformation, and reserves classes for genuine stateful entities or when a framework requires them (ORM models, Pydantic schemas).

## Core principles

1. **Functions are the default unit of design.** Only reach for a class when you need to bundle state with behavior across multiple calls, or a framework contract demands it.
2. **Prefer pure functions.** Same input, same output, no hidden mutation of arguments or module-level state. Push I/O and side effects to the edges of the call graph ("functional core, imperative shell").
3. **Immutable data by default.** Use `@dataclass(frozen=True)`, `NamedTuple`, or plain tuples for data that flows through a pipeline.
4. **Type hints everywhere public.** They are the primary documentation and the cheapest bug-catcher (`mypy`/`pyright` in CI).
5. **Composition of small functions over deep call hierarchies or metaclasses.**

## Data modeling

```python
from dataclasses import dataclass
from typing import NewType

UserId = NewType("UserId", int)

@dataclass(frozen=True, slots=True)
class Order:
    id: UserId
    items: tuple[str, ...]
    total_cents: int

    def with_item(self, item: str, price_cents: int) -> "Order":
        # Immutable "update" — return a new instance instead of mutating.
        return Order(self.id, self.items + (item,), self.total_cents + price_cents)
```

Use `NamedTuple` for lightweight positional data where you don't need methods; use `frozen` dataclasses when you want named fields plus behavior. Reach for Pydantic models specifically at I/O boundaries (API request/response, config parsing) where runtime validation matters, not as a general-purpose class replacement.

## Pure functions and the functional core / imperative shell

```python
# functional core — pure, trivially testable, no I/O
def apply_discount(order: Order, percent: float) -> Order:
    discounted = round(order.total_cents * (1 - percent))
    return Order(order.id, order.items, discounted)

def eligible_for_discount(order: Order, threshold_cents: int = 5000) -> bool:
    return order.total_cents >= threshold_cents

# imperative shell — I/O, orchestration, side effects live here only
def process_order(order_id: UserId, repo: "OrderRepository") -> None:
    order = repo.fetch(order_id)
    if eligible_for_discount(order):
        order = apply_discount(order, 0.1)
    repo.save(order)
```

This split is the single highest-leverage refactor available in Python: it lets you unit test `apply_discount` and `eligible_for_discount` with zero mocks, and confines all mocking/integration testing to the thin shell.

## Iterators, generators, and pipelines

Prefer generator pipelines over building intermediate lists when processing large or streaming data:

```python
from typing import Iterator

def read_lines(path: str) -> Iterator[str]:
    with open(path) as f:
        yield from f

def parse_records(lines: Iterator[str]) -> Iterator[dict]:
    for line in lines:
        if line.strip():
            yield parse_line(line)

def active_only(records: Iterator[dict]) -> Iterator[dict]:
    return (r for r in records if r.get("status") == "active")

# Nothing executes until iterated — constant memory regardless of file size.
for record in active_only(parse_records(read_lines("data.csv"))):
    handle(record)
```

Use `itertools` (`chain`, `groupby`, `islice`) instead of hand-rolled loops with counters for common patterns.

## When a class is still correct

- **Stateful entities with identity and behavior over time**: a connection pool, a game entity, a parser with internal cursor state.
- **Framework contracts**: Django models, SQLAlchemy ORM classes, `abc.ABC` plugin interfaces where callers need polymorphism.
- **Protocols for structural typing** instead of inheritance-based interfaces:

```python
from typing import Protocol

class SupportsTotal(Protocol):
    def total_cents(self) -> int: ...

def format_total(x: SupportsTotal) -> str:
    return f"${x.total_cents() / 100:.2f}"
```

`Protocol` gives you interface-like polymorphism without forcing implementers into an inheritance hierarchy — the Pythonic middle ground between "everything is a function" and Java-style OOP.

## Error handling

- Raise specific exceptions (`class InsufficientFundsError(Exception)`), never bare `except:`.
- Use `Result`-style returns (a small `Ok`/`Err` union, or `T | None` with an explicit contract) at boundaries where failure is an expected, frequent outcome (parsing user input); reserve exceptions for truly exceptional conditions.
- Context managers (`with`) for every resource that needs guaranteed cleanup; write custom ones (`@contextmanager`) rather than manual try/finally when the same cleanup pattern repeats.

## Style and structure conventions

- Module-level functions grouped by responsibility beat one large class with many static methods.
- Keep functions under ~30 lines and single-purpose; if a function needs a comment to explain a section, that section is usually a function.
- Avoid mutable default arguments (`def f(items=[])`) — use `None` and initialize inside.
- Prefer `pathlib.Path` over string paths, `enum.Enum`/`StrEnum` over magic strings, `functools.lru_cache`/`cache` for pure-function memoization instead of hand-rolled caching dicts.

## Common pitfalls

- Turning every module into a class with only `@staticmethod`s — that's Java written in Python syntax; use plain functions and a module namespace instead.
- Mutating a list/dict passed as an argument as a side effect the caller doesn't expect.
- Deep inheritance for code reuse where a small helper function or a `Protocol` would do.
- Catching `Exception` broadly to "keep the pipeline running" — this hides real bugs; catch specific exceptions at the boundary where you can meaningfully recover.
