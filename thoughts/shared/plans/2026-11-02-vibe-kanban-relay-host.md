# Vibe Kanban relay + host Implementation Plan

**Goal:** Implement `DEPLOYMENT.md` (stack commit 4f396fb): restructure `app/` into `app/remote/`, add the independent group-2 components `app/relay/` and `app/host/`, and run the staged gates A–F.

**Architecture:** Three independent compose components under `app/` (own `stackbuilder.toml`, `components/{base,environments,extensions}`, `build/`, `images/`). Group 1 = `app/remote`. Group 2 = `app/relay` + `app/host`, deployable on a different machine. Nothing is shared between groups except public URLs, the JWT secret and the published remote-DB port. Images are source-built from upstream commit `7c3807084daad0d9d315064f60fa869de254f027`, with no vendoring and no upstream patches.

**Design:** `stacks/self-hosting/ai-services/automation/vibe-kanban/DEPLOYMENT.md` (the contract). No separate design doc.

Stack path used below: `S=stacks/self-hosting/ai-services/automation/vibe-kanban` (an independent git repo). All `git` commands for stack files run in `$S`. Commits follow the stack's `.gitmessage` and the `git-commit` skill. PUSH NOTHING.

## Decisions recorded by this plan (design was silent)

1. **Network names.** Remote keeps `vibe-kanban-network`. Relay uses `vibe-kanban-relay-network` and host uses `vibe-kanban-host-network`, so two compose projects on one machine never share or collide on a bridge. Compose project names are `vibe-kanban-remote|relay|host`. All volumes have explicit `name:`, so the existing remote data is preserved across the rename.
2. **DB reachability (group 2 → remote DB).**
   - No shared docker network (group 2 may be on another machine).
   - The remote DB extension publishes Postgres through `ports: "${DB_PUBLISH_ADDR:-127.0.0.1}:${DB_PUBLISH_PORT:-5432}:5432"`.
   - The default is loopback only. For a remote relay the user sets `DB_PUBLISH_ADDR` to the interface, restricted by a firewall or VPN.
   - The relay gets `SERVER_DATABASE_URL=postgres://${REMOTE_DB_USER}:${REMOTE_DB_PASSWORD:?}@${REMOTE_DB_HOST:?}:${REMOTE_DB_PORT:-5432}/${REMOTE_DB_NAME:-remote}?sslmode=${REMOTE_DB_SSLMODE:-prefer}`.
   - Same-host default: `extra_hosts: host.docker.internal:host-gateway` in the relay, with `REMOTE_DB_HOST=host.docker.internal`.
   - The relay needs no DB service of its own: its schema is owned by remote (DEPLOYMENT.md).
   - Caveat for the README: Postgres is not TLS-protected by default. Cross-machine use needs a VPN or tunnel.
3. **Executor chosen for the host image: `opencode-ai`** (npm global, pinned via `ARG EXECUTOR_NPM_PACKAGES="opencode-ai@latest"`).
   - Reason: lightest to install, and it can run with a free or no-key provider where the upstream executor supports it.
   - Node 22 and npm are installed in the runtime layer, so `npx`-started executors work.
   - Gate D uses it. If it cannot run a task without credentials, the task falls back to a configured provider key in `.env` (`ANTHROPIC_API_KEY` or similar). Record the outcome in DEPLOYMENT.md "Open hypotheses".
   - The extension `extra executor CLIs` stays `available`.
4. **Image names.**
   - `localhost/vibe-kanban-relay:0.1.45` and `localhost/vibe-kanban-host:0.1.45`; the dirs are `app/relay/images/vibe-kanban-relay` and `app/host/images/vibe-kanban-host`.
   - The remote image keeps its name `localhost/vibe-kanban-remote-server:0.1.45`; its Dockerfile moves with `git mv` (R1) and is unchanged.
5. **Remote web relay URL.**
   - `VITE_RELAY_API_BASE_URL` is a build arg of the existing remote image, baked into the web bundle.
   - Set at build time: `docker build --build-arg VITE_RELAY_API_BASE_URL=https://relay.<domain> -t localhost/vibe-kanban-remote-server:0.1.45-relay app/remote/images/vibe-kanban-remote-server`.
   - Remote `.env` then sets `IMAGE=localhost/vibe-kanban-remote-server:0.1.45-relay`.
   - Task 7.1 does this at Stage D, once the relay public URL is known. The README documents it.
6. **Executors and state.**
   - The host uses 2 named volumes: `vibe-kanban-host-data` (state/credentials) and `vibe-kanban-host-worktrees`.
   - Task 2.17 verifies from the clone which env/path upstream uses (`asset_dir`, worktree base dir). Assumed: `XDG_DATA_HOME=/data`, so the data volume is mounted at `/data`.
   - If the assumption is wrong, set the corresponding ENV in the Dockerfile and record it.
7. **Wildcard.** The relay overlays set `VIRTUAL_HOST=relay.<domain>,*.relay.<domain>` and `LETSENCRYPT_HOST` with the same list. A wildcard cert needs DNS-01 on letsencrypt. If the step-ca/nginx-proxy stack cannot issue or route the wildcard, record it in PITFALLS.md and in DEPLOYMENT.md as a blocker note for Stage D. Do not patch upstream.
8. **sb build output.**
   - `build/` is tracked in this stack's git and is regenerated with `sb build` after each compose change (NEVER hand-edit).
   - Every task that changes `components/` ends with `cd <component> && sb build` and commits the regenerated `build/`.

## Dependency Graph

```
Batch 1 (1):   1.1                              [R1 git mv]
Batch 2 (23):  2.1–2.9 remote R2 | 2.10–2.16 relay | 2.17–2.23 host   [all independent files]
Batch 3 (1):   3.1                              [Stage A gate, remote regression]
Batch 4 (1):   4.1                              [relay image build]
Batch 5 (2):   5.1 Stage B gate | 5.2 host image build
Batch 6 (1):   6.1                              [Stage C gate]
Batch 7 (1):   7.1                              [remote image rebuild with VITE_RELAY_API_BASE_URL]
Batch 8 (1):   8.1                              [Stage D pairing E2E]
Batch 9 (1):   9.1                              [Stage E pgrust swap]
Batch 10 (2):  10.1 s3-storage extension files | 10.2 compose-config check (depends 10.1)
Batch 11 (1):  11.1                             [Stage F gate]
Batch 12 (7):  12.1 root README | 12.2 remote README | 12.3 relay README | 12.4 host README | 12.5 UPSTREAM.md | 12.6 PITFALLS.md | 12.7 DEPLOYMENT.md update
```

Heavy builds (4.1, 5.2, 7.1) are serialized on purpose.

- BuildKit Rust builds need 4+ GB RAM.
- Before each build run `free -h`.
- On memory/disk pressure: STOP and report the observed numbers (AGENTS.md host safety). Never "fix" the host.

Tests are shell/browser gates (stack-test skill), not unit tests. "Test" fields give the gate command. Browser tests use the `browser`/`agent-browser` skill. The step-ca variant runs first; never touch the live step-ca-manager setup.

---

## Batch 1: R1 restructure (1 implementer)

### Task 1.1: Move app/ → app/remote/ (history kept)
**File:** `$S/app/**` (move)
**Test:** `git -C $S status --short` shows only renames (R); `cd $S/app/remote && sb build` yields a `build/` identical to before.
**Depends:** none

```bash
cd $S
mkdir -p app/remote
for p in README.md build components images stackbuilder.toml; do git mv app/$p app/remote/$p; done
: > app/.gitkeep                       # app/ now holds only dirs
# dirs holding only dirs need .gitkeep (check each; add where missing):
for d in app/remote/components app/remote/components/environments app/remote/components/extensions app/remote/components/extensions/database app/remote/images app/remote/build app/remote/build/forwarding app/remote/build/letsencrypt app/remote/build/step-ca; do
  [ -z "$(find $d -maxdepth 1 -type f ! -name .gitkeep)" ] && : > $d/.gitkeep
done
# build/<env> dirs hold only combo dirs; build/ is generated — delete the .gitkeep in build dirs if sb build wipes them, then re-add after sb build
grep -rn "app/" README.md app/remote/README.md .vscode/settings.json   # fix paths
```

Edit these paths:
- Root `README.md` Quick Start: `cd app` → `cd app/remote`; link `app/` → `app/remote/`; `images/...` stays relative to `app/remote`.
- `app/remote/README.md`: path mentions.
- `.vscode/settings.json`: any `app/` paths.

Then run `cd app/remote && sb build` and confirm that `git diff --stat` for `build/` is empty (no content change). Re-add `.gitkeep` files if `sb build` removed them.

**Verify:** `git -C $S diff --stat -M HEAD` shows renames only.
**Commit:** `refactor(app): move remote component to app/remote (R1)`

---

## Batch 2: R2 rename + relay + host scaffolding (23 parallel implementers)

All tasks edit independent files. Every task commits separately in `$S`. Tasks that change compose end with `sb build` in their component (each component's `build/` is regenerated, so run it once at the end of the batch in 3.1/4.x; implementers write sources only and DO NOT run `sb build`, to avoid conflicts on `build/`).

### Remote (R2) — dir `$S/app/remote`

### Task 2.1: remote base compose rename
**File:** `app/remote/components/base/docker-compose.yml`
**Test:** `docker compose -f <file> config` after the full batch (Stage A).
**Depends:** none

Changes:
- service `vibe-kanban` → `vibe-kanban-remote`, `container_name: vibe-kanban-remote`.
- `vibe-kanban-electric`: `depends_on: vibe-kanban-remote`; `LOGICAL_PUBLISHER_HOST` default stays `vibe-kanban-electric`.
- Electric `DATABASE_URL` DB-name default: `${POSTGRES_DB:-vibe-kanban}` → `${POSTGRES_DB:-remote}`. This fixes a latent default mismatch with the DB extension, whose default is `remote`.
- Network and volume names unchanged.
- Image default stays `${IMAGE:-localhost/vibe-kanban-remote-server:0.1.45}`.
- `SERVER_DATABASE_URL` stays in the database extension.

### Task 2.2: remote base .env.example
**File:** `app/remote/components/base/.env.example`
**Depends:** none

Set `COMPOSE_PROJECT_NAME=vibe-kanban-remote`. Everything else unchanged (secrets stay empty; the runtime `.env` gets random values via `openssl rand -base64 32` — document in README).

### Task 2.3 / 2.4 / 2.5: remote env overlays
**Files:** `app/remote/components/environments/{forwarding,letsencrypt,step-ca}/docker-compose.yml`
**Depends:** none

In each, rename the service key `vibe-kanban:` → `vibe-kanban-remote:`. Everything else is unchanged. The forwarding port var stays `VIBEKANBAN_PORT`.

### Task 2.6: remote postgresql variant
**Files:** `app/remote/components/extensions/database/postgresql/{docker-compose.yml,docker-compose.db.yml,.env.example}`
**Depends:** none

- `docker-compose.yml`: the patched services are `vibe-kanban-remote` (SERVER_DATABASE_URL + depends_on db) and `vibe-kanban-electric` (unchanged).
- `docker-compose.db.yml`: add the DB publish port for group 2 (decision 2):

```yaml
    ports:
      - "${DB_PUBLISH_ADDR:-127.0.0.1}:${DB_PUBLISH_PORT:-5432}:5432"
```

- `.env.example`: add `DB_PUBLISH_ADDR=127.0.0.1` and `DB_PUBLISH_PORT=5432`.

### Task 2.7: remote pgrust variant
**Files:** `app/remote/components/extensions/database/pgrust/{docker-compose.yml,docker-compose.db.yml,.env.example}`
**Depends:** none

Same three edits as 2.6. The only difference to the postgresql variant remains `image: ${DB_IMAGE:-malisper/pgrust:v0.2}`.

### Task 2.8: remote stackbuilder.toml
**File:** `app/remote/stackbuilder.toml`
**Depends:** none

Verify that the relative paths still hold (`environments_path`, `extensions_dirs`). Expected: no change. Commit only if something changed; otherwise note "no change" in the 3.1 report.

### Task 2.9: remote README paths + rename
**File:** `app/remote/README.md`
**Depends:** none

Minimal edit now: service names, the `cd app/remote` path, the new `DB_PUBLISH_*` vars, and a "Relay build arg" section (decision 5). The full regeneration happens in 12.2.

### Relay — dir `$S/app/relay`

### Task 2.10: relay image
**File:** `app/relay/images/vibe-kanban-relay/Dockerfile`
**Test:** `docker build` in 4.1.
**Depends:** none

Self-contained, empty build context, pinned commit. Procedure for the implementer:

1. Clone upstream into `/tmp/opencode/upstreams/vibe-kanban-relay` (rm first) at `7c3807084daad0d9d315064f60fa869de254f027`.
2. Read `crates/relay-tunnel/Dockerfile`; keep its build and runtime stages.
3. Replace each `COPY crates/... ` of the repo context with a `source` stage:

```dockerfile
# syntax=docker/dockerfile:1.6
ARG GITHUB_REPO=BloopAI/vibe-kanban
ARG GIT_COMMIT=7c3807084daad0d9d315064f60fa869de254f027

FROM alpine:3.20 AS source
ARG GITHUB_REPO
ARG GIT_COMMIT
RUN apk add --no-cache git \
 && git clone --filter=blob:none "https://github.com/${GITHUB_REPO}.git" /repo \
 && git -C /repo checkout --detach "${GIT_COMMIT}" \
 && rm -rf /repo/.git
# ... builder stage: `COPY --from=source /repo/ /app/` replacing the context COPYs,
#     then the upstream `cargo build --locked --release -p relay-tunnel --bin relay-server` line as-is
# ... runtime stage as upstream: EXPOSE 8082, HEALTHCHECK GET /health
```

4. Header comment: Build standalone `docker build -t localhost/vibe-kanban-relay:0.1.45 app/relay/images/vibe-kanban-relay` + memory note.
5. Follow the `source-image` skill. Delete the clone at the end of the session (12.5 records provenance).

**Commit:** `feat(relay): add source-built relay image`

### Task 2.11: relay stackbuilder.toml
**File:** `app/relay/stackbuilder.toml`
**Depends:** none

```toml
[paths]
environments_path = "./environments"

[build]
skip_base_generation = true
copy_additional_files = true
yaml_merger = "rust"

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
extensions = []

[build.environments.letsencrypt]
extensions = []

[build.environments.step-ca]
extensions = []
```

No database combos: relay has no DB service (decision 2). If `sb build` rejects the missing combos/extensions, copy the numa relay-style toml shape and record it in PITFALLS.

### Task 2.12: relay base compose
**File:** `app/relay/components/base/docker-compose.yml`
**Depends:** none

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

services:
  vibe-kanban-relay:
    container_name: vibe-kanban-relay
    image: ${IMAGE:-localhost/vibe-kanban-relay:0.1.45}
    restart: unless-stopped
    logging: *default-logging
    environment:
      RUST_LOG: ${RUST_LOG:-info}
      RELAY_LISTEN_ADDR: ${RELAY_LISTEN_ADDR:-0.0.0.0:8082}
      VIBEKANBAN_REMOTE_JWT_SECRET: ${VIBEKANBAN_REMOTE_JWT_SECRET:?}
      SERVER_DATABASE_URL: postgres://${REMOTE_DB_USER:-vibe-kanban}:${REMOTE_DB_PASSWORD:?}@${REMOTE_DB_HOST:-host.docker.internal}:${REMOTE_DB_PORT:-5432}/${REMOTE_DB_NAME:-remote}?sslmode=${REMOTE_DB_SSLMODE:-prefer}
      TZ: ${TZ:-UTC}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://127.0.0.1:8082/health"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    networks:
      - vibe-kanban-relay-network

networks:
  vibe-kanban-relay-network:
    name: vibe-kanban-relay-network
    driver: bridge
```

Implementer checks that the runtime image of 2.10 has `wget` (else switch the healthcheck to the tool present, per the upstream HEALTHCHECK).

### Task 2.13: relay base .env.example
**File:** `app/relay/components/base/.env.example`
**Depends:** none

```
COMPOSE_PROJECT_NAME=vibe-kanban-relay

IMAGE=localhost/vibe-kanban-relay:0.1.45

LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

RUST_LOG=info
RELAY_LISTEN_ADDR=0.0.0.0:8082

# Must equal the remote group's secret (base64, >=32 bytes decoded)
VIBEKANBAN_REMOTE_JWT_SECRET=

# Remote group's Postgres (published port, see remote README)
REMOTE_DB_HOST=host.docker.internal
REMOTE_DB_PORT=5432
REMOTE_DB_NAME=remote
REMOTE_DB_USER=vibe-kanban
REMOTE_DB_PASSWORD=
REMOTE_DB_SSLMODE=prefer

TZ=UTC
```

### Task 2.14 / 2.15 / 2.16: relay environments (forwarding, letsencrypt, step-ca)
**Files:** `app/relay/components/environments/<env>/{docker-compose.yml,.env.example}` (3 tasks)
**Depends:** none

forwarding `docker-compose.yml`:

```yaml
services:
  vibe-kanban-relay:
    ports:
      - "${RELAY_PORT:-8082}:8082"
```

step-ca (letsencrypt is identical but uses `letsencrypt-*` names, as in the remote overlays):

```yaml
services:
  vibe-kanban-relay:
    environment:
      VIRTUAL_PORT: ${VIRTUAL_PORT:-8082}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PROTO: ${VIRTUAL_PROTO:-http}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    networks:
      - step-ca-network

networks:
  step-ca-network:
    name: step-ca-network
    external: true
```

env `.env.example` for letsencrypt/step-ca: `VIRTUAL_PORT=8082`, `VIRTUAL_HOST=relay.example.com,*.relay.example.com`, `VIRTUAL_PROTO=http`, `LETSENCRYPT_HOST=relay.example.com,*.relay.example.com` (decision 7), `LETSENCRYPT_EMAIL=admin@example.com`. For forwarding: `RELAY_PORT=8082`.

Copy the letsencrypt network/volume names from the remote letsencrypt overlay (`app/remote/components/environments/letsencrypt/docker-compose.yml`) — never invent them.

### Host — dir `$S/app/host`

### Task 2.17: host image
**File:** `app/host/images/vibe-kanban-host/Dockerfile`
**Depends:** none

Procedure:
1. Clone as in 2.10 (`/tmp/opencode/upstreams/vibe-kanban-host`). Read the upstream ROOT `Dockerfile` (the build stages for `packages/local-web` plus `cargo build --locked --release --bin server`).
2. Reproduce those stages with the same `source` stage as in 2.10, replacing the context `COPY`s with `COPY --from=source`. Keep the upstream build args as empty-default ARGs: `POSTHOG_API_KEY`, `POSTHOG_API_ENDPOINT`, `SENTRY_DSN`, `VK_SHARED_API_BASE=""` (the runtime env overrides it).
3. Runtime stage = upstream runtime (debian-slim + git, openssh-client, tini, wget; `ENV HOST=0.0.0.0 PORT=3000`; `HEALTHCHECK wget --spider http://127.0.0.1:${PORT}/health`), PLUS the executors layer:

```dockerfile
ARG NODE_MAJOR=22
ARG EXECUTOR_NPM_PACKAGES="opencode-ai@latest"
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g ${EXECUTOR_NPM_PACKAGES} \
 && rm -rf /var/lib/apt/lists/* /root/.npm
```

4. Verify from the clone and apply as ENV: the state-dir variable/path used by upstream (`asset_dir`, `dirs`/XDG); the worktree base dir; whether the process runs as a non-root user (so volumes are writable). Record the findings in the Dockerfile header (decision 6).
5. Header comment: build command `docker build -t localhost/vibe-kanban-host:0.1.45 app/host/images/vibe-kanban-host`, executor decision 3, memory note.

**Commit:** `feat(host): add source-built host image with executors layer`

### Task 2.18: host stackbuilder.toml
**File:** `app/host/stackbuilder.toml`
**Depends:** none
Same content as 2.11.

### Task 2.19: host base compose
**File:** `app/host/components/base/docker-compose.yml`
**Depends:** none

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

services:
  vibe-kanban-host:
    container_name: vibe-kanban-host
    image: ${IMAGE:-localhost/vibe-kanban-host:0.1.45}
    restart: unless-stopped
    logging: *default-logging
    environment:
      RUST_LOG: ${RUST_LOG:-info}
      HOST: ${HOST:-0.0.0.0}
      PORT: ${PORT:-3000}
      PREVIEW_PROXY_PORT: ${PREVIEW_PROXY_PORT:-3001}
      VK_SHARED_API_BASE: ${VK_SHARED_API_BASE:?}
      VK_SHARED_RELAY_API_BASE: ${VK_SHARED_RELAY_API_BASE:?}
      TZ: ${TZ:-UTC}
    volumes:
      - vibe-kanban-host-data:/data
      - vibe-kanban-host-worktrees:/var/tmp/vibe-kanban
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://127.0.0.1:${PORT:-3000}/health"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 15s
    networks:
      - vibe-kanban-host-network

networks:
  vibe-kanban-host-network:
    name: vibe-kanban-host-network
    driver: bridge

volumes:
  vibe-kanban-host-data:
    name: vibe-kanban-host-data
  vibe-kanban-host-worktrees:
    name: vibe-kanban-host-worktrees
```

Volume mount paths follow the Dockerfile findings of 2.17 (if they differ, adjust here and note it).

### Task 2.20: host base .env.example
**File:** `app/host/components/base/.env.example`
**Depends:** none

```
COMPOSE_PROJECT_NAME=vibe-kanban-host

IMAGE=localhost/vibe-kanban-host:0.1.45

LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

RUST_LOG=info
HOST=0.0.0.0
PORT=3000
PREVIEW_PROXY_PORT=3001

# Public URL of the remote group (group 1) and of the relay
VK_SHARED_API_BASE=https://vibe-kanban.example.com
VK_SHARED_RELAY_API_BASE=https://relay.example.com

TZ=UTC
```

Executor credentials are NOT added here; if gate D needs a provider key, add it only then, as an extension fragment (staged protocol).

### Task 2.21 / 2.22 / 2.23: host environments (forwarding, letsencrypt, step-ca)
**Files:** `app/host/components/environments/<env>/{docker-compose.yml,.env.example}` (3 tasks)
**Depends:** none

- forwarding: `ports: ["${HOST_UI_PORT:-3000}:3000", "${PREVIEW_PUBLISH_PORT:-3001}:3001"]`. The preview proxy port is published only here.
- letsencrypt/step-ca: same pattern as 2.14–2.16 with `VIRTUAL_PORT=3000`, `VIRTUAL_HOST=host.example.com`, `LETSENCRYPT_HOST=host.example.com`. The preview port is not exposed through nginx-proxy; record the limitation in the host README.
- `.env.example`: the corresponding vars (`HOST_UI_PORT`, `PREVIEW_PUBLISH_PORT`, or the `VIRTUAL_*` block).

### Scaffolding `.gitkeep` (part of tasks 2.10 and 2.17)
Both add `.gitkeep` to every dir-only directory: `app/relay`, `app/relay/components`, `app/relay/components/environments`, `app/relay/images`, and the same under `app/host`. Do this inside the Dockerfile tasks (2.10/2.17) so the file sets stay disjoint.

---

## Batch 3: Stage A — remote regression after move/rename (1 implementer)

### Task 3.1: Stage A gate (group 1)
**Files:** `app/remote/build/**` (regenerated); runtime `.env` (gitignored)
**Test:** browser E2E per `stack-test`, step-ca variant first
**Depends:** 1.1, 2.1–2.9

1. `cd $S/app/remote && sb build` and commit the regenerated `build/`.
2. `docker compose config` for each env/combo under `build/` (postgresql + pgrust, 3 envs) — all must validate.
3. Deploy `build/step-ca/postgresql` with a runtime `.env` made from `.env.example`: secrets random (`openssl rand -base64 32`; `POSTGRES_PASSWORD`, `ELECTRIC_ROLE_PASSWORD`, `VIBEKANBAN_REMOTE_JWT_SECRET`, `SELF_HOST_LOCAL_AUTH_PASSWORD`).
4. Gate (DEPLOYMENT.md Stage A):
   - `vibe-kanban-remote` healthy (`/v1/health`);
   - the web opens;
   - local login with the bootstrap creds works;
   - create org + project + issue, reload, data persists (Electric live).
5. Confirm the DB port is published (`docker port vibe-kanban-db`) on 127.0.0.1.
6. Tear down only our containers. Fix and retry on failure. Every obstacle goes into PITFALLS.md (hits +1 or new entry).

**Commit:** `chore(remote): regenerate build after R1/R2, Stage A passed`

---

## Batch 4: relay image (1 implementer)

### Task 4.1: build relay image
**Files:** none (image only)
**Test:** `docker image inspect localhost/vibe-kanban-relay:0.1.45`
**Depends:** 2.10

`free -h` first. Then `docker build -t localhost/vibe-kanban-relay:0.1.45 $S/app/relay/images/vibe-kanban-relay`. Memory failure → stop and report (no host changes). Fix Dockerfile defects, never upstream.
**Commit (if Dockerfile fixed):** `fix(relay): image build`

---

## Batch 5: Stage B gate + host image build (2 parallel implementers)

### Task 5.1: Stage B gate (relay)
**Files:** `app/relay/build/**` (regenerated)
**Depends:** 3.1, 4.1, 2.11–2.16

1. `cd $S/app/relay && sb build`, commit `build/`.
2. Deploy `build/step-ca` (or forwarding as a fallback) on the same machine. Use the Stage A remote's DB: `REMOTE_DB_*` from the remote `.env`, the same `VIBEKANBAN_REMOTE_JWT_SECRET`, and `REMOTE_DB_HOST=host.docker.internal`.
3. Gate: `vibe-kanban-relay` healthy; `curl http://127.0.0.1:8082/health` → `{"status":"ok"}`; `GET /v1/relay/connect` without a token → 401. Also confirm the relay log shows a DB connection (it must read the remote DB's schema).
4. Wildcard: check that `https://relay.<domain>` and a random `https://x.relay.<domain>` route to the relay via nginx-proxy in step-ca. Record the result (decision 7).

**Commit:** `chore(relay): regenerate build, Stage B passed`

### Task 5.2: build host image
**Files:** none (image only)
**Depends:** 2.17

`free -h` first. If less than 4 GB is available after 5.1's containers, wait or stop and report. `docker build -t localhost/vibe-kanban-host:0.1.45 $S/app/host/images/vibe-kanban-host`. Then check `docker run --rm --entrypoint opencode localhost/vibe-kanban-host:0.1.45 --version` and the same with `node --version`.

---

## Batch 6: Stage C gate (host) (1 implementer)

### Task 6.1: Stage C gate
**Files:** `app/host/build/**`
**Depends:** 5.1, 5.2, 2.18–2.23

1. `cd $S/app/host && sb build`, commit `build/`.
2. Deploy with `VK_SHARED_API_BASE=<remote public URL>` and `VK_SHARED_RELAY_API_BASE=<relay public URL>`.
3. Gate: container healthy; port `PORT` answers `/health`; the preview proxy port is bound (`ss`/`docker port`); `POST /api/auth/local/login` with the bootstrap creds succeeds; `/api/auth/status` shows logged in; the host log shows the relay connect with `relay_enabled`.
4. Verify the hypothesis "`VK_SHARED_API_BASE` runtime override is sufficient": remote features are enabled.

**Commit:** `chore(host): regenerate build, Stage C passed`

---

## Batch 7: remote web with relay URL (1 implementer)

### Task 7.1: rebuild remote image with VITE_RELAY_API_BASE_URL
**Files:** `app/remote/components/base/.env.example` (IMAGE note only, if the tag changes)
**Depends:** 6.1

`free -h`. Then:
```
docker build --build-arg VITE_RELAY_API_BASE_URL=https://relay.<domain> \
  -t localhost/vibe-kanban-remote-server:0.1.45-relay app/remote/images/vibe-kanban-remote-server
```
Set `IMAGE=...:0.1.45-relay` in the runtime `.env` and redeploy group 1 (data persists via volumes). Confirm the bundle contains the relay URL (`docker run --rm --entrypoint sh <img> -c 'grep -rl <relay-host> /app'` or the equivalent path). The README of the remote component documents the command (written in 12.2).

---

## Batch 8: Stage D — pairing E2E (functional gate) (1 implementer)

### Task 8.1: Stage D gate
**Test:** `stack-test` browser E2E per DEPLOYMENT.md Stage D, step-ca first
**Depends:** 7.1

1. Log in on the host UI (`/api/auth/local/login` creds).
2. Host UI → Settings → Remote Access → generate the one-time pairing code (`POST /api/relay-auth/server/enrollment-code`).
3. Remote web → Remote Access → Link a host → enter the code. Verify which server serves the client `/api/relay-auth/client/pair` route and record it in DEPLOYMENT.md.
4. The host is listed online. Open its workspaces via the relay (wildcard host route). Start a task with the `opencode` executor and see its output in the remote UI.
5. Observe: the relay reads the `hosts` rows created at registration; the executor needed credentials or not (decision 3).
6. Record every deviation in DEPLOYMENT.md (hypotheses section) and PITFALLS.md.

---

## Batch 9: Stage E — pgrust swap (1 implementer)

### Task 9.1: pgrust for remote-db
**Files:** `app/remote/stackbuilder.toml` (+ `build/` regeneration)
**Depends:** 8.1

1. Deploy `build/step-ca/pgrust` of the remote component (fresh DB volume or a documented reset; the relay uses the same DB).
2. Re-run Stage A and Stage D. If clean: make pgrust the default variant. In the remote `README` and in `stackbuilder.toml` put pgrust first (`combos` order); keep postgresql as the alternative.
3. If pgrust fails the gates: record it in PITFALLS.md and DEPLOYMENT.md (extension status), and keep postgresql default.

**Commit:** `feat(remote): pgrust default after Stage A+D re-run` (or `docs: record pgrust failure`)

---

## Batch 10: S3 extension files (Stage F prep)

### Task 10.1: s3-storage extension (remote)
**Files:** `app/remote/components/extensions/s3-storage/{docker-compose.yml,.env.example}`, `app/remote/stackbuilder.toml` (add `extensions/s3-storage` to `extensions_dirs`, the extension name to `extensions`, and an `s3` combo layered on the db combos)
**Depends:** 9.1

- `docker-compose.yml` patches `vibe-kanban-remote`:
```yaml
services:
  vibe-kanban-remote:
    environment:
      R2_ACCESS_KEY_ID: ${R2_ACCESS_KEY_ID:?}
      R2_SECRET_ACCESS_KEY: ${R2_SECRET_ACCESS_KEY:?}
      R2_REVIEW_ENDPOINT: ${R2_REVIEW_ENDPOINT:?}
      R2_REVIEW_BUCKET: ${R2_REVIEW_BUCKET:-vibe-kanban-review}
```
- `.env.example` documents the same vars (optional vars live in the extension fragment only).
- Use the `rustfs-s3` skill to create the bucket and key (delegate to the `rustfs-admin` subagent; destructive ops need user confirmation).
- The name of the extra vars follows upstream `R2_*` (verify names against the clone in `crates/remote`).

### Task 10.2: compose config check
**Depends:** 10.1
`sb build` in `app/remote`; `docker compose config` on every `build/*/*s3*` variant must validate. Commit `build/`.

---

## Batch 11: Stage F gate (1 implementer)

### Task 11.1: S3 gate
**Depends:** 10.2
Deploy the s3 variant; re-run Stage A. The gate observes that the remote starts with R2 configured against RustFS and that the review-payload path does not error at startup (hypothesis "R2 usable for RustFS without path-style quirks"). On failure the item is REFUSED with the reason in DEPLOYMENT.md (never dropped silently); otherwise the status becomes `implemented`.

---

## Batch 12: docs and records (7 parallel implementers)

### Task 12.1: stack root README
**File:** `$S/README.md`
**Depends:** 11.1
Regenerate with the `readme-gen` skill (hub style): the components remote / relay / host plus the ssl modules, the Quick Start per group, the extension statuses from DEPLOYMENT.md.

### Task 12.2 / 12.3 / 12.4: component READMEs
**Files:** `app/remote/README.md`, `app/relay/README.md`, `app/host/README.md`
**Depends:** 11.1
Component style (`readme-gen`, ~100–250 lines). Each covers: services, envs, build command for the image, random-secret `.env` recipe, the cross-group wiring tables.
- Remote: the `VITE_RELAY_API_BASE_URL` build command (decision 5) and `DB_PUBLISH_*` (decision 2).
- Relay: `REMOTE_DB_*`, the shared JWT secret, the wildcard host.
- Host: the executor image layer (decision 3), the pairing steps, the preview port limitation.

### Task 12.5: UPSTREAM.md (append-only)
**File:** `$S/UPSTREAM.md`
**Depends:** 11.1
Rows are only appended; no headers are rewritten.
- Append a row to the existing `## app` section: `| <date> | 7c38070… | - | moved to app/remote (R1); see sections below |`.
- Add new sections:
  - `## app/remote — https://github.com/BloopAI/vibe-kanban`, a row with image `localhost/vibe-kanban-remote-server:0.1.45` / `0.1.45-relay`;
  - `## app/relay — …`, with image `localhost/vibe-kanban-relay:0.1.45`, commit `7c3807084daad0d9d315064f60fa869de254f027`;
  - `## app/host — …`, with image `localhost/vibe-kanban-host:0.1.45`, commit `7c3807084daad0d9d315064f60fa869de254f027`.
- Delete the tmp clones (`rm -rf /tmp/opencode/upstreams/vibe-kanban-*`).

### Task 12.6: PITFALLS.md
**File:** `/home/archuser/projects/docker-stack-collection/PITFALLS.md` (main repo)
**Depends:** 11.1
Per the ledger protocol: for every obstacle hit in batches 3–11 increment `hits` / `last` or append a new entry (`hits: 1`, `status: open`). Set `fixed` plus `fix:` where solved. Never delete entries. Commit in the main repo.

### Task 12.7: DEPLOYMENT.md update
**File:** `$S/DEPLOYMENT.md`
**Depends:** 11.1
The living document: update extension statuses (database → implemented, s3-storage → implemented/refused, env overlays group 2 → implemented). Record the outcomes: executor choice, DB reachability decision, wildcard result, the pairing route finding, and the hypothesis results. Mark remediation R1–R4 done.

**Commit (each in the stack repo):** `docs: <file> after relay/host rollout`

---

## Task count

Batch 1: 1 · Batch 2: 23 · Batch 3: 1 · Batch 4: 1 · Batch 5: 2 · Batch 6: 1 · Batch 7: 1 · Batch 8: 1 · Batch 9: 1 · Batch 10: 2 · Batch 11: 1 · Batch 12: 7 (total 42)
