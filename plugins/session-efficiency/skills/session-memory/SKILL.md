---
name: session-memory
description: Managing what Claude Code remembers within and across sessions — keeping CLAUDE.md and rules lean and scoped, maintaining auto memory (MEMORY.md and topic files), compacting at the right time with focus instructions, persisting state before compaction or /clear, handoff documents for multi-session work, and resuming sessions. Use when context is nearly full, before /compact or /clear, when ending or resuming a multi-session task, when writing CLAUDE.md, rules, or memory files, or the user mentions memory, compaction, handoff, /resume, or Claude forgetting instructions.
---

# Session Memory

Claude Code has three kinds of memory, and each survives different things:

| Memory | Loaded | Survives compaction | Survives `/clear` and new sessions |
|---|---|---|---|
| Conversation (instructions given in chat, files read) | Accumulates during the session | Only as a summary | No |
| CLAUDE.md and `.claude/rules/` | At launch, and on demand for nested and path-scoped files | Yes, re-injected from disk | Yes |
| Auto memory (`MEMORY.md` + topic files) | `MEMORY.md` at launch; topic files on demand | Yes, re-injected | Yes |

**Rule**: anything that must outlast the current context goes into a file, not just the conversation. An instruction given only in chat is lost at the next compaction.

## CLAUDE.md and rules: lean and scoped

These load into every session, so every line costs tokens on every turn.

- **Keep each CLAUDE.md under about 200 lines.** Put in it what Claude can't infer from the code: build and test commands, conventions that differ from the defaults, architecture boundaries, and things that have caused mistakes before.
- **Locations, broadest first**:
  - managed policy, set by your organization
  - `~/.claude/CLAUDE.md` (you, all projects)
  - `./CLAUDE.md` or `./.claude/CLAUDE.md` (project, committed)
  - `./CLAUDE.local.md` (you, this project, not committed)

  Files in the working directory and its parents load at launch. A CLAUDE.md in a subdirectory loads only when Claude touches files there, so put module-specific guidance next to the module.
- **Path-scoped rules**: a file in `.claude/rules/` with `paths:` frontmatter loads only when matching files are touched. Use these for language- or directory-specific conventions instead of growing the root file.
- **`@path` imports** pull another file in (relative to the importing file, up to four levels deep). They're for organization, not savings: imported content still loads.
- **Don't duplicate** what the code, README, or git history already says, and don't narrate history. Describe the project as it is now.
- **`/memory`** lists every loaded memory file and toggles auto memory; `/context all` shows which files actually loaded this session. `claudeMdExcludes` skips CLAUDE.md files you don't want (for example, other teams' files in a monorepo).

## Auto memory

Auto memory lives in `~/.claude/projects/<project>/memory/`. It's machine-local and shared across worktrees of the same repo. Only the first 200 lines (or 25KB) of `MEMORY.md` load at startup; topic files load on demand.

- **`MEMORY.md` is an index**: one line per memory with a link and a short hook. Never put memory content in the index, or it crowds out entries past the load limit.
- **One fact per topic file**, with a description good enough to judge relevance from the index alone.
- **Update or delete instead of appending.** Check for an existing entry before writing a new one, and remove memories that turn out to be wrong.
- **Convert relative dates to absolute ones** ("2026-11-06", not "last Thursday").
- **Don't store** what the repo already records (code structure, fixed bugs, git history), what matters only to the current conversation, or secrets.
- **Treat recalled memory as possibly stale.** Verify a remembered file, function, or flag still exists before acting on it.

## Compaction

Compaction replaces the conversation with a summary. Afterwards, the root CLAUDE.md, unscoped rules, and auto memory are re-injected from disk, and up to 5,000 tokens of each invoked skill's body are restored. Nested CLAUDE.md files and path-scoped rules reload when their files are next touched. Everything else survives only as well as the summary captured it.

- **Compact at a natural boundary** (a feature done, a bug fixed, a phase complete) rather than letting auto-compact fire mid-task. Give it a focus: `/compact keep the failing test names, the root cause, and the remaining TODOs; drop exploration`.
- **Before compacting, write durable state to files**: decisions to CLAUDE.md or a design doc, user preferences to auto memory, progress to the handoff document. Don't count on the summary to keep them.
- **Tune the threshold** with `/autocompact <tokens>` (or `autoCompactWindow` in settings) if auto-compact fires too early or too late for your work.
- **Automate it with hooks**: a `PreCompact` hook's plain stdout becomes extra instructions for the summary (exit code 2 blocks compaction). A `SessionStart` hook with the `compact` matcher can re-inject context through `hookSpecificOutput.additionalContext` after compaction.

## `/clear` versus `/compact`

- **`/clear`** starts an empty context. Use it between unrelated tasks; carrying the last task's context into the next one costs tokens and can mislead. The old session is saved and `/resume` can reopen it.
- **`/compact`** keeps a summary. Use it to continue the same task with room to work.

## Handoff documents for multi-session work

For work spanning several sessions, keep a handoff file in the repo (for example `HANDOFF.md`, gitignored if it's personal) and tell CLAUDE.md to read it first. Keep it short and current:

```markdown
# Handoff — <feature>

## State
What works, what's committed, what's in progress (branch, last commit).

## Next steps
1. The next concrete action, specific enough to start without re-reading the code.

## Decisions
Choices made and the reason, so they aren't relitigated.

## Gotchas
Traps already hit: flaky tests, env quirks, misleading names.
```

Update it at the end of each session and before any compaction you didn't choose. Rewrite it in place; it's a snapshot, not a log.

## Resuming sessions

- **`claude --continue`** reopens the most recent session in the current directory. **`claude --resume`** opens a picker, and `--resume <name>` opens one by name (set names with `/rename`). **`/resume`** switches from inside a session.
- **A resumed session restores** the conversation, model, and permission mode. It does **not** restore launch flags such as `--mcp-config`, `--settings`, `--plugin-dir`, or `--add-dir`; pass them again.
- **When the old conversation is huge or stale**, a fresh session that reads the handoff document is often cheaper and clearer than resuming.

## Common pitfalls

- Telling Claude a rule once in chat and expecting it to hold after compaction.
- A 600-line CLAUDE.md that loads every turn, most of it irrelevant to the current task.
- A `MEMORY.md` index that holds full memory content and silently passes the 200-line load limit.
- Duplicate or contradictory memories piling up because nobody updates or deletes old ones.
- Letting auto-compact fire mid-debugging, losing the failing case and the current hypothesis.
- Resuming a session without the `--plugin-dir` or `--add-dir` flags it was started with.
