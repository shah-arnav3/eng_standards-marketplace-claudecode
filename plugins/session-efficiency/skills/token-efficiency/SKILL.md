---
name: token-efficiency
description: Token-efficient working habits for Claude Code sessions — reading files narrowly, delegating broad searches to subagents, filtering command output, keeping the prompt cache warm, and trimming always-on context from skills, plugins, and MCP servers. Use when a task will read many files or produce large output, when context is filling up or a session is getting expensive, or when the user mentions tokens, context usage, /context, /usage, or session cost.
---

# Token-Efficient Sessions

Every token in context is re-read on every turn. Each file read, command output, and verbose reply makes all later turns more expensive and brings compaction closer. The aim is to keep the main context to what the current decision needs.

Measure before optimizing:

- **`/context`** shows the live breakdown by category (conversation, CLAUDE.md and memory files, skills, MCP tools) with suggestions.
- **`/usage`** shows session cost, usage by model, and prompt cache hit ratio.
- **`claude plugin details <plugin>`**, run in a shell, projects each plugin's always-on and per-invoke token cost.

## Reading code

- **Search before reading.** Use Grep and Glob to find the file and line, then Read only that region with `offset` and `limit`. Reading a whole large file to find one function wastes most of what it loads.
- **Don't re-read what's already in context.** After an Edit, the tool would have errored if the edit failed, so trust the file state instead of reading it back.
- **One Read returns at most about 25,000 tokens and refuses very large files.** Page through big files deliberately instead of reaching for `allow_large`.
- **Read the interface, not the implementation**, when deciding how to call something: the signature, docstring, and one usage site are usually enough.

## Delegating to subagents

A subagent works in its own context window; only its summary comes back to the main thread. That makes subagents the main tool for keeping the main context clean.

- **Delegate when answering means sweeping many files** (where is X used, which modules touch Y, how does Z flow end to end) and you only need the conclusion. The built-in `Explore` agent is read-only and made for this.
- **Don't delegate a single-fact lookup** when you already know the file or symbol. Searching directly is cheaper than spinning up an agent.
- **Ask for a specific return shape** ("file:line list, max 10 entries, one-line reason each") so the summary stays small.
- **Run independent subagents in parallel** in one message, and never duplicate a search you've delegated.
- **Subagents still bill usage** and start with a fresh, uncached prompt. Delegation saves main-thread context, not total spend, so a cheaper model for the subagent is what saves money (see `model-selection`).

## Command output

- **Filter at the source**: `| head -50`, `| grep -n pattern`, `| tail -20`, `--quiet`, `--json | jq '.field'`. Bash output beyond a cap (30,000 characters by default) is truncated, but everything below the cap still lands in context.
- **For test runs**, ask the runner for failures only (`pytest -q`, `--reporter=dot`, `go test ./... 2>&1 | grep -E 'FAIL|panic'`) and expand a single failure when needed.
- **Never `cat` a lockfile, minified bundle, or generated file** to look at it. Grep it.
- **Run independent commands in parallel** tool calls instead of sequentially.

## Replies

- Report conclusions, not process. Don't paste back file contents, diffs, or command output the user can already see.
- Answer the question asked. Skip restating the request and closing summaries of what was just shown.

## Keeping the prompt cache warm

Cached context costs a fraction of uncached context, and the cache is a prefix match on the conversation.

- **Avoid mid-session model switches when cost matters.** Each switch is a cache miss, and so is each plan-mode toggle under `opusplan`, a skill whose frontmatter `model` differs from the session model, and turning fast mode on or off.
- **Long idle gaps let the cache expire.** The main conversation's cache lasts an hour on a Claude subscription within plan usage and five minutes on API keys and cloud providers; subagent caches last five minutes by default. Batch questions rather than drip-feeding them across a long break.
- **Changing CLAUDE.md or settings mid-session** changes what's injected and can invalidate the cached prefix.

## Trimming always-on context

Some context is paid on every turn whether used or not:

- **Skill descriptions** are always in context; the body loads only when the skill is invoked. Keep descriptions specific and short (the listing truncates each one at 1,536 characters).
- **Skills that should only run on an explicit `/command`** get `disable-model-invocation: true`, which removes their description from context entirely. For skills you don't own (outside plugins), `skillOverrides` can set them to `"name-only"`, `"user-invocable-only"`, or `"off"`.
- **Plugins you don't use in a project** should be disabled there. Check their always-on cost with `claude plugin details`.
- **MCP tool schemas** are deferred by default (tool search loads them on demand), so the cost of an MCP server is mostly its server instructions and any tools it can't defer. Check the MCP category in `/context` before adding another server.
- **CLAUDE.md and auto memory** load every session; see `session-memory` for keeping them lean.

## Common pitfalls

- Reading whole directories "for context" before knowing what the task needs.
- Running the full test suite with verbose output after every small edit.
- Delegating a one-line lookup to a subagent, or doing a 40-file sweep in the main thread.
- Switching to a bigger model mid-session for one hard question, then continuing on it with a cold cache, instead of handing that question to a subagent.
- Long, chatty replies that restate tool output the user already saw.
