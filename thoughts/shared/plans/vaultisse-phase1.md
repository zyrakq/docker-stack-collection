# Vaultisse — Phase 1 (Functional Base Scaffold) Implementation Plan

**Goal:** Scaffold the complete functional base of the `vaultisse` stack: stack-root boilerplate, base compose for the single product part, the three environment overlays, the mandatory `database/{postgresql,pgrust}` extension pair, docs, and a passing Stage A functional gate.

**Architecture:** Single product part `vaultisse` (published image `ghcr.io/albertamat/vaultisse:v1.3.8` — Express API + built Vue client on one port, EXPOSE 3000; image has its own HEALTHCHECK hitting `/api/rest/app/version` via `API_PORT`). Mandatory infra: `vaultisse-db` via the `database/{postgresql,pgrust}` extension pair (§8 dual-file idiom, patterns.md §11). The app talks TCP to Postgres via `DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD` (NOT `DATABASE_URL`) and auto-migrates its schema at startup — no init-SQL mount. Only app volume is logs (`/app/logs`, image sets `LOGGER_PATH=/app/logs`). Environment-dependent vars (`FRONT_END_URL`, `TRUST_PROXY`, `ALLOW_HTTP`) live ONLY in the overlays (§7/§13) — base is environment-agnostic.

**Design / authority documents:**
- `stacks/self-hosting/media-streaming/book-management/vaultisse/DEPLOYMENT.md` — deployment model contract (Base stage plan = ordering authority; extension catalog; refusals)
- `stacks/self-hosting/media-streaming/book-management/vaultisse/UPSTREAM.md` — provenance (upstream `cbcad08`, tag `v1.3.8`)
- `.opencode/skills/stack-init/references/scaffold-checklist.md` — Phase 1 checklist mirrored below
- `.opencode/skills/stack-conventions/references/patterns.md` — §4 (vhost.d tuning), §9 (numa TOML), §10 (logging anchors), §11 (database pair), §12 (env wiring), §13 (layering)
- Upstream reference clone (READ-ONLY): `/tmp/opencode/upstreams/vaultisse-app` @ `cbcad08` — env surface verified in `server/src/AppService.ts` and `.env.example`

**Stack root:** `stacks/self-hosting/media-streaming/book-management/vaultisse/` (independent git repo; Phase 0 commit `1dcc5de` already contains `DEPLOYMENT.md` + `UPSTREAM.md`; executor commits its own work there).

---

## Scope decisions (gap-fills — read before executing)

1. **DB env mapping.** Upstream app reads `DB_*` vars; the §11 canon keeps `POSTGRES_*` canonical in `.env.example` and on the db service. The app patch therefore MAPS: `DB_NAME: ${POSTGRES_DB:-vaultisse}`, `DB_USER: ${POSTGRES_USER:-vaultisse}`, `DB_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}`, and pins `DB_HOST: vaultisse-db`, `DB_PORT: 5432` (mirroring upstream compose, which hardcodes host/port to the service name).
2. **Layering (§7/§13).** `FRONT_END_URL` (required by the app — CORS origin + CSP), `TRUST_PROXY`, `ALLOW_HTTP` are environment-dependent: declared ONLY in overlays. Forwarding owns `http://localhost:3000` + `ALLOW_HTTP=true` + `TRUST_PROXY=false`; both TLS overlays own `https://${VIRTUAL_HOST}` + `TRUST_PROXY=true` + `ALLOW_HTTP=false`. None appear in base compose or base `.env.example`.
3. **No `step-ca-trust` combo.** DEPLOYMENT.md interaction map: one group only (`vaultisse` + its DB), no inter-group links → no `step-ca-trust` requirement; `stackbuilder.toml` has no `entire-trust` combo.
4. **pgrust files now, swap later.** Phase 1 creates BOTH `database/postgresql` and `database/pgrust` file sets (prompt scope: the pair), but the `entire` combo lists `database/postgresql` only. The pgrust swap + Stage A2 re-gate is Phase 2 (scaffold-checklist "Later base stages").
5. **No init SQL.** Upstream mounts `databaseSchema.sql` into the db, but the image runs migrations itself at startup (`runMigrations` against `/app/db` SQL baked in the image) — the pair files mount NO init SQL.
6. **Healthcheck.** The image's built-in HEALTHCHECK (upstream Dockerfile:113) already checks `GET /api/rest/app/version` on `API_PORT` — base compose does NOT override it (no `curl` guarantee in the image; the node one-liner is already correct).
7. **Volumes.** Only app state outside Postgres is logs → named volume `vaultisse-logs` at `/app/logs` (§3 naming: `<stack>-<purpose>`). Ebook uploads live in Postgres (`vaultisse-db` volume).
8. **Optional product vars omitted from base.** `GOOGLE_BOOKS_API_KEY`, `LIBRARYTHING_API_KEY`, `DEMO_MODE`, `MAX_EBOOK_FILE_SIZE_MB`, `MAX_IMPORT_FILE_SIZE_MB`, `DEBUG_LOGGING`, `CSP_EXTRA_IMG_SRC` are NOT referenced by base compose → NOT in base `.env.example` (§6 hygiene). They are Phase 5 menu items (metadata-provider keys are an env-only product feature in the DEPLOYMENT.md catalog). `OIDC_*` is Stage B — do not scaffold.
9. **vhost.d tuning in TLS overlays.** Ebook uploads (default 10 MB) would hit nginx-proxy's default `client_max_body_size 1m` — both TLS overlays carry the patterns.md §4 `configs.content` vhost fragment (`client_max_body_size 0;`).
10. **app/README.md.** INCLUDED as an executor task (Task 5.1) loading the `readme-gen` skill — the Phase 1 checklist lists it, and the aionui Phase 1 plan set the precedent. Recommendation: generate it in this phase, not deferred.
11. **Submodules.** The stack joins the SSL stack (letsencrypt + step-ca environments) → `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}` submodules required (scaffold-checklist; gitea stack is the shape reference).

---

## Dependency Graph

```
Batch 1 (parallel): 1.1–1.6   [stack root boilerplate — no deps]
Batch 2 (parallel): 2.1–2.3   [app base — no deps]
Batch 3 (parallel): 3.1–3.3   [environment overlays — no deps]
Batch 4 (parallel): 4.1–4.6   [database extension pair — no deps]
Batch 5 (sequential): 5.1 README → 5.2 sb build → 5.3 checks/cleanup → 5.4 Stage A gate → 5.5 catalog registration
```

Batches 1–4 are mutually independent (12 parallel implementers); Batch 5 verifies and gates.

---

## Batch 1: Stack root (parallel — 6 implementers)

`$ROOT = /home/archuser/projects/docker-stack-collection/stacks/self-hosting/media-streaming/book-management/vaultisse`

### Task 1.1: .gitignore
**File:** `$ROOT/.gitignore`
**Test:** none
**Depends:** none

```gitignore
.env
build/
.stackbuilder/
```

**Verify:** `test -f $ROOT/.gitignore && grep -q '^\.env$' $ROOT/.gitignore`
**Commit:** `chore: add gitignore`

### Task 1.2: .gitmessage
**File:** `$ROOT/.gitmessage`
**Test:** none
**Depends:** none

Copy verbatim from the collection root (do not invent text):

```bash
cp /home/archuser/projects/docker-stack-collection/.gitmessage $ROOT/.gitmessage
```

**Verify:** `test -s $ROOT/.gitmessage`
**Commit:** `chore: add git message template`

### Task 1.3: license files
**Files:** `$ROOT/LICENSE-APACHE`, `$ROOT/LICENSE-MIT`
**Test:** none
**Depends:** none

Copy both verbatim from the collection root (exception to one-file-per-task: two static copies, one command):

```bash
cp /home/archuser/projects/docker-stack-collection/LICENSE-APACHE $ROOT/LICENSE-APACHE
cp /home/archuser/projects/docker-stack-collection/LICENSE-MIT $ROOT/LICENSE-MIT
```

**Verify:** `test -s $ROOT/LICENSE-APACHE && test -s $ROOT/LICENSE-MIT`
**Commit:** `chore: add dual license files`

### Task 1.4: .vscode/settings.json
**File:** `$ROOT/.vscode/settings.json`
**Test:** none
**Depends:** none

Exact hard-rule content (identical across collection stacks):

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
  }
}
```

**Verify:** `python3 -m json.tool $ROOT/.vscode/settings.json >/dev/null`
**Commit:** `chore: add vscode settings`

### Task 1.5: stack-root hub README
**File:** `$ROOT/README.md`
**Test:** none
**Depends:** none

Load the `readme-gen` skill and generate the **stack-root hub README** (short hub style): stack name, one-paragraph description (personal book library: vaults, ISBN/metadata lookups, ebook uploads stored in Postgres), link to `app/` (compose entry point), `app/README.md` (component docs), `DEPLOYMENT.md` (deployment model contract), `UPSTREAM.md` (provenance); base = `vaultisse` @ port 3000 + `vaultisse-db` via the `database/postgresql` extension; note in one line: s3-storage refused (no S3 support in the app), oidc staged as base stage B, cloudflared available as a product extension.

**Verify:** `test -s $ROOT/README.md && grep -q "DEPLOYMENT.md" $ROOT/README.md`
**Commit:** `docs: add stack hub README`

### Task 1.6: ssl-automation manager submodules
**Files:** `$ROOT/.gitmodules`, `$ROOT/modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
**Test:** none
**Depends:** none

The stack joins the SSL stack (letsencrypt + step-ca environments) → both manager submodules, exactly like the gitea stack:

```bash
cd $ROOT
git submodule add https://github.com/zyrakq/letsencrypt-manager-stack.git modules/ssl-automation/letsencrypt-manager
git submodule add https://github.com/zyrakq/step-ca-manager-stack.git modules/ssl-automation/step-ca-manager
```

NEVER add `.gitkeep` or any file inside the submodule dirs.

**Verify:** `grep -q 'modules/ssl-automation/letsencrypt-manager' $ROOT/.gitmodules && grep -q 'modules/ssl-automation/step-ca-manager' $ROOT/.gitmodules`
**Commit:** `chore: add ssl-automation manager submodules`

---

## Batch 2: App base (parallel — 3 implementers)

### Task 2.1: base docker-compose.yml
**File:** `$ROOT/app/components/base/docker-compose.yml`
**Test:** none (validated by `docker compose config` in 5.2)
**Depends:** none

Follows §10 logging anchors + §12 env wiring. NO `ports:` in base (forwarding overlay owns publishing). NO `build:` section (published image). Base is environment-agnostic: NO `FRONT_END_URL`/`TRUST_PROXY`/`ALLOW_HTTP` (§7/§13 — overlays own them). No compose healthcheck — the image's built-in HEALTHCHECK already covers `/api/rest/app/version`.

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

services:
  vaultisse:
    container_name: vaultisse
    image: ${IMAGE:-ghcr.io/albertamat/vaultisse:v1.3.8}
    restart: unless-stopped
    logging: *default-logging
    environment:
      API_PORT: ${API_PORT:-3000}
      JWT_SECRET: ${JWT_SECRET:?set in .env}
      SESSION_TIME: ${SESSION_TIME:-3600000}
      MAX_SESSION_AGE_DAYS: ${MAX_SESSION_AGE_DAYS:-30}
      REGISTRATION_ENABLED: ${REGISTRATION_ENABLED:-true}
      TZ: ${TZ:-UTC}
    volumes:
      - vaultisse-logs:/app/logs
    networks:
      - vaultisse-network

networks:
  vaultisse-network:
    name: vaultisse-network
    driver: bridge

volumes:
  vaultisse-logs:
    name: vaultisse-logs
```

Notes for the implementer:
- `LOGGER_PATH=/app/logs`, `NODE_ENV=production`, `APP_VERSION` are set inside the image — do NOT duplicate them here.
- `SESSION_TIME` is the session-cookie lifetime in **milliseconds** (upstream default `3600000`).
- `JWT_SECRET` is required by the app (throws without it) → `${JWT_SECRET:?set in .env}`.
- `API_PORT` is the in-container listen port (image EXPOSE 3000); the host-side publish in the forwarding overlay reuses the same var (upstream compose pattern `"${API_PORT:-3000}:${API_PORT:-3000}"`).

**Verify:** `docker compose -f $ROOT/app/components/base/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add base compose for vaultisse`

### Task 2.2: base .env.example
**File:** `$ROOT/app/components/base/.env.example`
**Test:** none
**Depends:** none

Only vars the base compose actually references (§6). `API_PORT` is also referenced by the forwarding overlay; overlay-only vars (`FRONT_END_URL`, `TRUST_PROXY`, `ALLOW_HTTP`, `VIRTUAL_HOST`, …) are documented in the component README env table, never here (§13).

```env
# Compose
COMPOSE_PROJECT_NAME=vaultisse

# Image
IMAGE=ghcr.io/albertamat/vaultisse:v1.3.8

# Logging
LOG_MAX_SIZE=10m
LOG_MAX_FILE=3
LOG_COMPRESS=true

# App
# In-container listen port; the forwarding overlay publishes the same port
# on the host. FRONT_END_URL must match the public origin (set per environment).
API_PORT=3000
# Generate with: openssl rand -hex 32
JWT_SECRET=
# Session-cookie lifetime in milliseconds
SESSION_TIME=3600000
# Absolute session lifetime in days (forces re-login even if renewed)
MAX_SESSION_AGE_DAYS=30
REGISTRATION_ENABLED=true
TZ=UTC
```

**Verify:** `test -f $ROOT/app/components/base/.env.example`
**Commit:** `feat(app): add base env example`

### Task 2.3: stackbuilder.toml
**File:** `$ROOT/app/stackbuilder.toml`
**Test:** none (validated by `sb build` in 5.2)
**Depends:** none

New `[build.environments]` API (patterns.md §9 numa idiom). `database/postgresql` is listed in the `entire` combo (decision 4); no `entire-trust` (decision 3). No app-native config files → `env_file_patterns` is `.env` only.

```toml
[paths]
environments_path = "./environments"
extensions_dirs = ["extensions"]

[build]
skip_base_generation = true
copy_additional_files = true
env_file_patterns = [".env"]

[build.combos]
entire = ["database/postgresql"]

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
combos = ["entire"]

[build.environments.letsencrypt]
combos = ["entire"]

[build.environments.step-ca]
combos = ["entire"]
```

**Verify:** `cd $ROOT/app && sb build --help >/dev/null && test -f stackbuilder.toml`
**Commit:** `feat(app): add stackbuilder config with environments API`

---

## Batch 3: Environment overlays (parallel — 3 implementers)

### Task 3.1: forwarding overlay
**File:** `$ROOT/app/components/environments/forwarding/docker-compose.yml`
**Test:** none
**Depends:** none

Owns the plain/local defaults (§7/§13): publishes the port, plain-HTTP gate on, no proxy in front.

```yaml
services:
  vaultisse:
    environment:
      FRONT_END_URL: ${FRONT_END_URL:-http://localhost:3000}
      ALLOW_HTTP: ${ALLOW_HTTP:-true}
      TRUST_PROXY: ${TRUST_PROXY:-false}
    ports:
      - "${API_PORT:-3000}:${API_PORT:-3000}"
```

Note: if `API_PORT` is changed, `FRONT_END_URL` must be set explicitly in `.env` to match (the default hardcodes 3000).

**Verify:** `docker compose -f $ROOT/app/components/environments/forwarding/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add forwarding environment overlay`

### Task 3.2: letsencrypt overlay
**File:** `$ROOT/app/components/environments/letsencrypt/docker-compose.yml`
**Test:** none
**Depends:** none

External `letsencrypt-network` + `letsencrypt-vhost` volume; TLS-derived defaults owned here (§13); §4 vhost.d tuning so ebook uploads pass the proxy.

```yaml
services:
  vaultisse:
    environment:
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PORT: ${API_PORT:-3000}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      FRONT_END_URL: ${FRONT_END_URL:-https://${VIRTUAL_HOST}}
      TRUST_PROXY: ${TRUST_PROXY:-true}
      ALLOW_HTTP: ${ALLOW_HTTP:-false}
    configs:
      - source: vhost
        target: ${VHOST_PATH:-/vhost.d/${VIRTUAL_HOST}}
    volumes:
      - letsencrypt-vhost:/vhost.d
    networks:
      - letsencrypt-network

networks:
  letsencrypt-network:
    name: letsencrypt-network
    external: true

volumes:
  letsencrypt-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
```

**Verify:** `docker compose -f $ROOT/app/components/environments/letsencrypt/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add letsencrypt environment overlay`

### Task 3.3: step-ca overlay
**File:** `$ROOT/app/components/environments/step-ca/docker-compose.yml`
**Test:** none
**Depends:** none

Same shape as letsencrypt with the step-ca externals. No `step-ca-certs` mount: the app consumes no certs (TLS terminates at the proxy) and there are no inter-group links (no `step-ca-trust`).

```yaml
services:
  vaultisse:
    environment:
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PORT: ${API_PORT:-3000}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
      FRONT_END_URL: ${FRONT_END_URL:-https://${VIRTUAL_HOST}}
      TRUST_PROXY: ${TRUST_PROXY:-true}
      ALLOW_HTTP: ${ALLOW_HTTP:-false}
    configs:
      - source: vhost
        target: ${VHOST_PATH:-/vhost.d/${VIRTUAL_HOST}}
    volumes:
      - step-ca-vhost:/vhost.d
    networks:
      - step-ca-network

networks:
  step-ca-network:
    name: step-ca-network
    external: true

volumes:
  step-ca-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
```

**Verify:** `docker compose -f $ROOT/app/components/environments/step-ca/docker-compose.yml config >/dev/null`
**Commit:** `feat(app): add step-ca environment overlay`

---

## Batch 4: Database extension pair (parallel — 6 implementers)

patterns.md §11 verbatim, adapted only per decision 1 (app reads `DB_*`, not `DATABASE_URL`). No init-SQL mount (decision 5). The pgrust set is identical except the image default; `entire` still lists `postgresql` (decision 4).

### Task 4.1: postgresql app patch
**File:** `$ROOT/app/components/extensions/database/postgresql/docker-compose.yml`
**Test:** none
**Depends:** none

```yaml
services:
  vaultisse:
    environment:
      DB_HOST: vaultisse-db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB:-vaultisse}
      DB_USER: ${POSTGRES_USER:-vaultisse}
      DB_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
    depends_on:
      vaultisse-db:
        condition: service_healthy
```

**Verify:** `docker compose -f $ROOT/app/components/extensions/database/postgresql/docker-compose.yml config >/dev/null`
**Commit:** `feat(extensions): add postgresql app patch for vaultisse-db`

### Task 4.2: postgresql db service
**File:** `$ROOT/app/components/extensions/database/postgresql/docker-compose.db.yml`
**Test:** none
**Depends:** none

```yaml
services:
  vaultisse-db:
    image: ${DB_IMAGE:-postgres:alpine}
    container_name: vaultisse-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-vaultisse}
      POSTGRES_USER: ${POSTGRES_USER:-vaultisse}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
      POSTGRES_INITDB_ARGS: --encoding=UTF8 --lc-ctype=C --lc-collate=C
      TZ: ${TZ:-UTC}
    volumes:
      - vaultisse-db:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "/bin/sh", "-c", "exec pg_isready -h 127.0.0.1"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  vaultisse-db:
    name: vaultisse-db
```

Volume mounted at `/var/lib/postgresql` (NOT the legacy `/var/lib/postgresql/data`).

**Verify:** `docker compose -f $ROOT/app/components/extensions/database/postgresql/docker-compose.db.yml config >/dev/null`
**Commit:** `feat(extensions): add vaultisse-db postgresql service`

### Task 4.3: postgresql .env.example
**File:** `$ROOT/app/components/extensions/database/postgresql/.env.example`
**Test:** none
**Depends:** none

```env
# Database (postgresql variant)
COMPOSE_EXTENDS=:docker-compose.db.yml
COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}
POSTGRES_DB=vaultisse
POSTGRES_USER=vaultisse
POSTGRES_PASSWORD=
```

The leading colon in `COMPOSE_EXTENDS` lets multiple extensions chain correctly (§11 note).

**Verify:** `test -f $ROOT/app/components/extensions/database/postgresql/.env.example`
**Commit:** `feat(extensions): add postgresql env example`

### Task 4.4: pgrust app patch
**File:** `$ROOT/app/components/extensions/database/pgrust/docker-compose.yml`
**Test:** none
**Depends:** none

Identical to Task 4.1 (the app patch does not vary with the DB engine):

```yaml
services:
  vaultisse:
    environment:
      DB_HOST: vaultisse-db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB:-vaultisse}
      DB_USER: ${POSTGRES_USER:-vaultisse}
      DB_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
    depends_on:
      vaultisse-db:
        condition: service_healthy
```

**Verify:** `docker compose -f $ROOT/app/components/extensions/database/pgrust/docker-compose.yml config >/dev/null`
**Commit:** `feat(extensions): add pgrust app patch for vaultisse-db`

### Task 4.5: pgrust db service
**File:** `$ROOT/app/components/extensions/database/pgrust/docker-compose.db.yml`
**Test:** none
**Depends:** none

Identical to Task 4.2 except the image default (`malisper/pgrust:v0.2`):

```yaml
services:
  vaultisse-db:
    image: ${DB_IMAGE:-malisper/pgrust:v0.2}
    container_name: vaultisse-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-vaultisse}
      POSTGRES_USER: ${POSTGRES_USER:-vaultisse}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
      POSTGRES_INITDB_ARGS: --encoding=UTF8 --lc-ctype=C --lc-collate=C
      TZ: ${TZ:-UTC}
    volumes:
      - vaultisse-db:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "/bin/sh", "-c", "exec pg_isready -h 127.0.0.1"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  vaultisse-db:
    name: vaultisse-db
```

**Verify:** `docker compose -f $ROOT/app/components/extensions/database/pgrust/docker-compose.db.yml config >/dev/null`
**Commit:** `feat(extensions): add vaultisse-db pgrust service`

### Task 4.6: pgrust .env.example
**File:** `$ROOT/app/components/extensions/database/pgrust/.env.example`
**Test:** none
**Depends:** none

```env
# Database (pgrust variant)
COMPOSE_EXTENDS=:docker-compose.db.yml
COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}
POSTGRES_DB=vaultisse
POSTGRES_USER=vaultisse
POSTGRES_PASSWORD=
```

**Verify:** `test -f $ROOT/app/components/extensions/database/pgrust/.env.example`
**Commit:** `feat(extensions): add pgrust env example`

---

## Batch 5: Docs, build, gate (sequential)

### Task 5.1: app README (component README)
**File:** `$ROOT/app/README.md`
**Test:** none
**Depends:** Batches 1–4 (documents their exact content)

Load the `readme-gen` skill and generate the **component README** (~100–250 lines) from DEPLOYMENT.md. Required content:
- What Vaultisse is (one paragraph) + upstream link and tag `v1.3.8`.
- Base parts table: single part `vaultisse` (Express API + Vue client, port 3000, logs in `vaultisse-logs`, ebooks stored in Postgres) + mandatory infra `vaultisse-db` via the `database/postgresql` extension (pgrust as the Stage A2 swap).
- Extension status table from the DEPLOYMENT.md catalog: `database/pgrust` available (A2 swap); `oidc` available (base stage B); `s3-storage` refused; `cloudflared` available (product); metadata provider keys available (env-only product feature).
- Env table: every var from Task 2.2 + the database pair vars (`POSTGRES_DB/USER/PASSWORD`, `DB_IMAGE`, `COMPOSE_EXTENDS/COMPOSE_FILE`) + the overlay-only vars (`FRONT_END_URL`, `ALLOW_HTTP`, `TRUST_PROXY`, `VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`, `VHOST_PATH`, `API_PORT`) documented per §13 ("sb merges no env files for environments today").
- Build & run section: `cp .env.example .env` (set `JWT_SECRET`, `POSTGRES_PASSWORD`) → `cd app/ && sb build` → pick environment → `docker compose up -d`; first user registers at `/register`.
- Stage A gate summary (the 7 steps of Task 5.4).

**Verify:** `test -s $ROOT/app/README.md && grep -q "vaultisse-db" $ROOT/app/README.md`
**Commit:** `docs(app): add component README`

### Task 5.2: sb build + compose validation
**File:** none
**Depends:** 5.1 (README may reference build output layout)

```bash
cd $ROOT/app && sb build
```

Then validate every generated variant (3 environments × the `entire` combo):

```bash
cd $ROOT/app/build && for d in */*/; do (cd "$d" && docker compose config >/dev/null) || echo "FAIL: $d"; done
```

Confirm the generated forwarding compose merges to: services `vaultisse` + `vaultisse-db`, `container_name`s exact, image `ghcr.io/albertamat/vaultisse:v1.3.8` + `postgres:alpine`, volumes `vaultisse-logs` + `vaultisse-db`, network `vaultisse-network`, port `3000:3000`, app `depends_on: vaultisse-db (service_healthy)`, `FRONT_END_URL` present only via the overlay, no `build:` section.

**Verify:** `sb build` exits 0; no `FAIL:` lines.
**Commit:** `chore(app): verify sb build` (only if generated files need fixing; sb output under `build/` is gitignored)

### Task 5.3: convention checks + artifact cleanup
**Files:** stack repo working tree
**Depends:** 5.2

```bash
bash /home/archuser/projects/docker-stack-collection/.opencode/skills/stack-conventions/scripts/check-gitkeep.sh $ROOT
bash /home/archuser/projects/docker-stack-collection/.opencode/skills/stack-conventions/scripts/check-stack.sh $ROOT
```

Both must print nothing (`check-gitkeep.sh --fix` applies fixes; NEVER inside the submodule dirs). Delete tool artifacts if present: `.kilocode/`, `.clinerules/`, stray clones. The stack repo must contain only: `app/`, `modules/`, `README.md`, `DEPLOYMENT.md`, `UPSTREAM.md`, `.gitignore`, `.gitmessage`, `.gitmodules`, `.vscode/`, `LICENSE-APACHE`, `LICENSE-MIT`, `.git/`.

**Verify:** both scripts silent; `cd $ROOT && git status --porcelain` clean after committing.
**Commit:** `chore: clean artifacts after scaffold` (if needed)

### Task 5.4: Stage A functional gate (stack-test skill)
**File:** none
**Depends:** 5.3

Load the `stack-test` skill. Stage A = product parts + database, **forwarding** environment:

```bash
cd $ROOT/app && cp components/base/.env.example .env
# append the database pair vars:
cat components/extensions/database/postgresql/.env.example >> .env
# then set in .env: JWT_SECRET=$(openssl rand -hex 32) and POSTGRES_PASSWORD=<strong>
sb build && cd build/forwarding/entire && docker compose up -d
```

Gate checklist (DEPLOYMENT.md functional gate scenario):
1. `vaultisse-db` becomes healthy (`pg_isready`); `vaultisse` starts after it (`depends_on`), logs show startup + auto-migration, no fault loop.
2. `curl http://localhost:3000/api/rest/app/version` returns 200 with a version payload.
3. Browser opens `http://localhost:3000` → login page renders.
4. Register the first user via `/register` (observe whether `/register` stays available afterwards — DEPLOYMENT.md open hypothesis).
5. Log in → create a vault → add a book manually → verify it appears in the vault.
6. Log out → log back in with the same account.
7. `docker compose restart` → login still works, the book is still there (state persisted in `vaultisse-db`).

Any failure: fix, rebuild, re-run from step 1. Record the outcome (and any `/register` observation) in the final commit message.

**Verify:** all 7 steps pass.
**Commit:** n/a (gate run)

### Task 5.5: register the stack in the parent catalog
**File:** `/home/archuser/projects/docker-stack-collection/stacks.csv` (parent repo)
**Depends:** 5.4

Append exactly one row (merge=union in `.gitattributes` handles it):

```
stacks/self-hosting/media-streaming/book-management/vaultisse;-;unverified
```

Do NOT hand-edit `stacks.md` or the `# BEGIN stack-sync` block in the parent `.gitignore` (generated). Commit in the **parent** repo.

**Verify:** `grep -q 'vaultisse;-;unverified' /home/archuser/projects/docker-stack-collection/stacks.csv`
**Commit:** `feat(catalog): register vaultisse stack` (parent repo)

---

## Open risks / questions

- **`FRONT_END_URL` semantics behind the proxy** (DEPLOYMENT.md open hypothesis, medium confidence): the exact-URL cookie/JWT-issuer scope may need a TLS-environment re-run to confirm `https://${VIRTUAL_HOST}` is the right default — Stage A (forwarding) cannot fully validate it.
- **`/register` availability after the first user** (open hypothesis): the gate observes it; if registration locks after user 1, note it in the component README.
- **`TRUST_PROXY` + `ALLOW_HTTP` interaction** (open hypothesis): Stage A validates the forwarding defaults; the TLS overlays' defaults get checked at the TLS stage.
- **`sb` combo semantics**: if `sb build` rejects per-environment `combos` without per-environment `extensions`, add `extensions = []` to each `[build.environments.<env>]` block and rebuild (Task 5.2 catches this).
- **pgrust image pull**: `malisper/pgrust:v0.2` files are scaffolded but not built in this phase; the A2 swap (Phase 2) is its first real pull/run.
