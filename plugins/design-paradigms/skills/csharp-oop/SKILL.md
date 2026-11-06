---
name: csharp-oop
description: Modern object-oriented architecture for C# and .NET — SOLID principles, constructor injection with the .NET service collection, records as value objects, exception hierarchies, and layered/hexagonal architecture. Use whenever writing, reviewing, or refactoring C# code, designing class hierarchies, choosing between inheritance and composition, structuring a service layer, or the user mentions .NET, ASP.NET Core, EF Core, or design patterns on the CLR.
---

# C# Object-Oriented Architecture

Apply the principles first; the class-design sections show how they look in idiomatic modern C#.

## Core principles (apply in this order)

1. **Composition over inheritance.** Reach for inheritance only for genuine "is-a" relationships with stable contracts (e.g., `Shape -> Circle`). Everything else — sharing behavior, reusing code, varying policy — should be composed via interfaces and injected collaborators.
2. **Program to interfaces, not implementations.** Every class that has more than one reasonable implementation, or that crosses a module boundary, should be exposed as an interface. Concrete classes stay package/internal-private where possible.
3. **SOLID as a checklist, not dogma:**
   - **S**ingle Responsibility — a class has one reason to change. If you describe a class with "and", split it.
   - **O**pen/Closed — extend behavior via new classes/strategies, not by editing existing branching logic.
   - **L**iskov Substitution — a subtype must be usable anywhere the base type is expected without weakening postconditions or strengthening preconditions.
   - **I**nterface Segregation — many small, role-specific interfaces beat one fat interface.
   - **D**ependency Inversion — high-level modules depend on abstractions owned by the high-level module, not on low-level details.
4. **Immutability by default.** Favor immutable value objects; mutate only where performance or genuine state-machine semantics require it.
5. **Fail fast, fail typed.** Validate at construction time so invalid objects cannot exist.

## Value objects: records (C# 9+)

Use records for anything that represents data rather than behavior. Validate in the constructor and return modified copies with `with`.

```csharp
// C#
public sealed record Money(decimal Amount, string Currency)
{
    public Money
    {
        if (Amount < 0) throw new ArgumentOutOfRangeException(nameof(Amount));
    }

    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException("Currency mismatch");
        return this with { Amount = Amount + other.Amount };
    }
}
```

## Dependency injection: constructor injection only

Property injection hides required dependencies and permits partially-constructed objects. Constructor injection makes every dependency explicit and lets the compiler enforce completeness.

```csharp
public sealed class OrderService : IOrderService
{
    private readonly IOrderRepository _repository;
    private readonly IPaymentGateway _paymentGateway;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repository, IPaymentGateway paymentGateway, ILogger<OrderService> logger)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _paymentGateway = paymentGateway ?? throw new ArgumentNullException(nameof(paymentGateway));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<OrderResult> PlaceAsync(OrderRequest request, CancellationToken ct)
    {
        var order = Order.Create(request);          // domain invariants enforced in the factory
        var charge = await _paymentGateway.ChargeAsync(order.Total, ct);
        if (!charge.Succeeded) return OrderResult.Failed(charge.Reason);
        await _repository.SaveAsync(order, ct);
        return OrderResult.Success(order.Id);
    }
}
```

Wire concrete implementations in `Program.cs` via the service collection (`builder.Services.AddScoped<IOrderService, OrderService>()`). Nothing else should call `new` on a cross-cutting dependency.

## Exception hierarchies

A small root exception per bounded context with a machine-readable code; map it to a `ProblemDetails` response in one global exception handler (`IExceptionHandler` / exception middleware), the one place that catches broadly.

```csharp
public class DomainException(string errorCode, string message) : Exception(message)
{
    public string ErrorCode { get; } = errorCode;
}

public sealed class InsufficientInventoryException(string sku)
    : DomainException("INSUFFICIENT_INVENTORY", $"No stock for SKU {sku}");
```

## Layered / hexagonal architecture

Default to a ports-and-adapters shape for anything beyond a toy service:

```
api/            controllers, request/response DTOs — no business logic
application/    use cases / services — orchestrate domain + ports
domain/         entities, value objects, domain services — no framework imports
infrastructure/ repository implementations, external API clients, messaging
```

Rule: `domain/` never imports from `infrastructure/` or a framework package (no `DbContext` in domain types unless you've deliberately chosen an anemic/ORM-first model). Dependencies point inward. This keeps the domain testable without spinning up a database or web server.

## Patterns worth defaulting to

| Situation | Pattern |
|---|---|
| Multiple interchangeable algorithms | Strategy (inject the interface, don't `switch` on an enum) |
| Building complex objects with optional parts | Builder, or object initializers and `with` expressions on records |
| Wrapping a third-party API to match your domain's interface | Adapter |
| Observing domain events without coupling emitter to consumer | Domain events + in-process or message-bus event handlers |
| Cross-cutting concerns (logging, retries, caching) | Decorator, or middleware (ASP.NET Core) |

Avoid: deep inheritance chains (>2 levels), static/singleton service locators, and the "manager"/"helper" class that accumulates unrelated methods.

## Common pitfalls

- Nullable reference types disabled, or `!` used to silence warnings instead of handling the null case.
- Exposing EF Core entities directly from an API controller — map to records at the boundary.
- `async void` outside event handlers, and `.Result`/`.Wait()` on tasks, which deadlock or hide exceptions.
- Anemic domain model with a "God service" holding all logic — push behavior onto the entities that own the data.
- Mutable public fields — always private state with intent-revealing methods.
- Interfaces with a single implementation and no plausible second one — don't abstract prematurely; introduce the interface when a second implementation or a test double is actually needed.

## Testing implications

OOP done this way is what makes unit testing tractable: constructor-injected interfaces are trivially mockable, immutable value objects need no reset between tests, and domain logic with no framework dependency runs without a ASP.NET context. See the `testing-practices` skill for framework-level guidance (xUnit/Moq).
