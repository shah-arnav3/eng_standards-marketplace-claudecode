---
name: system-security
description: System and host/OS-level security vulnerability scanning — least-privilege OS accounts, container hardening, patch management, filesystem permissions, and secure defaults for compute infrastructure. Use whenever reviewing server/container/OS hardening, Dockerfiles, deployment configuration, or the user mentions system security, container security, or host hardening.
---

# System / Host Security Vulnerability Scanning

## Least-privilege execution

- Application processes run as a non-root, dedicated user with only the filesystem/capability access they need — never root, and never a shared "app" user across unrelated services.
- Containers run as a non-root user explicitly (most base images default to root unless told otherwise) and drop unnecessary Linux capabilities (`--cap-drop=ALL`, add back only what's required).

```dockerfile
FROM node:20-slim
RUN groupadd -r app && useradd -r -g app app
WORKDIR /app
COPY --chown=app:app . .
USER app
CMD ["node", "server.js"]
```

## Container hardening

- Build from minimal base images (distroless, `-slim`/`-alpine` variants) to shrink the attack surface and reduce the number of exploitable packages present at runtime.
- Multi-stage builds so build tools and source-only dependencies never ship in the final runtime image.
- Read-only root filesystem (`--read-only`) with explicit writable volumes only where the application genuinely needs to write (temp dirs, upload targets).
- No secrets baked into image layers (`ENV`/`ARG` with a credential, or a `COPY` of a credentials file) — layers persist in the image history even if a later layer deletes the file. Inject secrets at runtime instead.
- Scan images for known CVEs in base OS packages before deploying (Trivy, Grype, or the registry's built-in scanner) — see the `dependency-audit` skill for the same discipline applied to application dependencies.

```dockerfile
# WRONG — secret baked into a layer, recoverable from image history even after deletion
ARG API_KEY
RUN echo $API_KEY > /app/.env

# RIGHT — injected at runtime, never part of the image
# (docker run -e API_KEY=... or a mounted secret / orchestrator secret store)
```

## Patch management

- Automated, scheduled patching for OS packages and base container images — a pinned image tag that's never rebuilt silently accumulates unpatched CVEs over time even though "nothing changed" in your own code.
- Track and remediate critical/high CVEs on a defined SLA (e.g., critical within days, high within weeks) rather than an ad hoc "when we get to it" cadence.
- Subscribe to security advisories for the specific base images/runtimes in use so a zero-day is noticed promptly, not discovered during an unrelated audit.

## Filesystem and permissions

- Principle of least privilege on file permissions: config/credential files readable only by the service account that needs them (`chmod 600`), never world-readable.
- No world-writable directories that a compromised process could use to plant executable content.
- Separate mutable data directories from the application code directory, so a compromised app process can't rewrite its own executable code on disk.

## Host/VM hardening

- Disable unused services and remove unused packages from the base image/AMI — every running service is additional attack surface, whether or not it's ever intentionally used.
- Enforce host-level firewall rules in addition to cloud-level security groups/NSGs (defense in depth) for anything with a broader network reach than strictly necessary.
- Centralized, immutable logging (shipped off-host immediately) so a compromised host's local logs can't be tampered with to hide an intrusion.

## Secure defaults for orchestration (Kubernetes and equivalents)

- Pod Security Standards/Admission enforced (`restricted` profile as the default posture): no privileged containers, no host network/PID/IPC namespace sharing, no privilege escalation.
- Network policies to enforce the same segmentation principle as the network-security skill, expressed at the cluster level — default deny between namespaces/services that don't need to talk to each other.
- Secrets mounted via the orchestrator's secret mechanism (backed by an external secrets manager) rather than plain Kubernetes Secrets (base64-encoded, not encrypted, by default) without additional encryption at rest configured.

## Quick scan checklist

- [ ] Processes/containers run as non-root with minimal capabilities
- [ ] Container images are minimal, multi-stage, and free of baked-in secrets
- [ ] Images/hosts scanned for known CVEs and patched on a defined SLA
- [ ] File permissions follow least privilege; no world-writable directories
- [ ] Unused services/packages removed from base images and hosts
- [ ] Orchestration enforces non-privileged pods and network policies (default deny)
- [ ] Logs shipped off-host immediately, not solely stored locally
