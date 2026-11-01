# Stack Init — Scaffold Checklist (Phase 1: base only)

Checklist for Phase 1 of the `stack-init` workflow — the BASE
implementation only. Extensions (database, oidc, s3) are added in later
phases, one at a time, each gated by a test (stack-conventions §9). Copy
boilerplate (`LICENSE-APACHE`, `LICENSE-MIT`, `.gitmessage`) verbatim
from the collection root — do not invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `.gitignore` — must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from the collection root.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from the collection
      root.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir (base only)

- [ ] `components/base/docker-compose.yml` — core service named
      `<stack>-<role>` (§3); logging anchor (`x-logging` with
      LOG_MAX_SIZE/LOG_MAX_FILE/LOG_COMPRESS); named volumes with explicit
      `name:` (§4); no bind mounts; healthcheck where applicable; EVERY
      env value `${VAR:-}`/`${VAR:?}` (§5; before/after fragment in
      `stack-conventions` `references/patterns.md` §12).
- [ ] `components/base/.env.example` — per stack-conventions §6 key order
      and hygiene (only vars the base compose actually references).
- [ ] `components/base/` config examples (`*.example` files; delivered via
      `dockerfile_inline` COPY or `configs.content`).
- [ ] `components/environments/forwarding/` — plain ports publish; owns
      the plain/local default for env-dependent vars (§7; layering
      fragment in patterns.md §13).
- [ ] `components/environments/letsencrypt/` — external `letsencrypt-network`
      + `letsencrypt-vhost` volume + VIRTUAL_HOST/LETSENCRYPT_* env.
- [ ] `components/environments/step-ca/` — external `step-ca-network` +
      `step-ca-certs` + `step-ca-vhost` volumes + VIRTUAL_HOST/
      LETSENCRYPT_* env + app TLS env (cert paths `/certs/<VIRTUAL_HOST>/...`).
- [ ] NO env-dependent var (public base URLs, TLS-derived defaults) in
      base compose or base `.env.example` — overlays only (§7).
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native
      config files (numa idiom — embedded fragment in patterns.md §9);
      per-env `extensions`/`combos`.
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Append to `stacks.csv`: `stacks/<path>;-;unverified` (semicolon-separated;
      `-` url when no remote; do not touch other rows).

## First build (Phase 1 gate)

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
- [ ] Stage A gate passed (base deployment, browser E2E per `stack-test`)
      before ANY extension is added.

## Later extensions (NOT at Phase 1)

Added one at a time in later phases, each followed by its test gate
(stack-conventions §9). Fragment shapes are embedded in `stack-conventions`
`references/patterns.md` — never copy from live stacks:

- [ ] Phase 2 — `components/extensions/database/postgresql/` dual-file
      pair (patterns.md §11): `docker-compose.yml` (app patch) +
      `docker-compose.db.yml` (`<stack>-db` service) + `.env.example`
      (`COMPOSE_EXTENDS`/`COMPOSE_FILE`/`POSTGRES_*`); volume mounted at
      `/var/lib/postgresql`; `postgres:alpine` default.
- [ ] Phase 3 — `components/extensions/database/pgrust/` (same shape,
      `malisper/pgrust:v0.2` image default); promote to default combo on a
      clean Stage A2 pass.
- [ ] Phase 4 — `components/extensions/oidc/` (patterns.md §6) and
      `step-ca-trust/` (patterns.md §7) where applicable.
- [ ] Phase 5 — `components/extensions/s3-storage/` (patterns.md §8)
      where the app supports S3 natively; s3fs-fuse fallback ONLY on
      volumes with NO database data.
