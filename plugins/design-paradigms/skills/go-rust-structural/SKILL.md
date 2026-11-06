---
name: go-rust-structural
description: Modern structural and procedural design in Go and Rust — composition via interfaces/traits, ownership and borrowing, error handling without exceptions, zero-cost abstractions, and package/module layout. Use whenever writing, reviewing, or architecting Go or Rust code, designing structs/traits, working through the borrow checker, or the user mentions Go interfaces, Rust ownership, or systems-level design. Read the matching reference file (go.md or rust.md) for language-specific idioms.
---

# Go / Rust Structural & Procedural Design

Both languages reject classical inheritance in favor of composition, and both push error handling into the type system rather than exceptions. Treat these as one family with two dialects: apply the shared principles below, then load the reference file for the language in play.

## Core principles

1. **No inheritance — compose structs/types and satisfy small interfaces/traits.**
2. **Errors are values, not exceptions.** Every fallible operation returns its failure explicitly; there is no `try/catch` control flow to reason about.
3. **Small interfaces/traits defined by the consumer, not the producer.** ("Accept interfaces, return structs" in Go.)
4. **Explicit over implicit.** No hidden allocations, no hidden control flow, no magic.

## Layering

Both languages use the same shape: domain types and business rules with no I/O at the center, use-case orchestration around them, concrete adapters (database, HTTP clients) at the edge, and an entry point that only wires things together. The reference files give each language's directory convention.

## Reference files — read the one relevant to the task

- `references/go.md` — consumer-defined interfaces, error wrapping with `%w`, `cmd/`/`internal/` package layout
- `references/rust.md` — ownership and borrowing, trait bounds vs. `dyn`, `thiserror`/`anyhow`, module layout

Load only the language the task involves; each file is self-contained and assumes the principles above.

## Common pitfalls (both languages)

- Reaching for a trait/interface before there is a second real implementation or a test double that needs one.
- Swallowing an error value instead of returning or handling it — the type system makes failures visible only if you don't discard them.
