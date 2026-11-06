---
name: rust-structural
description: Modern structural and procedural Rust design — ownership and borrowing, traits instead of inheritance, static vs. dynamic dispatch, Result/Option error handling with thiserror/anyhow, and module layout. Use whenever writing, reviewing, or architecting Rust code, designing structs and traits, working through the borrow checker, or the user mentions Rust ownership, lifetimes, or traits.
---

# Rust Structural & Procedural Design

Rust rejects classical inheritance in favor of composition and pushes error handling into the type system rather than exceptions.

## Core principles

1. **No inheritance — compose types and satisfy small traits.**
2. **Errors are values, not exceptions.** Every fallible operation returns its failure explicitly; there is no `try/catch` control flow to reason about.
3. **Small traits defined by the consumer, not the producer.**
4. **Explicit over implicit.** No hidden allocations, no hidden control flow, no magic.

Layering: domain types and business rules with no I/O at the center, use-case orchestration around them, concrete adapters (database, HTTP clients) at the edge, and a `main.rs` that only wires things together.

## Ownership and borrowing

Ownership rules replace both garbage collection and a large class of concurrency bugs with compile-time checks:

- Each value has exactly one owner; when the owner goes out of scope, the value is dropped.
- You may have either one mutable borrow (`&mut T`) or any number of immutable borrows (`&T`) at a time, never both.
- Move semantics are the default for non-`Copy` types — passing a `String` by value transfers ownership; the original binding becomes invalid.

```rust
struct Order {
    id: String,
    items: Vec<String>,
    total_cents: u64,
}

impl Order {
    fn new(id: String, items: Vec<String>, total_cents: u64) -> Self {
        Self { id, items, total_cents }
    }

    // Borrows immutably — caller keeps ownership.
    fn total(&self) -> u64 {
        self.total_cents
    }

    // Borrows mutably — exclusive access enforced by the compiler.
    fn add_item(&mut self, item: String, price_cents: u64) {
        self.items.push(item);
        self.total_cents += price_cents;
    }
}
```

## Traits instead of interfaces/inheritance

```rust
trait Notifier {
    fn notify(&self, user_id: &str, message: &str) -> Result<(), NotifyError>;
}

struct OrderService<N: Notifier> {
    notifier: N,
}

impl<N: Notifier> OrderService<N> {
    fn place(&self, req: OrderRequest) -> Result<Order, OrderError> {
        let order = Order::try_from(req).map_err(OrderError::Invalid)?;
        self.notifier
            .notify(&order.id, "order placed")
            .map_err(OrderError::Notification)?;
        Ok(order)
    }
}
```

Prefer generic trait bounds (`fn f<T: Trait>`) for zero-cost static dispatch in hot paths; use `Box<dyn Trait>` only when you genuinely need runtime polymorphism (heterogeneous collections, plugin-style dispatch).

## Error handling

- `Result<T, E>` for anything fallible; `Option<T>` for anything absent-but-not-erroneous. Never `.unwrap()`/`.expect()` outside tests, prototypes, or truly invariant-guaranteed cases — each one is a potential panic in production.
- Define an error enum per module with `thiserror` for library code; use `anyhow` at application boundaries where you don't need callers to match on variants.

```rust
#[derive(thiserror::Error, Debug)]
enum OrderError {
    #[error("invalid order: {0}")]
    Invalid(String),
    #[error("notification failed: {0}")]
    Notification(#[from] NotifyError),
}
```

- Use `?` to propagate errors instead of manual `match` chains at every call site.

## Module layout

```
src/
  domain/       core types and business rules, no I/O
  service/      use-case orchestration
  infra/        concrete adapters (DB, HTTP clients)
  main.rs       wiring only
```

## Common pitfalls

- Excessive `.clone()` to silence the borrow checker instead of restructuring ownership.
- `unsafe` blocks used to avoid understanding a lifetime issue rather than for a genuine, documented invariant.
- Large `match` on error kinds via string comparison instead of typed variants.
- Reaching for a trait before there is a second real implementation or a test double that needs one.
- Swallowing an error value instead of returning or handling it — the type system makes failures visible only if you don't discard them.
