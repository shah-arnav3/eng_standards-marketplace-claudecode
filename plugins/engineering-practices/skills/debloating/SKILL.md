---
name: debloating
description: Finding and safely removing bloat — dead code, unused dependencies, speculative abstraction, stale feature flags, and oversized build artifacts — with evidence before every deletion. Use whenever the user asks to clean up, simplify, slim down, or remove dead or unused code or dependencies, reduce bundle/image size, or retire a feature flag. Not for adding features; see `scoped-changes` for keeping new changes small.
---

# Debloating

Bloat is code, dependencies, and abstractions that cost maintenance, build time, attack surface, or load time without delivering behavior anyone uses. Removing it is high-value but risky: "unused" is a claim that needs evidence, because reflection, config files, and external callers don't show up in a grep.

## Rule: evidence before deletion

For each candidate, establish why it's safe before removing it:

1. **Static evidence** — no references found by the language's tooling (not just text search): the compiler, type checker, or a dead-code analyzer.
2. **Dynamic-reference check** — search for the name as a string: reflection, DI container registration, routing tables, serialization, templates, config files, CLI entry points, cron definitions.
3. **Runtime evidence** for anything externally reachable (public endpoints, exported library APIs, message handlers): traffic/usage metrics showing zero calls over a representative period (see `observability`). No telemetry means the deletion is unproven, not that the code is unused.
4. **Tests still pass**, and the deleted code's tests are removed alongside it, not left behind or skipped.

Something exported from a published library is never "unused" based on your own repo: deprecate it, then remove it in a major version.

## Finding candidates — tools by ecosystem

| Kind | Tools |
|---|---|
| Unused code/exports | TypeScript/JS: `knip`, `ts-prune`; Python: `vulture`; Go: `staticcheck` (U1000), `deadcode`; Rust: compiler `dead_code` lint, `cargo udeps`; Java/C#: IDE inspections, `-Xlint`, Roslyn IDE0051/IDE0052 |
| Unused dependencies | `depcheck`/`knip` (npm), `deptry` (Python), `go mod tidy`, `cargo udeps`/`cargo machete`, Maven `dependency:analyze` |
| Bundle and image size | `source-map-explorer`, `webpack-bundle-analyzer`, `vite-bundle-visualizer`; `dive` for container image layers |
| Stale feature flags | Flag platform's "last evaluated"/"100% rolled out" reports; grep for the flag key |

Treat tool output as a candidate list, not a verdict. Every tool here has false positives for dynamic usage.

## What to remove, and how

- **Dead code**: delete it outright. Don't comment it out or move it to a `legacy/` folder; version control is the archive.
- **Unused dependencies**: remove them from the manifest, regenerate the lockfile, and run a clean build. Also check for a heavy dependency that's used for one function the standard library already provides (`lodash` for `Array.prototype.flat`, `moment` for `Intl.DateTimeFormat`) — replacing it shrinks attack surface as well as size (see `dependency-audit`).
- **Speculative abstraction**: interfaces with one implementation and no test double, factories that build one type, config options nobody sets, extension points nobody extends. Inline them back into the concrete code. Re-introduce the abstraction when the second real use appears.
- **Stale feature flags**: once a flag has served one value everywhere for a full release cycle, delete the losing branch and the flag check together, then delete the flag in the flag service. A flag left at 100% is a permanent untested code path.
- **Oversized artifacts**: multi-stage builds and a minimal base image for containers (see `system-security`); tree-shakeable ES-module imports, route-level code splitting, and dropping unused polyfills for frontend bundles.

## Process

1. Measure first: line count, dependency count, bundle/image size, build time. Without a baseline you can't show the cleanup helped.
2. Remove in small, single-kind commits ("remove unused deps", "delete dead export X"), each independently revertible (see `git-workflows`). Don't mix debloating with feature or behavior changes.
3. For externally reachable code with weak telemetry, add a usage log or metric first, ship it, and decide after the observation window.
4. Measure again and record the delta in the PR description.

## Common pitfalls

- Deleting a "dead" handler that's wired up by name in config, reflection, or a framework convention, then discovering it in production.
- Removing a dependency the code doesn't import but the runtime needs (database driver, plugin, peer dependency, type package).
- A cleanup PR mixed with a refactor, so a regression can't be traced to either.
- Replacing a small, well-tested dependency with hand-rolled code that reimplements it with fewer edge cases handled.
- Treating lines-of-code reduction as the goal; the goal is less to maintain, build, ship, and secure.
