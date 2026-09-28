---
name: debugging
description: Systematic debugging methodology — reproducing bugs reliably, binary-search isolation, reading stack traces, using debuggers and structured logging, and distinguishing symptoms from root causes. Use whenever diagnosing a bug, investigating unexpected behavior, reading an error/stack trace, or the user asks why something is failing or behaving unexpectedly.
---

# Debugging Methodology

Debugging is a search problem: narrow the space that could contain the bug as fast as possible, rather than guessing at fixes and re-running to see if they "worked."

## The process, in order

1. **Reproduce reliably first.** A bug you can't reproduce on demand can't be confirmed fixed. Find the minimal, deterministic sequence of steps/inputs that triggers it before touching any code. If it's intermittent, look for what varies between occurrences (timing, data, concurrency, environment) rather than accepting "it's flaky."
2. **Read the actual error, fully, before hypothesizing.** The first line of a stack trace is often a symptom; the root cause is frequently several frames down, at the first frame that belongs to your own code rather than a framework/library.
3. **Form a specific, falsifiable hypothesis.** "Something's wrong with the database" is not a hypothesis. "The query returns zero rows because the filter uses the wrong timezone" is — it predicts a specific observation you can check.
4. **Isolate with binary search**, not linear scanning: comment out/bisect halves of the suspect code path, add a log/breakpoint at the midpoint of the call chain, or `git bisect` across commits to find exactly where behavior changed.
5. **Fix the root cause, not the symptom.** If a null check makes a crash go away but you don't know why the value was null, you've hidden the bug, not fixed it — trace back to where the invalid state originated.
6. **Add a regression test that fails before the fix and passes after.** This is what proves you understood the bug, not just papered over its current symptom.

## git bisect for "this used to work"

```bash
git bisect start
git bisect bad                  # current commit is broken
git bisect good v1.4.0           # this earlier tag was known good
# git checks out a midpoint commit — build/test it, then:
git bisect good   # or: git bisect bad
# repeat until git identifies the exact breaking commit
git bisect reset
```

Automate the good/bad check with a script when the reproduction is scriptable:

```bash
git bisect start HEAD v1.4.0
git bisect run ./scripts/reproduce_bug.sh
```

## Reading stack traces

- Find the first frame in *your* code, not a framework internal — that's usually the most useful starting point, even if the exception was thrown deeper.
- Note the exception/error type itself before the message — `NullReferenceException` vs. `TimeoutException` vs. `ConstraintViolationException` point in very different directions.
- For async/concurrent stack traces, check whether the trace shows the point of *failure* or the point where an *unrelated* task's rejection was surfaced — async stack traces can be misleading about causality; correlate with logs/timestamps.

## Structured logging over print debugging

- Prefer structured (JSON) logs with consistent fields (correlation/request id, timestamp, severity, relevant entity ids) over ad hoc `print`/`console.log` statements, so you can filter/correlate across a distributed system.
- Log at the boundary of a decision, not everywhere: "why did we take this branch" is more useful than "entered function X."
- Remove debug-only prints before merging; if the information is genuinely useful long-term, make it a real log line at an appropriate level (`debug`/`info`), not a temporary artifact.

```python
logger.info("order_priced", extra={
    "order_id": order.id,
    "base_total_cents": order.total_cents,
    "discount_percent": discount,
    "correlation_id": ctx.correlation_id,
})
```

## Using a debugger effectively

- Set a breakpoint at the earliest point where you can confirm state is already wrong, then step forward — don't start at the crash site and step backward through unrelated code.
- Conditional breakpoints (`break if order.id == "o-4821"`) for bugs that only manifest for specific data, instead of stepping through every iteration of a loop.
- Watch expressions for a specific variable's value across a loop/recursion instead of manually re-inspecting it at every step.

## Distinguishing symptom from root cause — a concrete example

```
Symptom:   Users report duplicate emails being sent.
Naive fix: Add a `sent` boolean flag and check it before sending. (Suppresses the symptom.)
Root cause investigation: Why is the send code running twice? Trace the call path —
  discover the message queue redelivers on a slow consumer without an idempotency key.
Real fix: Add an idempotency key at the point of dispatch, keyed by a unique send-intent
  id, so redelivery is safe by construction — not just less visible.
```

## Common pitfalls

- Changing multiple things at once "to see what fixes it" — you lose the ability to know which change mattered, and often introduce a second bug.
- Trusting a fix because the specific reported case now works, without understanding why it was broken (means related cases likely still fail).
- Debugging in production data/environment when a controlled reproduction in a lower environment is possible — riskier, slower feedback loop, and harder to instrument.
- Ignoring timestamps/ordering in logs from concurrent/distributed systems — apparent causality in log order isn't guaranteed causality across processes/clocks.
- Suppressing a warning/exception instead of understanding what it indicates, only to have the same root cause resurface as a different symptom later.
