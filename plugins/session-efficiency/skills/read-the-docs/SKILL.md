---
name: read-the-docs
description: Docs-first discipline — reading current, authoritative documentation (local specs, official references, migration guides, SDK types) before writing code or answers that depend on an external API, library, CLI, cloud service, or fast-moving product behavior, instead of relying on memory. Use when adding, upgrading, or configuring a dependency or integration; when an error suggests API drift (unknown option, missing export, deprecation, version mismatch); when the work touches auth, payments, webhooks, migrations, deploys, rate limits, or other costly-to-reverse behavior; or when the user asks for the latest, current, official, or recommended way.
---

# Read the Docs First

Memory of an API is a snapshot from training, and libraries move faster than that snapshot. When the task depends on an external contract, read the contract before writing against it. A few minutes of reading is cheaper than debugging an option that was renamed two majors ago.

## When docs are required

Read before acting when any of these hold:

- **A dependency is added, upgraded, configured, or imported**: packages, SDKs, frameworks, CLIs, plugins, cloud resources, model providers.
- **The surface is fast-moving or version-sensitive**: AI/LLM SDKs, frontend frameworks and build tools, ORMs, payment and messaging APIs, auth libraries, CI and deployment platforms, browser APIs.
- **An error points at drift**: unknown option, missing export, unsupported field, deprecation warning, changed default, version mismatch.
- **The behavior is costly to get wrong or reverse**: auth and OAuth scopes, secrets, webhooks and signature checks, billing, PII and retention, encryption, migrations and schema changes, retries and rate limits, deploys, public wire formats, persistent IDs and event names.
- **The repo defines the contract**: local docs, ADRs, OpenAPI or protobuf specs, generated clients and types, package READMEs, route or action registries.
- **The user asks for "latest", "current", "official", "supported", or "recommended"**, or says to look it up.
- **You notice yourself hedging**: "usually", "I think", "probably", "from memory". That's the signal to check, not to write it down.

## When a docs pass isn't needed

- Language syntax, standard-library basics, typo and formatting fixes, and self-contained logic with no external contract.
- The answer is already in the repo: an existing call site of the same API at the same version, nearby tests, or typed interfaces. A quick local read is the docs pass.

## Source order

Use the most authoritative source available, in this order:

1. **The repo**: specs, ADRs, generated types, tests, and existing usage. These define project-specific behavior and win for internal code.
2. **Official upstream docs** for the version actually installed: API reference, migration guides, changelogs, release notes.
3. **Installed source and type definitions** (`node_modules/<pkg>`, site-packages, `go doc`, docs.rs) when the docs are thin. These are evidence of what the installed version does.
4. **Community sources** (issue trackers, forums, blog posts) only to explain a symptom once the official contract is known. Never as the primary source when official docs exist.

## Workflow

1. **Pin the exact surface**: package and installed version (from the lockfile, not the manifest range), target version, endpoint, CLI subcommand, config key.
2. **Check versions before adding a dependency**: `npm view <pkg> version`, `pip index versions <pkg>`, `cargo search <crate>`, `go list -m -versions <module>`. Read the docs for that major version.
3. **Find the page**: if the docs aren't local or linked, search for `<product> <feature> docs`, `<package> migration guide`, or `<provider> API reference`, and fetch the specific page rather than the landing page.
4. **Extract only what the task needs**: option names, imports, defaults, lifecycle rules, limits, required permissions, breaking changes, and an example for the current major.
5. **Implement against those facts.** If the docs conflict with existing code, inspect the local code path and call out the discrepancy instead of silently picking one.
6. **Verify with the smallest real check**: typecheck, a targeted test, a build, a CLI `--dry-run`, schema validation.
7. **Cite what you relied on** in the final report when it shaped the decision: the doc page or the local file.

## In Claude Code

- **Claude Code, the Agent SDK, and the Claude API**: use the `claude-code-guide` agent or the `claude-api` skill rather than memory; these change often.
- **Broad doc research** (comparing libraries, reading several migration guides) goes to a subagent that returns only the extracted facts, so pages of docs don't land in the main context. See `token-efficiency`.
- **Fetch narrowly.** One reference page or one section beats a whole docs site.

## If docs are unavailable

When network access, auth, or missing files block the docs, say so before relying on memory. Narrow the uncertainty by reading installed source or types, mark the result as unverified against current docs, and list it under open findings in the final report.

## Common pitfalls

- Writing config for the previous major because the manifest says `^4` but the lockfile resolved to `5.x`.
- Trusting a tutorial or snippet over the official migration guide.
- Reading the docs landing page and guessing the rest.
- Reading the docs, then contradicting them because existing code does it differently, without flagging which is wrong.
- Searching the web for something the repo's own spec or generated types already answer.
