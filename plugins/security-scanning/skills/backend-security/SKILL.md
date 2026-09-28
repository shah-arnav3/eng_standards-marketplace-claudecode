---
name: backend-security
description: Backend and application-layer security vulnerability scanning — injection flaws, broken authentication/authorization, insecure deserialization, SSRF, business logic flaws, and secrets management, aligned to OWASP Top 10 / ASVS. Use whenever reviewing backend/API code for security issues, designing authentication or authorization, or the user mentions backend security, OWASP, or vulnerability scanning for server-side code.
---

# Backend Security Vulnerability Scanning

Scan backend code against this checklist, organized by the vulnerability classes most likely to appear in server-side application code (aligned to OWASP Top 10 / ASVS).

## Injection (SQL, command, LDAP, NoSQL, template)

- Any SQL built via string concatenation or f-strings with user input is a vulnerability, regardless of "it's just an internal admin tool" — always use parameterized queries/prepared statements.
- Any use of `os.system`/`subprocess` with `shell=True`/`exec()`/`eval()` fed by user input is a command injection risk — use argument-array APIs (`subprocess.run([...])` without `shell=True`) and never build a shell string from user input.
- Template engines rendering user-controlled template strings (server-side template injection) — user input must be data passed to a template, never the template source itself.

```python
# WRONG — SQL injection
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# RIGHT — parameterized
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

## Broken authentication

- Passwords hashed with a slow, salted algorithm designed for it (bcrypt/scrypt/Argon2) — never MD5/SHA-256 alone, which are fast-hash algorithms vulnerable to brute force/rainbow tables.
- Session tokens/JWTs: short expiry, secure random generation, signature verification on every use (reject `alg: none`), and revocation capability for refresh tokens.
- Rate limiting and account lockout (with care to avoid a lockout-based denial-of-service) on login/password-reset endpoints to prevent credential stuffing and brute force.
- Multi-factor authentication available for sensitive accounts/actions; password reset flows use single-use, short-lived, unguessable tokens sent out of band.

```python
import bcrypt
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
```

## Broken access control / authorization

- Enforce authorization on every request server-side — never trust a hidden field, a disabled button, or a client-side role check as the actual control.
- Check object-level authorization on every request that references an id (`/orders/{id}`) — confirm the authenticated principal actually owns/can access that specific object (Insecure Direct Object Reference / IDOR is one of the most common real-world vulnerabilities).

```python
# WRONG — no ownership check, any authenticated user can read any order
@app.get("/orders/{order_id}")
def get_order(order_id: str, user: User = Depends(current_user)):
    return db.get_order(order_id)

# RIGHT — verify the resource belongs to the requester
@app.get("/orders/{order_id}")
def get_order(order_id: str, user: User = Depends(current_user)):
    order = db.get_order(order_id)
    if order is None or order.customer_id != user.id:
        raise HTTPException(404)  # 404, not 403 — don't confirm existence to a non-owner
    return order
```

- Default deny: a new endpoint/role with no explicit permission grant should be inaccessible, not accessible-by-default.

## Insecure deserialization

- Never deserialize untrusted data with a format that can execute code as a side effect (Python `pickle`, Java native serialization, Ruby `Marshal`, unrestricted YAML `load`) — use a safe, data-only format (JSON, `yaml.safe_load`) for anything crossing a trust boundary.
- If a legacy format must be kept, sign/HMAC the payload and verify before deserializing, and use an allowlist of permitted classes/types.

## Server-Side Request Forgery (SSRF)

- Any backend feature that fetches a URL supplied by the user (webhook registration, "import from URL", link preview) can be abused to reach internal-only services/metadata endpoints unless mitigated.
- Validate and restrict the destination: resolve DNS and block private/link-local/metadata IP ranges, disallow redirects to a different host than validated, and use an allowlist of permitted schemes/hosts where the use case allows it.

## Secrets management

- No secrets/API keys/credentials committed to source control, ever — use a secrets manager (Vault, AWS Secrets Manager, Azure Key Vault) or environment variables injected at deploy time, and add a pre-commit secret scanner as a backstop.
- Rotate credentials on a schedule and immediately on suspected exposure; scope each credential to the minimum permission it needs (see cloud IAM guidance in `cloud-design`).
- Never log secrets, tokens, or full payment/PII data — redact at the logging layer, not by hoping call sites remember to.

## Business logic flaws

- Re-validate business invariants server-side even when the client "shouldn't" allow an invalid state (negative quantities, discount stacking beyond policy, race conditions in a "redeem once" coupon).
- Idempotency keys on any operation that has a financial/state-changing side effect and might be retried (payment capture, order placement) to prevent duplicate execution from retries or replay.

## Quick scan checklist

- [ ] All SQL/shell/template construction is parameterized, never string-concatenated with user input
- [ ] Passwords hashed with bcrypt/scrypt/Argon2, never a fast general-purpose hash
- [ ] Every endpoint enforces both authentication and object-level authorization server-side
- [ ] No unsafe deserialization of untrusted data (`pickle`, native serialization, unrestricted YAML)
- [ ] User-supplied URLs fetched server-side are validated against SSRF (private IP ranges, redirects)
- [ ] No secrets in source control, logs, or error messages
- [ ] Rate limiting on auth and other abuse-prone endpoints
- [ ] Financial/state-changing operations are idempotent and re-validated server-side
