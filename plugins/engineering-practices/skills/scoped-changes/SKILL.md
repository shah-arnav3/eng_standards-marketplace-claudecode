---
name: scoped-changes
description: Discipline for file creation, code extension, and bug fixes — keeping changes scoped and grounded in what was actually asked, verifying assumptions against the real codebase before editing, and avoiding unrequested refactors or hallucinated APIs. Use whenever creating new files, adding a feature to existing code, or fixing a bug in an existing codebase, especially when the surrounding code or its conventions are not yet confirmed.
---

# Scoped, Grounded Changes: File Creation, Extension, and Bug Fixes

The most common way an otherwise-correct-looking change goes wrong is scope creep and ungrounded assumptions — editing more than was asked, or writing code against an API/convention that was never actually verified against the real codebase.

## Ground every change in the real codebase before writing it

1. **Read the surrounding code before extending it.** Before adding a function to a module or a method to a class, open the file and check existing naming conventions, error-handling style, and how neighboring functions are structured — new code should look like it was written by the same author as the code around it.
2. **Verify imports, APIs, and signatures actually exist** — don't assume a library function's name, argument order, or return type from memory or a similar-looking API in another language/library. Check the actual dependency version in use (lockfile, `package.json`/`requirements.txt`/`go.mod`) before relying on a feature that may not exist in that version.
3. **Check for an existing utility before writing a new one.** A duplicate helper for something the codebase already has (a date formatter, a retry wrapper, a validation function) fragments behavior and creates two places that can drift out of sync.
4. **When a needed fact isn't visible (a config value, an env-specific behavior, a convention used elsewhere), look it up rather than guessing** — grep the codebase, check the README/docs, or ask, rather than inventing a plausible-sounding default.

## Scope discipline

- **Do exactly what was asked, and flag adjacent problems rather than fixing them unasked.** If fixing a bug reveals a second unrelated issue, mention it and let the requester decide whether to expand scope — don't silently bundle an unrelated fix or refactor into the same change.
- **A bug fix changes the minimum code necessary to correct the behavior**, not the surrounding style, unrelated variable names, or formatting of code you didn't need to touch. A diff should be reviewable at a glance against the stated problem.
- **A new file/feature request is not an invitation to restructure existing files** unless that restructuring was explicitly requested or is strictly required to make the new piece work.
- **Match the existing architecture rather than introducing a new pattern for one feature** — a new endpoint in a codebase with an established layered structure goes into the existing layers, not into a new ad hoc structure alongside them, even if the new structure would be "cleaner" in isolation.

## Bug fixes specifically

1. Reproduce and confirm the actual root cause first (see the `debugging` skill) — don't patch the first plausible-looking cause without confirming it's the real one.
2. Write or update a test that captures the bug before fixing it, so the fix is provably correct rather than "looks right."
3. Check whether the same bug pattern exists elsewhere in the codebase (a bug in one date-parsing call site often means the same bad assumption is made at other call sites) — mention this to the requester rather than fixing all instances unasked if the request was scoped to one location.
4. Confirm the fix doesn't change behavior for any case that was already working — a regression hidden inside a "fix" is worse than the original bug because it's less visible.

## File creation

- Match the project's existing file organization, naming convention, and module boundaries — check a sibling file's structure before inventing a new one.
- Include only what was asked: a new module for one function doesn't need speculative extension points, unused configuration hooks, or abstractions for hypothetical future requirements ("YAGNI" — you aren't going to need it).
- Verify the file doesn't already exist somewhere under a different name before creating a duplicate.

## Example: grounded vs. ungrounded extension

```
Task: "Add a method to retry a failed webhook delivery."

Ungrounded: Write a brand-new RetryHelper class with an invented exponential-backoff
API, without checking whether the codebase already has a retry utility, and add it
in a new top-level `utils/` file regardless of the project's existing module layout.

Grounded: Grep the codebase for "retry"/"backoff" first. Codebase already has
`common/retry.py` with `retry_with_backoff(fn, max_attempts, base_delay)` used
elsewhere. Reuse it in the webhook delivery module, matching its existing call
pattern, instead of introducing a second retry implementation.
```

## Common pitfalls

- Inventing a library method name/signature that "sounds right" instead of checking the actual installed version's API.
- Rewriting a whole file via full replacement when only a few lines needed to change, discarding unrelated content or formatting the requester didn't ask to change.
- Fixing a symptom in the one place it was reported while leaving the same root cause live at other call sites, without flagging that they exist.
- Adding speculative configuration options, feature flags, or abstraction layers "in case it's needed later" when nothing in the request called for them.
- Silently changing a public function's signature or behavior while fixing an internal bug, breaking callers that weren't part of the request.
