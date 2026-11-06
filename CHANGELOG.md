# Changelog

Versions are per plugin. The marketplace `metadata.version` tracks the latest release.

## 2026-11-06

### agent-team 1.1.0
- Added the `ship` skill (`/agent-team:ship`), which runs the pipeline from the main
  session with file-based handoffs under `.agent-team/<feature>/`, a design approval gate,
  and a three-round limit on review and CI fix loops.
- Added a `PreToolUse` hook that forces a permission prompt before deploy, rollback, and
  infrastructure-mutating commands.
- Agents now return their output to the caller instead of handing off to other agents
  directly, which subagents cannot do.
- DevOps requires explicit approval before each deploy. SRE/Monitoring is read-only and
  recommends rollbacks instead of triggering them.

### design-paradigms 1.1.0
- Added `api-design`.
- Replaced `go-rust-structural` with `go-structural` and `rust-structural`, and
  `java-csharp-oop` with `java-oop` and `csharp-oop`, so each language triggers and
  loads on its own.

### engineering-practices 1.1.0
- Added `observability` and `debloating`.
- `git-workflows` now forbids AI co-author trailers and "Generated with" markers in
  commits and PRs, with the Claude Code settings and a `commit-msg` hook that enforce it.

### Marketplace
- Removed `strict: false` and the explicit skill/agent lists from plugin manifests;
  components are auto-discovered.
- README install command now points at the GitHub repository.
- Added CI that validates every manifest, skill, and agent, and tests the deploy hook.

## 2026-09-28 — 1.0.0
- Initial release: design-paradigms, engineering-practices, security-scanning, agent-team.
