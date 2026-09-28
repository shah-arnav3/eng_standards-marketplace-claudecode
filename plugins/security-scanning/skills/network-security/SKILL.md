---
name: network-security
description: Network-layer security vulnerability scanning — TLS configuration, firewall and segmentation rules, exposed ports/services, DNS security, and API gateway/rate-limiting posture. Use whenever reviewing network architecture, firewall/security group rules, TLS configuration, or the user mentions network security, exposed ports, or infrastructure hardening.
---

# Network Security Vulnerability Scanning

## Transport encryption (TLS)

- TLS 1.2 minimum, prefer TLS 1.3 wherever the stack supports it; disable SSLv3/TLS 1.0/1.1 entirely — they have known, exploitable weaknesses.
- Strong cipher suites only (AEAD ciphers — AES-GCM, ChaCha20-Poly1305); disable legacy ciphers (RC4, single-DES, export-grade ciphers, CBC-mode ciphers where AEAD is available).
- Certificates from a trusted CA with automated renewal (ACME/Let's Encrypt or a managed cloud certificate service) — no long-lived manually-renewed certs that lapse silently.
- HSTS (`Strict-Transport-Security`) on every public-facing HTTP service, with `includeSubDomains` and a meaningful `max-age`, to prevent downgrade to plain HTTP.
- Internal service-to-service traffic encrypted too (mTLS via a service mesh, or TLS termination at each hop) — "it's inside the VPC" is not encryption.

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

## Firewall rules and network segmentation

- Default-deny inbound; explicitly allow only the ports/protocols a service actually needs.
- No management ports (SSH 22, RDP 3389, database ports) exposed to `0.0.0.0/0` — restrict to a bastion host, VPN, or specific known IP ranges.
- Segment networks by trust tier: public-facing load balancers in one tier, application servers in a private tier reachable only from the load balancer tier, data stores in a tier reachable only from the application tier. A compromised public-facing host should not have a direct network path to the database.
- Egress filtering, not just ingress — an application server with unrestricted outbound access is a much more useful pivot point for an attacker who's already gained a foothold; restrict egress to only what's needed (specific API endpoints, package registries).

```
# Example security group intent, described declaratively
ingress: 443/tcp from 0.0.0.0/0          # public HTTPS only
ingress: 5432/tcp from app-tier-sg only  # DB reachable only from app tier
ingress: 22/tcp from bastion-sg only     # SSH only via bastion
egress:  443/tcp to specific-api-ranges  # no unrestricted outbound
```

## Exposed services and attack surface

- Enumerate every publicly reachable port/service and justify each one — an unused exposed admin panel, debug endpoint, or default-credential service (Redis, MongoDB, Elasticsearch with no auth) is one of the most common breach vectors in practice, not a theoretical one.
- Disable/remove default accounts and default credentials on every exposed service before it goes live.
- Close debug/profiling endpoints (e.g., a framework's debug console) in production builds — many frameworks enable a stack-trace-revealing or code-execution-capable debug mode by default in development that must be explicitly disabled for production.

## DNS security

- DNSSEC where the domain registrar/DNS provider supports it, to prevent DNS spoofing/cache poisoning.
- Monitor for dangling DNS records (a CNAME pointing to a deprovisioned cloud resource) — these enable subdomain takeover, where an attacker claims the now-unclaimed cloud resource and serves content under your domain.
- Restrict zone transfer (`AXFR`) to authorized secondary nameservers only.

## API gateway and rate limiting

- Rate limit at the network/gateway layer (not only in application code) so a flood of requests is absorbed before reaching application servers.
- Apply stricter limits to expensive or sensitive endpoints (auth, search, export) than to cheap ones.
- Use a Web Application Firewall (WAF) or equivalent for public-facing APIs to catch common attack signatures (injection patterns, known bad user agents/IP reputation) as a defense-in-depth layer, not a substitute for fixing the underlying application vulnerability.

## Quick scan checklist

- [ ] TLS 1.2+ only, strong AEAD cipher suites, valid auto-renewing certificates
- [ ] HSTS enabled on all public HTTP(S) services
- [ ] No management/database ports exposed to the public internet
- [ ] Network segmented by trust tier with least-path connectivity between tiers
- [ ] Egress filtered, not just ingress
- [ ] No exposed service running with default credentials or no auth
- [ ] Debug/profiling endpoints disabled in production
- [ ] Rate limiting and/or a WAF in front of public APIs
