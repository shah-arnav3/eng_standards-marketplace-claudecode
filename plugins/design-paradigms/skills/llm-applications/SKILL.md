---
name: llm-applications
description: Designing LLM-powered applications for cost, latency, and quality — token optimization (prompt caching, progressive disclosure, batching, output control), task-specific model and effort selection, and context and memory design for agents (compaction, context editing, subagents, cross-session memory). Use whenever designing or reviewing code that calls an LLM API, choosing a model or effort level for a task, building an agent loop, reducing an LLM bill, or the user mentions prompt caching, model routing, token costs, or agent memory. For Claude SDK syntax and current model IDs and prices, use the claude-api skill.
---

# LLM Application Design

The bill and the latency of an LLM application are decided mostly by architecture: what gets resent on every call, how much the model reads, and which model and effort level each task runs at. Measure cost per **completed task** on real traffic, not cost per request. A cheaper request that needs more turns or retries isn't cheaper.

Model names, prices, context limits, and feature availability change every few months. Don't hard-code them from memory; read them from the provider's models endpoint and pricing page (for Claude, the `claude-api` skill holds the current table and SDK syntax).

## Order of levers

Apply levers that don't cost quality first. Then apply levers that trade quality for cost, one at a time, against an eval.

1. **Prompt caching**: free, and usually the largest single saving.
2. **Input hygiene**: send less, and let the model fetch the rest.
3. **Batching** for anything no one is waiting on.
4. **Output control**: specify the shape; `max_tokens` is only a backstop.
5. **Effort level**: the first tradeoff.
6. **Model choice**: last, because it caps the intelligence ceiling.

Without an eval (even 20–30 frozen real requests with a pass/fail check), you can't tell an optimization from a regression. Build that first; every tradeoff lever needs it.

## Prompt caching

Every agent turn resends the whole conversation (system prompt, tool definitions, every prior turn), so cost grows roughly with the square of turn count. Caching reprices the repeated prefix at a small fraction of the input rate.

- **The cache is a prefix match.** Any byte change invalidates everything after it. Render order is tools → system → messages: keep the system prompt and tool list frozen for the session, and put anything volatile (timestamps, request IDs, the user's question) after the last cache breakpoint.
- **Silent invalidators**: the current time in the system prompt, unsorted JSON or tool lists, per-user text in the system prompt, adding or removing tools mid-session, and changing model or reasoning settings mid-conversation. Caches are per model.
- **Change instructions by appending, not editing.** To change behavior mid-conversation, append a system or reminder message instead of editing the system prompt, and treat the message history as append-only.
- **Shared prefixes across conversations** (one system prompt serving many users) need an explicit breakpoint on that static prefix. Automatic caching only reuses within one conversation.
- **Verify from usage, not code review.** On a warmed-up loop, cache-read tokens should dominate uncached input tokens. If cache reads stay at zero across identical requests, something above the breakpoint is changing.
- **Prefixes below the provider's minimum length don't cache**, and the minimum varies by model.

## Input tokens: progressive disclosure

- **Large reference documents** go behind a retrieval tool or a skill the model loads when needed, unless most calls need most of the document; a cached document is already cheap.
- **Many tool schemas** (MCP servers add up fast) go behind tool search with deferred loading, so only relevant schemas enter context. This pays once schemas exceed roughly 10K tokens; below that, the search step is overhead.
- **Don't restate tool schemas in prose** in the system prompt; they're already in the request.
- **Prefer narrow tools** (`get_order(id)`) over data dumps (`list_all_orders()`), and give list tools `limit`, `fields`, and date-range parameters.
- **Downscale images** to what the task needs; vision tokens scale with pixel area, not information content.
- **Use code execution for large tables and files**: let the model compute in a sandbox so only the answer enters context.
- **Count before sending unbounded user input** with the provider's token-counting endpoint, not a third-party tokenizer. Then truncate, summarize, or reject.
- **Caveat**: a smaller prompt isn't automatically a cheaper task. Deferred context can cost discovery turns, so validate on the eval.

## Batching and output

- **Batch APIs** discount every token, including cache reads, for unattended work: evals, backfills, nightly jobs, bulk classification. Results arrive asynchronously, so keep user-facing calls synchronous.
- **Specify the output shape** with an example, or use structured outputs, to shorten responses.
- **`max_tokens` is a backstop, not a tuning knob.** The model doesn't see it, and hitting it truncates mid-thought, which wastes the whole attempt. Set it generously for agentic work, stream large responses, and treat a `max_tokens` stop as a failed attempt.
- **Add a stop sequence the model emits when it can't proceed**, so it exits early instead of explaining at length.

## Task-specific model and effort selection

**Sweep effort before changing the model.** Effort (reasoning depth) scales thinking and tool-call volume within one model. How much it matters depends on the workload:

| Workload | Typical starting point | Notes |
|---|---|---|
| Classification, extraction, routing, short Q&A | Smallest tier, low effort | High volume with checkable outputs; validate on the hard tail |
| Chat and support | Mid tier, low–medium effort | Latency-sensitive; effort curves are usually flat here |
| Research and knowledge work | Mid or top tier, medium effort | High effort rarely beats medium measurably |
| Long-horizon coding and agents | Top tier, high effort | Real tradeoff: each step down costs pass rate |
| Subagents doing bulk reading or search | Small or mid tier, low effort | They return a summary; the parent decides |

- **Price the tail, not the median.** Compare models on the hardest tenth of tasks; the cheap model's failures there decide the bill.
- **Try the top model at lower effort before building a cascade.** It often beats a smaller model at high effort per solved task, and one model keeps one cache.
- **Re-run failures at higher effort** when you have a failure signal (tests, a validator): run everything at low effort and retry only the failures higher.
- **Switch models between conversations, not inside one.** A mid-conversation switch cold-starts the cache and may drop the earlier model's reasoning.
- **Two-model designs pay in only two shapes**:
  - **Orchestrator–workers**: a strong model plans and cheap workers handle many independent pieces, ideally more than one context window holds.
  - **Advisor**: a cheap executor consults a strong model on hard decisions, and only works when there is a cheap signal for "this one is hard".

  For one dependent chain of work that fits in context, a single model at lower effort usually wins.
- **Re-sweep after every model migration.** Effort defaults and calibrations differ between models, and prompts written for an older model often make a newer one over-work, so audit them too.

## Context and memory for agents

Three tools solve different problems, and long-running agents often need all three:

| Tool | Problem | Cost behavior |
|---|---|---|
| **Compaction** (summarize and continue) | The conversation will exceed the context window | Pays only in long sessions; write the summarization instructions to keep task-critical state |
| **Context editing** (clear old tool results or thinking) | Stale bulky results crowd the window | A context-window tool, not a savings lever: every clear rewrites the cached prefix. Clear rarely and in large batches |
| **Memory** (files or a store the agent reads and writes) | State must survive across sessions | Load an index at start and fetch entries on demand; never load the whole store |

- **Subagents for self-contained bulky steps**: the subagent absorbs its own heavy tool results and returns one paragraph, optionally on a cheaper model. Skip this when the deciding model needs the intermediate detail, and note that the subagent starts a fresh, uncached prefix.
- **Server-side over client-side trimming**: rewriting earlier turns yourself breaks the cache from that point and, on some models, invalidates earlier reasoning. Prefer the provider's compaction and context-editing features, or append a summary instead of rewriting history.
- **Memory design**:
  - Keep one fact per entry, with a short index line used for recall.
  - Store absolute dates, not "last week".
  - Update existing entries instead of appending duplicates.
  - Treat recalled memory as context that may be stale: verify file paths and identifiers before acting on them.
  - Never store secrets.

## Review checklist

- [ ] An eval (frozen inputs plus a pass/fail check) exists before any tradeoff lever
- [ ] System prompt and tool list are byte-stable; volatile content sits after the cache breakpoint
- [ ] Cache hits verified from usage metrics after every prompt-assembly change
- [ ] Unbounded inputs counted before sending; large references behind retrieval
- [ ] Unattended workloads batched
- [ ] Effort swept per route before changing models; candidates compared on cost per completed task and on the hard tail
- [ ] No model switching inside a conversation; any cheaper model runs in a subagent
- [ ] Long sessions use server-side compaction; cross-session state lives in indexed memory, not the prompt
- [ ] Model IDs, prices, and limits come from config or the provider API, not hard-coded from memory
