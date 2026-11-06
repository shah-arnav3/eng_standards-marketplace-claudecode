---
name: java-csharp-oop
description: Modern object-oriented architecture for Java and C# — SOLID principles, dependency injection, interface design, records/value objects, exception hierarchies, and layered architecture. Use whenever writing, reviewing, or refactoring Java or C# code, designing class hierarchies, choosing between inheritance and composition, structuring a service layer, or when the user mentions Spring, .NET, ASP.NET Core, enterprise architecture, or design patterns in a JVM/CLR context. Read the matching reference file (java.md or csharp.md) for language-specific idioms.
---

# Java / C# Object-Oriented Architecture

Modern JVM and CLR codebases converge on the same architectural defaults. Apply the shared principles below regardless of language, then load the reference file for the language in play.

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

## Shared class-design rules

- **Value objects are records**, validated at construction. Both languages have first-class records (Java 16+, C# 9+).
- **Constructor injection only.** Field/setter/property injection hides required dependencies and permits partially-constructed objects. Wire concrete implementations at the composition root only.
- **Exception hierarchies stay small:**
  - Define a small root exception per bounded context (`OrderDomainException`, `PaymentException`), not one exception per failure mode.
  - Distinguish **recoverable** (business-rule violations — expected, caught and mapped to a response) from **unrecoverable** (bugs, infra failures — logged, allowed to propagate to a global handler).
  - Never catch `Exception`/`System.Exception` except at a process boundary (controller advice, global exception filter). Catching broadly elsewhere swallows bugs.
  - Attach structured context (order id, correlation id) to exceptions instead of only a message string.

## Reference files — read the one relevant to the task

- `references/java.md` — records, Spring constructor injection, exception hierarchy with `@ControllerAdvice`
- `references/csharp.md` — records with `with`, .NET DI in `Program.cs`, exception hierarchy with `ProblemDetails`

Load only the language the task involves; each file is self-contained and assumes the principles above.

## Layered / hexagonal architecture

Default to a ports-and-adapters shape for anything beyond a toy service:

```
api/            controllers, request/response DTOs — no business logic
application/    use cases / services — orchestrate domain + ports
domain/         entities, value objects, domain services — no framework imports
infrastructure/ repository implementations, external API clients, messaging
```

Rule: `domain/` never imports from `infrastructure/` or a framework package (no `@Entity`, no `DbContext` in domain types unless you've deliberately chosen an anemic/ORM-first model). Dependencies point inward. This keeps the domain testable without spinning up a database or web server.

## Patterns worth defaulting to

| Situation | Pattern |
|---|---|
| Multiple interchangeable algorithms | Strategy (inject the interface, don't `switch` on an enum) |
| Building complex objects with optional parts | Builder (or C# object initializers / Java `with`-style records) |
| Wrapping a third-party API to match your domain's interface | Adapter |
| Observing domain events without coupling emitter to consumer | Domain events + in-process or message-bus event handlers |
| Cross-cutting concerns (logging, retries, caching) | Decorator, or interceptors/middleware (Spring AOP, ASP.NET Core middleware) |

Avoid: deep inheritance chains (>2 levels), static/singleton service locators, and the "manager"/"helper" class that accumulates unrelated methods.

## Common pitfalls

- Exposing persistence entities (JPA/EF Core) directly from an API — map to DTOs/records at the boundary.
- Anemic domain model with a "God service" holding all logic — push behavior onto the entities that own the data.
- Mutable public fields — always private state with intent-revealing methods.
- Interfaces with a single implementation and no plausible second one — don't abstract prematurely; introduce the interface when a second implementation or a test double is actually needed.

## Testing implications

OOP done this way is what makes unit testing tractable: constructor-injected interfaces are trivially mockable, immutable value objects need no reset between tests, and domain logic with no framework dependency runs without a Spring/ASP.NET context. See the `testing-practices` skill for framework-level guidance (JUnit5/Mockito, xUnit/Moq).
