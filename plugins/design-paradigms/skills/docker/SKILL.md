---
name: docker
description: Modern Docker and container image practices — Dockerfile structure, layer caching, multi-stage builds, BuildKit cache and secret mounts, base image pinning, signal handling and PID 1, health checks, image tagging, multi-arch builds, and Docker Compose for local development. Use whenever writing or reviewing a Dockerfile, .dockerignore, or compose.yaml, containerizing an application, debugging slow builds or large images, or the user mentions Docker, containers, BuildKit, buildx, or Docker Compose.
---

# Docker and Container Images

A good image builds fast from cache, contains only what the process needs to run, starts and stops cleanly under an orchestrator, and is reproducible from a tag. Security hardening (non-root users, capability drops, CVE scanning, secrets) is covered in the `system-security` skill; apply it alongside this one.

## Dockerfile structure and layer caching

Each instruction is a cached layer, and a change invalidates that layer and every layer after it. Order instructions from least to most frequently changing:

1. Base image
2. System packages
3. Dependency manifests (`package.json` + lockfile, `requirements.txt`, `go.mod`/`go.sum`)
4. Dependency install
5. Application source
6. Build step

Copying the whole source tree before installing dependencies means every code change reinstalls every dependency.

```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim@sha256:<digest> AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

FROM node:22-bookworm-slim@sha256:<digest> AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM gcr.io/distroless/nodejs22-debian12@sha256:<digest> AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER nonroot
EXPOSE 8080
CMD ["dist/server.js"]
```

- **Multi-stage builds**: compilers, dev dependencies, and source stay in build stages; the runtime stage copies only artifacts. For compiled languages the runtime stage can be `distroless/static` or `scratch` with a single binary.
- **Install from the lockfile** (`npm ci`, `pip install --require-hashes -r`, `go mod download`), never a floating resolve, so the same commit builds the same image.
- **Combine package-manager steps in one `RUN`** and clean up in the same layer (`apt-get update && apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*`). Deleting files in a later layer doesn't shrink the image.
- **BuildKit cache mounts** (`--mount=type=cache`) keep package caches between builds without putting them in the image.
- **Build-time secrets** (private registry tokens) use `RUN --mount=type=secret,id=npmrc,target=/root/.npmrc`, never `ARG` or `COPY` — those persist in image history.

## .dockerignore

The build context is everything sent to the builder; without a `.dockerignore`, `.git`, `node_modules`, local `.env` files, and build output are sent and can leak into a `COPY . .`.

```
.git
node_modules
dist
*.log
.env*
Dockerfile*
compose*.yaml
```

Prefer an allowlist for large repos: ignore `*` and re-include what the build needs (`!src/`, `!package*.json`).

## Base images and pinning

- Choose the smallest base that runs the app: `distroless` or `scratch` for static binaries, `-slim` Debian variants for interpreted runtimes. Alpine's musl libc can break native modules and change DNS and performance behavior; use it only after testing.
- Pin by digest (`image:tag@sha256:...`) for reproducible builds, and let Dependabot or Renovate open PRs to bump the digest. A floating tag (`node:22`) changes under you; a pinned digest that's never bumped accumulates CVEs (see `system-security` on patching).
- Never use `latest` for a base image.

## Runtime behavior

- **Exec form for `CMD`/`ENTRYPOINT`** (`["node", "server.js"]`). Shell form (`CMD node server.js`) runs the app under `/bin/sh`, which doesn't forward `SIGTERM`, so the orchestrator waits for its timeout and then kills the process mid-request.
- **PID 1**: a process running as PID 1 gets no default signal handlers and must reap zombie children. Handle `SIGTERM` explicitly in the app (stop accepting work, drain, exit), and use `docker run --init` or `tini` when the process spawns children.
- **One concern per container.** Run the web process and the worker as separate containers from the same image with different commands, not under a process supervisor in one container.
- **Logs to stdout/stderr**, unbuffered (`PYTHONUNBUFFERED=1`), as structured lines (see `observability`). The platform collects them; don't write log files inside the container.
- **Configuration from environment variables** at runtime, so one image is promoted unchanged from staging to production. Anything environment-specific baked into the image forces a rebuild per environment.
- **Treat the container filesystem as disposable.** Persistent data goes in volumes or external services; run with a read-only root filesystem where possible.

## Health checks

- Expose a cheap health endpoint and wire it to the orchestrator's probes (Kubernetes liveness/readiness) or to `HEALTHCHECK` for plain Docker and Compose.
- Liveness answers "is the process stuck?" and must not check dependencies, or a database blip restarts every replica. Readiness answers "can it serve traffic now?" and may check them.
- Distroless images have no shell or `curl`; ship a tiny health-check binary or rely on orchestrator HTTP probes instead of `HEALTHCHECK CMD curl ...`.

## Tagging and publishing

- Tag every image with an immutable identifier: the git commit SHA, plus a semver tag for releases. Deploy by SHA or digest so a rollback redeploys exactly the previous artifact.
- `latest` may exist as a convenience pointer but is never what an environment deploys.
- Build multi-arch images (`docker buildx build --platform linux/amd64,linux/arm64`) when developers run Apple Silicon and production runs x86, or when deploying to ARM instances.
- Add OCI labels (`org.opencontainers.image.source`, `.revision`, `.created`) so an image can be traced back to its commit.

## Docker Compose for local development

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    env_file: .env.local
    depends_on:
      db:
        condition: service_healthy
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
  db:
    image: postgres:17@sha256:<digest>
    environment:
      POSTGRES_PASSWORD: local-only
    volumes: ["db-data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 10
volumes:
  db-data:
```

- `depends_on` with `condition: service_healthy` waits for readiness; plain `depends_on` only waits for the container to start.
- Use named volumes for data and `develop.watch` or bind mounts for live code reload.
- Compose is a local and CI tool. Production runs on an orchestrator whose config is defined as code (see `cloud-design`).

## Common pitfalls

- `COPY . .` before dependency install, so every code change busts the dependency cache.
- Shell-form `CMD`, causing slow, unclean shutdowns on every deploy.
- `apt-get update` in its own `RUN` layer, which caches a stale package index and installs outdated packages later.
- Building different images per environment instead of one image configured at runtime.
- Running `docker build` without BuildKit features (`# syntax=docker/dockerfile:1`), losing cache and secret mounts.
- Mounting the Docker socket (`/var/run/docker.sock`) into a container, which gives it root on the host.

## Review checklist

- [ ] Instructions ordered for caching; dependencies installed from the lockfile before source is copied
- [ ] Multi-stage build; runtime stage contains only runtime artifacts
- [ ] `.dockerignore` excludes `.git`, local env files, dependencies, and build output
- [ ] Base images pinned by digest, with automated bump PRs
- [ ] Exec-form `CMD`/`ENTRYPOINT`; app handles `SIGTERM` and drains
- [ ] Logs to stdout; configuration from environment variables
- [ ] Health endpoint wired to probes; liveness doesn't check dependencies
- [ ] Image tagged with commit SHA; deploys reference the SHA or digest
- [ ] Hardening from `system-security` applied (non-root, no baked secrets, scanned)
