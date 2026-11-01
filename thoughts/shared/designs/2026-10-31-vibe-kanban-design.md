---
date: 2026-10-31
topic: "vibe-kanban self-hosted deployment stack"
status: validated
---

# Vibe Kanban — self-hosted deployment stack

## Problem Statement

The stack `stacks/self-hosting/ai-services/automation/vibe-kanban` was an empty
old-format skeleton (`src/` layout, no deployment configs, status `incomplete`).
Upstream (BloopAI/vibe-kanban) historically resisted self-hosting (paid hosted
product), but is now community-maintained with real self-hosting docs
(`docs/self-hosting/deploy-docker.mdx`). We need working deployment configs
adapted to collection standards.

The first implementation (2026-10-31) violated the conventions overhaul
(P-008: generic service names, postgres in base compose, hardcoded env
literals, dead vars, no layering, no staged gates). This revision defines the
conformant target shape.

## Constraints

- No published upstream Docker images (checked GHCR/Docker Hub, CI workflows) —
  image must be built from source.
- Two upstream variants: local (desktop, **no auth**, agents not in image) and
  remote/cloud (multi-user, auth). Local is unsuitable for a server deployment.
- Remote variant auth = GitHub/Google OAuth or bootstrap local auth. **No
  generic OIDC** → no kanidm oidc extension for this stack.
- Relay/tunnel feature needs wildcard TLS (`*.relay.<domain>`) — incompatible
  with our HTTP-challenge proxy stacks. Out of scope; documented as future work.
- Build is heavy: Rust nightly release build + pnpm frontend build, 10–15 min,
  4+ GB RAM, requires BuildKit (cache mounts). **Never modify the host to
  "fix" build resource pressure** (P-009) — report and stop.
- The release tag `v0.1.45-20260919085201` does NOT compile (P-007: remote-web
  TS2339, fixed in 3 commits right after the tag) — the image must build from
  the pinned commit `7c3807084daad0d9d315064f60fa869de254f027` (2026-10-28).
- Self-hosted build (empty `FEATURES`) strips the private billing crate → no
  private-repo access, no `--mount=type=ssh`.
- Collection conventions §1–§19 are mandatory: `<stack>-<role>` naming,
  `${VAR:-}`/`${VAR:?}` env wiring, DB-as-extension, environment layering,
  staged protocol with test gates.

## Approach

Dockerize the **remote (Cloud) variant, core app only** (no relay), replacing
upstream's Caddy reverse proxy with the collection's nginx-proxy integration.
Conformant shape:

- **Naming (§3):** services `vibe-kanban`, `vibe-kanban-db`,
  `vibe-kanban-electric` (`container_name` = service name; the app service
  carries the stack name — 2026-11-01 user correction, was `vibe-kanban-app`);
  network `vibe-kanban-network`; volumes `vibe-kanban-db`, `vibe-kanban-electric`.
- **Postgres is NEVER a base-compose service (§8):** it lives in the
  `components/extensions/database/{postgresql,pgrust}` extension pair
  (dual-file idiom, patterns.md §11) — `postgres:alpine` default,
  `malisper/pgrust:v0.2` alternative, volume at `/var/lib/postgresql`,
  `POSTGRES_INITDB_ARGS`, `pg_isready` healthcheck. Electric requires logical
  replication → the db service carries `command: postgres -c wal_level=logical`
  in both variants.
- **Electric stays in base compose** — it is app-specific sync infrastructure,
  not a swappable database. Its `DATABASE_URL` points at `vibe-kanban-db` with
  the `electric_sync` role the app creates on first startup.
- **Source-built image (§19 / `source-image` skill):**
  `app/images/vibe-kanban-remote-server/Dockerfile`, fully self-contained —
  clones upstream at the pinned commit itself, empty build context, no
  vendored source. Compose references it via
  `image: ${IMAGE:-localhost/vibe-kanban-remote-server:0.1.45}` — never a
  `build:` section.

## Architecture

Services (from upstream `docker-compose.prod.yml`, Caddy removed):

- `vibe-kanban` — source-built image `localhost/vibe-kanban-remote-server:0.1.45`
  (based on upstream `crates/remote/Dockerfile`; self-hosted build strips the
  private billing dep). Port 8081, healthcheck `wget /v1/health`, runs as
  appuser, static frontend embedded at `/srv/static`. `SERVER_DATABASE_URL` is
  wired by the database extension patch, not by base.
- `vibe-kanban-db` — database extension service (§8): `${DB_IMAGE:-postgres:alpine}`
  (pgrust variant: `${DB_IMAGE:-malisper/pgrust:v0.2}`), `wal_level=logical`,
  `POSTGRES_INITDB_ARGS`, `pg_isready` healthcheck, volume
  `vibe-kanban-db:/var/lib/postgresql`.
- `vibe-kanban-electric` — `${ELECTRIC_IMAGE:-electricsql/electric:1.4.13}`,
  Postgres→client sync layer; depends on `vibe-kanban` healthy (the server
  creates the `electric_sync` role on first startup) and on `vibe-kanban-db`
  healthy (the db dependency is added by the database extension patch, since
  base must not reference the db service).

Bootstrap order: db healthy → app healthy (migrations + `electric_sync` role)
→ electric starts.

## Components

- `app/components/base/docker-compose.yml` — `vibe-kanban` +
  `vibe-kanban-electric` only. Every env value is `${VAR:-}` or `${VAR:?}`
  (§5). `SERVER_PUBLIC_BASE_URL` is NOT declared in base (§7 layering).
- `app/components/extensions/database/{postgresql,pgrust}/` — dual-file idiom:
  - `docker-compose.yml` — patches `vibe-kanban`
    (`SERVER_DATABASE_URL: postgres://${POSTGRES_USER:-…}:${POSTGRES_PASSWORD:?…}@vibe-kanban-db:5432/${POSTGRES_DB:-…}`
    + `depends_on: vibe-kanban-db: service_healthy`) and `vibe-kanban-electric`
    (`depends_on: vibe-kanban-db: service_healthy`);
  - `docker-compose.db.yml` — the `vibe-kanban-db` service itself;
  - `.env.example` — `POSTGRES_DB/USER/PASSWORD`,
    `COMPOSE_EXTENDS=:docker-compose.db.yml`,
    `COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}`.
- `app/components/environments/{forwarding,letsencrypt,step-ca}/` — compose
  fragments (patching `vibe-kanban`) **plus** `.env.example` fragments
  (n8n/linkwarden idiom; sb concatenates them into the built `.env.example`).
  forwarding owns `SERVER_PUBLIC_BASE_URL:-http://localhost:8081` and publishes
  8081; letsencrypt/step-ca own the `https://${VIRTUAL_HOST}` default and the
  `VIRTUAL_*`/`LETSENCRYPT_*` vars, joining the external proxy networks.
- `app/stackbuilder.toml` — linkwarden idiom:
  `extensions_dirs = ["extensions/database"]`, top-level
  `extensions = ["postgresql", "pgrust"]`, named `combos`
  `postgresql = ["postgresql"]` / `pgrust = ["pgrust"]`, per-environment
  `extensions = []` + `combos = ["postgresql", "pgrust"]`;
  `copy_additional_files = true`, `yaml_merger = "rust"` (P-006).
  Built variants: `build/<env>/{postgresql,pgrust}/`.
- `app/components/base/.env.example` — `COMPOSE_PROJECT_NAME`,
  `IMAGE=localhost/vibe-kanban-remote-server:0.1.45`, `LOG_*`, `RUST_LOG`,
  `SERVER_LISTEN_ADDR`, `ELECTRIC_URL`, secrets
  (`VIBEKANBAN_REMOTE_JWT_SECRET`, `ELECTRIC_ROLE_PASSWORD`), local auth
  (`SELF_HOST_LOCAL_AUTH_EMAIL`/`PASSWORD` — required `:?` vars), `TZ`.
  **2026-11-01 user correction (ground-truthed against upstream
  `crates/remote/src/config.rs`):** the server requires ≥1 auth provider
  (`ConfigError::NoOAuthProviders` otherwise) and genuinely reads
  `SELF_HOST_LOCAL_AUTH_*` at runtime — env vars ARE the local-auth bootstrap
  (no CLI, no first-run page; login page → `POST /v1/auth/local/login`), so
  they stay as required base vars. `GITHUB_OAUTH_*`/`GOOGLE_OAUTH_*` (optional
  providers), `LOOPS_*` (no-op mailer when unset), `AZURE_STORAGE_*`
  (disabled when account name unset) are genuinely read but optional
  third-party integrations → stripped from compose env entirely, README-only
  documentation in app/README.md "Optional integrations" (user adds the env
  entries themselves; no extension exists for them).
  `VITE_RELAY_API_BASE_URL` is a build-arg passthrough, referenced by no
  compose file → dead var, removed (documented in the README).
- `app/images/vibe-kanban-remote-server/Dockerfile` — self-contained source
  build at pinned commit `7c380708…` (P-007), empty build context, NOT part
  of the sb build.
- `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}` — existing
  submodules (target format).
- Stack root: `README.md` (hub style), `.gitignore`, `.gitmessage`,
  `LICENSE-APACHE`, `LICENSE-MIT`, `.gitmodules`, `UPSTREAM.md`.
- `UPSTREAM.md` — append-only log; the 2026-11-01 row records the conformance
  rework and the image rename.

## Data Flow

Browser → nginx-proxy (step-ca/letsencrypt stack) → `vibe-kanban:8081` →
`vibe-kanban-db`. ElectricSQL syncs Postgres tables to the browser client
through endpoints proxied by the app. Bootstrap order: db healthy → app
healthy (migrations + `electric_sync` role) → electric starts.

## Error Handling

- `restart: unless-stopped` on all services.
- `depends_on` with `condition: service_healthy` chain (upstream ordering).
- Electric connection issues after first boot: document restart of
  `vibe-kanban-electric` (upstream troubleshooting).
- pgrust may not support logical replication (`wal_level=logical`) — if the
  Stage A2 gate fails, `postgresql` stays the default combo and the component
  README records why (§9).

## Testing Strategy

Staged protocol (§9 / `stack-test` skill):

1. `sb build` in `app/`; verify `build/<env>/{postgresql,pgrust}/` each
   contains the merged `docker-compose.yml` (all three services; app has
   `SERVER_DATABASE_URL` and the db dependency; electric depends on BOTH app
   and db), the copied `docker-compose.db.yml`, and the concatenated
   `.env.example` (base + environment + database fragment).
2. `docker compose config` validation for all six variants (required vars
   supplied on the command line).
3. **Stage A** (base + `postgresql` extension, no oidc/s3): build the image
   (host-safe — on resource pressure report numbers and STOP), deploy the
   forwarding variant, health checks, browser E2E gate (bootstrap local auth
   login, one core flow, screenshot). letsencrypt/step-ca browser gates need a
   real domain from the user.
4. **Stage A2**: rebuild with the `pgrust` combo, same gate; clean pass →
   pgrust becomes the default combo; failure → postgresql default + README note.
5. No Stage B (no OIDC), no S3 round-trip (attachments are Azure-only).
6. `stacks.csv` status: `incomplete` until Stage A passes → `unverified`.

## Open Questions

- None blocking. Relay support (wildcard TLS) deferred by design.
- letsencrypt/step-ca browser verification awaits a real domain from the user.
