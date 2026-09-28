---
name: go-rust-structural
description: Modern structural and procedural design in Go and Rust — composition via interfaces/traits, ownership and borrowing, error handling without exceptions, zero-cost abstractions, and package/module layout. Use whenever writing, reviewing, or architecting Go or Rust code, designing structs/traits, working through the borrow checker, or the user mentions Go interfaces, Rust ownership, or systems-level design.
---

# Go / Rust Structural & Procedural Design

Both languages reject classical inheritance in favor of composition, and both push error handling into the type system rather than exceptions. Treat these as one family with two dialects.

## Core principles

1. **No inheritance — compose structs/types and satisfy small interfaces/traits.**
2. **Errors are values, not exceptions.** Every fallible operation returns its failure explicitly; there is no `try/catch` control flow to reason about.
3. **Small interfaces/traits defined by the consumer, not the producer.** ("Accept interfaces, return structs" in Go.)
4. **Explicit over implicit.** No hidden allocations, no hidden control flow, no magic.

## Go: interfaces and composition

Define interfaces where they're consumed, keep them minimal, and let concrete types satisfy them implicitly:

```go
// Defined by the consumer package, not by the struct's package.
type Notifier interface {
    Notify(ctx context.Context, userID string, message string) error
}

type OrderService struct {
    repo     OrderRepository
    notifier Notifier
}

func NewOrderService(repo OrderRepository, notifier Notifier) *OrderService {
    return &OrderService{repo: repo, notifier: notifier}
}

func (s *OrderService) Place(ctx context.Context, req OrderRequest) (Order, error) {
    order, err := NewOrder(req)
    if err != nil {
        return Order{}, fmt.Errorf("creating order: %w", err)
    }
    if err := s.repo.Save(ctx, order); err != nil {
        return Order{}, fmt.Errorf("saving order: %w", err)
    }
    if err := s.notifier.Notify(ctx, order.UserID, "order placed"); err != nil {
        // Non-critical side effect — log, don't fail the whole operation.
        slog.Error("notify failed", "error", err, "order_id", order.ID)
    }
    return order, nil
}
```

Composition over embedding-as-inheritance: embed a struct only to reuse a genuinely shared implementation (e.g., embedding `sync.Mutex`), not to simulate a class hierarchy.

### Error handling

- Wrap errors with `%w` to preserve the chain; check with `errors.Is`/`errors.As`, never string-match error messages.
- Define sentinel errors (`var ErrNotFound = errors.New("not found")`) or custom error types for cases callers need to branch on.
- Return early on error; do not nest happy-path code inside `if err == nil`.

```go
func (r *SQLOrderRepository) FindByID(ctx context.Context, id string) (Order, error) {
    row := r.db.QueryRowContext(ctx, "SELECT * FROM orders WHERE id = $1", id)
    var o Order
    if err := row.Scan(&o.ID, &o.UserID, &o.Total); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return Order{}, fmt.Errorf("order %s: %w", id, ErrNotFound)
        }
        return Order{}, fmt.Errorf("scanning order %s: %w", id, err)
    }
    return o, nil
}
```

### Package layout

```
/cmd/<binary>       main packages — wiring only, minimal logic
/internal/domain     entities, business rules — no external imports
/internal/service    use cases, orchestration
/internal/store      concrete repository implementations
/pkg/                only code intended for import by other modules
```

Keep business logic under `/internal` so it cannot be imported by other modules — Go enforces this at compile time.

## Rust: ownership, borrowing, and traits

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

### Traits instead of interfaces/inheritance

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

### Error handling

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

### Module layout

```
src/
  domain/       core types and business rules, no I/O
  service/      use-case orchestration
  infra/        concrete adapters (DB, HTTP clients)
  main.rs       wiring only
```

## Common pitfalls

- **Go**: returning `interface{}`/`any` instead of a concrete type or a small typed interface; ignoring returned errors (`_, _ = f()`); defining interfaces in the producer package with many methods "just in case."
- **Rust**: excessive `.clone()` to silence the borrow checker instead of restructuring ownership; `unsafe` blocks used to avoid understanding a lifetime issue rather than for a genuine, documented invariant; large `match` on error kinds via string comparison instead of typed variants.
- Both: reaching for a trait/interface before there is a second real implementation or a test double that needs one.
