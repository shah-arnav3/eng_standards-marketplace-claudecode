# C#: records, injection, exceptions

Assumes the shared principles in `../SKILL.md`.

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

## Pitfalls

- Nullable reference types disabled, or `!` used to silence warnings instead of handling the null case.
- Exposing EF Core entities directly from an API controller — map to records at the boundary.
- `async void` outside event handlers, and `.Result`/`.Wait()` on tasks, which deadlock or hide exceptions.
