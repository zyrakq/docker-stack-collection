# re-kord Stage A Phase 1 — Functional Base Scaffold (Implementation Plan)

**Goal:** Scaffold the entire functional base (Stage A) of `stacks/self-hosting/media-streaming/music/re-kord/` — single `re-kord` service from the published image, base compose + `.env.example`, three environment overlays, stackbuilder config, provenance and root files — ready for the Stage A browser gate.

**Architecture:** Single-part product (per committed `DEPLOYMENT.md`, commit f3e6c50): Rust axum hub, published image `ghcr.io/creiv/re-kord:latest`, SQLite in `/data`, library in `/music`, client UI at `/`, admin at `/admin`, health `/api/v1/health`. Mandatory infra REFUSED (no external DB — SQLite is embedded; no OIDC; S3 not mandated) → functional base = one service, no extension wiring. Layout mirrors the polaris/koito precedent stacks: `app/components/base/`, `app/components/environments/{forwarding,letsencrypt,step-ca}/`, `app/stackbuilder.toml`, generated `app/build/` committed.

**Design:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md` (the contract) + stack-conventions skill.

---

## Decisions (gap-fills — implementer reads these, not the upstream repo)

1. **Image pin:** Contract says `ghcr.io/creiv/re-kord:latest` → default stays `latest` (`${IMAGE:-ghcr.io/creiv/re-kord:latest}`). Upstream publishes version tags (`5.3.0`, current release; upstream clone HEAD `b4e05cd`, tag `v5.3`); pinning is a user choice via `IMAGE` in `.env`, not a scaffold change.
2. **Healthcheck:** The image carries its own `HEALTHCHECK` on `/api/v1/health` and has `curl` installed (upstream Dockerfile runtime stage). Compose still declares an explicit anchored healthcheck (precedent consistency, overrides image default): `curl -fsS http://127.0.0.1:7420/api/v1/health`. Port is fixed 7420 inside the container (`REKORD_BIND` default), so a literal URL is safe.
3. **Env hygiene:** Every env value in compose is `${VAR:-default}`. Container-internal wiring (`REKORD_BIND`, `REKORD_DATA_DIR`, `REKORD_MUSIC_ROOT`) is overridable with the upstream defaults and listed in `.env.example` — changing them is discouraged but the rule wins.
4. **`REKORD_ACCESS_KEY`:** NOT in base (optional product feature; upstream comments it out; catalog decision comes later). `REKORD_ALLOW_REMOTE_ADMIN` IS in base (`${REKORD_ALLOW_REMOTE_ADMIN:-0}`) — inside a container no request is local, so admin operations need it or `docker exec`; keep it wired, default off.
5. **Volumes:** Upstream bind mounts (`${REKORD_DATA_HOST}`, `${REKORD_MUSIC_HOST}`) are replaced by named volumes `re-kord-data` → `/data`, `re-kord-music` → `/music` (no-bind-mount policy). Named volumes initialize ownership from the image's `/data` and `/music` dirs (both `chown rekord:rekord`, uid 10001 at build) — no seed/init helper needed. Music is added into `re-kord-music` later (Stage A gate uses `docker cp` or admin upload).
6. **No `app/images/`:** published image exists → no source build, no `build:` section, no seed service.
7. **stackbuilder.toml:** polaris format (most recent precedent): `yaml_merger = "rust"` (both precedents use it; `yq` present at `/usr/bin/yq`), `skip_base_generation = true` globally, per-env `skip_base_generation = false` for the three base-only environments. NO `[build.combos]` — re-kord has zero implemented extensions (catalog: all `available`, none implemented); polaris (also combo-less shape for base-only envs) is the model. `step-ca` env has NO extensions (no s3fs for re-kord).
8. **SSL overlays:** koito shape verbatim, adapted: join external `letsencrypt-network` / `step-ca-network` + external vhost volume, `VIRTUAL_PORT: 7420`, vhost config with `client_max_body_size 0` (512 MiB restores) + `chunked_transfer_encoding on` (Range streaming). re-kord-specific env: `REKORD_PUBLIC_URL: https://${VIRTUAL_HOST}` and `REKORD_ALLOWED_ORIGINS: https://${VIRTUAL_HOST}` (upstream reverse-proxy requirements). No `step-ca-trust` env (DEPLOYMENT.md stage plan doesn't list it).
9. **No README.md yet** at stack root (precedent: README generation is a later phase via `readme-gen`).
10. **`.gitignore`:** `.env` + `.stackbuilder/` only; `app/build/` is COMMITTED.

---

## Dependency Graph

```
Batch 1 (parallel): 1.1–1.12  [all independent file creations]
Batch 2 (single):   2.1       [sb build + verification + commit build/]
```

All paths below are relative to the stack root:
`stacks/self-hosting/media-streaming/music/re-kord/`

---

## Batch 1: Foundation (parallel — 12 implementers)

### Task 1.1: `.gitignore`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/.gitignore`
**Depends:** none

```
.env
.stackbuilder/
```

**Verify:** `git -C stacks/self-hosting/media-streaming/music/re-kord check-ignore -q .env && echo ok`
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.2: `.gitmessage`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/.gitmessage`
**Depends:** none

Copy verbatim from `stacks/self-hosting/media-streaming/music/polaris/.gitmessage` (18 lines, commit-template rules comment block).

**Verify:** `diff` against the polaris file is empty.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.3: `LICENSE-APACHE`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/LICENSE-APACHE`
**Depends:** none

Copy verbatim from `stacks/self-hosting/media-streaming/music/polaris/LICENSE-APACHE`.

**Verify:** `diff` empty vs polaris file.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.4: `LICENSE-MIT`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/LICENSE-MIT`
**Depends:** none

Copy verbatim from `stacks/self-hosting/media-streaming/music/polaris/LICENSE-MIT`.

**Verify:** `diff` empty vs polaris file.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.5: `.vscode/settings.json`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/.vscode/settings.json`
**Depends:** none

Copy verbatim from `stacks/self-hosting/media-streaming/music/polaris/.vscode/settings.json` (git repo isolation + file associations; no `.codegraph`/formatting entries needed).

**Verify:** `python3 -m json.tool` parses it.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.6: `UPSTREAM.md`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/UPSTREAM.md`
**Depends:** none

```markdown
# Upstream provenance log

Append-only. One row per upstream sync. Never edit or delete previous rows.

| Date (UTC) | Upstream commit | Tag/Ref | Note |
|---|---|---|---|
| 2026-11-05 | b4e05cd | v5.3 (release 5.3.0) | Initial dockerization (upstream `Creiv/RE-KORD`; published image `ghcr.io/creiv/re-kord:latest`, amd64/arm64; clone reference-only, nothing vendored) |
```

**Verify:** table has exactly one data row; upstream commit matches `git -C /tmp/opencode/upstreams/re-kord log -1 --format=%h` (re-verify at execution time; if HEAD moved, use the new hash).
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.7: `app/stackbuilder.toml`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/stackbuilder.toml`
**Depends:** none

```toml
[paths]
environments_path = "./environments"
extensions_dirs = ["extensions"]

[build]
yaml_merger = "rust"
skip_base_generation = true
copy_additional_files = true

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

# Base-only environments: keep generating their build dirs (global
# skip_base_generation = true would otherwise drop them).
[build.environments.forwarding]
skip_base_generation = false

[build.environments.letsencrypt]
skip_base_generation = false

[build.environments.step-ca]
skip_base_generation = false
```

**Verify:** `sb build` in Task 2.1 succeeds with these three envs.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.8: `app/components/base/docker-compose.yml`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/base/docker-compose.yml`
**Depends:** none

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

x-healthcheck: &default-healthcheck
  test:
    [
      "CMD",
      "curl", "-fsS", "http://127.0.0.1:7420/api/v1/health",
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s

services:
  re-kord:
    container_name: re-kord
    image: ${IMAGE:-ghcr.io/creiv/re-kord:latest}
    restart: unless-stopped
    logging: *default-logging
    healthcheck: *default-healthcheck
    environment:
      REKORD_BIND: ${REKORD_BIND:-0.0.0.0:7420}
      REKORD_DATA_DIR: ${REKORD_DATA_DIR:-/data}
      REKORD_MUSIC_ROOT: ${REKORD_MUSIC_ROOT:-/music}
      # Inside the container no request is local: machine operations
      # (scan, restore, tunnel) need this, or docker exec curl against
      # 127.0.0.1. Enable only on a trusted network.
      REKORD_ALLOW_REMOTE_ADMIN: ${REKORD_ALLOW_REMOTE_ADMIN:-0}
      TZ: ${TZ:-UTC}
    volumes:
      - re-kord-data:/data
      - re-kord-music:/music
    networks:
      - re-kord-network

volumes:
  re-kord-data:
    name: re-kord-data
  re-kord-music:
    name: re-kord-music

networks:
  re-kord-network:
    name: re-kord-network
```

**Verify:** `docker compose -f <file> config` parses; service/volume/network names exact.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.9: `app/components/base/.env.example`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/base/.env.example`
**Depends:** 1.8 (must reference exactly the vars the base compose uses)

```
# === BASE CONFIGURATION ===
# Project name for Docker Compose
COMPOSE_PROJECT_NAME=re-kord

# Docker image (published by upstream; pin a release e.g. ghcr.io/creiv/re-kord:5.3.0)
IMAGE=ghcr.io/creiv/re-kord:latest

# Logging
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

# Timezone
TZ=UTC

# Hub server (container-internal wiring — keep upstream defaults)
REKORD_BIND=0.0.0.0:7420
REKORD_DATA_DIR=/data
REKORD_MUSIC_ROOT=/music

# Allow admin/machine operations from non-local clients (0 = off)
REKORD_ALLOW_REMOTE_ADMIN=0
```

Only vars the base compose references. `REKORD_ACCESS_KEY` deliberately absent (optional feature, later decision).
**Verify:** every `VAR` referenced in 1.8 appears here; no extra vars.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.10: `app/components/environments/forwarding/docker-compose.yml`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/environments/forwarding/docker-compose.yml`
**Depends:** none

```yaml
services:
  re-kord:
    ports:
      - "${REKORD_PORT:-7420}:7420"
```

**Verify:** merges cleanly in Task 2.1 build.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.11: `app/components/environments/letsencrypt/docker-compose.yml`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/environments/letsencrypt/docker-compose.yml`
**Depends:** none

```yaml
services:
  re-kord:
    environment:
      VIRTUAL_PORT: 7420
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      REKORD_PUBLIC_URL: https://${VIRTUAL_HOST}
      REKORD_ALLOWED_ORIGINS: https://${VIRTUAL_HOST}
    configs:
      - source: vhost
        target: ${VHOST_PATH:-/vhost.d/${VIRTUAL_HOST}}
    volumes:
      - letsencrypt-vhost:/vhost.d
    networks:
      - letsencrypt-network

volumes:
  letsencrypt-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
      chunked_transfer_encoding on;

networks:
  letsencrypt-network:
    external: true
```

**Verify:** merges cleanly in Task 2.1 build.
**Commit:** with the stack scaffold commit (Task 2.1).

### Task 1.12: `app/components/environments/step-ca/docker-compose.yml`
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/environments/step-ca/docker-compose.yml`
**Depends:** none

Same as Task 1.11 with `step-ca-vhost` / `step-ca-network` names:

```yaml
services:
  re-kord:
    environment:
      VIRTUAL_PORT: 7420
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      REKORD_PUBLIC_URL: https://${VIRTUAL_HOST}
      REKORD_ALLOWED_ORIGINS: https://${VIRTUAL_HOST}
    configs:
      - source: vhost
        target: ${VHOST_PATH:-/vhost.d/${VIRTUAL_HOST}}
    volumes:
      - step-ca-vhost:/vhost.d
    networks:
      - step-ca-network

volumes:
  step-ca-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
      chunked_transfer_encoding on;

networks:
  step-ca-network:
    external: true
```

**Verify:** merges cleanly in Task 2.1 build.
**Commit:** with the stack scaffold commit (Task 2.1).

---

## Batch 2: Build + Verification (single task)

### Task 2.1: Generate `app/build/`, verify, commit everything
**Files:** all generated under `stacks/self-hosting/media-streaming/music/re-kord/app/build/` (committed) + the stack git commit.
**Depends:** 1.1–1.12

Steps (run from the stack repo root):

```bash
cd stacks/self-hosting/media-streaming/music/re-kord

# 1. Generate build dirs for all three environments
cd app && sb build && cd ..

# 2. Validate every generated compose file
for f in $(find app/build -name docker-compose.yml); do
  docker compose -f "$f" config -q || exit 1
done

# 3. Conventions checks
/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-conventions/scripts/check-stack.sh \
  stacks/self-hosting/media-streaming/music/re-kord
/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-conventions/scripts/check-gitkeep.sh \
  stacks/self-hosting/media-streaming/music/re-kord

# 4. Commit (single-line conventional message)
git add -A
git commit -m "Scaffold functional base (Stage A)"
```

Expected generated tree (committed):
```
app/build/forwarding/base/docker-compose.yml
app/build/letsencrypt/base/docker-compose.yml
app/build/step-ca/base/docker-compose.yml
```
(+ `.env.example` copies if `copy_additional_files` produces them — commit whatever `sb build` generates.)

**Verify:** `git status` clean after commit; `check-stack.sh` exits 0; no `.gitkeep` leftovers.
**Commit:** `Scaffold functional base (Stage A)`

---

## Out of scope (later phases)
- Stage A browser gate (stack-test skill): open `http://localhost:7420/`, `/admin`, library scan over `/music`, Range playback via `/media`, `GET /api/v1/health`.
- README generation (`readme-gen` skill).
- Extension decisions from the DEPLOYMENT.md catalog (access key, oidc, s3, etc.) — each needs explicit user confirmation.
