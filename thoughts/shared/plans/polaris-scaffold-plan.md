# Polaris Stack — Phase 1 Scaffold Plan (functional base)

**Goal:** Scaffold the complete functional base of the new `polaris` stack (source-built Rust music server, upstream `agersant/polaris` 0.16.1) at `stacks/self-hosting/media-streaming/music/polaris/`, ready for the Stage A browser gate.

**Architecture:** Single core service `polaris` (axum, port 5050) built from source by `app/images/polaris/Dockerfile` (pinned tag `0.16.1`, commit `218e6a4`, polaris-web `web.zip` baked alongside the binary, gate seed audio generated in-image). Base compose runs `polaris` + a one-shot `polaris-seed` init service over three named volumes (`polaris-music` / `polaris-data` / `polaris-cache`) on `polaris-network`; config `polaris.toml` is delivered via `dockerfile_inline` COPY (§13). NO database stage, NO oidc, NO s3-storage — all REFUSED in the committed deployment model (§3); Phases 2–4 are bypassed by design. Environments: `forwarding` (owns the port publish), `letsencrypt`, `step-ca`.

**Design:** `thoughts/shared/designs/polaris-deployment-model.md` (committed, ff583e6) — mirrored at the stack root as `DEPLOYMENT.md`.

---

## Paths (constants for every task)

```bash
COLLECTION=/home/archuser/projects/docker-stack-collection
STACK=$COLLECTION/stacks/self-hosting/media-streaming/music/polaris
SKILLS=$COLLECTION/.opencode/skills
```

## Decisions (gap-fills made by the planner)

- **Music seeding (H4):** seed audio is GENERATED inside the image (ffmpeg sine-tone mp3s, properly tagged, one with embedded cover art per H5) at `/seed`, and a one-shot `polaris-seed` init service copies them into `polaris-music` with `cp -rn` (no-clobber) on every `up`. This survives `compose down -v` (volume recreated → reseeded on next up) and never overwrites user-added music. No bind mounts anywhere.
- **Non-root (H3):** image runs as `USER polaris` (uid 1000); `/data`, `/cache`, `/music` are created and chowned in the image so named volumes inherit polaris ownership on first mount. The config file is baked with `COPY --chown=polaris:polaris` so polaris can rewrite it after hashing `initial_password`. Fallback if the gate hits permission errors: drop `USER polaris`, run root, note in component README.
- **Foreground (H2):** compose `command` starts with `-f` — without it the unix binary daemonizes (daemonize crate) and PID 1 exits.
- **Web client (H1):** `web.zip` from polaris-web `releases/latest` (same strategy as upstream CI); the Dockerfile normalizes both zip layouts (flat or `web/` subdir) and hard-fails if `index.html` is missing.
- **`.gitignore`:** minimal stack-level file (`.env`, `.stackbuilder/`, `build/`) — the collection-root `.gitignore` contains repo-specific stack-sync blocks and is NOT copied verbatim; the checklist requirement "must ignore `build/`" is satisfied. `.gitmessage` / `LICENSE-APACHE` / `LICENSE-MIT` ARE copied verbatim from the collection root.
- **`stackbuilder.toml`:** koito's `yaml_merger = "rust"` is NOT copied (precedent-only, forbidden without explicit user permission). Uses `skip_base_generation = true` + `copy_additional_files = true` (numa idiom) and the new `[build.environments]` API with ONE base combo `entire`.
- **Parent-tracked DEPLOYMENT.md:** stays committed in the collection repo; the stack repo gets its own copy via the initial commit. Removing the parent-tracked copy (`git rm --cached`) is deferred until polaris has a remote and lands in the stack-sync `.gitignore` block.
- **READMEs:** intentionally deferred to the `readme-gen` skill — NOT in this plan.
- **Submodules / `modules/ssl-automation`:** out of scope — polaris joins no SSL stack at scaffold time; environments are plain overlays without submodules.
- **stacks.csv row:** registered in this plan's commit (`stacks/self-hosting/media-streaming/music/polaris;-;unverified`); Task 1.20 only verifies it.

---

## Dependency Graph

```
Batch 1 (parallel): 1.1..1.20 [foundation — all independent file tasks; 1.1 is the git-init prerequisite for commits only]
Batch 2 (sequential): 2.1 image build → 2.2 sb build + compose config → 2.3 convention checks → 2.4 stack repo commits
Batch 3: 3.1 Stage A browser gate (depends on 2.1 + 2.2)
```

---

## Batch 1: Foundation (parallel — 20 independent tasks)

Every task below creates exactly ONE file (or performs one atomic action). No task depends on another task's output.

### Task 1.1: Initialize the stack git repo
**File:** `$STACK/.git` (repo init; DEPLOYMENT.md already exists on disk)
**Depends:** none

```bash
cd "$STACK" && git init -b main \
  && git add DEPLOYMENT.md \
  && git commit -m "docs: add deployment model (Phase 0 contract, upstream 0.16.1 / 218e6a4)"
```

**Verify:** `git -C "$STACK" log --oneline` shows exactly one commit; `git -C "$STACK" status --porcelain` shows DEPLOYMENT.md not dirty.
**Commit:** included in the command above.

### Task 1.2: `.gitignore`
**File:** `$STACK/.gitignore`
**Depends:** none

```gitignore
.env
.stackbuilder/
build/
```

**Verify:** `grep -q '^build/$' "$STACK/.gitignore"`
**Commit:** `chore: add gitignore`

### Task 1.3: `.gitmessage` (copy verbatim from collection root)
**File:** `$STACK/.gitmessage`
**Depends:** none

```bash
cp "$COLLECTION/.gitmessage" "$STACK/.gitmessage"
```

**Verify:** `diff -q "$COLLECTION/.gitmessage" "$STACK/.gitmessage"`
**Commit:** `chore: add gitmessage template`

### Task 1.4: `LICENSE-APACHE` (copy verbatim)
**File:** `$STACK/LICENSE-APACHE`
**Depends:** none

```bash
cp "$COLLECTION/LICENSE-APACHE" "$STACK/LICENSE-APACHE"
```

**Verify:** `diff -q "$COLLECTION/LICENSE-APACHE" "$STACK/LICENSE-APACHE"`
**Commit:** `chore: add Apache-2.0 license`

### Task 1.5: `LICENSE-MIT` (copy verbatim)
**File:** `$STACK/LICENSE-MIT`
**Depends:** none

```bash
cp "$COLLECTION/LICENSE-MIT" "$STACK/LICENSE-MIT"
```

**Verify:** `diff -q "$COLLECTION/LICENSE-MIT" "$STACK/LICENSE-MIT"`
**Commit:** `chore: add MIT license`

### Task 1.6: `.vscode/settings.json`
**File:** `$STACK/.vscode/settings.json`
**Depends:** none

```json
{
  "git.openRepositoryInParentFolders": "never",
  "git.detectSubmodules": false,
  "git.scanRepositories": [],
  "git.autoRepositoryDetection": false,
  "files.associations": {
    "LICENSE-APACHE": "plaintext",
    "LICENSE-MIT": "plaintext",
    ".gitmessage": "plaintext"
  },
  "[dockerfile]": {
    "editor.formatOnSave": false
  },
  "files.exclude": {
    "**/.git": false
  }
}
```

**Verify:** `python3 -c "import json;json.load(open('$STACK/.vscode/settings.json'))"`
**Commit:** `chore: add vscode workspace settings`

### Task 1.7: `UPSTREAM.md`
**File:** `$STACK/UPSTREAM.md`
**Depends:** none

```markdown
# Upstream provenance log

Append-only. One row per upstream sync. Never edit or delete previous rows.

| Date (UTC) | Upstream commit | Tag/Ref | Note |
|---|---|---|---|
| 2026-11-05 | 218e6a4 | 0.16.1 | Initial dockerization (upstream `agersant/polaris`; no published image exists — source-built via `app/images/polaris/Dockerfile`; web client from polaris-web latest `web.zip`, same strategy as upstream CI) |
```

**Verify:** `grep -q '218e6a4' "$STACK/UPSTREAM.md"`
**Commit:** `docs: add upstream provenance log`

### Task 1.8: Source-built image Dockerfile
**File:** `$STACK/app/images/polaris/Dockerfile`
**Depends:** none

```dockerfile
# Polaris — source-built image (stack-conventions §19 / source-image skill).
# Self-contained: EMPTY build context — the server is cloned at a pinned tag,
# the web client is fetched from polaris-web releases, and the Stage A gate
# seed audio is generated inline. NEVER vendor upstream source into the repo.

ARG RUST_IMAGE=rust:1-bookworm
ARG RUNTIME_IMAGE=debian:stable-slim
ARG POLARIS_VERSION=0.16.1

# --- server binary -----------------------------------------------------------
FROM ${RUST_IMAGE} AS server-builder
ARG POLARIS_VERSION
RUN git clone https://github.com/agersant/polaris.git /src \
 && git -C /src checkout "${POLARIS_VERSION}"
WORKDIR /src
RUN cargo build --release && cp target/release/polaris /polaris

# --- web client assets (upstream CI strategy: latest polaris-web release) ----
FROM ${RUST_IMAGE} AS web-fetcher
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/web.zip \
      https://github.com/agersant/polaris-web/releases/latest/download/web.zip \
 && mkdir /tmp/webx && unzip -q /tmp/web.zip -d /tmp/webx \
 && mkdir /web \
 && if [ -f /tmp/webx/index.html ]; then cp -a /tmp/webx/. /web/; \
    else cp -a /tmp/webx/*/ /web/; fi \
 && test -f /web/index.html

# --- gate seed audio (DEPLOYMENT.md §4; H5: one track with embedded art) -----
FROM alpine:3.20 AS seed-builder
RUN apk add --no-cache ffmpeg \
 && mkdir /seed \
 && ffmpeg -loglevel error -f lavfi -i color=c=0x1f6f8b:s=512x512 -frames:v 1 -q:v 2 /tmp/cover.jpg \
 && ffmpeg -loglevel error -f lavfi -i sine=frequency=440:duration=30 \
      -metadata title="Seed Track One" -metadata artist="Polaris Seed" \
      -metadata album="Seed Collection" -metadata track=1 \
      -c:a libmp3lame -b:a 128k /seed/01-seed-track-one.mp3 \
 && ffmpeg -loglevel error -f lavfi -i sine=frequency=550:duration=30 \
      -metadata title="Seed Track Two" -metadata artist="Polaris Seed" \
      -metadata album="Seed Collection" -metadata track=2 \
      -c:a libmp3lame -b:a 128k /seed/02-seed-track-two.mp3 \
 && ffmpeg -loglevel error -f lavfi -i sine=frequency=660:duration=30 -i /tmp/cover.jpg \
      -map 0:a -map 1:v -c:a libmp3lame -b:a 128k -c:v copy -id3v2_version 3 \
      -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
      -metadata title="Seed Track Three" -metadata artist="Polaris Seed" \
      -metadata album="Seed Collection" -metadata track=3 \
      /seed/03-seed-track-three.mp3 \
 && ls -la /seed

# --- runtime -----------------------------------------------------------------
FROM ${RUNTIME_IMAGE}
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 1000 --home-dir /app --create-home polaris
COPY --from=server-builder /polaris /app/polaris
COPY --from=web-fetcher /web/ /app/web/
COPY --from=seed-builder /seed/ /seed/
RUN chmod 0755 /app/polaris \
 && mkdir -p /data /cache /music /config \
 && chown polaris:polaris /data /cache /music
WORKDIR /app
USER polaris
EXPOSE 5050
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \
  CMD curl -f http://127.0.0.1:5050/ || exit 1
ENTRYPOINT ["/app/polaris"]
```

Notes: `/data`, `/cache`, `/music` are empty polaris-owned dirs in the image so named volumes inherit that ownership on first mount (H3). The `ui` cargo feature is Windows-only — unix builds are headless, no extra flags needed.

**Verify:** `docker build -t localhost/polaris:0.16.1 "$STACK/app/images/polaris"` (executed in Batch 2, Task 2.1 — the Dockerfile itself only needs to exist here).
**Commit:** `feat(images): add source-built polaris 0.16.1 image (server + web client + seed audio)`

### Task 1.9: Base compose
**File:** `$STACK/app/components/base/docker-compose.yml`
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
      "curl", "-f", "http://127.0.0.1:5050/",
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s

services:
  polaris:
    container_name: polaris
    image: ${IMAGE:-localhost/polaris:0.16.1}
    restart: unless-stopped
    logging: *default-logging
    healthcheck: *default-healthcheck
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE:-localhost/polaris:0.16.1}
        COPY --chown=polaris:polaris polaris.toml.example /config/polaris.toml
    # -f is MANDATORY: without it the unix binary daemonizes and PID 1 exits (H2)
    command:
      - "-f"
      - "--config"
      - "/config/polaris.toml"
      - "--data"
      - "/data"
      - "--cache"
      - "/cache"
    depends_on:
      polaris-seed:
        condition: service_completed_successfully
    volumes:
      - polaris-music:/music
      - polaris-data:/data
      - polaris-cache:/cache
    networks:
      - polaris-network

  polaris-seed:
    container_name: polaris-seed
    image: ${IMAGE:-localhost/polaris:0.16.1}
    restart: "no"
    logging: *default-logging
    user: root
    entrypoint: ["/bin/sh", "-c"]
    # -n = no-clobber: reseeds after `down -v` without ever overwriting
    # user-added music; seed files stay root-owned world-readable (polaris
    # only needs read access to scan/play them)
    command: ["cp -rn /seed/. /music/"]
    volumes:
      - polaris-music:/music
    networks:
      - polaris-network

volumes:
  polaris-music:
    name: polaris-music
  polaris-data:
    name: polaris-data
  polaris-cache:
    name: polaris-cache

networks:
  polaris-network:
    name: polaris-network
```

Notes: the `build.dockerfile_inline` block is the §13 conf-layer pattern (zot exemplar) — it layers `polaris.toml` onto the prebuilt source image; the source build itself lives ONLY in `app/images/polaris/Dockerfile` (§19: compose never builds upstream source). No `ports:` in base — plain port publishing belongs to the `forwarding` environment (§7). No env-dependent vars in base.

**Verify:** `docker compose -f "$STACK/app/components/base/docker-compose.yml" config --quiet` (may warn about missing .env — acceptable at scaffold time; full validation in Task 2.2).
**Commit:** `feat(base): add polaris core service with seed init container`

### Task 1.10: Base `.env.example`
**File:** `$STACK/app/components/base/.env.example`
**Depends:** none

```env
# === BASE CONFIGURATION ===
# Project name for Docker Compose
COMPOSE_PROJECT_NAME=polaris

# Docker image (source-built: app/images/polaris/Dockerfile)
IMAGE=localhost/polaris:0.16.1

# Logging
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true
```

Only vars the base compose actually references (§6 hygiene). `POLARIS_PORT` is env-dependent → forwarding overlay only.

**Verify:** every var name above appears in `$STACK/app/components/base/docker-compose.yml`.
**Commit:** `chore(base): add env example`

### Task 1.11: `polaris.toml.example` (config delivered via dockerfile_inline COPY)
**File:** `$STACK/app/components/base/polaris.toml.example`
**Depends:** none

```toml
# Polaris configuration — baked to /config/polaris.toml by the base compose
# dockerfile_inline layer. `initial_password` is pbkdf2-hashed by polaris at
# first boot (the file is rewritten in place; it is baked polaris-owned so
# that write succeeds). Change credentials via the web UI afterwards.

[[users]]
name = "admin"
initial_password = "changeme"

[[mount_dirs]]
name = "Music"
path = "/music"
```

No `port` key — the server defaults to 5050 and the port is owned by the forwarding overlay publish mapping.

**Verify:** `grep -q 'mount_dirs' "$STACK/app/components/base/polaris.toml.example" && grep -q 'initial_password' "$STACK/app/components/base/polaris.toml.example"`
**Commit:** `feat(base): add polaris.toml config example (admin user + music mount)`

### Task 1.12: forwarding environment compose
**File:** `$STACK/app/components/environments/forwarding/docker-compose.yml`
**Depends:** none

```yaml
services:
  polaris:
    ports:
      - "${POLARIS_PORT:-5050}:5050"
```

**Verify:** `docker compose -f "$STACK/app/components/environments/forwarding/docker-compose.yml" config --quiet` (merge validation happens in Task 2.2).
**Commit:** `feat(environments): add forwarding overlay (plain port publish)`

### Task 1.13: forwarding environment `.env.example`
**File:** `$STACK/app/components/environments/forwarding/.env.example`
**Depends:** none

```env
# === FORWARDING ENVIRONMENT ===
# Host port the polaris web client / API is published on
POLARIS_PORT=5050
```

**Verify:** `grep -q 'POLARIS_PORT' "$STACK/app/components/environments/forwarding/.env.example"`
**Commit:** `chore(environments): add forwarding env example`

### Task 1.14: letsencrypt environment compose
**File:** `$STACK/app/components/environments/letsencrypt/docker-compose.yml`
**Depends:** none

```yaml
services:
  polaris:
    environment:
      VIRTUAL_PORT: ${VIRTUAL_PORT:-5050}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
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

Polaris terminates plain HTTP behind the proxy — no app-native TLS env needed (DEPLOYMENT.md §5).

**Verify:** file parses as YAML: `python3 -c "import yaml,sys;yaml.safe_load(open('$STACK/app/components/environments/letsencrypt/docker-compose.yml'))"`
**Commit:** `feat(environments): add letsencrypt overlay`

### Task 1.15: letsencrypt environment `.env.example`
**File:** `$STACK/app/components/environments/letsencrypt/.env.example`
**Depends:** none

```env
# === LETSENCRYPT ENVIRONMENT ===
VIRTUAL_HOST=polaris.example.com
LETSENCRYPT_HOST=polaris.example.com
LETSENCRYPT_EMAIL=admin@example.com
VIRTUAL_PORT=5050
```

**Verify:** `grep -q 'VIRTUAL_HOST' "$STACK/app/components/environments/letsencrypt/.env.example"`
**Commit:** `chore(environments): add letsencrypt env example`

### Task 1.16: step-ca environment compose
**File:** `$STACK/app/components/environments/step-ca/docker-compose.yml`
**Depends:** none

```yaml
services:
  polaris:
    environment:
      VIRTUAL_PORT: ${VIRTUAL_PORT:-5050}
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
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

**Verify:** `python3 -c "import yaml,sys;yaml.safe_load(open('$STACK/app/components/environments/step-ca/docker-compose.yml'))"`
**Commit:** `feat(environments): add step-ca overlay`

### Task 1.17: step-ca environment `.env.example`
**File:** `$STACK/app/components/environments/step-ca/.env.example`
**Depends:** none

```env
# === STEP-CA ENVIRONMENT ===
VIRTUAL_HOST=polaris.example.com
LETSENCRYPT_HOST=polaris.example.com
LETSENCRYPT_EMAIL=admin@example.com
VIRTUAL_PORT=5050
```

**Verify:** `grep -q 'VIRTUAL_HOST' "$STACK/app/components/environments/step-ca/.env.example"`
**Commit:** `chore(environments): add step-ca env example`

### Task 1.18: `stackbuilder.toml`
**File:** `$STACK/app/stackbuilder.toml`
**Depends:** none

```toml
[paths]
environments_path = "./environments"
extensions_dirs = ["extensions"]

[build]
skip_base_generation = true
copy_additional_files = true

[build.combos]
entire = []

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
extensions = []
combos = ["entire"]

[build.environments.letsencrypt]
extensions = []
combos = ["entire"]

[build.environments.step-ca]
extensions = []
combos = ["entire"]
```

NOTE: koito's `yaml_merger = "rust"` is deliberately NOT copied (precedent-only; forbidden without explicit user permission).

**Verify:** `python3 -c "import tomllib;tomllib.load(open('$STACK/app/stackbuilder.toml','rb'))"`
**Commit:** `feat: add stackbuilder config (single `entire` combo, three environments)`

### Task 1.19: `.gitkeep` for the empty extensions dir
**File:** `$STACK/app/components/extensions/.gitkeep`
**Depends:** none

```bash
mkdir -p "$STACK/app/components/extensions" && touch "$STACK/app/components/extensions/.gitkeep"
```

(Empty file — pure placeholder, never referenced by configs.)

**Verify:** `bash "$SKILLS/stack-conventions/scripts/check-gitkeep.sh" "$STACK"` prints nothing.
**Commit:** `chore: add gitkeep for empty extensions dir`

### Task 1.20: Register the stack in `stacks.csv` (collection repo — VERIFY ONLY, row added with this plan's commit)
**File:** `$COLLECTION/stacks.csv`
**Depends:** none

```bash
grep -q '^stacks/self-hosting/media-streaming/music/polaris;' "$COLLECTION/stacks.csv" \
  || echo "stacks/self-hosting/media-streaming/music/polaris;-;unverified" >> "$COLLECTION/stacks.csv"
```

**Verify:** `grep -q '^stacks/self-hosting/media-streaming/music/polaris;-;unverified$' "$COLLECTION/stacks.csv"`
**Commit:** none (row lands with the plan commit in the collection repo).

---

## Batch 2: Build + validation (sequential)

### Task 2.1: Build the source image
**File:** none (build action)
**Depends:** 1.8

```bash
docker build -t localhost/polaris:0.16.1 "$STACK/app/images/polaris"
```

**Verify:** `docker run --rm localhost/polaris:0.16.1 --help` exits 0 and mentions `-f`; `docker run --rm --entrypoint ls localhost/polaris:0.16.1 /app/web /seed` lists `index.html` and the three seed mp3s.
**Commit:** none.

### Task 2.2: `sb build` + compose config validation for every variant
**File:** none (build action)
**Depends:** 1.9, 1.10, 1.11, 1.12, 1.14, 1.16, 1.18

```bash
cd "$STACK/app" && sb build
for variant in build/forwarding/entire build/letsencrypt/entire build/step-ca/entire; do
  docker compose --project-directory "$STACK/app/$variant" -f "$variant/docker-compose.yml" config --quiet
done
```

**Verify:** `build/<env>/<combo>/` structure exists for all three environments; every `docker compose config` exits 0; `polaris.toml.example` is present in each build dir (copy_additional_files).
**Commit:** none (`build/` is gitignored).

### Task 2.3: Convention checks
**File:** none (verification action)
**Depends:** all Batch 1 file tasks

```bash
bash "$SKILLS/stack-conventions/scripts/check-gitkeep.sh" "$STACK"
bash "$SKILLS/stack-conventions/scripts/check-stack.sh" "$STACK"
```

**Verify:** both scripts print no errors (check-gitkeep must print nothing; run with `--fix` if it flags the extensions dir, then re-verify).
**Commit:** none.

### Task 2.4: Commit the scaffold in the stack repo
**File:** none (git action)
**Depends:** 1.2–1.19

```bash
cd "$STACK" \
  && git add .gitignore .gitmessage LICENSE-APACHE LICENSE-MIT .vscode UPSTREAM.md \
       app/images app/components app/stackbuilder.toml \
  && git commit -m "feat: scaffold functional base (polaris core service, seed init, environments)"
```

**Verify:** `git -C "$STACK" status --porcelain` is empty (except nothing untracked); `git -C "$STACK" log --oneline` shows the docs commit + scaffold commits.
**Commit:** included in the command above (per-task commits from Batch 1 are also acceptable — executor may commit per task; the end state must be a clean tree).

---

## Batch 3: Stage A browser gate (functional base)

### Task 3.1: Stage A gate — DEPLOYMENT.md functional gate scenario
**File:** none (test action; screenshots saved as run artifacts)
**Depends:** 2.1, 2.2

Load the `agent-browser` skill first (`agent-browser skills get core`). No step-ca/oidc/s3 stages exist for this stack — Stage A is the ONLY gate. Use the **forwarding** variant (plain HTTP, no TLS prerequisites).

**Deploy:**

```bash
cd "$STACK/app/build/forwarding/entire"
[ -f .env ] || cp "$STACK/app/components/base/.env.example" .env
docker compose up -d
docker logs polaris          # expect: foreground mode, config path /config/polaris.toml, port 5050
docker ps --filter name=polaris --format '{{.Names}} {{.Status}}'   # polaris healthy; polaris-seed Exited (0)
```

**Gate checklist (each item = pass/fail, screenshot the working states):**

- [ ] Fresh boot: `polaris` stays up (H2 — container would exit without `-f`); healthcheck turns healthy.
- [ ] `polaris-seed` exits 0; `docker exec polaris ls /music` shows the three seed mp3s.
- [ ] Open `http://localhost:5050` in agent-browser: polaris-web UI loads (H1 — a web/API DTO mismatch surfaces immediately here).
- [ ] Log in with the TOML admin (`admin` / `changeme`).
- [ ] Settings shows the `[[mount_dirs]]` entry `Music → /music`.
- [ ] Trigger an index scan via the UI action (or `POST /api/trigger_index`); poll `GET /api/index_status` until the index completes.
- [ ] Browse albums: "Seed Collection" appears with artwork (H5 — the embedded cover in "Seed Track Three" exercises the thumbnail path; verify a thumbnail renders).
- [ ] Play "Seed Track Three" end-to-end in the browser player (exercises native_db reads + Range-based audio streaming).
- [ ] Non-root check (H3): `docker exec polaris id` runs as uid 1000; no permission errors in `docker logs polaris`. If password-hash/scan write errors appear → fallback: remove `USER polaris` from the Dockerfile, rebuild, re-run the gate, record the fallback in the component README.
- [ ] Reseed check (H4): `docker compose down -v && docker compose up -d` → seed files reappear, gate scenario still passes.
- [ ] Screenshot the working app state (logged in, album view, playing track) → run artifact.

**Model-vs-gate mismatch** → update `DEPLOYMENT.md` (living doc, §20) and re-run the stage.

**Verify:** all checklist items pass; screenshots saved.
**Commit:** none (test artifacts only). If DEPLOYMENT.md was updated: `docs: record Stage A gate observations` in the stack repo.

---

## Out of scope (explicitly)

- README.md files (stack-root hub + app component) — deferred to `readme-gen`.
- `.gitmodules` / `modules/ssl-automation` submodules — polaris joins no SSL stack.
- database/postgresql, pgrust, oidc, s3-storage stages — REFUSED in DEPLOYMENT.md §3; never implement.
- s3fs-fuse media volume, DDNS toggle — extension-menu items (Phase 5, user confirmation only).
- Removing the parent-tracked `DEPLOYMENT.md` from the collection repo index — deferred until polaris has a remote.
