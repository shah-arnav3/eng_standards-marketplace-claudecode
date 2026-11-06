---
name: ship
description: Runs the agent-team delivery pipeline end to end — Architect, Software Engineer, Reviewer, QA Test Generator, CI/CD Orchestrator, and optionally DevOps and SRE/Monitoring — routing each stage's output to the next through files, enforcing retry limits, and stopping for human approval at the design and deploy gates.
argument-hint: <PRD path or feature description> [--deploy]
disable-model-invocation: true
---

# Ship a feature through the agent-team pipeline

Subagents cannot call each other, so you — the main session — are the orchestrator. You invoke each agent, save what it returns, decide where it goes next, and enforce the limits below. Agents never route work themselves.

Input: $ARGUMENTS

## Setup

1. Resolve the input. If it is a file path, read it; otherwise treat the text as the feature description. If there are no acceptance criteria, draft them and confirm with the user before continuing — every later stage tests against them.
2. Pick a short kebab-case slug for the feature and create `.agent-team/<slug>/`. Save the PRD there as `prd.md`.
3. Note whether `--deploy` was passed. Without it, the pipeline stops after a green CI run.

## Run directory

Every handoff is a file, so each stage reads a complete input instead of a chat summary, and the user can inspect or edit any stage's output.

| File | Written by | Read by |
|---|---|---|
| `prd.md` | you | Architect, QA |
| `tdd.md` | Architect | everyone after |
| `impl-notes.md` | you, from Engineer's return | Reviewer, QA |
| `review.md` | you, from Reviewer's return | Engineer (fix rounds) |
| `test-plan.md` | you, from QA's return | CI/CD |
| `ci-report.md` | you, from CI/CD's return | Engineer or Architect (fix rounds) |
| `deploy.md` | you, from DevOps's return | SRE |
| `health.md` | you, from SRE's return | user |
| `log.md` | you | user |

Append one line to `log.md` per stage invocation: stage, round, verdict, output file. On a fix round, overwrite the stage's file and record the round number in `log.md`; do not keep numbered copies.

When invoking an agent, give it the absolute paths of its input files and tell it what to return. Do not paste file contents into the prompt — the agent reads them itself.

## Stages

1. **Architect** (`architect-agent`): input `prd.md`; it writes `tdd.md`.
   **Design gate:** show the user the TDD summary, its labeled assumptions, and its non-goals. Stop until they approve or request changes. Implementing against an unapproved design wastes every later stage.
2. **Software Engineer** (`software-engineer-agent`): input `tdd.md`; save its handoff note as `impl-notes.md`.
3. **Reviewer** (`reviewer-agent`): input `tdd.md`, `impl-notes.md`, and the changed files listed there; save as `review.md`.
   - `Verdict: changes required` → back to the Software Engineer with `review.md`, then review again.
   - Limit: 3 review rounds. If round 3 still has blocking issues, stop and show the user the unresolved items.
4. **QA Test Generator** (`qa-test-generator-agent`): input `prd.md`, `tdd.md`, `impl-notes.md`; save its coverage summary as `test-plan.md`. If it flags an untestable acceptance criterion, ask the user to clarify it before running CI.
5. **CI/CD Orchestrator** (`cicd-orchestrator-agent`): input `test-plan.md`; save as `ci-report.md`.
   - `Verdict: implementation bug` → Software Engineer with `ci-report.md`, then CI again.
   - `Verdict: flaky/environmental` → tell the user what failed and why it looks environmental; do not loop on it.
   - `Verdict: design-level` → Architect with `ci-report.md` to revise `tdd.md`, then repeat the design gate. At most one design revision per run.
   - Limit: 3 fix attempts against the same failing test. After that, stop and show the user `ci-report.md`.
   - Green with no `--deploy` → finish (see below).
6. **DevOps** (`devops-agent`), only with `--deploy`: input `tdd.md`, `ci-report.md`; save as `deploy.md`.
   **Deploy gate:** before each deploy the agent presents a plan and waits for approval. Relay the plan to the user word for word and pass back only their explicit answer. Staging and production are separate approvals. The plugin's deploy hook will also prompt on the command itself.
7. **SRE/Monitoring** (`sre-monitoring-agent`), after any deploy: input `deploy.md`; save as `health.md`. If it recommends a rollback, show the user the recommendation and command. Never run it yourself, and never route it to DevOps without the user's go-ahead. A bug report in `health.md` starts a new run, not a loop in this one.

## Finishing

Report to the user: stages run and rounds per stage (from `log.md`), final verdicts, files changed, any assumptions the Architect or Engineer labeled, and anything stopped at a limit. Point to `.agent-team/<slug>/` for the full record, and suggest adding `.agent-team/` to `.gitignore` if the user doesn't want run records committed.

## Rules

- Stop at a limit; never raise one yourself. Reaching a limit means a person needs to look.
- Never skip a stage to save time. Review before QA, and QA before CI, are what make a green build mean something.
- Never edit application code, tests, or `tdd.md` yourself during a run. Route every change through the agent that owns it, so each file has one author per round.
