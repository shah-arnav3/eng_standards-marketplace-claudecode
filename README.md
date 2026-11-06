# Engineering Standards Marketplace

A Claude Code plugin marketplace covering four areas: design paradigms, cross-language
engineering practices, layered security scanning, and a seven-agent software delivery
pipeline. Every skill is written for modern coding standards, uses generalized code
examples, and is organized so Claude reads only what a given task needs.

## Install

```bash
claude plugin marketplace add shah-arnav3/eng_standards-marketplace-claudecode
claude plugin install design-paradigms@engineering-standards-marketplace
claude plugin install engineering-practices@engineering-standards-marketplace
claude plugin install security-scanning@engineering-standards-marketplace
claude plugin install agent-team@engineering-standards-marketplace
```

Or install all four from the `/plugin` panel inside a session. To pick up a new
release, run `claude plugin marketplace update engineering-standards-marketplace`.

## Plugins

### design-paradigms
Object-oriented (Java/C#), functional/procedural (Python), stateless service design
(Node.js), structural/procedural (Go/Rust), relational schema design (SQL), API design
(REST/gRPC/GraphQL, errors, pagination, versioning), Docker and container images,
cloud architecture (AWS/Azure/GCP), and functional React.

### engineering-practices
Concurrency, testing procedures, git workflows, code quality (immutability, error
handling, input validation), debugging methodology, scoped and grounded code changes,
documentation practices, performance/complexity optimization, observability (structured
logs, metrics, tracing, SLOs), and debloating (removing dead code and unused
dependencies with evidence).

### security-scanning
Vulnerability scanning checklists for backend, frontend, network, system/host,
database, and dependency/supply-chain risk — aligned to OWASP Top 10 / ASVS.

### agent-team
Seven subagents forming a delivery pipeline, each with an explicit input/output
contract, plus a skill that runs them in order:

```
Architect -> Software Engineer -> Reviewer -> QA Test Generator
    -> CI/CD Orchestrator -> DevOps -> SRE/Monitoring
```

- **Architect** — PRD -> Technical Design Document (data model, API schema, logic flow)
- **Software Engineer** — TDD -> working modular source code
- **Reviewer** — critiques code for readability, edge cases, security, TDD adherence
- **QA Test Generator** — writes adversarial unit/integration tests from acceptance criteria
- **CI/CD Orchestrator** — runs the suite in a sandbox, turns failures into fix instructions
- **DevOps** — Dockerfiles, Terraform/Kubernetes config, staged deployment after approval
- **SRE/Monitoring** — read-only; watches production, alerts on error-rate spikes, recommends rollbacks

#### Running the pipeline

```
/agent-team:ship docs/prd/checkout.md
/agent-team:ship "Add CSV export to the orders page" --deploy
```

Subagents can't call each other, so the `ship` skill makes the main session the
orchestrator. Each stage's output is saved under `.agent-team/<feature>/` (`tdd.md`,
`review.md`, `ci-report.md`, ...) and passed to the next stage as a file. The skill
stops for your approval after the design, caps review and CI fix loops at three rounds,
and stops after a green build unless `--deploy` is passed. Add `.agent-team/` to
`.gitignore` if you don't want run records committed.

#### Deploy approval hook

Installing `agent-team` adds a `PreToolUse` hook that forces a permission prompt before
any Bash command that deploys, rolls back, or mutates live infrastructure
(`terraform apply`, `kubectl apply`, `helm upgrade`, `gcloud run deploy`, deploy scripts,
and similar). It applies to every session with the plugin enabled, not only to the
agents. Matching is deliberately broad, so an occasional harmless command (for example,
a `grep` for `kubectl apply`) also prompts. The patterns live in
`plugins/agent-team/hooks/confirm-deploy.sh`.

## Development

- `claude plugin validate --strict <dir>` checks a manifest, or the skills/agents in a
  directory. CI runs it on every plugin, plus `tests/confirm-deploy.test.sh` for the hook.
- Skills and agents are auto-discovered from each plugin's `skills/` and `agents/`
  folders; adding one doesn't require a manifest change.
- Bump the plugin's `version` in its `plugin.json` and add a `CHANGELOG.md` entry for
  any change users should receive — installed copies update only when the version changes.

## Design notes

- No emojis, no decorative dividers, no filler — every SKILL.md is dense, checklist-driven
  reference material.
- Skills stay under the ~500-line guideline. Each language has its own skill (`go-structural`,
  `rust-structural`, `java-oop`, `csharp-oop`), so only the language in play loads.
  `cloud-design` keeps shared principles in `SKILL.md` and puts each provider in a
  `references/` file for the same reason.
- Each skill states precisely when it should trigger, so Claude consults it for
  substantive tasks without over-triggering on trivial ones.
