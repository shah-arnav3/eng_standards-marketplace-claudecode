# Java: records, injection, exceptions

Assumes the shared principles in `../SKILL.md`.

## Value objects: records (Java 16+)

Use records for anything that represents data rather than behavior. Validate in the compact constructor so an invalid instance cannot exist.

```java
// Java
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        if (amount.scale() > currency.getDefaultFractionDigits()) {
            throw new IllegalArgumentException("Too many decimal places for " + currency);
        }
    }
    public Money add(Money other) {
        requireSameCurrency(other);
        return new Money(amount.add(other.amount), currency);
    }
    private void requireSameCurrency(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("Currency mismatch");
        }
    }
}
```

## Dependency injection: constructor injection only

Field injection (`@Autowired` on a field) hides required dependencies and permits partially-constructed objects. With a single constructor, Spring injects it without any annotation.

```java
@Service
public final class OrderService {
    private final OrderRepository repository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository repository, PaymentGateway paymentGateway) {
        this.repository = Objects.requireNonNull(repository);
        this.paymentGateway = Objects.requireNonNull(paymentGateway);
    }

    public OrderResult place(OrderRequest request) {
        Order order = Order.create(request);          // domain invariants enforced in the factory
        ChargeResult charge = paymentGateway.charge(order.total());
        if (!charge.succeeded()) return OrderResult.failed(charge.reason());
        repository.save(order);
        return OrderResult.success(order.id());
    }
}
```

Wire concrete implementations in `@Configuration` classes at the composition root. Nothing else should call `new` on a cross-cutting dependency.

## Exception hierarchies

Unchecked exceptions rooted per bounded context, carrying a machine-readable code; map them to responses in a `@ControllerAdvice`, the one place that catches broadly.

```java
public class DomainException extends RuntimeException {
    private final String errorCode;
    public DomainException(String errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }
    public String errorCode() { return errorCode; }
}

public class InsufficientInventoryException extends DomainException {
    public InsufficientInventoryException(String sku) {
        super("INSUFFICIENT_INVENTORY", "No stock for SKU " + sku);
    }
}
```

## Pitfalls

- Returning `null` instead of `Optional<T>` for a value that may be absent (but don't use `Optional` for fields or parameters).
- Exposing JPA `@Entity` classes directly from a REST controller — map to records at the boundary.
- Checked exceptions declared for business-rule failures callers can't recover from, forcing `throws` clauses through every layer.
