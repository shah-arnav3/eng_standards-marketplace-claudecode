---
name: frontend-security
description: Frontend and client-side security vulnerability scanning — XSS, CSRF, clickjacking, insecure storage of tokens, content security policy, and third-party script risk. Use whenever reviewing frontend/client-side code for security issues, working with cookies/localStorage/tokens in the browser, or the user mentions XSS, CSP, or frontend security.
---

# Frontend Security Vulnerability Scanning

The client is an untrusted environment the attacker fully controls (they can modify JS, inspect network calls, tamper with storage) — frontend security is about preventing the browser from being tricked into harming the user or their session, not about hiding logic from a sufficiently motivated user.

## Cross-Site Scripting (XSS)

- **Stored/Reflected XSS**: never inject user-controlled data into the DOM as raw HTML. Modern frameworks (React, Vue, Angular) escape by default in normal templating — the vulnerability appears the moment that default is bypassed.

```jsx
// WRONG — bypasses React's default escaping, executes injected script tags/handlers
<div dangerouslySetInnerHTML={{ __html: userComment }} />

// RIGHT — rendered as text, not parsed as HTML
<div>{userComment}</div>

// If raw HTML is genuinely required, sanitize first with an allowlist-based sanitizer
import DOMPurify from "dompurify";
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />
```

- **DOM-based XSS**: avoid `eval()`, `new Function()`, `document.write`, and assigning untrusted data to `innerHTML`/`href`/`src` without validation — including via URL query parameters read directly into the DOM.
- **javascript: URLs**: validate/strip any user-supplied URL used in an `href`/`src` — reject the `javascript:` scheme explicitly rather than assuming it won't appear.

## Cross-Site Request Forgery (CSRF)

- For any cookie-based session auth, use `SameSite=Lax` or `Strict` cookies as the primary defense, plus a CSRF token (double-submit cookie or synchronizer token pattern) for state-changing requests as defense in depth.
- Token/header-based auth (`Authorization: Bearer <token>` not stored in a cookie) is inherently immune to classic CSRF, since the browser won't attach it automatically to a cross-origin request — but see token storage below for the trade-off this introduces.

## Token and session storage

- **`localStorage`/`sessionStorage` for auth tokens is readable by any script that executes on the page** — a single XSS bug becomes full session takeover. Prefer an `HttpOnly`, `Secure`, `SameSite` cookie for session tokens, which JavaScript cannot read even if XSS occurs.
- If a bearer token must be held client-side (e.g., an SPA calling a separate API domain where cookies aren't viable), keep it in memory (a JS variable/module state) rather than persistent storage, and accept the trade-off of re-authenticating on full page reload, refreshed via an HttpOnly refresh-token cookie.

## Clickjacking

- Set `X-Frame-Options: DENY` (or `SAMEORIGIN` if legitimate framing is needed) or the equivalent `Content-Security-Policy: frame-ancestors` directive on any page that performs a sensitive action, to prevent it being framed invisibly on an attacker's page.

## Content Security Policy (CSP)

- Define a CSP that disallows `unsafe-inline`/`unsafe-eval` for scripts wherever feasible — this is the single strongest structural mitigation against XSS, since it blocks injected inline scripts from executing even if an injection point exists.

```
Content-Security-Policy: default-src 'self'; script-src 'self' https://trusted-cdn.example; object-src 'none'; frame-ancestors 'none';
```

- Use a nonce or hash-based allowlist for any inline script that's genuinely required, generated per-request server-side — never a static, guessable nonce.

## Third-party scripts and supply-chain risk on the client

- Every third-party script (analytics, ads, chat widgets) executes with the same DOM access as first-party code — a compromised or malicious third-party script can exfiltrate anything on the page, including form input.
- Use Subresource Integrity (`integrity="sha384-..."` on `<script>`/`<link>` tags) for any script loaded from a CDN, so a tampered file fails to execute rather than silently running.
- Load third-party scripts from an isolated context (an iframe with a restrictive `sandbox` attribute) where the script doesn't need full page access.

## Sensitive data exposure in the client

- Never ship secrets (API keys meant to be server-only, internal service URLs) in frontend bundles — anything in client-side JavaScript is public, regardless of minification/obfuscation.
- Avoid logging sensitive data (tokens, full card numbers, passwords) to the browser console, even temporarily during development — it's easy to forget to remove.

## Quick scan checklist

- [ ] No `dangerouslySetInnerHTML`/`innerHTML`/`v-html` with unsanitized user input
- [ ] No `eval`, `new Function`, or `document.write` on any path touching user input
- [ ] Session tokens in `HttpOnly` cookies where possible, not `localStorage`
- [ ] `SameSite` cookie attribute set; CSRF token present on state-changing requests if using cookie auth
- [ ] `X-Frame-Options`/`frame-ancestors` set on sensitive pages
- [ ] CSP defined without blanket `unsafe-inline`/`unsafe-eval`
- [ ] Third-party `<script>` tags from a CDN carry Subresource Integrity hashes
- [ ] No secrets or internal URLs present in the client bundle
