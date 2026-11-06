---
name: work-report
description: A structured, detailed end-of-task report — results with verification evidence, actions taken, open findings, clarifications (assumptions made and questions to confirm), and next steps split between the user and Claude Code. Use when finishing or pausing multi-step work such as implementing a feature, fixing a bug, a refactor, an investigation, an autonomous run, or a review, and when the user asks for a summary, status, or report of what was done.
---

# Work Report

A final report should let the user see what happened, check it, and know what to do next, without scrolling back through the session. Keep the detail, and put it in a fixed structure so it's quick to scan.

## When to use it

- **Use it** at the end of multi-step work: features, bug fixes, refactors, investigations, reviews, autonomous runs, and when pausing work that will resume later.
- **Skip it** for a direct answer to a question, a one-line edit, or a short follow-up in an ongoing exchange. A plain answer is the right report there.

## Structure

Use these five sections, in this order, with these headings. Keep all five so the reader always knows where to look; write "None." under a section with nothing in it.

```markdown
### Results
Status: done | partially done | blocked — one line on the outcome.
- What now works or what was found, stated as outcomes.
- Verification: each command or check run and its result (tests passed or
  failed, with counts; build; manual check). Name what was not verified.

### Actions taken
- Grouped by area, one bullet per change: the file (`path:line` where
  useful) and what changed in it.
- Commands with side effects: installs, migrations, commits, pushes, config
  changes outside the repo.

### Open findings
- Problems noticed but not fixed, risks, unverified behavior, and follow-ups
  out of scope. Each with where it is and why it matters.

### Clarifications
- Assumptions made and judgment calls, each with its reason.
- Questions that need the user's answer, phrased so they can answer in a word
  or two.
- Places where the request was read a particular way, if another reading was
  plausible.

### Next steps
**For you**
1. Actions only the user can take: approvals, credentials, manual testing,
   running an interactive command, answering a clarification. Include the
   exact command where there is one.

**For Claude Code**
1. What Claude would do next if asked, in order, specific enough to start
   from in a fresh session.
```

## Writing each section

- **Results first, as outcomes.** "Checkout now rejects expired cards with a 402" rather than "edited checkout.ts". Lead with the status word so a partial or blocked result can't be missed.
- **Verification is evidence, not adjectives.** Give the command and the result (`pytest -q tests/billing: 42 passed`). If tests failed or a check was skipped, say so here in plain words.
- **Actions taken are complete but not narrated.** List what changed, not the order you explored it in. Don't paste diffs or file contents the user can already see.
- **Open findings are things the user would want to know** even though no one asked: a bug spotted in adjacent code, a flaky test, a dependency with a known vulnerability, a doc that's now stale.
- **Clarifications let the user overturn a decision cheaply.** One line per item: the choice, then the reason. Put unanswered questions here, not buried in Results.
- **Next steps are split by who acts.** Never put a step under "For Claude Code" that needs the user's approval or access; put the approval under "For you" and the follow-on work under "For Claude Code".
- **Reference code as `path:line`** so the user can jump to it.
- **No status emoji, banners, or closing pleasantries.** The headings are the structure.

## Example

```markdown
### Results
Status: done. Order export now streams CSV instead of building it in memory.
- Exports of 200k rows complete in about 9s with flat memory (previously
  timed out at 30s).
- Verification: `npm test -- export`: 18 passed. Manual export of the seeded
  200k-row dataset succeeded. Not verified: exports over 1M rows.

### Actions taken
- `src/export/orders.ts:40` replaced the array build with a row stream piped
  to the response.
- `src/export/csv.ts` added `escapeField` for quotes and newlines.
- `tests/export/orders.test.ts` added streaming and escaping cases.

### Open findings
- `src/export/invoices.ts:22` uses the same in-memory pattern and will hit the
  same timeout at scale. Not changed; out of scope.

### Clarifications
- Kept the existing column order so downstream spreadsheets don't break.
- Should exports over 1M rows move to a background job? (yes/no)

### Next steps
**For you**
1. Answer the background-job question above.

**For Claude Code**
1. Apply the same streaming change to `src/export/invoices.ts`.
2. If background jobs are wanted, add a queued export with an email link.
```

## Making it the default

A skill loads only when its description matches the task. To use this format at the end of every substantial task, add one line to `~/.claude/CLAUDE.md` (or the project's CLAUDE.md): `End multi-step work with a report in the work-report skill's format.`

## Common pitfalls

- Hiding a failed test or skipped check in Actions taken instead of stating it under Results.
- A Results section that lists edits rather than outcomes.
- Questions for the user scattered through the report instead of collected under Clarifications.
- "Next steps" that mix what the user must do with what Claude will do.
- Pasting back diffs or command output the user already saw.
- Dropping empty sections, so the user can't tell "no open findings" from "forgot to check".
