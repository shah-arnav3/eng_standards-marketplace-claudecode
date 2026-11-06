# Go: interfaces, composition, errors, layout

Assumes the shared principles in `../SKILL.md`.

## Interfaces and composition

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

## Error handling

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

## Package layout

```
/cmd/<binary>       main packages — wiring only, minimal logic
/internal/domain     entities, business rules — no external imports
/internal/service    use cases, orchestration
/internal/store      concrete repository implementations
/pkg/                only code intended for import by other modules
```

Keep business logic under `/internal` so it cannot be imported by other modules — Go enforces this at compile time.

## Pitfalls

- Returning `interface{}`/`any` instead of a concrete type or a small typed interface.
- Ignoring returned errors (`_, _ = f()`).
- Defining interfaces in the producer package with many methods "just in case."
