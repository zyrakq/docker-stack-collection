# AionUi — Phase 1 (Functional Base Scaffold) Implementation Plan

**Goal:** Scaffold the complete functional base of the new `aionui` stack: source-built image, base compose, environments, docs, and registration — ending with a passing Stage A functional gate.

**Architecture:** Single product part `aionui-app` (web/server mode: web-host + renderer `out/renderer`, port 25808; `aioncore` v0.2.2 baked into the image as a pinned release binary — NOT a separate service). SQLite data in named volume `aionui-data` at `/data`. Image is source-built per the `source-image` skill (upstream Dockerfile is broken at HEAD: `build-server.mjs` + `build:renderer:web` deleted in upstream commit `b157719a5`), pinned to upstream commit `119dd2b47`. The required-for-gate `agent-cli-gemini` extension is **baked into the image** (global CLI install) because it is a CLI binary spawned by `aioncore` over ACP via PATH lookup — not a network service; compose injection would needlessly mount a node runtime.

**Design / authority documents:**
- `stacks/self-hosting/ai-services/chats/aionui/DEPLOYMENT.md` — deployment model contract (Base stage plan = ordering authority; extension catalog; refusals)
- `stacks/self-hosting/ai-services/chats/aionui/UPSTREAM.md` — provenance log (append-only)
- `.opencode/skills/stack-init/references/scaffold-checklist.md` — Phase 1 checklist mirrored below
- `.opencode/skills/stack-conventions/references/patterns.md` — §9 (numa TOML + env patterns), §10 (logging anchors), §12 (env wiring), §13 (ENV layering)
- `.opencode/skills/source-image/references/dockerfiles.md` — Dockerfile skeletons
- Upstream reference clone (READ-ONLY): `/tmp/opencode/upstreams/aionui-aionui` @ `119dd2b47`

**Stack root:** `stacks/self-hosting/ai-services/chats/aionui/` (independent git repo; executor commits its own work there).

---

## Refusals (recorded once — no tasks generated)

Per DEPLOYMENT.md, the following mandatory infra was attempted and REFUSED; the refusal reasons live in DEPLOYMENT.md and are NOT duplicated in code or config:

- **database (postgresql/pgrust)** — REFUSED: aioncore is SQLite-embedded; no external DB support surface.
- **oidc** — REFUSED: no OIDC/OAuth client support surface in the webui auth model.
- **s3-storage** — REFUSED: no object-storage support surface; filesystem-only.

Phases 2–4 of stack-init are no-ops for this stack except recording these statuses (already done in DEPLOYMENT.md).

## Key upstream research (already verified in the clone)

- `scripts/webui.ts` env surface: `AIONUI_PORT`/`PORT` (default **25808** when `NODE_ENV=production`), `AIONUI_HOST` (`0.0.0.0` implies remote), `AIONUI_ALLOW_REMOTE`/`AIONUI_REMOTE`, `AIONUI_DATA_DIR`, `AIONUI_LOG_DIR` (default `<dataDir>/logs`), `AIONUI_STATIC_DIR` (default `out/renderer`), `AIONUI_BACKEND_BIN`, `AIONUI_BACKEND_BUNDLED_DIR`, `AIONUI_NO_BUILD`, `AIONUI_OPEN_BROWSER`.
- Backend binary resolution (`packages/desktop/src/process/backend/binaryResolver.ts` + `scripts/webui.ts:resolveBackendBinary`): `AIONUI_BACKEND_BIN` override → `resources/bundled-aioncore/<platform>-<arch>/aioncore` → PATH.
- aioncore provisioning: `node scripts/prepareAioncore.js` (CJS, runs under bun too) reads `aioncoreVersion: "v0.2.2"` from root `package.json`, downloads the release binary from `iOfficeAI/AionCore` GitHub releases into `resources/bundled-aioncore/linux-{x64,arm64}/aioncore`; arch override via `AIONUI_BACKEND_ARCH`.
- Renderer build: `bun run package` (= `electron-vite build`) produces `out/renderer/index.html` at the pinned commit.
- Fresh-install admin seeding: webui queries `/api/auth/status`; if `needs_setup`, POSTs `/api/webui/reset-password` and prints credentials to stdout (container logs) — this is how gate step 3 gets credentials.
- `agent-cli-gemini`: the backend spawns `gemini` from PATH for ACP runs; credentials via `GEMINI_API_KEY`/`GOOGLE_API_KEY` env or UI settings.

---

## Dependency Graph

```
Batch 1 (parallel): 1.1–1.12  [all scaffold files — no deps]
Batch 2 (sequential): 2.1 image build → 2.2 sb build → 2.3 Stage A gate → 2.4 registration + 2.5 cleanup/commit
```

---

## Batch 1: Scaffold files (parallel — 12 implementers)

All tasks in this batch are independent. Stack root is
`/home/archuser/projects/docker-stack-collection/stacks/self-hosting/ai-services/chats/aionui/`
(referred to as `$ROOT` below). Create parent dirs as needed; add `.gitkeep` to any
directory that would otherwise contain only directories (none expected here).

### Task 1.1: stackbuilder.toml
**File:** `$ROOT/app/stackbuilder.toml`
**Test:** none (validated by `sb build` in 2.2)
**Depends:** none

Imitates patterns.md §9 (numa) `[build.environments]` API; no extensions exist yet, so `extensions_dirs` is empty and there are no `[build]` extension keys.

```toml
[paths]
environments_path = "./environments"
extensions_dirs = []

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]
```

**Verify:** `cd $ROOT/app && sb build --help >/dev/null && test -f stackbuilder.toml`
**Commit:** `feat(app): add stackbuilder config with environments API`

### Task 1.2: base docker-compose.yml
**File:** `$ROOT/app/components/base/docker-compose.yml`
**Test:** none (validated by `docker compose config` in 2.2)
**Depends:** none

Follows §10 logging anchors + §12 env wiring (every value overridable). NO `ports:` in base (canonical vibe-kanban/trailbase pattern — forwarding overlay owns publishing). NO `build:` section (§19 — prebuilt source-built image only). Base is environment-agnostic: no public-URL vars (§13).

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

services:
  aionui-app:
    container_name: aionui-app
    image: ${IMAGE:-localhost/aionui:v2.2.2}
    restart: unless-stopped
    logging: *default-logging
    environment:
      # Expose to LAN inside the container network so the published port works
      # (static server binds 127.0.0.1 when remote is not allowed).
      AIONUI_ALLOW_REMOTE: ${AIONUI_ALLOW_REMOTE:-1}
      AIONUI_LOG_DIR: ${AIONUI_LOG_DIR:-/data/logs}
      # agent-cli-gemini credentials (required-for-gate); also settable in UI.
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      GOOGLE_API_KEY: ${GOOGLE_API_KEY:-}
      TZ: ${TZ:-UTC}
    volumes:
      - aionui-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://127.0.0.1:25808/health"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s
    networks:
      - aionui-network

networks:
  aionui-network:
    name: aionui-network
    driver: bridge

volumes:
  aionui-data:
    name: aionui-data
```

Notes for the implementer:
- `NODE_ENV=production`, `AIONUI_DATA_DIR=/data`, `AIONUI_NO_BUILD=1`, `AIONUI_STATIC_DIR=/app/out/renderer`, `AIONUI_BACKEND_BIN`, `AIONUI_OPEN_BROWSER=0` are structural and set in the image (Task 1.4) — do NOT duplicate them here.
- Port 25808 is the fixed in-container listen port (production default); the host-side port is published by the forwarding overlay as `${AIONUI_PORT:-25808}:25808`.
- Healthcheck hits `/health` per DEPLOYMENT.md gate markers; if Stage A shows `/health` returns 404, switch the check to `curl -f http://127.0.0.1:25808/` and note it in the commit message.

**Verify:** `docker compose -f $ROOT/app/components/base/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add base compose for aionui-app`

### Task 1.3: base .env.example
**File:** `$ROOT/app/components/base/.env.example`
**Test:** none
**Depends:** none

Only vars the compose files actually reference (§6). `AIONUI_PORT` is referenced by the forwarding overlay (Task 1.5); it is listed here with a comment because environments get no merged env file today (§13 note).

```env
# Image (source-built; see app/images/aionui/Dockerfile)
IMAGE=localhost/aionui:v2.2.2

# Logging
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

# App
# Host-side published port (used by the forwarding environment overlay;
# the container always listens on 25808).
AIONUI_PORT=25808
AIONUI_ALLOW_REMOTE=1
AIONUI_LOG_DIR=/data/logs
TZ=UTC

# agent-cli-gemini (required-for-gate) — Gemini CLI credentials
GEMINI_API_KEY=
GOOGLE_API_KEY=
```

**Verify:** `test -f $ROOT/app/components/base/.env.example`
**Commit:** `feat(app): add base env example`

### Task 1.4: source-built Dockerfile (bakes aioncore + gemini CLI)
**File:** `$ROOT/app/images/aionui/Dockerfile`
**Test:** none (built and smoke-tested in 2.1)
**Depends:** none

Per the `source-image` skill: fully self-contained (clones upstream at the pinned commit itself, empty build context), no vendored source, no submodules. Bakes:
1. renderer bundle (`out/renderer`) via `bun run package`,
2. `aioncore` v0.2.2 release binary via `scripts/prepareAioncore.js` (reads the pin from `package.json`),
3. `gemini` CLI globally (required-for-gate executor).

```dockerfile
# syntax=docker/dockerfile:1
# AionUi — source-built image (web/server mode).
# Upstream: https://github.com/iOfficeAI/AionUi @ 119dd2b47 (v2.2.2 line)
# Self-contained: clones upstream at the pinned commit; build with an empty context:
#   docker build -t localhost/aionui:v2.2.2 app/images/aionui

FROM oven/bun:1.2-debian AS build

ARG AIONUI_REPO=https://github.com/iOfficeAI/AionUi.git
ARG AIONUI_COMMIT=119dd2b47

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --filter=blob:none "${AIONUI_REPO}" . \
    && git checkout "${AIONUI_COMMIT}"

# Renderer + main bundles into out/ (electron-vite build). postinstall
# (electron-builder install-app-deps) failures are non-fatal upstream.
RUN bun install \
    && bun run package

# aioncore v0.2.2 release binary -> resources/bundled-aioncore/linux-<arch>/aioncore
# (reads "aioncoreVersion" from package.json; arch = process.arch of the builder)
RUN bun scripts/prepareAioncore.js

FROM oven/bun:1.2-debian

ARG AIONUI_COMMIT=119dd2b47
LABEL org.opencontainers.image.title="aionui" \
      org.opencontainers.image.source="https://github.com/iOfficeAI/AionUi" \
      org.opencontainers.image.revision="${AIONUI_COMMIT}" \
      org.opencontainers.image.description="AionUi web/server mode with baked aioncore v0.2.2 and gemini CLI"

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # agent-cli-gemini (required-for-gate): global CLI so aioncore finds it on PATH
    && bun install -g @google/gemini-cli

WORKDIR /app
COPY --from=build /app /app

ENV NODE_ENV=production \
    AIONUI_DATA_DIR=/data \
    AIONUI_STATIC_DIR=/app/out/renderer \
    AIONUI_NO_BUILD=1 \
    AIONUI_OPEN_BROWSER=0 \
    AIONUI_BACKEND_BIN=/app/resources/bundled-aioncore/linux-x64/aioncore

EXPOSE 25808

# webui CLI: web-host (backend launcher + static server + auth seeding).
# NODE_ENV=production -> default port 25808; AIONUI_NO_BUILD skips rebuild.
CMD ["bun", "scripts/webui.ts"]
```

Implementer notes:
- If the builder arch is arm64, `AIONUI_BACKEND_BIN` must be `linux-arm64` — make the ENV arch-aware if the build host is arm64 (check `uname -m` first; on this host assume x64 unless proven otherwise).
- If `bun install -g @google/gemini-cli` produces a shim that fails under the bun runtime at Stage A, fallback: switch the final stage to `node:22-slim`, install bun via the official install script, keep `CMD ["bun", "scripts/webui.ts"]`, and install gemini with `npm i -g @google/gemini-cli`. Record whichever variant shipped in UPSTREAM.md notes.
- If `bun run package` fails because electron-vite needs the electron binary at build time, retry with `bun install` including dev deps (default) and, if still blocked, set `ELECTRON_SKIP_BINARY_DOWNLOAD=1` — electron-vite build does not launch electron. Report a genuine blocker only if the renderer bundle is not produced.

**Verify:** file exists and `docker build` succeeds (Task 2.1).
**Commit:** `feat(images): add source-built aionui image (aioncore v0.2.2 + gemini CLI)`

### Task 1.5: forwarding environment overlay
**File:** `$ROOT/app/components/environments/forwarding/docker-compose.yml`
**Test:** none
**Depends:** none

Canonical pattern (vibe-kanban/trailbase): overlay only publishes ports.

```yaml
services:
  aionui-app:
    ports:
      - "${AIONUI_PORT:-25808}:25808"
```

**Verify:** `docker compose -f $ROOT/app/components/environments/forwarding/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add forwarding environment overlay`

### Task 1.6: letsencrypt environment overlay
**File:** `$ROOT/app/components/environments/letsencrypt/docker-compose.yml`
**Test:** none
**Depends:** none

```yaml
services:
  aionui-app:
    environment:
      DOMAIN: ${DOMAIN}
      VIRTUAL_PORT: ${VIRTUAL_PORT}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    networks:
      - letsencrypt-network

networks:
  letsencrypt-network:
    name: letsencrypt-network
    external: true
```

**Verify:** `docker compose -f $ROOT/app/components/environments/letsencrypt/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add letsencrypt environment overlay`

### Task 1.7: step-ca environment overlay
**File:** `$ROOT/app/components/environments/step-ca/docker-compose.yml`
**Test:** none
**Depends:** none

```yaml
services:
  aionui-app:
    environment:
      DOMAIN: ${DOMAIN}
      VIRTUAL_PORT: ${VIRTUAL_PORT}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    networks:
      - step-ca-network

networks:
  step-ca-network:
    name: step-ca-network
    external: true
```

**Verify:** `docker compose -f $ROOT/app/components/environments/step-ca/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add step-ca environment overlay`

### Task 1.8: app README (component README)
**File:** `$ROOT/app/README.md`
**Test:** none
**Depends:** none (may be regenerated after 2.3 if gate reveals corrections)

Load the `readme-gen` skill and generate the **component README** (~100–250 lines) from DEPLOYMENT.md. Required content:
- What AionUi is (one paragraph) + upstream link and pinned commit `119dd2b47`.
- Base parts table: single part `aionui-app` (web/server mode, port 25808, aioncore v0.2.2 baked in, SQLite in `aionui-data` at `/data`).
- Extension status table from the DEPLOYMENT.md catalog: `agent-cli-gemini` = **required-for-gate, baked into image** (credentials via `GEMINI_API_KEY`/`GOOGLE_API_KEY` or UI settings); `agent-cli-claude/codex/qwen`, `mcp-servers`, `im-bot-*` = available (not implemented); database/oidc/s3 = refused (link to DEPLOYMENT.md refusals).
- Env table: every var from Task 1.3 with meaning and default, plus `AIONUI_PORT` (forwarding overlay) and the overlay-only vars (`DOMAIN`, `VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`) documented per §13 ("sb merges no env files for environments today").
- Build & run section: `docker build -t localhost/aionui:v2.2.2 images/aionui` → `cd app/ && sb build` → pick environment → `docker compose up -d`; first login credentials appear in container logs on fresh DB.
- Stage A gate summary (5 steps from DEPLOYMENT.md).

**Verify:** `test -s $ROOT/app/README.md && grep -q "agent-cli-gemini" $ROOT/app/README.md`
**Commit:** `docs(app): add component README`

### Task 1.9: stack-root hub README
**File:** `$ROOT/README.md`
**Test:** none
**Depends:** none

Load the `readme-gen` skill and generate the **stack-root hub README** (short hub style): stack name, one-paragraph description, link to `app/` (compose entry point), `app/README.md` (component docs), `DEPLOYMENT.md` (deployment model contract), `UPSTREAM.md` (provenance); base = `aionui-app` @ port 25808; note source-built image and the three infra refusals in one line each.

**Verify:** `test -s $ROOT/README.md && grep -q "DEPLOYMENT.md" $ROOT/README.md`
**Commit:** `docs: add stack hub README`

### Task 1.10: stack-root .gitignore
**File:** `$ROOT/.gitignore`
**Test:** none
**Depends:** none

```
.env
```

**Verify:** `test -f $ROOT/.gitignore`
**Commit:** `chore: add gitignore`

### Task 1.11: stack-root .gitmessage
**File:** `$ROOT/.gitmessage`
**Test:** none
**Depends:** none

Copy verbatim from the canonical stack (trailbase) — content:

```
# Header: verb in infinitive form (max 50 chars)

# What was done (max 72 chars per line)
# Each change on new line, past tense verbs (Replaced, Added, Updated)

# Why it was done (max 72 chars per line)
# Each reason on new line, present tense verbs (Provide, Improve, Enable)

# Rules:
# - Header starts with verb in infinitive form
# - Blocks separated by empty lines
# - No period at end of line if no second sentence
# - Answer "what" and "why", not "how"
# - Focus on business value, not technical details
# - Each change item starts on new line
# - Use past tense for "what" (Replaced, Added, Updated)
# - Use present tense for "why" (Provide, Improve, Enable)
# - All text in English
```

**Verify:** `test -s $ROOT/.gitmessage`
**Commit:** `chore: add git message template`

### Task 1.12: license files
**Files:** `$ROOT/LICENSE-APACHE`, `$ROOT/LICENSE-MIT`
**Test:** none
**Depends:** none

Copy both verbatim from the parent repo root (exception to one-file-per-task: two static copies, one command):

```bash
cp /home/archuser/projects/docker-stack-collection/LICENSE-APACHE $ROOT/LICENSE-APACHE
cp /home/archuser/projects/docker-stack-collection/LICENSE-MIT $ROOT/LICENSE-MIT
```

**Verify:** `test -s $ROOT/LICENSE-APACHE && test -s $ROOT/LICENSE-MIT`
**Commit:** `chore: add dual license files`

---

## Batch 2: Build & verify (sequential)

### Task 2.1: build the image
**File:** none (produces `localhost/aionui:v2.2.2`)
**Depends:** 1.4

```bash
cd $ROOT && docker build -t localhost/aionui:v2.2.2 app/images/aionui
```

Smoke-check the baked artifacts:

```bash
docker run --rm --entrypoint sh localhost/aionui:v2.2.2 -c \
  'ls /app/out/renderer/index.html /app/resources/bundled-aioncore/*/aioncore && command -v gemini'
```

All three paths must exist. If `gemini` shim fails here, apply the Task 1.4 fallback (node:22-slim variant) before proceeding.

**Verify:** image tagged; smoke check passes.
**Commit:** n/a (image only). If the Dockerfile needed fixes, commit them: `fix(images): correct build for gate`

### Task 2.2: sb build + compose validation
**File:** none
**Depends:** 2.1

```bash
cd $ROOT/app && sb build
```

Then validate the generated compose for the default (forwarding) environment:

```bash
cd $ROOT/app && docker compose config >/dev/null && echo OK
```

Confirm the generated compose: service `aionui-app`, `container_name: aionui-app`, image `localhost/aionui:v2.2.2`, volume `aionui-data:/data`, network `aionui-network`, ports `25808:25808`, no `build:` section, no leftover artifacts.

**Verify:** `sb build` exits 0; `docker compose config` OK.
**Commit:** `chore(app): verify sb build` (only if generated files need fixing; sb output that is gitignored needs no commit)

### Task 2.3: Stage A functional gate (stack-test skill)
**File:** none
**Depends:** 2.2

Load the `stack-test` skill. Stage A = product parts + database (SQLite is embedded — no separate DB stage). Run with the **forwarding** environment. The required-for-gate `agent-cli-gemini` is already baked into the image (verified in 2.1) — confirm `GEMINI_API_KEY` is set in `.env` before starting.

Gate checklist (from DEPLOYMENT.md functional gate scenario):

1. `docker compose up -d`; container `aionui-app` becomes healthy; logs show the webui startup banner and backend launch (aioncore resolved from `AIONUI_BACKEND_BIN`); `/health` (or `/` fallback) returns 200.
2. Browser loads the renderer at `http://localhost:25808` (login page renders, no console-fatal errors).
3. Login: on a fresh DB the initial admin username/password are printed to container logs (webui seeding via `/api/webui/reset-password`) — log in with them; on an existing DB use existing credentials.
4. Create a conversation and complete ONE agent run end-to-end using the Gemini executor (agent-cli-gemini over ACP). A real model response must appear in the UI.
5. `docker compose restart` → log in again → the conversation from step 4 still exists (state persisted in `aionui-data`).

If `/health` 404s, switch the healthcheck to `/` (Task 1.2 note) and rebuild. Any gate failure: fix, rebuild image if needed, re-run the gate from step 1.

**Verify:** all 5 steps pass; record the result in the commit message of 2.5.
**Commit:** n/a (gate run)

### Task 2.4: register the stack in the parent catalog
**File:** `/home/archuser/projects/docker-stack-collection/stacks.csv` (parent repo)
**Depends:** 2.3

Append exactly one row (merge=union in `.gitattributes` handles it):

```
stacks/self-hosting/ai-services/chats/aionui;-;unverified
```

Do NOT hand-edit `stacks.md` or the `# BEGIN stack-sync` block in the parent `.gitignore` (generated). Commit in the **parent** repo: `feat(catalog): register aionui stack`.

**Verify:** `grep -q 'aionui;-;unverified' /home/archuser/projects/docker-stack-collection/stacks.csv`
**Commit:** `feat(catalog): register aionui stack` (parent repo)

### Task 2.5: artifact cleanup + final commits
**Files:** stack repo working tree
**Depends:** 2.3 (2.4 can run in parallel)

1. In `$ROOT`, delete tool artifacts if present: `.kilocode/`, `.clinerules/`, `.vscode/`, any `src/` leftovers, stray clones — the stack repo must contain only: `app/`, `README.md`, `DEPLOYMENT.md`, `UPSTREAM.md`, `.gitignore`, `.gitmessage`, `LICENSE-APACHE`, `LICENSE-MIT`, `.git/`.
2. Append the UPSTREAM.md provenance row if the shipped image differs from the planned row (image id/build date note); otherwise leave UPSTREAM.md untouched (append-only, §17).
3. `git status` must be clean in the stack repo after committing everything the executor produced (Batch 1 + any gate fixes). Suggested final commit if leftovers exist: `chore: clean artifacts after stage A gate`.
4. Verify parent repo is clean too (plan + stacks.csv committed).

**Verify:** `cd $ROOT && git status --porcelain` is empty; `ls -A` shows only the expected entries.
**Commit:** `chore: clean artifacts after stage A gate` (stack repo, if needed)

---

## Open risks

- **gemini CLI under bun runtime** — the global shim runs the CLI with bun; if the ACP handshake fails at gate step 4, apply the documented node:22-slim fallback (Task 1.4) and re-run the gate.
- **`bun run package` in a container** — electron-vite build should not need the electron binary; if it does, `ELECTRON_SKIP_BINARY_DOWNLOAD=1` is the first lever.
- **`/health` endpoint existence** — taken from DEPLOYMENT.md gate markers; fallback to `/` documented in Task 1.2.
- **arm64 hosts** — `AIONUI_BACKEND_BIN` in the Dockerfile hardcodes `linux-x64`; adjust per builder arch (Task 1.4 note).
