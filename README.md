# Engineering Standards Marketplace

A Claude Code plugin marketplace covering four areas: design paradigms, cross-language
engineering practices, layered security scanning, and a seven-agent software delivery
pipeline. Every skill is written for modern coding standards, uses generalized code
examples, and is organized so Claude reads only what a given task needs.

## Install

```bash
claude plugin marketplace add /path/to/marketplace
claude plugin install design-paradigms@engineering-standards-marketplace
claude plugin install engineering-practices@engineering-standards-marketplace
claude plugin install security-scanning@engineering-standards-marketplace
claude plugin install agent-team@engineering-standards-marketplace
```

Or install all four from the `/plugin` panel inside a session.

## Plugins

### design-paradigms
Object-oriented (Java/C#), functional/procedural (Python), stateless service design
(Node.js), structural/procedural (Go/Rust), relational schema design (SQL), cloud
architecture (AWS/Azure/GCP, with per-provider reference files), and functional React.

### engineering-practices
Concurrency, testing procedures, git workflows, code quality (immutability, error
handling, input validation), debugging methodology, scoped and grounded code changes,
documentation practices, and performance/complexity optimization.

### security-scanning
Vulnerability scanning checklists for backend, frontend, network, system/host,
database, and dependency/supply-chain risk — aligned to OWASP Top 10 / ASVS.

### agent-team
Seven subagents forming a delivery pipeline, each with an explicit input/output
contract so handoffs are unambiguous:

```
Architect -> Software Engineer -> Reviewer -> QA Test Generator
    -> CI/CD Orchestrator -> DevOps -> SRE/Monitoring
                  ^                        |
                  '------ bug reports ------'
```

- **Architect** — PRD -> Technical Design Document (data model, API schema, logic flow)
- **Software Engineer** — TDD -> working modular source code
- **Reviewer** — critiques code for readability, edge cases, security, TDD adherence
- **QA Test Generator** — writes adversarial unit/integration tests from acceptance criteria
- **CI/CD Orchestrator** — runs the suite in a sandbox, turns failures into fix instructions
- **DevOps** — Dockerfiles, Terraform/Kubernetes config, staged deployment
- **SRE/Monitoring** — watches production, alerts on error-rate spikes, can trigger rollback

## Design notes

- No emojis, no decorative dividers, no filler — every SKILL.md is dense, checklist-driven
  reference material.
- Skills stay under the ~500-line guideline; `cloud-design` uses a references/ subfolder
  per provider so only the relevant one loads into context.
- Each skill states precisely when it should trigger, so Claude consults it for
  substantive tasks without over-triggering on trivial ones.
