# re-kord Extensions Implementation Plan

**Goal:** Implement the five confirmed re-kord extensions (access-key auth, remote-admin, podcasts toggle, yt-dlp toggle, s3fs-fuse for `/music`) as gated extension fragments, then regenerate READMEs.

**Architecture:** Each extension is its own micro-batch: fragment files under `app/components/extensions/<ext>/` + `app/stackbuilder.toml` wiring + `sb build` + `docker compose config` + a stack-test gate in the **forwarding** environment (user-confirmed). Extensions are implemented strictly one at a time, in the user-confirmed order: access-key → remote-admin → podcasts → yt-dlp → s3fs-fuse (heaviest, needs live RustFS, LAST). Final batch regenerates READMEs.

**Stack repo:** `stacks/self-hosting/media-streaming/music/re-kord/` (independent git repo — all `Commit:` lines below run there). **No push at any point.**

**Design:** Confirmed extension list + ordering from user checkpoint; upstream evidence verified from https://github.com/Creiv/RE-KORD (cloned at `/tmp/opencode/upstreams/re-kord`).

---

## Verified upstream evidence (cite, never guess)

| Var / toggle | Semantics | Evidence |
|---|---|---|
| `REKORD_ACCESS_KEY` | 32–256 chars, classes `A-Z a-z 0-9 . _ ~ -`, ≥10 different chars, not a repeated block. **Set but empty/invalid/weak → hub refuses to start.** | `docs/DEPLOY.md` "Environment only" table; commented example in upstream `docker-compose.yml` |
| `REKORD_ALLOW_REMOTE_ADMIN` | Default `0`; `1` allows machine ops (scan/restore/tunnel) from non-local clients | `docs/DEPLOY.md`; `docs/install.md:192`. **Already wired in stack base compose** (`app/components/base/docker-compose.yml:34`) with `${REKORD_ALLOW_REMOTE_ADMIN:-0}` |
| `ENABLE_YTDLP` | NOT `REKORD_*`-prefixed. Default `1`; `0` disables Studio downloads | `crates/core/src/ytdlp.rs:120`, `crates/core/src/config.rs:568` |
| Podcasts | **App-internal toggle, NO env var.** Admin panel → *Podcasts & news* / `PUT /api/v1/podcasts/admin/settings`, persisted in `settings.json` → `podcasts` (`enabled`, `cacheTtlMinutes`); off by default; discovery via `GET /api/v1/health` → `modules` contains `"podcasts"`, and `GET /api/v1/modules` | `docs/MODULES.md` |
| Base defaults | `REKORD_BIND=0.0.0.0:7420`, `REKORD_DATA_DIR=/data`, `REKORD_MUSIC_ROOT=/music`, image `ghcr.io/creiv/re-kord:latest`, container uid **10001** | upstream `docker-compose.yml` |

**s3fs-fuse precedent (copy the pattern):** `stacks/self-hosting/media-streaming/music/polaris/app/components/extensions/s3fs-fuse/` (`docker-compose.yml` + `s3fs-entrypoint.sh`). Key facts from it: stackbuilder merges volume/network lists **append-only** (base `re-kord-music:/music` mount cannot be removed → entrypoint `umount`s it); `entrypoint:` must be a **string** so the merge replaces the image ENTRYPOINT; s3fs needs `-f`-style foreground + `SYS_ADMIN` cap + `/dev/fuse` + `apparmor:unconfined`; credentials go into a 0600 passwd file, never logged.

**RustFS network:** the RustFS stack's base network is `rustfs-network` (`stacks/devops/s3/storage/rustfs/app/components/base/docker-compose.yml`), reachable as host `rustfs` on that network → `S3FS_ENDPOINT=http://rustfs:9000`, attach via `networks: rustfs-network: external: true`.

**Conventions enforced throughout:** every compose env value overridable (`${VAR:-}` / `${VAR:?}`); `.env.example` holds only vars the fragment actually references; no bind mounts (s3fs-fuse exception: FUSE device only); `app/build/` regenerated exclusively via `sb build`, never hand-edited; DEPLOYMENT.md is the contract — flip extension statuses `available` → `implemented` as each gate passes.

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4   [access-key fragment + wiring + docs]
  → Gate 1 (sequential, after batch 1)
Batch 2 (parallel): 2.1                  [remote-admin: doc-only + gate]
Batch 3 (parallel): 3.1                  [podcasts: doc-only + browser gate]
Batch 4 (parallel): 4.1, 4.2, 4.3, 4.4   [yt-dlp fragment + wiring + docs]
  → Gate 4
Batch 5: 5.0 (discovery) → 5.1, 5.2, 5.3, 5.4, 5.5 [s3fs-fuse] → Gate 5
Batch 6 (parallel): 6.1, 6.2             [README regen + final commit]
```

Batches are **sequential** (one extension at a time, each gated). Within a batch, tasks touch different files → parallel.

---

## Batch 1: access-key auth (parallel — 4 implementers)

Upstream refuses to start on an empty/invalid/weak `REKORD_ACCESS_KEY`, so the fragment uses the **required** idiom `${REKORD_ACCESS_KEY:?...}` — compose fails fast at `config`/`up` time instead of booting an unauthenticated hub. NOT `${VAR:-}`.

### Task 1.1: access-key compose fragment
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/access-key/docker-compose.yml`
**Test:** Gate 1 below
**Depends:** none

```yaml
# access-key extension: requires REKORD_ACCESS_KEY for the hub.
#
# Upstream semantics (docs/DEPLOY.md "Environment only" table + commented
# example in upstream docker-compose.yml): the key must be 32-256 chars
# from A-Z a-z 0-9 . _ ~ -, contain at least 10 different characters, and
# not be a repeated block. The hub REFUSES TO START when the variable is
# set but empty/invalid/weak — so this fragment uses the required-var
# idiom (${VAR:?}) and compose fails fast when the key is missing or
# empty, instead of booting an unauthenticated hub.
#
# The rust yaml merger merges service environment maps key-by-key, so
# this adds one key to the base `re-kord` service without touching the
# rest of the base definition.
services:
  re-kord:
    environment:
      REKORD_ACCESS_KEY: ${REKORD_ACCESS_KEY:?REKORD_ACCESS_KEY is required: 32-256 chars from A-Z a-z 0-9 . _ ~ - with at least 10 different characters}
```

**Verify:** `cd stacks/self-hosting/media-streaming/music/re-kord && sb build && cd app/build/forwarding && docker compose config >/dev/null && echo OK` (after Tasks 1.2/1.3; with `REKORD_ACCESS_KEY=` empty in `.env`, `docker compose config` must FAIL with the message above — that is the fail-fast proof).
**Commit:** `feat(re-kord): access-key extension fragment`

### Task 1.2: access-key .env.example
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/access-key/.env.example`
**Test:** Gate 1
**Depends:** none

```bash
# access-key
# Required when the access-key extension is wired. 32-256 chars from
# A-Z a-z 0-9 . _ ~ -, at least 10 different characters, no repeated
# block. Empty/invalid/weak -> the hub refuses to start (upstream
# behavior, docs/DEPLOY.md).
REKORD_ACCESS_KEY=
```

**Verify:** after `sb build`, `app/build/forwarding/.env.example` contains the `# access-key` section (stackbuilder merges extension `.env.example` files into the build dir — precedent: `stacks/distribution/server/components/extensions/auth/oidc/.env.example`).
**Commit:** `feat(re-kord): access-key env example`

### Task 1.3: wire access-key into all environments
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/stackbuilder.toml`
**Test:** `sb build` produces the fragment merged in all three build dirs
**Depends:** none (content-wise; gate needs 1.1+1.2)

Auth is environment-agnostic → wire into all three. Full resulting file:

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
extensions = ["access-key"]

[build.environments.letsencrypt]
skip_base_generation = false
extensions = ["access-key"]

[build.environments.step-ca]
skip_base_generation = false
extensions = ["access-key"]
```

**Verify:** `sb build && grep -c REKORD_ACCESS_KEY app/build/{forwarding,letsencrypt,step-ca}/docker-compose.yml` → `1 1 1`.
**Commit:** `feat(re-kord): wire access-key extension into all environments`

### Task 1.4: DEPLOYMENT.md status flip
**File:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md`
**Test:** none (docs)
**Depends:** none

Line 62: change `| access-key auth (REKORD_ACCESS_KEY) — required for remote/reverse-proxy access | product | available | none (compose env fragment) |` → status `implemented`. Also update line 41's parenthetical `(s3fs-fuse only, available)` only when s3fs-fuse lands (Batch 5) — leave untouched here.

**Verify:** `grep -n "access-key auth" DEPLOYMENT.md` shows `implemented`.
**Commit:** `docs(re-kord): access-key extension implemented`

### Gate 1 (sequential, after Batch 1) — forwarding env

```bash
cd stacks/self-hosting/media-streaming/music/re-kord/app/build/forwarding
cp .env.example .env
# Generate a compliant key, e.g.:
openssl rand -hex 24   # 48 chars, >10 different chars — compliant
# put it in .env as REKORD_ACCESS_KEY=<key>
docker compose config && docker compose up -d
curl -fsS http://localhost:7420/api/v1/health   # health is unauthenticated (base healthcheck curls it without a key)
```

Checks:
1. **Negative:** set `REKORD_ACCESS_KEY=short` in `.env` → `docker compose up -d` must fail (container exits / unhealthy, log shows key rejection). Restore the strong key afterwards.
2. **Positive:** UI at `http://localhost:7420` asks for the access key; wrong key rejected; correct key grants access (load `agent-browser` skill before browser steps).
3. Unauthenticated non-health API call (e.g. `curl -i http://localhost:7420/api/v1/modules`) is rejected (401) without the key.

---

## Batch 2: remote-admin (parallel — 1 implementer)

**Decision — no compose fragment.** `REKORD_ALLOW_REMOTE_ADMIN` is already wired in base (`app/components/base/docker-compose.yml:34`, `${REKORD_ALLOW_REMOTE_ADMIN:-0}`) and stack-conventions say the env stays wired in base; a fragment re-declaring it would be dead weight. This extension is documentation + a behavioral gate only.

### Task 2.1: DEPLOYMENT.md status flip
**File:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md`
**Test:** Gate 2
**Depends:** Gate 1 passed

Line 66: `| remote-admin enable (REKORD_ALLOW_REMOTE_ADMIN) | product | available | none (env stays wired in base) |` → status `implemented (base-wired; doc-only extension)`.

**Verify:** `grep -n "remote-admin" DEPLOYMENT.md` shows `implemented`.
**Commit:** `docs(re-kord): remote-admin extension implemented (base-wired)`

### Gate 2 — forwarding env

```bash
cd stacks/self-hosting/media-streaming/music/re-kord/app/build/forwarding
# default .env has REKORD_ALLOW_REMOTE_ADMIN=0
docker compose up -d
# machine op from a NON-LOCAL client (another container on re-kord-network):
docker run --rm --network re-kord-network curlimages/curl -si \
  -X POST http://re-kord:7420/api/v1/library/scan | head -1   # expect 403
# flip: REKORD_ALLOW_REMOTE_ADMIN=1 in .env, then
docker compose up -d
docker run --rm --network re-kord-network curlimages/curl -si \
  -X POST http://re-kord:7420/api/v1/library/scan | head -1   # expect 2xx/202
# restore REKORD_ALLOW_REMOTE_ADMIN=0
```

Implementer: confirm the exact machine-op path from upstream `docs/DEPLOY.md` / `docs/install.md:192` before running; the POST above is the expected shape. Inside the container no request is local (base compose comment) — that is why the test client is a second container, not `docker exec curl`.

---

## Batch 3: podcasts toggle (parallel — 1 implementer)

**Decision — no compose fragment, no env var.** Verified app-internal toggle (`docs/MODULES.md`): admin panel → *Podcasts & news* / `PUT /api/v1/podcasts/admin/settings`, persisted in `settings.json` on the `re-kord-data` volume; off by default. Wiring approach = browser toggle; no `.env.example` vars (hygiene: no dead vars).

### Task 3.1: DEPLOYMENT.md status flip
**File:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md`
**Test:** Gate 3
**Depends:** Gate 2 passed

Line 64: `| podcasts module (in-hub module toggle) | product | available | none |` → status `implemented (app-internal toggle; no env var)`.

**Verify:** `grep -n "podcasts module" DEPLOYMENT.md` shows `implemented`.
**Commit:** `docs(re-kord): podcasts extension implemented (app-internal)`

### Gate 3 — forwarding env (browser; load `agent-browser` skill first)

1. `docker compose up -d` (default env).
2. `curl -fsS http://localhost:7420/api/v1/health | jq .modules` → no `"podcasts"`.
3. Browser: log in → `/admin` → *Podcasts & news* → enable.
4. `curl -fsS http://localhost:7420/api/v1/health | jq .modules` → contains `"podcasts"`; `curl -fsS http://localhost:7420/api/v1/modules` lists the module.
5. Persistence: `docker compose restart re-kord` → modules still contains `"podcasts"` (settings.json survived).

---

## Batch 4: yt-dlp import toggle (parallel — 4 implementers)

Upstream default is **ON** (`ENABLE_YTDLP=1`); the extension exposes the overridable env so operators can turn Studio downloads off — it does not "enable" anything. **Decision:** expose only `ENABLE_YTDLP`. `REKORD_YTDLP_COOKIES` is deliberately out of scope: it points at a file inside the container, which would require a mounted cookies file (bind mount — banned; extra volume — scope creep). Documented as a follow-up in DEPLOYMENT.md wording.

### Task 4.1: yt-dlp compose fragment
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/yt-dlp/docker-compose.yml`
**Test:** Gate 4
**Depends:** none

```yaml
# yt-dlp extension: overridable toggle for the bundled yt-dlp importer.
#
# Upstream evidence: the tool (yt-dlp + qjs) is bundled in the image and
# used in-process; the toggle is ENABLE_YTDLP (NOT REKORD_*-prefixed),
# default 1, 0 disables Studio downloads
# (crates/core/src/ytdlp.rs:120, crates/core/src/config.rs:568).
# Upstream default is ON, so this fragment exposes the overridable env
# rather than enabling something off.
#
# REKORD_YTDLP_COOKIES (cookie file for age-gated/private videos,
# docs/DEPLOY.md) is intentionally NOT exposed: it would require
# mounting a cookies file into the container (no-bind-mount policy).
services:
  re-kord:
    environment:
      ENABLE_YTDLP: ${ENABLE_YTDLP:-1}
```

**Verify:** `sb build && grep -n ENABLE_YTDLP app/build/forwarding/docker-compose.yml`.
**Commit:** `feat(re-kord): yt-dlp toggle extension fragment`

### Task 4.2: yt-dlp .env.example
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/yt-dlp/.env.example`
**Test:** Gate 4
**Depends:** none

```bash
# yt-dlp
# 1 = Studio downloads enabled (upstream default), 0 = disabled.
ENABLE_YTDLP=1
```

**Verify:** merged section appears in `app/build/forwarding/.env.example` after `sb build`.
**Commit:** `feat(re-kord): yt-dlp env example`

### Task 4.3: wire yt-dlp into all environments
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/stackbuilder.toml`
**Test:** `sb build`
**Depends:** 1.3 (extends its file)

Append `yt-dlp` to each environment's extension list (full resulting file):

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
extensions = ["access-key", "yt-dlp"]

[build.environments.letsencrypt]
skip_base_generation = false
extensions = ["access-key", "yt-dlp"]

[build.environments.step-ca]
skip_base_generation = false
extensions = ["access-key", "yt-dlp"]
```

**Verify:** `sb build && grep -c ENABLE_YTDLP app/build/{forwarding,letsencrypt,step-ca}/docker-compose.yml` → `1 1 1`.
**Commit:** `feat(re-kord): wire yt-dlp extension into all environments`

### Task 4.4: DEPLOYMENT.md status flip
**File:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md`
**Test:** none
**Depends:** none

Line 63: `| yt-dlp import toggle (REKORD_* yt-dlp envs; tool bundled in image) | product | available | none |` → `| yt-dlp import toggle (ENABLE_YTDLP env; tool bundled in image) | product | implemented | none (compose env fragment; REKORD_YTDLP_COOKIES out of scope — needs a mounted file) |`. Note the corrected var name (`ENABLE_YTDLP`, not `REKORD_*`).

**Verify:** `grep -n "yt-dlp import toggle" DEPLOYMENT.md` shows `implemented` and `ENABLE_YTDLP`.
**Commit:** `docs(re-kord): yt-dlp extension implemented`

### Gate 4 — forwarding env

```bash
cd stacks/self-hosting/media-streaming/music/re-kord/app/build/forwarding
cp .env.example .env   # ENABLE_YTDLP=1
docker compose up -d
curl -fsS http://localhost:7420/api/v1/health | jq .modules
curl -fsS http://localhost:7420/api/v1/modules
# note the ytdlp-related module entry (confirm exact key name from the response)
# then: ENABLE_YTDLP=0 in .env && docker compose up -d
curl -fsS http://localhost:7420/api/v1/health | jq .modules   # ytdlp entry gone
```

Fallback if the module list is inconclusive: browser check (load `agent-browser`) — Studio download/import UI present at `1`, absent at `0`. Restore `ENABLE_YTDLP=1`.

---

## Batch 5: s3fs-fuse for `/music` (heaviest — needs live RustFS, LAST)

Serves the music library from a RustFS bucket instead of the local `re-kord-music` volume. `/data` (SQLite DB + settings.json) **stays on the local named volume** — s3fs-fuse is never on the DB volume (DEPLOYMENT.md line 39–41). Follows the polaris precedent verbatim, adapted: re-kord's container user is **uid 10001** (numeric — username not guaranteed), and the gate runs in the **forwarding** env, so the fragment attaches to the external `rustfs-network`.

### Task 5.0: image discovery (no file — blocks 5.1/5.2)
**Depends:** Gate 4 passed

```bash
docker pull ghcr.io/creiv/re-kord:latest
docker inspect ghcr.io/creiv/re-kord:latest \
  --format 'ep={{json .Config.Entrypoint}} cmd={{json .Config.Cmd}} user={{.Config.User}} os={{.Os}}'
```

Record: (a) the image ENTRYPOINT/CMD — the fragment's `command:` must reproduce the **full original server start line** (string form, so the merge replaces base and the wrapper can `exec` it); (b) `User` (expect `10001`); (c) base distro — `apt-get` (debian/ubuntu) vs `apk` (alpine) decides the dockerfile_inline package install. Fill these into Tasks 5.1/5.2 before writing them.

### Task 5.1: s3fs entrypoint script
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/s3fs-fuse/s3fs-entrypoint.sh`
**Test:** Gate 5
**Depends:** 5.0

Adapted from the polaris precedent (`stacks/self-hosting/media-streaming/music/polaris/app/components/extensions/s3fs-fuse/s3fs-entrypoint.sh`); changes: numeric `S3FS_EXEC_UID` (default 10001) instead of a named user, re-kord defaults.

```bash
#!/bin/sh
# s3fs-fuse extension entrypoint (re-kord stack).
# Mounts the RustFS bucket at /music via s3fs, then execs the service's
# original command. Credentials are supplied through environment variables
# only and written to a 0600 passwd file at start; they are never logged.
set -euf

: "${S3FS_ENDPOINT:=http://rustfs:9000}"
: "${S3FS_BUCKET:?S3FS_BUCKET is required}"
: "${S3FS_MOUNTPOINT:=/music}"
: "${S3FS_ARGS:=-o allow_other,uid=10001,gid=10001}"

: "${RUSTFS_ACCESS_KEY:?RUSTFS_ACCESS_KEY is required}"
: "${RUSTFS_SECRET_KEY:?RUSTFS_SECRET_KEY is required}"

PASSWD_FILE="/tmp/.s3fs-passwd-${S3FS_BUCKET}"
umask 077
printf '%s:%s\n' "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY" > "$PASSWD_FILE"

# The base compose still mounts the local re-kord-music volume at /music
# (stackbuilder merges volume lists append-only); drop it so the bucket is
# the only music source, then mount s3fs over the mountpoint.
umount "$S3FS_MOUNTPOINT" 2>/dev/null || true

s3fs "$S3FS_BUCKET" "$S3FS_MOUNTPOINT" \
  -o passwd_file="$PASSWD_FILE" \
  -o url="$S3FS_ENDPOINT" \
  -o use_path_request_style \
  -o connect_timeout=30 \
  -o readwrite_timeout=120 \
  $S3FS_ARGS

# s3fs can return before the mount is fully live; wait for it to appear.
i=0
while ! awk -v m="$S3FS_MOUNTPOINT" '$2 == m && $3 ~ /^fuse/ { f = 1 } END { exit !f }' /proc/mounts; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "s3fs: mount did not come up within 30s" >&2
    exit 1
  fi
  sleep 1
done

# When running as root on behalf of the app, drop privileges to the
# container's original uid (10001 per upstream compose) before exec.
if [ "$(id -u)" = "0" ] && [ -n "${S3FS_EXEC_UID:-}" ]; then
  exec setpriv --reuid="$S3FS_EXEC_UID" --regid="$S3FS_EXEC_UID" \
    --init-groups env HOME=/data "$@"
fi

exec "$@"
```

**Verify:** `sh -n s3fs-entrypoint.sh` (syntax); behavior proven by Gate 5.
**Commit:** `feat(re-kord): s3fs-fuse entrypoint script`

### Task 5.2: s3fs-fuse compose fragment
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/s3fs-fuse/docker-compose.yml`
**Test:** Gate 5
**Depends:** 5.0 (command line + distro from image inspection), 5.1

`<SERVER_CMD>` below = the full original start line discovered in Task 5.0 (string form). If the image is alpine, swap the `apt-get` layer for `apk add --no-cache s3fs fuse3` (and skip the fuse.conf echo if N/A — keep `user_allow_other` when fuse3 supports it).

```yaml
# s3fs-fuse extension: serves the music library from the RustFS bucket
# (re-kord-music) instead of the local re-kord-music volume. re-kord has
# no native S3 support, so the service gets an s3fs-enabled image built
# inline from ${IMAGE} and an entrypoint wrapper that mounts the bucket
# at /music before exec'ing the original command.
#
# /data (SQLite DB + settings.json) is NEVER on S3: the base named volume
# re-kord-data stays local (DEPLOYMENT.md: s3fs-fuse only on the music
# volume, never on the DB).
#
# NOTE: stackbuilder merges volume lists append-only, so the base
# `re-kord-music:/music` mount cannot be removed here; the entrypoint
# wrapper umounts it at start so the bucket is the only music source.
#
# Wired into the forwarding environment (gate env): the fragment declares
# the external rustfs-network where the RustFS stack lives; the rust
# merger appends it to the base re-kord-network attachment.
services:
  re-kord:
    # Distinct tag so a rebuild never clobbers the published image used
    # by the base deployment.
    image: ${REKORD_S3FS_IMAGE:-localhost/re-kord-s3fs:latest}
    # Root is needed to mount s3fs; the wrapper drops back to the
    # container's original uid (S3FS_EXEC_UID, 10001) before exec.
    user: root
    # String form (not a list) so the merge REPLACES the image ENTRYPOINT
    # instead of appending to it; the wrapper execs the original command.
    entrypoint: /usr/local/bin/s3fs-entrypoint
    # Full original server start line from `docker inspect` (Task 5.0).
    command: <SERVER_CMD>
    environment:
      S3FS_ENDPOINT: ${S3FS_ENDPOINT:-http://rustfs:9000}
      S3FS_BUCKET: ${S3FS_BUCKET:?S3FS_BUCKET is required}
      S3FS_ARGS: ${S3FS_ARGS:-}
      S3FS_EXEC_UID: ${S3FS_EXEC_UID:-10001}
      RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY:-}
      RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY:-}
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/fuse:/dev/fuse
    security_opt:
      - apparmor:unconfined
    networks:
      - rustfs-network
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE:-ghcr.io/creiv/re-kord:latest}
        USER root
        RUN apt-get update \
         && apt-get install -y --no-install-recommends s3fs fuse3 \
         && rm -rf /var/lib/apt/lists/* \
         && echo user_allow_other >> /etc/fuse.conf
        COPY s3fs-entrypoint.sh /usr/local/bin/s3fs-entrypoint
        RUN chmod 0755 /usr/local/bin/s3fs-entrypoint

networks:
  rustfs-network:
    external: true
```

**Verify:** `sb build && cd app/build/forwarding && docker compose config >/dev/null && echo OK`.
**Commit:** `feat(re-kord): s3fs-fuse extension fragment`

### Task 5.3: s3fs-fuse .env.example
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/components/extensions/s3fs-fuse/.env.example`
**Test:** Gate 5
**Depends:** none

```bash
# s3fs-fuse
# RustFS endpoint reachable from the re-kord container (rustfs-network).
S3FS_ENDPOINT=http://rustfs:9000
# Bucket holding the music library (created by rustfs-admin).
S3FS_BUCKET=re-kord-music
# FUSE mount options; uid/gid match the container's app user (10001).
S3FS_ARGS=-o allow_other,uid=10001,gid=10001
# S3 credentials for the bucket user (from rustfs-admin) — required.
RUSTFS_ACCESS_KEY=
RUSTFS_SECRET_KEY=
```

**Verify:** merged section appears in `app/build/forwarding/.env.example` after `sb build`.
**Commit:** `feat(re-kord): s3fs-fuse env example`

### Task 5.4: wire s3fs-fuse into forwarding
**File:** `stacks/self-hosting/media-streaming/music/re-kord/app/stackbuilder.toml`
**Test:** `sb build`
**Depends:** 4.3 (extends its file)

Wire into **forwarding only** (the gate env; other environments need their own RustFS network topology check — record as follow-up in DEPLOYMENT.md). Full resulting file:

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
extensions = ["access-key", "yt-dlp", "s3fs-fuse"]

[build.environments.letsencrypt]
skip_base_generation = false
extensions = ["access-key", "yt-dlp"]

[build.environments.step-ca]
skip_base_generation = false
extensions = ["access-key", "yt-dlp"]
```

**Verify:** `sb build && grep -c rustfs-network app/build/forwarding/docker-compose.yml` → `2` (service + declaration).
**Commit:** `feat(re-kord): wire s3fs-fuse extension into forwarding`

### Task 5.5: DEPLOYMENT.md status flip
**File:** `stacks/self-hosting/media-streaming/music/re-kord/DEPLOYMENT.md`
**Test:** none
**Depends:** Gate 5

Line 61: status `available` → `implemented (forwarding env; other environments pending RustFS network topology check)`. Line 41: `(s3fs-fuse only, available)` → `(s3fs-fuse only, implemented for /music)`.

**Verify:** `grep -n "s3fs-fuse" DEPLOYMENT.md` shows `implemented`.
**Commit:** `docs(re-kord): s3fs-fuse extension implemented`

### RustFS provisioning (before Gate 5) — `rustfs-admin` subagent, narrow mandate

**Provided by the subagent (can be pre-arranged):**
- Create bucket `re-kord-music` on the live RustFS.
- Create a dedicated user (e.g. `re-kord-s3fs`) + access/secret key pair.
- Attach a policy granting that user read/write **only** on `re-kord-music`.

**Cannot be pre-filled (implementer fills at gate time):** the actual `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` values go into `app/build/forwarding/.env` (never committed; `.env` is gitignored).

### Gate 5 — forwarding env (load `agent-browser` skill before browser steps)

```bash
cd stacks/self-hosting/media-streaming/music/re-kord/app/build/forwarding
cp .env.example .env
# fill RUSTFS_ACCESS_KEY / RUSTFS_SECRET_KEY from rustfs-admin output
docker compose config && docker compose up --build -d
docker logs re-kord --tail 50        # s3fs mount came up, server started
docker exec re-kord sh -c 'mount | grep /music'   # fuse mount on /music
docker volume inspect re-kord-data   # /data still the LOCAL named volume
```

1. Seed fixture: upload a minimal `Artist/Album/track.flac` (or mp3) into the bucket via mc/aws/rustfs console (rustfs-admin can do this).
2. Browser: log in → trigger a library scan → the seeded artist/album appears.
3. Negative: stop RustFS reachability is NOT tested destructively; instead verify `/data` writes still land locally: `docker exec re-kord ls /data` shows `rekord.db` + `settings.json` on the local volume.
4. Rollback check: comment out `s3fs-fuse` in `stackbuilder.toml`, `sb build`, `docker compose up -d` → base deployment with the local `re-kord-music` volume works again.

---

## Batch 6: README regeneration + final commit (parallel — 2 implementers)

### Task 6.1: regenerate READMEs
**Files:** `stacks/self-hosting/media-streaming/music/re-kord/README.md` + `app/README.md`
**Depends:** all gates passed

Load the `readme-gen` skill; regenerate the stack-root hub README and the component README (~100–250 lines) from the final DEPLOYMENT.md (base parts + extension statuses, all `implemented`).

**Verify:** READMEs list all five extensions with `implemented` status; no stale `available` rows.
**Commit:** `docs(re-kord): regenerate READMEs after extensions`

### Task 6.2: final commit + verify clean tree
**Depends:** 6.1

```bash
cd stacks/self-hosting/media-streaming/music/re-kord
git status   # must be clean; commit anything left untracked
git log --oneline -12
```

**NO push.** Report the commit list to the user.

---

## Open items / decisions recorded

- **remote-admin**: no fragment — base already wires `${REKORD_ALLOW_REMOTE_ADMIN:-0}`; doc-only + behavioral gate (justified in Batch 2).
- **podcasts**: app-internal toggle, no env var, no fragment, no `.env.example` vars (hygiene); browser gate proves `modules` discovery + persistence.
- **yt-dlp**: real var name is `ENABLE_YTDLP` (not `REKORD_*`); default ON upstream → fragment exposes the overridable env; `REKORD_YTDLP_COOKIES` out of scope (needs a mounted file).
- **access-key**: `${VAR:?}` required idiom because upstream refuses to start on empty/invalid/weak keys — fail-fast at compose level.
- **s3fs-fuse**: wired into forwarding only (gate env); extending to letsencrypt/step-ca needs a per-environment RustFS network topology check — recorded as follow-up in DEPLOYMENT.md.
- **Image ENTRYPOINT/CMD** for the s3fs fragment is discovered at Task 5.0 — never guessed.
