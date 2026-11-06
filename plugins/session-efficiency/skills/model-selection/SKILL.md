---
name: model-selection
description: Choosing the right Claude model and effort level per task in Claude Code — for the main session, for subagents via frontmatter or the Agent tool's model parameter, and for skills — and avoiding the cache and quality costs of switching. Use when delegating work to a subagent, defining a subagent or skill, starting a session whose difficulty is clear up front, or the user mentions model choice, haiku/sonnet/opus/fable, /model, /effort, opusplan, or making a session cheaper or smarter.
---

# Task-Specific Model and Effort Selection

Model sets the capability ceiling. Effort (reasoning depth: `low`, `medium`, `high`, `xhigh`, `max`) sets how much of that capability a turn spends. Pick both per task, and prefer moving work to a subagent on the right model over switching the main session back and forth.

## Defaults by task

| Task | Model | Effort | Where it runs |
|---|---|---|---|
| Broad codebase search, "where is X used", log scanning | `haiku` | low | Subagent (e.g. `Explore`) |
| Mechanical edits: renames, formatting, boilerplate, config tweaks | `haiku` or `sonnet` | low | Subagent or main |
| Everyday feature work and bug fixes with clear scope | `sonnet` | medium | Main |
| Running tests and interpreting failures | `sonnet` | low–medium | Subagent |
| Code review, security review, tricky debugging | `opus` | high | Main or subagent |
| Architecture, design documents, cross-cutting refactors | `opus` or `fable` | high–xhigh | Main |
| Hardest long-horizon or research problems | `fable` | high–max | Main |

These are starting points. If a cheaper setting keeps failing a task, step up one notch: raise effort first, then the model.

- **Effort before model.** A stronger model at lower effort often beats a weaker model at high effort, and it keeps one model (and one cache) in play.
- **Default effort varies by model**: `medium` on the current Opus, Sonnet, and Haiku; `high` on most others. Set effort explicitly when it matters instead of assuming.

## Setting the main session's model

- **`/model <alias>`** switches the model and saves it as your default. Inside the `/model` picker, `s` applies it to this session only. `--model` and `ANTHROPIC_MODEL` are session-only.
- **Aliases**: `haiku`, `sonnet`, `opus`, `fable`, `best`, `default`, the `[1m]` long-context variants, and `opusplan`.
- **`opusplan`** uses Opus in plan mode and Sonnet for execution: strong planning with cheaper implementation. Each plan-mode toggle is a model switch and therefore a cache miss, so it suits sessions with one planning phase, not constant toggling.
- **`/effort <level>`** (or `/effort` for a slider, `/effort auto` to reset) sets effort for the session; `--effort` sets it at launch. `effortLevel` and `modelSettings.<model>.effortLevel` in settings persist it. The `CLAUDE_CODE_EFFORT_LEVEL` env var overrides everything.
- **Choose at the start.** Switching mid-session cold-starts the prompt cache, so the next turn re-reads the whole conversation at full price.

## Setting a subagent's model

Model precedence for a subagent: the Agent tool's `model` parameter, then the subagent's `model` frontmatter, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the main session's model. (`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` makes the env var win.)

- **In a subagent definition** (`.claude/agents/*.md` or a plugin's `agents/`), set `model:` to `haiku`, `sonnet`, `opus`, `fable`, a full model ID, or `inherit`, and set `effort:` to the level the role needs:

  ```markdown
  ---
  name: test-runner
  description: Runs the test suite and reports failures with file:line and a one-line cause.
  tools: Bash, Read, Grep
  model: sonnet
  effort: low
  ---
  ```

- **Per invocation**, the Agent tool's `model` parameter accepts only `haiku`, `sonnet`, `opus`, or `fable`. Use it to send one heavy task to a stronger model, or a bulk task to a cheaper one, without changing the definition.
- **Match the model to what the subagent decides, not what it reads.** A subagent that reads 50 files and returns a list can be cheap. One whose judgment the main thread will trust (a reviewer, an architect) should not be.
- **A one-off hard question goes to a subagent on a stronger model**; the main session stays on its model and keeps its cache.

## Setting a skill's model

A skill's frontmatter can set `model:` and `effort:`. It applies for that turn only (or for the forked subagent when the skill uses `context: fork`). If it differs from the session model, that turn is a cache miss, so set it only when the skill truly needs a different model.

## Signs the choice is wrong

- **Too weak**: repeated failed attempts at the same fix, ignoring constraints stated earlier, shallow reviews that miss obvious issues, plans that fall apart on contact with the code. Step up effort, then model, and count retries as cost; cheap attempts that fail aren't cheap.
- **Too strong**: long deliberation on mechanical work, simple searches and edits running on the top model at high effort, high spend on tasks a subagent could have done. Move that work to a cheaper subagent.

## Common pitfalls

- Running every subagent on `inherit` when the main session is on the top model, so bulk searches cost top-model rates.
- Switching the main session's model several times per hour, paying a cold cache each time.
- Picking a smaller model to save money on a task it keeps failing.
- Setting `model:` on a frequently used skill, causing a cache miss on every invocation.
- Assuming the effort default; it differs by model.
