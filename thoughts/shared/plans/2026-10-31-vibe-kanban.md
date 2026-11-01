# Vibe Kanban (Remote Variant) Implementation Plan

**Goal:** Turn the old-format `vibe-kanban` skeleton into a working self-hosted
deployment stack for the BloopAI/vibe-kanban **remote (Cloud) variant** —
source-built `vk-remote-server` image + Postgres + ElectricSQL, wired into the
collection's nginx-proxy SSL environments.

**Architecture:** Three services in `app/components/base/docker-compose.yml`
(`remote-server` from a self-contained source-built image, `remote-db`
postgres:16-alpine with `wal_level=logical`, `electric` electricsql/electric:1.4.13).
Upstream's Caddy is replaced by the collection's letsencrypt/step-ca
environments (external proxy networks, `VIRTUAL_PORT=8081`, no in-app TLS).
The image is built standalone from `app/images/vk-remote-server/Dockerfile`
(empty build context, fetches the upstream release tarball itself); compose
references it via `image: ${IMAGE:-...}` — no `build:` section.

**Design:** thoughts/shared/designs/2026-10-31-vibe-kanban-design.md

**Stack repo:** `stacks/self-hosting/ai-services/automation/vibe-kanban`
(independent git repo, branch `master`, remote
`git@github.com:zyrakq/vibe-kanban-stack.git`). Commit style per the stack's
`.gitmessage`: header = verb in infinitive form, ≤50 chars.

---

## Design decisions (gap fills — implementer MUST follow these)

1. **Fetch strategy = release tarball.** Upstream has no git submodules and the
   tag `v0.1.45` exists → deterministic GitHub archive tarball
   (`https://github.com/BloopAI/vibe-kanban/archive/refs/tags/v<VERSION>.tar.gz`)
   via `ARG GITHUB_REPO` / `ARG VERSION`. No git history needed.
2. **No `--mount=type=ssh`.** The self-hosted build (empty `FEATURES`) strips
   the private billing crate from `crates/remote/Cargo.toml`, so no private
   repo / SSH access is needed. Dropping the ssh mount removes the ssh-agent
   requirement entirely (design's open verification point becomes moot).
   `openssh-client` + `ssh-keyscan` are dropped from the builder for the same
   reason; `git` stays (runtime needs it for agent worktrees anyway).
3. **Toolchain:** upstream pins `nightly-2025-12-04` in `rust-toolchain.toml`.
   The `rust:1.93-slim-bookworm` image ships rustup, so `cargo --version`
   auto-installs the pinned toolchain (upstream Dockerfile behavior, kept
   verbatim). Do NOT "fix" this to the image's default toolchain.
4. **`.env.example` lives at `app/components/base/.env.example`** (sb
   convention; the design's `app/.env.example` is shorthand for it).
5. **`VITE_RELAY_API_BASE_URL` is build-arg only.** Compose has no `build:`
   section, so the variable is inert at runtime; it is kept in `.env.example`
   with a comment explaining it only takes effect when rebuilding the image
   (`docker build --build-arg VITE_RELAY_API_BASE_URL=... `).
6. **Secrets fail fast:** `VIBEKANBAN_REMOTE_JWT_SECRET`, `DB_PASSWORD`,
   `ELECTRIC_ROLE_PASSWORD` use `${VAR:?...}` interpolation so `docker compose
   up` refuses to boot with placeholder secrets.
7. **Old `src/vibe-kanban/` is deleted** (stale v0.0.161-era local-variant
   configs, superseded by the new remote-variant `app/`; git history preserves
   it). `.vscode/` is KEPT — it disables submodule repo detection and is still
   correct after the module relocation. `.clinerules/` and `.kilocode/` are
   deleted per stack-modernize.
8. **`app/build/` is committed** (matches the kanidm exemplar; stack
   `.gitignore` only excludes `.env`).
9. **Sequential execution.** All tasks operate on ONE git repo (the stack) —
   parallel implementers would race on the git index. The executor MUST run
   tasks in the listed order, one commit per task. Batches express dependency
   order, not parallelism, for this plan.
10. **Volume/network naming:** explicit `name:` (`vk-db-data`,
    `vk-electric-data`, `vk-network`) per stack-conventions §3; `PROJECT_NAME=vk`
    in `.env.example` documents the `vk-` prefix convention.
11. **No step-ca-trust extension:** remote-server terminates no TLS and only
    talks to internal services (db, electric) plus external OAuth APIs via the
    system CA bundle — nothing needs to trust the step-ca CA.

---

## Dependency Graph

```
Batch 1 (sequential): 1.1 → 1.2 → 1.3        [stack modernization]
Batch 2 (after batch 1): 2.1                 [source-built image + build]
Batch 3 (after batch 1; parallel-safe files, sequential commits): 3.1..3.7
Batch 4 (after 2 + 3): 4.1 → 4.2 → 4.3       [sb build, validation, cleanup]
```

Batch 3 does NOT depend on Batch 2 (compose files reference the image tag
regardless), but Batch 4 does.

---

## Batch 1: Stack modernization (sequential, one commit each)

All commands run from the stack root:
`cd stacks/self-hosting/ai-services/automation/vibe-kanban`

### Task 1.1: Layout surgery — modules relocation + stale artifact removal
**File:** `.gitmodules` (modified), `modules/ssl-automation/*` (moved),
`src/` (removed), `.clinerules/`, `.kilocode/` (removed)
**Depends:** none

```bash
cd stacks/self-hosting/ai-services/automation/vibe-kanban

# 1. Relocate ssl-automation submodules to target format
mkdir -p modules
git mv src/ssl-automation modules/ssl-automation
# git mv updates .gitmodule paths for submodules moved with their parent dir;
# the sed is an idempotent safety net:
sed -i 's|path = src/ssl-automation/|path = modules/ssl-automation/|g' .gitmodules
git add .gitmodules
git submodule sync --recursive

# 2. Remove the stale local-variant project (v0.0.161-era, superseded by app/)
git rm -r src/vibe-kanban

# 3. Artifact cleanup (stack-modernize step 9)
git rm -r .clinerules .kilocode

# 4. Verify: no src/ left, modules present, .gitmodules paths updated
test ! -e src && echo OK-no-src
cat .gitmodules   # must show path = modules/ssl-automation/{letsencrypt,step-ca}-manager

git commit -m "Modernize layout to target format"
```

Resulting `.gitmodules`:

```git-config
[submodule "modules/ssl-automation/letsencrypt-manager"]
	path = modules/ssl-automation/letsencrypt-manager
	url = https://github.com/zyrakq/letsencrypt-manager-stack.git
[submodule "modules/ssl-automation/step-ca-manager"]
	path = modules/ssl-automation/step-ca-manager
	url = https://github.com/zyrakq/step-ca-manager-stack.git
```

**Verify:** `git status` clean; `git submodule status` shows both modules at
`modules/ssl-automation/...`; `ls modules/ssl-automation` shows both dirs.
**Commit:** `Modernize layout to target format`

### Task 1.2: UPSTREAM.md (stack provenance)
**File:** `UPSTREAM.md` (stack root, new)
**Depends:** 1.1 (so the row lands after the layout commit)

```markdown
# Upstream Provenance

## app — https://github.com/BloopAI/vibe-kanban

| date | upstream commit | image tag / digest | note |
|------|-----------------|--------------------|------|
| 2026-10-31 | 7c3807084daad0d9d315064f60fa869de254f027 | localhost/vk-remote-server:0.1.45 | initial dockerization (remote variant, no relay); source-built via app/images/vk-remote-server |
```

**Verify:** `test -f UPSTREAM.md && grep -c '7c380708' UPSTREAM.md`
**Commit:** `Add upstream provenance record`

### Task 1.3: Stack-root hub README
**File:** `README.md` (stack root, overwrite old skeleton README)
**Depends:** 1.1

````markdown
# 🎯 Vibe Kanban Stack

Self-hosted deployment of the Vibe Kanban Cloud (remote) variant — multi-user
Kanban for AI coding agents with GitHub/Google OAuth or bootstrap local
authentication, PostgreSQL persistence, and ElectricSQL real-time sync.

## 🧩 Components

### 🖥️ [Vibe Kanban Remote Server](app/)

The remote-server deployment: source-built `vk-remote-server` image, PostgreSQL
database, and ElectricSQL sync layer, with forwarding / letsencrypt / step-ca
environments behind the collection's nginx-proxy stacks.

### 🌐 [Let's Encrypt Manager](modules/ssl-automation/letsencrypt-manager/)

Automatic SSL certificate generation and renewal using Let's Encrypt for
production deployments with internet access.

### 🔒 [Step CA Manager](modules/ssl-automation/step-ca-manager/)

Self-signed trusted certificate authority for virtual Docker networks
without internet access. Automatically manages and distributes CA
certificates within isolated environments.

## 🚀 Quick Start

```bash
cd app
docker build -t localhost/vk-remote-server:0.1.45 images/vk-remote-server
sb build
cd build/forwarding   # or letsencrypt / step-ca
cp .env.example .env  # set secrets + auth config
docker compose up -d
```

See [`app/README.md`](app/README.md) for the full runbook.

## 📋 Requirements

- Docker & Docker Compose (BuildKit for the source image build)
- 4+ GB free RAM for the image build (10–15 min)
- Domain name (for production deployments)
- Email address (for Let's Encrypt)
- One auth method: GitHub or Google OAuth credentials, or bootstrap local auth

## 📄 License

This project is dual-licensed under:

- [Apache License 2.0](LICENSE-APACHE)
- [MIT License](LICENSE-MIT)
````

**Verify:** `test -f README.md && grep -c 'modules/ssl-automation' README.md`
**Commit:** `Add stack hub README`

---

## Batch 2: Source-built image

### Task 2.1: `app/images/vk-remote-server/Dockerfile`
**File:** `app/images/vk-remote-server/Dockerfile` (new)
**Test:** none (verified by the docker build below)
**Depends:** 1.1 (app/ path exists after layout surgery)

Based on upstream `crates/remote/Dockerfile` @ `7c38070`, adapted for the
self-contained tarball fetch (decisions 1–3 above):

```dockerfile
# syntax=docker/dockerfile:1.6
#
# Source-built image for the BloopAI/vibe-kanban remote (Cloud) variant.
# Fully self-contained: fetches the upstream release tarball itself and builds
# with an EMPTY build context (stack-conventions §15 — no vendored source).
#
# Self-hosted build (FEATURES empty) strips the private billing crate from
# crates/remote/Cargo.toml, so no SSH / private-repo access is needed and no
# --mount=type=ssh is used.
#
# Build standalone:
#   docker build -t localhost/vk-remote-server:<tag> images/vk-remote-server
#
# Requires BuildKit (cache mounts). Heavy: Rust nightly release build + pnpm
# frontend build, ~10-15 min, 4+ GB RAM.

ARG GITHUB_REPO=BloopAI/vibe-kanban
ARG VERSION=0.1.45
ARG APP_NAME=remote
ARG FEATURES=""
ARG VITE_RELAY_API_BASE_URL=""
ARG VITE_PUBLIC_REACT_VIRTUOSO_LICENSE_KEY=""
ARG POSTHOG_API_KEY=""
ARG POSTHOG_API_ENDPOINT=""
ARG SENTRY_DSN_REMOTE=""

# --- source stage: fetch upstream release tarball (no git history needed) ---
FROM alpine:3.20 AS source
ARG GITHUB_REPO
ARG VERSION
RUN apk add --no-cache tar wget \
 && wget -q -O /tmp/src.tar.gz \
      "https://github.com/${GITHUB_REPO}/archive/refs/tags/v${VERSION}.tar.gz" \
 && mkdir -p /repo \
 && tar -xzf /tmp/src.tar.gz -C /repo --strip-components=1 \
 && rm /tmp/src.tar.gz

# --- frontend builder (remote-web SPA, embedded at /srv/static) ---
FROM node:20-alpine AS fe-builder
ARG VITE_RELAY_API_BASE_URL
ARG VITE_PUBLIC_REACT_VIRTUOSO_LICENSE_KEY
WORKDIR /repo
ENV VITE_RELAY_API_BASE_URL=${VITE_RELAY_API_BASE_URL} \
    VITE_PUBLIC_REACT_VIRTUOSO_LICENSE_KEY=${VITE_PUBLIC_REACT_VIRTUOSO_LICENSE_KEY}

RUN corepack enable

# Copy manifests first so `pnpm install` is cached independently of source
COPY --from=source /repo/pnpm-lock.yaml /repo/pnpm-workspace.yaml /repo/package.json ./
COPY --from=source /repo/patches/ patches/
COPY --from=source /repo/packages/local-web/package.json packages/local-web/package.json
COPY --from=source /repo/packages/remote-web/package.json packages/remote-web/package.json
COPY --from=source /repo/packages/ui/package.json packages/ui/package.json
COPY --from=source /repo/packages/web-core/package.json packages/web-core/package.json

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY --from=source /repo/packages/remote-web/ packages/remote-web/
COPY --from=source /repo/packages/local-web/tailwind.new.config.js packages/local-web/tailwind.new.config.js
COPY --from=source /repo/packages/public/ packages/public/
COPY --from=source /repo/packages/ui/ packages/ui/
COPY --from=source /repo/packages/web-core/ packages/web-core/
COPY --from=source /repo/shared/ shared/

RUN pnpm -C packages/remote-web build

# --- rust builder (remote server binary) ---
FROM rust:1.93-slim-bookworm AS builder
ARG APP_NAME
ARG FEATURES
ARG POSTHOG_API_KEY
ARG POSTHOG_API_ENDPOINT
ARG SENTRY_DSN_REMOTE

ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse \
    CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CARGO_TARGET_DIR=/app/target \
    POSTHOG_API_KEY=${POSTHOG_API_KEY} \
    POSTHOG_API_ENDPOINT=${POSTHOG_API_ENDPOINT} \
    SENTRY_DSN_REMOTE=${SENTRY_DSN_REMOTE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=source /repo/ .

# rust-toolchain.toml pins nightly-2025-12-04; rustup in the rust image
# auto-installs it on first cargo invocation.
RUN cargo --version >/dev/null

RUN mkdir -p /app/bin

# Self-hosted build (FEATURES empty): strip the private billing dependency and
# its feature flag so cargo never fetches the private git repo; drop the
# crate-local Cargo.lock that references it.
RUN if [ -z "${FEATURES}" ]; then \
      sed -i '/^billing = {.*vibe-kanban-private.*/d' crates/remote/Cargo.toml; \
      sed -i '/^# private crate for billing/d' crates/remote/Cargo.toml; \
      sed -i 's/^vk-billing = \["dep:billing"\]/vk-billing = []/' crates/remote/Cargo.toml; \
      rm -f crates/remote/Cargo.lock; \
    fi

RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=cargo-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=remote-target,target=/app/target \
    cargo build ${FEATURES:+--locked} --release --manifest-path crates/remote/Cargo.toml ${FEATURES:+--features ${FEATURES}} \
 && cp /app/target/release/${APP_NAME} /app/bin/${APP_NAME}

# --- runtime ---
FROM debian:bookworm-slim AS runtime
ARG APP_NAME

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libssl3 wget git \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --create-home --uid 10001 appuser

WORKDIR /srv

COPY --from=builder /app/bin/${APP_NAME} /usr/local/bin/${APP_NAME}
COPY --from=fe-builder /repo/packages/remote-web/dist /srv/static

USER appuser

ENV SERVER_LISTEN_ADDR=0.0.0.0:8081 \
    RUST_LOG=info

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["wget","--spider","-q","http://127.0.0.1:8081/v1/health"]

ENTRYPOINT ["/usr/local/bin/remote"]
```

**Verify (long-running, 10–15 min, BuildKit required):**

```bash
cd stacks/self-hosting/ai-services/automation/vibe-kanban/app
docker build -t localhost/vk-remote-server:0.1.45 images/vk-remote-server
docker run --rm localhost/vk-remote-server:0.1.45 id   # expect uid=10001 appuser
```

If the build OOMs, add swap (upstream docs: 2G swapfile) or build on a bigger
host. Record build RAM/time behavior in the commit body.

**Commit:** `Add source-built remote-server image`

---

## Batch 3: App wiring (sequential commits, one file per task)

All paths relative to the stack root. Files are independent; commits are
sequential because they share the stack git index.

### Task 3.1: `app/stackbuilder.toml`
**Depends:** 1.1

```toml
[paths]
environments_path = "./environments"
extensions_dirs = []

[build]
copy_additional_files = true

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]
```

**Verify:** `cd app && sb build` exits 0 and creates `build/{forwarding,letsencrypt,step-ca}/docker-compose.yml` (full verification in Task 4.1).
**Commit:** `Add stackbuilder configuration`

### Task 3.2: `app/components/base/docker-compose.yml`
**Depends:** none (file-level)

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

services:
  remote-server:
    container_name: vk-remote-server
    image: ${IMAGE:-localhost/vk-remote-server:0.1.45}
    restart: unless-stopped
    logging: *default-logging
    depends_on:
      remote-db:
        condition: service_healthy
    environment:
      RUST_LOG: info,remote=info
      # Core runtime
      SERVER_DATABASE_URL: postgres://remote:${DB_PASSWORD:?set DB_PASSWORD in .env}@remote-db:5432/remote
      SERVER_LISTEN_ADDR: 0.0.0.0:8081
      ELECTRIC_URL: http://electric:3000
      ELECTRIC_ROLE_PASSWORD: ${ELECTRIC_ROLE_PASSWORD:?set ELECTRIC_ROLE_PASSWORD in .env}
      SERVER_PUBLIC_BASE_URL: ${SERVER_PUBLIC_BASE_URL:-http://localhost:8081}
      VIBEKANBAN_REMOTE_JWT_SECRET: ${VIBEKANBAN_REMOTE_JWT_SECRET:?set VIBEKANBAN_REMOTE_JWT_SECRET in .env}
      # Auth — configure at least one OAuth provider, or bootstrap local auth
      GITHUB_OAUTH_CLIENT_ID: ${GITHUB_OAUTH_CLIENT_ID:-}
      GITHUB_OAUTH_CLIENT_SECRET: ${GITHUB_OAUTH_CLIENT_SECRET:-}
      GOOGLE_OAUTH_CLIENT_ID: ${GOOGLE_OAUTH_CLIENT_ID:-}
      GOOGLE_OAUTH_CLIENT_SECRET: ${GOOGLE_OAUTH_CLIENT_SECRET:-}
      SELF_HOST_LOCAL_AUTH_EMAIL: ${SELF_HOST_LOCAL_AUTH_EMAIL:-}
      SELF_HOST_LOCAL_AUTH_PASSWORD: ${SELF_HOST_LOCAL_AUTH_PASSWORD:-}
      # Email / notifications (optional)
      LOOPS_EMAIL_API_KEY: ${LOOPS_EMAIL_API_KEY:-}
      LOOPS_INVITE_TEMPLATE_ID: ${LOOPS_INVITE_TEMPLATE_ID:-cmhvy2wgs3s13z70i1pxakij9}
      LOOPS_REVIEW_READY_TEMPLATE_ID: ${LOOPS_REVIEW_READY_TEMPLATE_ID:-cmj47k5ge16990iylued9by17}
      LOOPS_REVIEW_FAILED_TEMPLATE_ID: ${LOOPS_REVIEW_FAILED_TEMPLATE_ID:-cmj49ougk1c8s0iznavijdqpo}
      # Attachments (optional — only set when enabling blob storage)
      AZURE_STORAGE_ACCOUNT_NAME: ${AZURE_STORAGE_ACCOUNT_NAME:-}
      AZURE_STORAGE_ACCOUNT_KEY: ${AZURE_STORAGE_ACCOUNT_KEY:-}
      AZURE_STORAGE_CONTAINER_NAME: ${AZURE_STORAGE_CONTAINER_NAME:-}
      AZURE_STORAGE_ENDPOINT_URL: ${AZURE_STORAGE_ENDPOINT_URL:-}
      AZURE_STORAGE_PUBLIC_ENDPOINT_URL: ${AZURE_STORAGE_PUBLIC_ENDPOINT_URL:-}
      TZ: ${TZ:-UTC}
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://127.0.0.1:8081/v1/health"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    networks:
      - vk-network

  remote-db:
    container_name: vk-remote-db
    image: postgres:16-alpine
    command: ["postgres", "-c", "wal_level=logical"]
    restart: unless-stopped
    logging: *default-logging
    environment:
      POSTGRES_DB: remote
      POSTGRES_USER: remote
      POSTGRES_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      TZ: ${TZ:-UTC}
    volumes:
      - vk-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U remote -d remote"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 5s
    networks:
      - vk-network

  electric:
    container_name: vk-electric
    image: electricsql/electric:1.4.13
    working_dir: /app
    restart: unless-stopped
    logging: *default-logging
    environment:
      DATABASE_URL: postgresql://electric_sync:${ELECTRIC_ROLE_PASSWORD:?set ELECTRIC_ROLE_PASSWORD in .env}@remote-db:5432/remote?sslmode=disable
      PG_PROXY_PORT: 65432
      LOGICAL_PUBLISHER_HOST: electric
      AUTH_MODE: insecure
      ELECTRIC_INSECURE: true
      ELECTRIC_MANUAL_TABLE_PUBLISHING: true
      ELECTRIC_USAGE_REPORTING: false
      ELECTRIC_FEATURE_FLAGS: allow_subqueries,tagged_subqueries
      TZ: ${TZ:-UTC}
    volumes:
      - vk-electric-data:/app/persistent
    depends_on:
      remote-db:
        condition: service_healthy
      remote-server:
        condition: service_healthy
    networks:
      - vk-network

networks:
  vk-network:
    name: vk-network
    driver: bridge

volumes:
  vk-db-data:
    name: vk-db-data
  vk-electric-data:
    name: vk-electric-data
```

**Verify:** `docker compose -f app/components/base/docker-compose.yml config -q` with dummy env vars (see Task 4.1 command).
**Commit:** `Add base compose configuration`

### Task 3.3: `app/components/base/.env.example`
**Depends:** none (file-level)

```bash
# === BASE CONFIGURATION ===
# Project name for Docker Compose
COMPOSE_PROJECT_NAME=vibe-kanban

# Volume/network prefix convention
PROJECT_NAME=vk

# Prebuilt source-built image (build it first, see app/README.md)
IMAGE=localhost/vk-remote-server:0.1.45

# Logging
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

# nginx-proxy wiring (letsencrypt / step-ca environments)
VIRTUAL_PORT=8081
VIRTUAL_HOST=vk.example.com
LETSENCRYPT_HOST=vk.example.com
LETSENCRYPT_EMAIL=admin@example.com

# Public base URL used for OAuth callback construction.
# forwarding: http://<host>:8081 — letsencrypt/step-ca: https://<VIRTUAL_HOST>
SERVER_PUBLIC_BASE_URL=

# === SECRETS (openssl rand -base64 48) — all three are required ===
VIBEKANBAN_REMOTE_JWT_SECRET=
DB_PASSWORD=
ELECTRIC_ROLE_PASSWORD=

# === AUTH (configure at least one method) ===
# GitHub OAuth app: callback https://<domain>/v1/oauth/github/callback
GITHUB_OAUTH_CLIENT_ID=
GITHUB_OAUTH_CLIENT_SECRET=
# Google OAuth: redirect https://<domain>/v1/oauth/google/callback
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
# Bootstrap local auth (single shared admin credential)
SELF_HOST_LOCAL_AUTH_EMAIL=
SELF_HOST_LOCAL_AUTH_PASSWORD=

# === EMAIL (optional — leave empty to disable invitation emails) ===
LOOPS_EMAIL_API_KEY=
LOOPS_INVITE_TEMPLATE_ID=cmhvy2wgs3s13z70i1pxakij9
LOOPS_REVIEW_READY_TEMPLATE_ID=cmj47k5ge16990iylued9by17
LOOPS_REVIEW_FAILED_TEMPLATE_ID=cmj49ougk1c8s0iznavijdqpo

# === ATTACHMENTS (optional — Azure Blob Storage) ===
AZURE_STORAGE_ACCOUNT_NAME=
AZURE_STORAGE_ACCOUNT_KEY=
AZURE_STORAGE_CONTAINER_NAME=issue-attachments
AZURE_STORAGE_ENDPOINT_URL=
AZURE_STORAGE_PUBLIC_ENDPOINT_URL=

# === BUILD-ARG PASSTHROUGH (inert at runtime — no build: section) ===
# Only takes effect when rebuilding the image:
#   docker build --build-arg VITE_RELAY_API_BASE_URL=<url> images/vk-remote-server
# Empty = relay/tunnel feature disabled (out of scope for this stack).
VITE_RELAY_API_BASE_URL=

TZ=UTC
```

**Verify:** present in every generated `build/<env>/.env.example` after `sb build`.
**Commit:** `Add environment example file`

### Task 3.4: `app/components/environments/forwarding/docker-compose.yml`
**Depends:** 3.2 (service name)

```yaml
services:
  remote-server:
    ports:
      - "8081:8081"
```

**Verify:** included in `build/forwarding/docker-compose.yml`.
**Commit:** `Add forwarding environment`

### Task 3.5: `app/components/environments/letsencrypt/docker-compose.yml`
**Depends:** 3.2

```yaml
services:
  remote-server:
    environment:
      VIRTUAL_PORT: ${VIRTUAL_PORT:-8081}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PROTO: ${VIRTUAL_PROTO:-http}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      SERVER_PUBLIC_BASE_URL: ${SERVER_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}
    networks:
      - letsencrypt-network

networks:
  letsencrypt-network:
    name: letsencrypt-network
    external: true
```

Note: no certs volume — the server terminates no TLS; nginx-proxy does.
**Verify:** included in `build/letsencrypt/docker-compose.yml`.
**Commit:** `Add letsencrypt environment`

### Task 3.6: `app/components/environments/step-ca/docker-compose.yml`
**Depends:** 3.2

```yaml
services:
  remote-server:
    environment:
      VIRTUAL_PORT: ${VIRTUAL_PORT:-8081}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PROTO: ${VIRTUAL_PROTO:-http}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      SERVER_PUBLIC_BASE_URL: ${SERVER_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}
    networks:
      - step-ca-network

networks:
  step-ca-network:
    name: step-ca-network
    external: true
```

**Verify:** included in `build/step-ca/docker-compose.yml`.
**Commit:** `Add step-ca environment`

### Task 3.7: `app/README.md` (component README)
**Depends:** 3.1–3.6 (documents exactly what those files define)

````markdown
# 🎯 Vibe Kanban Remote Server

A modular Docker Compose configuration system for self-hosting the Vibe Kanban
Cloud (remote) variant — multi-user Kanban for AI coding agents with GitHub /
Google OAuth or bootstrap local authentication, PostgreSQL persistence, and
ElectricSQL real-time sync to the browser client.

## 🚀 Quick Start

### 0. Build the source image (once)

No upstream Docker image is published, so the remote-server image is built
from source (Rust nightly + pnpm; 10–15 min, 4+ GB RAM, BuildKit required):

```bash
docker build -t localhost/vk-remote-server:0.1.45 images/vk-remote-server
```

### 1. Build Configurations

```bash
sb build
```

This will create all environments in the `build/` directory based on
[`stackbuilder.toml`](stackbuilder.toml).

### 2. Choose Your Configuration

```bash
# For development with port forwarding
cd build/forwarding/

# For production with Let's Encrypt SSL
cd build/letsencrypt/

# For production with Step CA SSL
cd build/step-ca/
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env: set the three secrets and one auth method
openssl rand -base64 48   # for VIBEKANBAN_REMOTE_JWT_SECRET
```

### 4. Deploy

```bash
docker compose up -d
```

Access: `http://localhost:8081` (forwarding mode) or `https://<VIRTUAL_HOST>`
(proxy modes). First boot: the server runs migrations and creates the
`electric_sync` database role, then Electric starts.

## 📁 Project Structure

- [`components/`](components/) — Source compose components
  - [`base/`](components/base/) — Base three-service configuration
  - [`environments/`](components/environments/) — Environment-specific configurations
- [`images/`](images/) — Source-built image definitions (NOT part of `sb build`)
- [`build/`](build/) — Generated configurations (auto-generated, ready to deploy)
- [`stackbuilder.toml`](stackbuilder.toml) — Build configuration for stackbuilder

## 🔧 Available Configurations

### Environments

- **forwarding**: publishes port 8081 directly to the host
- **letsencrypt**: joins `letsencrypt-network`; nginx-proxy terminates TLS and
  routes to `remote-server:8081`
- **step-ca**: joins `step-ca-network`; same wiring with the step-ca stack

## 🔧 Environment Variables

### Base Configuration

- `COMPOSE_PROJECT_NAME`: Project name for Docker Compose (default: vibe-kanban)
- `PROJECT_NAME`: Volume/network prefix convention (default: vk)
- `IMAGE`: Prebuilt remote-server image (default: localhost/vk-remote-server:0.1.45)
- `LOG_MAX_SIZE` / `LOG_MAX_FILE` / `LOG_COMPRESS`: json-file log rotation
- `SERVER_PUBLIC_BASE_URL`: Public URL for OAuth callbacks (default: http://localhost:8081)
- `TZ`: Timezone (default: UTC)

### Secrets (all required)

- `VIBEKANBAN_REMOTE_JWT_SECRET`: JWT signing secret (`openssl rand -base64 48`)
- `DB_PASSWORD`: PostgreSQL password for the `remote` user
- `ELECTRIC_ROLE_PASSWORD`: Password for the `electric_sync` role the server
  creates on first startup

### Auth Configuration (at least one method)

- `GITHUB_OAUTH_CLIENT_ID` / `GITHUB_OAUTH_CLIENT_SECRET`: GitHub OAuth app
  (callback `https://<domain>/v1/oauth/github/callback`)
- `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET`: Google OAuth
  (redirect `https://<domain>/v1/oauth/google/callback`)
- `SELF_HOST_LOCAL_AUTH_EMAIL` / `SELF_HOST_LOCAL_AUTH_PASSWORD`: bootstrap
  local admin credential (single shared login)

### Optional Configuration

- `LOOPS_EMAIL_API_KEY`: transactional email (empty = invitation emails off)
- `LOOPS_INVITE_TEMPLATE_ID` / `LOOPS_REVIEW_READY_TEMPLATE_ID` /
  `LOOPS_REVIEW_FAILED_TEMPLATE_ID`: Loops template IDs (upstream defaults)
- `AZURE_STORAGE_ACCOUNT_NAME` / `AZURE_STORAGE_ACCOUNT_KEY` /
  `AZURE_STORAGE_CONTAINER_NAME` / `AZURE_STORAGE_ENDPOINT_URL` /
  `AZURE_STORAGE_PUBLIC_ENDPOINT_URL`: issue attachment blob storage
- `VITE_RELAY_API_BASE_URL`: build-arg passthrough only — inert at runtime;
  rebuild the image with it to enable relay (out of scope here)

### Let's Encrypt / Step CA Configuration

- `VIRTUAL_PORT`: Port for nginx-proxy (default: 8081)
- `VIRTUAL_HOST`: Domain for nginx-proxy
- `VIRTUAL_PROTO`: Protocol nginx-proxy expects (default: http)
- `LETSENCRYPT_HOST`: Domain for SSL certificate
- `LETSENCRYPT_EMAIL`: Email for certificate registration

## 🌐 Networks

- **forwarding**: `vk-network` (internal bridge)
- **letsencrypt**: `vk-network` + `letsencrypt-network` (external)
- **step-ca**: `vk-network` + `step-ca-network` (external)

## 🔒 Security

⚠️ **Production Checklist:**

- Generate all three secrets with `openssl rand -base64 48`; compose refuses
  to start when they are empty
- Configure OAuth with exact callback URLs, or set a strong
  `SELF_HOST_LOCAL_AUTH_PASSWORD`
- Set `SERVER_PUBLIC_BASE_URL` to the real public URL (OAuth callbacks break
  otherwise)
- Relay/tunnel support is intentionally out of scope (needs wildcard TLS)

## 🆘 Troubleshooting

**Build Issues:**
- Image build OOMs → add swap or build on a host with 4+ GB free RAM
- Build requires BuildKit (cache mounts); Docker 23+ has it by default

**Runtime Issues:**
- **ElectricSQL fails to connect**: the `electric_sync` role is created by the
  remote-server on first startup. Verify the server is healthy and
  `ELECTRIC_ROLE_PASSWORD` matches, then `docker compose restart electric`
- **Database connection refused**: check `docker compose logs remote-db`;
  the server retries, but `docker compose restart remote-server` helps after
  a slow first DB boot

**SSL Issues:**
- **Let's Encrypt**: verify domain DNS and letsencrypt-manager
- **Step CA**: check step-ca-manager and virtual network config

## 📝 Notes

- The `build/` directory is automatically generated and should not be edited manually
- Environment variables in generated files use `$VARIABLE_NAME` format for proper interpolation
- Each generated configuration includes a complete `docker-compose.yml` and `.env.example`
- Use `sb build` to regenerate all configurations after modifying components
- The image in `images/` is built standalone (empty build context, fetches
  upstream source itself) — never add a `build:` section to compose
- No generic OIDC: upstream auth is GitHub/Google OAuth or bootstrap local
  auth only, so there is no kanidm `oidc` extension for this stack
````

**Verify:** README documents every var present in `.env.example` (cross-check manually).
**Commit:** `Add component README`

---

## Batch 4: Build, validation, provenance cleanup

### Task 4.1: `sb build` + compose config validation
**Depends:** 2.1, 3.1–3.6

```bash
cd stacks/self-hosting/ai-services/automation/vibe-kanban/app
sb build

# Validate every generated environment (dummy secrets satisfy :? checks)
for env in forwarding letsencrypt step-ca; do
  VIBEKANBAN_REMOTE_JWT_SECRET=x DB_PASSWORD=x ELECTRIC_ROLE_PASSWORD=x \
  VIRTUAL_HOST=vk.example.com LETSENCRYPT_HOST=vk.example.com \
  LETSENCRYPT_EMAIL=a@b.c \
    docker compose -f "build/$env/docker-compose.yml" config -q \
    && echo "$env OK"
done

# Sanity: image reference has no build: section anywhere
! grep -rn 'build:' build/*/docker-compose.yml
grep -n 'image: ${IMAGE:-localhost/vk-remote-server:0.1.45}' build/forwarding/docker-compose.yml

git add build
git commit -m "Add generated build configurations"
```

If `sb build` misbehaves, consult `STASKBUILDER.md` at the collection root and
record the obstacle in `PITFALLS.md` (stack-conventions §14).

**Verify:** all three `config -q` pass; `git status` clean.
**Commit:** `Add generated build configurations`

### Task 4.2: Catalog status update (collection repo)
**Depends:** 4.1

```bash
cd /home/archuser/projects/docker-stack-collection
sed -i \
  's|stacks/self-hosting/ai-services/automation/vibe-kanban;https://github.com/zyrakq/vibe-kanban-stack.git;incomplete|stacks/self-hosting/ai-services/automation/vibe-kanban;https://github.com/zyrakq/vibe-kanban-stack.git;unverified|' \
  stacks.csv
git add stacks.csv
git commit -m "Mark vibe-kanban stack unverified"
```

(`unverified` = likely finished, not browser-confirmed — per the catalog's
status semantics.)

**Verify:** `grep vibe-kanban stacks.csv` shows `unverified`.
**Commit:** in the collection repo (above).

### Task 4.3: Deployment test + clone cleanup
**Depends:** 4.1

1. Follow the `stack-test` skill: step-ca variant first (never touching the
   live step-ca-manager setup), health checks (`docker compose ps` — all three
   services healthy), then browser Stage A: login via bootstrap local auth,
   create an organisation and a project. Stage B (OIDC) is N/A — no generic
   OIDC support; optionally verify GitHub OAuth instead.
2. Record any obstacle in `PITFALLS.md`.
3. **Clone cleanup (mandatory, §13):** the UPSTREAM.md row was already
   appended in Task 1.2, so remove the reference clone:

```bash
rm -rf /tmp/opencode/upstreams/vibe-kanban
```

**Verify:** `test ! -d /tmp/opencode/upstreams/vibe-kanban && echo cleaned`.

---

## Out of scope (deferred by design)

- Relay/tunnel support (needs `*.relay.<domain>` wildcard TLS — incompatible
  with HTTP-challenge proxy stacks). Future work; `VITE_RELAY_API_BASE_URL`
  stays empty.
- Generic OIDC / kanidm `oidc` extension — upstream has no generic OIDC.
- `azurite` attachments dev-profile from upstream's dev compose — production
  stacks use real `AZURE_STORAGE_*` only.

---

## Batch 5: Conformance rework (2026-11-01)

Run 1 of 2 (file rework + `sb build` + `docker compose config` validation —
no image build, no compose up, no browser testing):

- Task A: `git mv app/images/vk-remote-server app/images/vibe-kanban-remote-server`;
  Dockerfile header §15 → §19, build command updated (commit 14252d3).
- Task B: base compose rewritten to `vibe-kanban-app` + `vibe-kanban-electric`
  only — no db service, no ports, no `SERVER_PUBLIC_BASE_URL`; all env
  `${VAR:-}`/`${VAR:?}` wired (commit 14252d3).
- Task C: `components/extensions/database/{postgresql,pgrust}/` pair created
  (patch + `docker-compose.db.yml` + `.env.example` each; `wal_level=logical`
  in both; `POSTGRES_INITDB_ARGS` hardcoded) (commit c619b04).
- Task D: env overlays renamed to `vibe-kanban-app`; forwarding owns
  `SERVER_PUBLIC_BASE_URL` + `VIBEKANBAN_PORT`; per-env `.env.example`
  fragments created (commit b6f21ba).
- Task E/F: base `.env.example` reduced to referenced vars; stackbuilder.toml
  rewritten with the combos idiom (commit 3452ff2).
- Task G: `sb build` → `build/<env>/{postgresql,pgrust}/` (6 variants);
  `skip_base_generation = true` added after sb auto-generated a broken
  no-extension `base` variant (P-010); rust merger deep-merges `depends_on` —
  electric depends on BOTH app and db, no fallback needed; all 6 variants
  pass `docker compose config` (commit 05c7004).
- Task H: hub + component READMEs regenerated (commit 7868310).
- Task I: UPSTREAM.md row appended (commit 3260a37); `stacks.csv` status set
  back to `incomplete` (Stage A not yet passed).

Run 2 (pending): image build, Stage A gate (base + postgresql, forwarding
variant, browser E2E via bootstrap local auth), then Stage A2 (pgrust combo —
clean pass makes pgrust the default), letsencrypt/step-ca browser gates need
a real domain from the user.
