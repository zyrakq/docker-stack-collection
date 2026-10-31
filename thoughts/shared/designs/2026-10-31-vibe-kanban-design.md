---
date: 2026-10-31
topic: "vibe-kanban self-hosted deployment stack"
status: validated
---

# Vibe Kanban — self-hosted deployment stack

## Problem Statement

The stack `stacks/self-hosting/ai-services/automation/vibe-kanban` is an empty
old-format skeleton (`src/` layout, no deployment configs, status `incomplete`).
Upstream (BloopAI/vibe-kanban) historically resisted self-hosting (paid hosted
product), but is now community-maintained with real self-hosting docs
(`docs/self-hosting/deploy-docker.mdx`). We need working deployment configs
adapted to collection standards.

## Constraints

- No published upstream Docker images (checked GHCR/Docker Hub, CI workflows) —
  image must be built from source.
- Two upstream variants: local (desktop, **no auth**, agents not in image) and
  remote/cloud (multi-user, auth). Local is unsuitable for a server deployment.
- Remote variant auth = GitHub/Google OAuth or bootstrap local auth. **No
  generic OIDC** → no kanidm oidc extension for this stack.
- Relay/tunnel feature needs wildcard TLS (`*.relay.<domain>`) — incompatible
  with our HTTP-challenge proxy stacks. Out of scope; documented as future work.
- Build is heavy: Rust 1.93 release build + pnpm frontend build, 10–15 min,
  4+ GB RAM, requires BuildKit (cache mounts, `--mount=type=ssh`).
- Upstream reference commit: `7c3807084daad0d9d315064f60fa869de254f027`
  (2026-10-28, version 0.1.45).

## Approach

Dockerize the **remote (Cloud) variant, core app only** (no relay), replacing
upstream's Caddy reverse proxy with the collection's nginx-proxy integration.

The remote-server image is **source-built** per stack-conventions §15 and the
`source-image` skill: `app/images/vk-remote-server/Dockerfile`, fully
self-contained — it fetches the upstream source itself (release tarball from
`https://github.com/BloopAI/vibe-kanban/archive/refs/tags/v<VERSION>.tar.gz`
or a shallow git clone at a pinned tag via `ARG GIT_REPO`/`GIT_TAG`; no
published Docker image exists upstream). The Dockerfile builds with an empty
build context — the stack repo never vendors upstream source (no submodule,
no source tree). Built standalone (`docker build -t
localhost/vk-remote-server:<tag> app/images/vk-remote-server`); compose
references the prebuilt image via `image: ${IMAGE:-localhost/vk-remote-server:<tag>}`
— no `build:` section.

## Architecture

Services (from upstream `docker-compose.prod.yml`, Caddy removed):

- `remote-server` — source-built image `localhost/vk-remote-server:<tag>`
  (Dockerfile in `app/images/vk-remote-server/`, based on upstream
  `crates/remote/Dockerfile`; self-hosted build strips private billing dep).
  Port 8081, healthcheck `wget /v1/health`, runs as appuser, static frontend
  embedded at `/srv/static`.
- `remote-db` — `postgres:16-alpine`, `wal_level=logical`, `pg_isready`
  healthcheck, named volume.
- `electric` — `electricsql/electric:1.4.13`, Postgres→client sync layer;
  depends on db healthy AND remote-server healthy (server creates the
  `electric_sync` role on first startup / migrations).

## Components

- `app/components/base/docker-compose.yml` — the three services, named volumes
  (`vk-db-data`, `vk-electric-data`), env-driven configuration, log rotation
  envs, `TZ`.
- `app/components/environments/{forwarding,letsencrypt,step-ca}/` —
  forwarding publishes 8081; letsencrypt/step-ca join the proxy stacks
  (external network + volumes, `VIRTUAL_HOST`, `VIRTUAL_PORT=8081`,
  `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`). No TLS termination in-app → no
  `ROCKET_TLS`-style fragment, no step-ca-trust extension needed.
- `app/stackbuilder.toml` — environments `forwarding`, `letsencrypt`,
  `step-ca`; `copy_additional_files = true`.
- `app/.env.example` — standard key order: `COMPOSE_PROJECT_NAME`,
  `PROJECT_NAME`, `IMAGE=localhost/vk-remote-server:<tag>`,
  `LOG_MAX_SIZE/LOG_MAX_FILE/LOG_COMPRESS`, `VIRTUAL_PORT=8081`,
  `VIRTUAL_HOST`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`, secrets
  (`VIBEKANBAN_REMOTE_JWT_SECRET`, `DB_PASSWORD`, `ELECTRIC_ROLE_PASSWORD`),
  auth block (`GITHUB_OAUTH_CLIENT_ID/SECRET`, `GOOGLE_OAUTH_CLIENT_ID/SECRET`,
  `SELF_HOST_LOCAL_AUTH_EMAIL/PASSWORD`), optional `LOOPS_EMAIL_API_KEY` +
  template IDs, optional `AZURE_STORAGE_*` (attachments), `TZ=UTC`.
  Also build-arg passthrough `VITE_RELAY_API_BASE_URL` (default empty).
- `app/images/vk-remote-server/Dockerfile` — self-contained source build of
  the remote variant (fetches BloopAI/vibe-kanban at a pinned tag itself;
  empty build context; NOT part of the sb build; built standalone).
- `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}` — existing
  submodules relocated from legacy `src/ssl-automation/` (target format).
- Stack root: `README.md` (hub style), `.gitignore`, `.gitmessage`,
  `LICENSE-APACHE`, `LICENSE-MIT`, `.gitmodules`, `UPSTREAM.md`.
- `UPSTREAM.md` — one section `## app — https://github.com/BloopAI/vibe-kanban`,
  append-only log, first row: date, commit `7c3807084daad0d9d315064f60fa869de254f027`,
  image `built from source (v0.1.45)`, note "initial dockerization (remote variant, no relay)".

## Data Flow

Browser → nginx-proxy (step-ca/letsencrypt stack) → `remote-server:8081` →
Postgres. ElectricSQL syncs Postgres tables to the browser client through
endpoints proxied by remote-server. Server bootstrap order: db healthy →
server healthy (migrations + `electric_sync` role) → electric starts.

## Error Handling

- `restart: unless-stopped` on all services.
- `depends_on` with `condition: service_healthy` chain (upstream ordering).
- Electric connection issues after first boot: document restart of `electric`
  (upstream troubleshooting).

## Testing Strategy

1. `sb build` in `app/` for all three environments; inspect generated
   `build/<env>/docker-compose.yml`.
2. `docker compose config` validation per built env.
3. Follow the `stack-test` skill: step-ca variant first, health checks,
   browser Stage A (login via bootstrap local auth, create org/project),
   then optionally Stage B is N/A (no OIDC) — GitHub OAuth configured via
   env as an alternative verification step.
4. Record build RAM/time behavior; verify `--mount=type=ssh` build works
   without an ssh agent (expected: empty agent, no failure).

## Open Questions

- None blocking. Relay support (wildcard TLS) deferred by design.
