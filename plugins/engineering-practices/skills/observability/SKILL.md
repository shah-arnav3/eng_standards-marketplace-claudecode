---
name: observability
description: Instrumenting services so production behavior can be understood — structured logging, metrics (RED/USE), distributed tracing with OpenTelemetry, correlation IDs, SLOs, and alerting on symptoms rather than causes. Use whenever adding logging, metrics, or tracing to code, designing dashboards or alerts, defining SLOs, or the user mentions observability, OpenTelemetry, Prometheus, log levels, or alert fatigue.
---

# Observability

Observability is being able to answer a question about production you didn't anticipate, from telemetry you already emit. Instrument while writing the code: the first incident is too late to discover a request path that logs nothing.

## The three signals and what each answers

| Signal | Answers | Cost profile |
|---|---|---|
| Metrics | Is something wrong, and how much? (rates, percentiles, saturation) | Cheap per event; cost scales with label cardinality |
| Traces | Where in the request path is it wrong? | Moderate; sample to control volume |
| Logs | Why did this specific request fail? | Expensive at volume; cost scales with lines × size |

Link them: every log line and span carries the same trace ID, so an alert on a metric leads to example traces, and a trace leads to its logs.

## Structured logging

- Log JSON (or logfmt) with stable keys, never interpolated prose. `{"event":"payment_failed","order_id":"o-123","reason":"card_declined"}` can be queried; `"Payment for o-123 failed: card declined"` has to be regex-parsed.
- Every line includes: timestamp (UTC), level, service name, version, environment, and `trace_id`/`span_id` from the active context.
- Levels mean something:
  - `ERROR` — the operation failed and someone may need to act.
  - `WARN` — degraded but handled (a retry succeeded, a fallback was used).
  - `INFO` — business-significant events (order placed, job finished).
  - `DEBUG` — off in production by default.
- Log once, where the error is handled. A failure logged at every layer it passes through becomes five lines for one error.
- Never log secrets, tokens, or full PII; redact in the logger configuration, not at each call site (see `backend-security`).

```python
import structlog

log = structlog.get_logger()

def capture_payment(order: Order) -> None:
    log_ctx = log.bind(order_id=order.id, amount_cents=order.total_cents)
    try:
        gateway.capture(order)
    except CardDeclined as exc:
        log_ctx.warning("payment_declined", decline_code=exc.code)
        raise
    log_ctx.info("payment_captured")
```

## Metrics

- **Request-driven services: RED** — rate, errors, duration for every endpoint and outbound dependency.
- **Resources: USE** — utilization, saturation, errors for pools, queues, CPU, memory, and disks. Saturation (queue depth, pool wait time) warns earliest.
- Record latency as a histogram and look at p95/p99, not the average; the average hides the slow tail users actually feel (see `performance-optimization`).
- Keep label cardinality bounded: `route="/orders/{id}"`, never `path="/orders/o-8f2c..."`; never user IDs, emails, or request IDs as labels. One unbounded label can multiply series count into the millions.
- Name metrics with units and a consistent scheme: `http_server_request_duration_seconds`, `orders_placed_total`.

## Distributed tracing

- Use OpenTelemetry for all three signals: vendor-neutral SDKs and wire format, so changing backends is a config change, not a re-instrumentation.
- Turn on auto-instrumentation for the HTTP server, HTTP/gRPC clients, database driver, and queue client first; it covers most spans for free. Add manual spans only around significant internal work.
- Propagate context across every boundary: W3C `traceparent` on HTTP/gRPC, message headers on queues. A trace that breaks at a queue hop loses the part you most need.
- Sample at the head for volume (e.g. 10%), and use tail-based sampling in the collector to keep 100% of errors and slow requests.

## SLOs and alerting

- Define SLOs from the user's point of view: "99.9% of checkout requests succeed and 99% complete in under 800 ms over 28 days." The remaining 0.1% is the error budget.
- Alert on symptoms users feel (SLO burn rate, error rate, latency), not on causes (CPU at 85%). Cause metrics go on dashboards for diagnosis.
- Use multi-window burn-rate alerts: page when the budget burns fast over both a short and a long window (e.g. 14× over 5 min and 1 h), and open a ticket when it burns slowly. This catches real incidents without paging on blips.
- Every page is actionable and links to a runbook. An alert that nobody acts on gets deleted or downgraded, not muted and left in place.

## Instrumenting a change — checklist

- [ ] New endpoint or job emits RED metrics and is covered by tracing
- [ ] New outbound dependency has a client span plus latency and error metrics
- [ ] Logs are structured, carry trace IDs, use the right level, and contain no secrets or PII
- [ ] No unbounded metric labels
- [ ] Context propagates across any new queue or async boundary
- [ ] User-facing behavior change is covered by an existing SLO, or a new one is proposed

## Common pitfalls

- Logging instead of metrics for counts (`log.info("request served")` × millions), which is expensive and slow to aggregate.
- Dashboards with dozens of panels and no SLO, where nobody can say whether the service is healthy.
- Health checks that return `200` without checking the dependencies the service needs, so the load balancer keeps routing to a broken instance.
- Alerts set on static thresholds copied from another service, causing noise or silence instead of signal.
