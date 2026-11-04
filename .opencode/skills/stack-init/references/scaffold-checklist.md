# Stack Init — Scaffold Checklist (Phase 1: functional base)

Checklist for Phase 1 of the `stack-init` workflow — the functional base
scaffold: EVERY product part listed in the DEPLOYMENT.md
`## Functional base` section (stack-conventions §20), one compose service
per part, plus the mandatory database stage. Phases 2–4 complete the
remaining mandatory infra stages (pgrust, oidc, s3); Phase 5 is the
extension-menu confirmation — confirmed extensions are added one at a
time after that, each gated by a test (stack-conventions §9). Copy
boilerplate (`LICENSE-APACHE`, `LICENSE-MIT`, `.gitmessage`) verbatim
from the collection root — do not invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `DEPLOYMENT.md` — produced by the stack-analysis skill in Phase 0;
      committed at the stack root next to `UPSTREAM.md`; executed as
      analyzed — no approval gate (§20). Do NOT scaffold without it.
- [ ] `.gitignore` — must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from the collection root.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from the collection
      root.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir (functional base — ALL product parts)

- [ ] `components/base/docker-compose.yml` — ONE service per product
      part, each named `<stack>-<role>` (§3); base ≠ one app container
      (§20).
      Logging anchor (`x-logging` with LOG_MAX_SIZE/LOG_MAX_FILE/
      LOG_COMPRESS); named volumes with explicit `name:` (§4); no bind
      mounts; healthcheck where applicable; EVERY env value
      `${VAR:-}`/`${VAR:?}` (§5; before/after fragment in
      `stack-conventions` `references/patterns.md` §12).
- [ ] ONE image per product part: the published upstream image, or
      source-built `app/images/<image>/Dockerfile` via the
      `source-image` skill (self-contained, no vendoring — §19); compose
      references `image: ${IMAGE:-...}` per part.
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
- [ ] `components/extensions/database/postgresql/` — the database stage
      (mandatory infra, ALWAYS attempted): dual-file pair (patterns.md
      §11): `docker-compose.yml` (app patch) + `docker-compose.db.yml`
      (`<stack>-db` service) + `.env.example` (`COMPOSE_EXTENDS`/
      `COMPOSE_FILE`/`POSTGRES_*`); volume mounted at
      `/var/lib/postgresql`; `postgres:alpine` default; wire the
      `postgresql` combo in `stackbuilder.toml`. Unresolvable blocker →
      REFUSE the stage with the reason recorded in DEPLOYMENT.md.
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native
      config files (numa idiom — embedded fragment in patterns.md §9);
      per-env `extensions`/`combos`.
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Register the stack in the project's stack manifest, if one exists.

## First build (Stage A gate)

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
- [ ] Stage A gate passed — the DEPLOYMENT.md functional gate scenario
      (cross-part E2E per `stack-test`) before ANY further stage work.

## Later base stages (mandatory infra — Phases 2–4, NOT at Phase 1)

Added one per phase after the Stage A gate, each followed by its test
gate (stack-conventions §9) — ALWAYS attempted; an unresolvable blocker
is REFUSED with the reason recorded in DEPLOYMENT.md. Fragment shapes
are embedded in `stack-conventions` `references/patterns.md` — never
copy from live stacks:

- [ ] pgrust — `components/extensions/database/pgrust/` (same shape as
      the postgresql stage, `malisper/pgrust:v0.2` image default);
      promote to default combo on a clean Stage A2 pass.
- [ ] oidc — `components/extensions/oidc/` (patterns.md §6) and
      `step-ca-trust/` (patterns.md §7) where applicable.
- [ ] s3 — `components/extensions/s3-storage/` (patterns.md §8) where
      the app supports S3 natively; s3fs-fuse fallback ONLY on volumes
      with NO database data.

## Confirmed extensions (ONLY after explicit user confirmation — Phase 5)

Chosen from the DEPLOYMENT.md extension catalog at the Phase 5 menu —
NEVER implemented without explicit user confirmation — then added one at
a time, each followed by its test gate (stack-conventions §9):

- [ ] Product extensions — per the DEPLOYMENT.md catalog entry: one
      service per part (`<stack>-<role>`, §3), image per §19 when
      upstream publishes none, own stage + gate; status → `implemented`
      in DEPLOYMENT.md when it lands.
- [ ] Non-mandated optional infra — implemented only on explicit user
      confirmation at the Phase 5 menu; same one-at-a-time staging and
      gating; refused with a reason if rejected, `available` if
      unselected.
