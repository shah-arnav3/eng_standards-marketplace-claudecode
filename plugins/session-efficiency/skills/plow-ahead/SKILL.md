---
name: plow-ahead
description: Autonomous execution through ordinary ambiguity — turning routine questions into stated assumptions, choosing small reversible options, validating as you go, and stopping only for real blockers (missing credentials, destructive or outward-facing actions, decisions the user reserved). Use only when the user explicitly asks for uninterrupted progress, such as "plow ahead", "keep going until done", "don't stop to ask", "use your best judgment", or "finish this while I'm away".
---

# Plow Ahead

The user has traded check-ins for momentum. Keep working through normal uncertainty, record every judgment call, and make the final report detailed enough that they can audit what happened while they weren't watching.

## Autonomy contract

- **Turn routine questions into assumptions.** Don't pause to ask which of two reasonable options the user prefers; pick one, note why, and continue.
- **Decide from evidence in this order**: the user's stated instructions and memory, repo conventions and nearby code, local docs and tests, then upstream docs (see `read-the-docs`).
- **Keep going through ordinary friction**: failing tests, missing context that can be found, implementation choices, minor ambiguity in the request.
- **Run independent work in parallel**: research, implementation, and verification subagents when they don't depend on each other.
- **Stay in scope.** Autonomy covers how to do what was asked, not adding what wasn't. Unrequested improvements go under open findings, not into the diff.

## Stop conditions

Stop and ask only when one of these applies:

- **Missing access**: credentials, secrets, accounts, paid services, or private data aren't available.
- **Destructive or hard to reverse**: deleting data or files the user didn't name, history rewrites, force pushes, dropping tables, overwriting uncommitted work.
- **Outward-facing**: pushing, opening or merging PRs, deploying, publishing, sending messages, or spending money, unless the user explicitly authorized that specific action for this task.
- **High risk that a conservative choice can't reduce**: security, privacy, legal, or safety.
- **The user reserved the decision**, now or in standing instructions.
- **Speculative fixes**: the same verification failure persists after a real investigation, and the next fix would be a guess or a broad rewrite.

When blocked on one item, finish every other part of the task that doesn't depend on it before stopping.

## Decision rules

1. Reuse an existing pattern before inventing one.
2. Prefer local, reversible, small-blast-radius changes.
3. Choose correctness and maintainability over cleverness.
4. Validate with the narrowest meaningful check first; widen only when the risk justifies it.
5. When two options are close, choose the one easier for a reviewer to understand.

Keep a running decision log as you go (in your working notes or the plan, not a new repo file unless the task needs one). Every entry becomes a line under **Clarifications** in the final report.

## Work loop

1. Identify the goal and the acceptance criteria implied by the request.
2. Inspect the real files, docs, tests, and runtime behavior before editing.
3. State the assumption, then act on it.
4. Implement in small coherent steps.
5. Run targeted validation; fix what it finds.
6. Repeat until the work is complete or a stop condition applies.
7. Review the full diff and the verification evidence against the original request before reporting.

## Final report

End with the full structure from `work-report`. For autonomous runs, two sections matter most:

- **Clarifications**: every assumption and judgment call made without asking, each with its reason, so the user can overturn any of them cheaply.
- **Next steps**: if a stop condition ended the run, state exactly what input is needed and the command or file to resume from, so a fresh session can pick it up.

## Common pitfalls

- Asking "should I continue?" after the user said to keep going.
- Treating "keep going" as permission to push, deploy, or delete.
- Making assumptions silently, so the user can't tell a decision from an accident.
- Expanding scope with refactors nobody asked for because nobody was there to say no.
- Looping on a failing test with guesses instead of stopping with a clear diagnosis.
- Stopping at the first blocker when other parts of the task were independent of it.
