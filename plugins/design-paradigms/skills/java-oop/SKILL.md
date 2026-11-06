---
name: java-oop
description: Modern object-oriented architecture for Java — SOLID principles, Spring constructor injection, records as value objects, exception hierarchies, and layered/hexagonal architecture. Use whenever writing, reviewing, or refactoring Java code, designing class hierarchies, choosing between inheritance and composition, structuring a service layer, or the user mentions Spring, Spring Boot, JPA, or design patterns on the JVM.
---

# Java Object-Oriented Architecture

Apply the principles first; the class-design sections show how they look in idiomatic modern Java.

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

## Layered / hexagonal architecture

Default to a ports-and-adapters shape for anything beyond a toy service:

```
api/            controllers, request/response DTOs — no business logic
application/    use cases / services — orchestrate domain + ports
domain/         entities, value objects, domain services — no framework imports
infrastructure/ repository implementations, external API clients, messaging
```

Rule: `domain/` never imports from `infrastructure/` or a framework package (no `@Entity` in domain types unless you've deliberately chosen an anemic/ORM-first model). Dependencies point inward. This keeps the domain testable without spinning up a database or web server.

## Patterns worth defaulting to

| Situation | Pattern |
|---|---|
| Multiple interchangeable algorithms | Strategy (inject the interface, don't `switch` on an enum) |
| Building complex objects with optional parts | Builder, or `with`-style copy methods on records |
| Wrapping a third-party API to match your domain's interface | Adapter |
| Observing domain events without coupling emitter to consumer | Domain events + in-process or message-bus event handlers |
| Cross-cutting concerns (logging, retries, caching) | Decorator, or interceptors (Spring AOP) |

Avoid: deep inheritance chains (>2 levels), static/singleton service locators, and the "manager"/"helper" class that accumulates unrelated methods.

## Common pitfalls

- Returning `null` instead of `Optional<T>` for a value that may be absent (but don't use `Optional` for fields or parameters).
- Exposing JPA `@Entity` classes directly from a REST controller — map to records at the boundary.
- Checked exceptions declared for business-rule failures callers can't recover from, forcing `throws` clauses through every layer.
- Anemic domain model with a "God service" holding all logic — push behavior onto the entities that own the data.
- Mutable public fields — always private state with intent-revealing methods.
- Interfaces with a single implementation and no plausible second one — don't abstract prematurely; introduce the interface when a second implementation or a test double is actually needed.

## Testing implications

OOP done this way is what makes unit testing tractable: constructor-injected interfaces are trivially mockable, immutable value objects need no reset between tests, and domain logic with no framework dependency runs without a Spring context. See the `testing-practices` skill for framework-level guidance (JUnit 5/Mockito).
