# Conventions Enforcement Implementation Plan

**Goal:** Restructure `stack-conventions` into a §1–§19 lifecycle-ordered rulebook, make every skill self-contained (zero `stacks/` path pointers), weave the staged protocol with test gates through stack-init/stack-test, and add enforcement iron rules to repo `AGENTS.md`.

**Architecture:** Single canonical rulebook (`stack-conventions/SKILL.md` renumbered §1–§19) + embedded pattern fragments (patterns.md, new dockerfiles.md) + enforcement layer (AGENTS.md iron rules, always in context) + staged protocol (stack-conventions §9, stack-init phases 0–5, stack-test stages A/A2/B). The two wrong rules (old §3 `PROJECT_NAME` naming preference, old §9 `PROJECT_NAME` key) are deleted. vibe-kanban and everything under `stacks/` is NOT touched.

**Design:** `thoughts/shared/designs/2026-11-01-conventions-enforcement-design.md`

**Hard constraints (apply to EVERY task):**
- ZERO edits under `stacks/`. Edit surface: `.opencode/skills/**`, repo-root `AGENTS.md`, repo-root `PITFALLS.md` only. `.opencode/agents/**` and `~/.config/opencode/micode.jsonc` are untouched.
- All docs English (except the PITFALLS.md P-008 entry, which is Russian per that file's format).
- Line numbers below are indicative — match by content, not line number.
- Commit each task's file(s) immediately after verification, using the `.gitmessage` format: header = infinitive verb ≤50 chars; "what" block = past-tense lines; "why" block = present-tense lines; blocks separated by empty lines; English; no trailing period.
- These are markdown/docs files — no test files. Each task's Verify step is its test.

---

## Section Renumbering Map (stack-conventions SKILL.md, old → new)

| old | new | change |
|-----|-----|--------|
| §1 Repo layout | §1 | extensions list gains `database/{postgresql,pgrust}` |
| §2 sb/stackbuilder | §2 | drop numa path pointer; add DB-combos note |
| — | §3 | NEW Naming |
| §3 Volume policy | §4 | `PROJECT_NAME` naming line REMOVED |
| — | §5 | NEW Env wiring |
| §9 .env.example | §6 | rewritten hygiene (key order kept) |
| §6 Environments | §7 | + layering rule |
| — | §8 | NEW Database as extension |
| — | §9 | NEW Staged integration protocol |
| §7 OIDC policy | §10 | drop zerobyte runbook path |
| §8 S3 policy | §11 | expand: volumes-first staging, s3fs non-DB only |
| §4 Config delivery | §12 | unchanged |
| §5 dockerfile_inline | §13 | unchanged |
| §10 step-ca | §14 | unchanged |
| §11 vhost.d | §15 | unchanged |
| §12 Operational gotcha | §16 | genericize example path |
| §13 Upstream provenance | §17 | unchanged |
| §14 Pitfalls ledger | §18 | unchanged |
| §15 Source-built images | §19 | self-ref §13→§17 only |

## § Cross-Reference Remap Table (15 refs; Batch 1/2 executors apply these)

| File | Old ref | New ref |
|------|---------|---------|
| `.opencode/skills/stack-init/SKILL.md` (Phase 0 provenance) | §13 | §17 |
| `.opencode/skills/stack-init/SKILL.md` (source-image bullet) | §15 | §19 |
| `.opencode/skills/stack-init/references/scaffold-checklist.md` (env key order) | §9 | §6 |
| `.opencode/skills/source-image/SKILL.md` (L15 "hard rules") | §15 | §19 |
| `.opencode/skills/source-image/SKILL.md` (L21 clone-in-tmp) | §13 | §17 |
| `.opencode/skills/source-image/SKILL.md` (L62 key order) | §9 | §6 |
| `.opencode/skills/source-image/SKILL.md` (L63 UPSTREAM.md row) | §13 | §17 |
| `.opencode/skills/stack-modernize/SKILL.md` (provenance step) | §13 | §17 |
| `.opencode/skills/stack-modernize/SKILL.md` (layout ref) | §1 | §1 (unchanged) |
| `.opencode/skills/stack-modernize/SKILL.md` (vendoring step) | §15 | §19 |
| `.opencode/skills/stack-conventions/SKILL.md` (self-ref in source-built images) | §13 | §17 |
| `.opencode/skills/stack-test/SKILL.md` (clone-in-tmp) | §13 | §17 |
| `AGENTS.md` (source-built images section) | §15 | §19 |
| `PITFALLS.md` P-001 fix line | §12 | §16 |
| `PITFALLS.md` P-004 fix line | §15 | §19 |

NOT remapped (internal to stack-test's own reference docs, unaffected): `browser-e2e.md` §0/§1/§2/§1–4 refs and `verification-procedure.md` §1/§2 refs — these number browser-e2e.md's own sections, which stay 0–3 (Stage A2 is added as a subsection of §1, deliberately, so these refs keep resolving).

## Legitimate `stacks/` survivors (verification grep #1 allow-list)

After all edits, `grep -rn "stacks/" .opencode/` must show ONLY:
- Generic layout placeholders: `stacks/<category>/<subcategory>/<stack-name>/`, `stacks/<category>/<...>/<stack>`, `stacks/<path>;-;unverified` (stack-init SKILL.md, scaffold-checklist.md)
- stack-conventions §16 gotcha: the word `stacks/` (gitignore statements) + generic example `stacks/<category>/<...>/<stack>/app/...`
- stack-conventions §17: `(`stacks/` is gitignored by the collection repo)` statement
- rationale.md: generic `stacks/<category>/<stack>/` placeholder

## Legitimate `PROJECT_NAME` survivors (verification grep #2 allow-list)

Prohibition/hygiene text only: stack-conventions §3 ("Do NOT introduce a `PROJECT_NAME`-style variable"), §6 ("the `PROJECT_NAME` failure"), AGENTS.md iron rules ("no unused `PROJECT_NAME`-style vars"). PITFALLS.md P-008 mentions it as historical record (not in grep #2 scope anyway).

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8 [conventions canon + self-containment — no deps]
Batch 2 (parallel): 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7 [remaps + rewrites — depends on Batch 1]
Batch 3 (sequential): 3.1 → 3.2 [global verification + commit safety net — depends on Batch 2]
```

Batch 2 depends on Batch 1 because its rewrites point at patterns.md §11 (created in Task 1.2) and the new § numbering (canon created in Task 1.1).

---

## Batch 1: Conventions canon + self-contained skills (parallel — 8 implementers)

All tasks in this batch have NO dependencies and run simultaneously.

### Task 1.1: Restructure stack-conventions/SKILL.md into §1–§19
**File:** `.opencode/skills/stack-conventions/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Replace the ENTIRE file content with the following (complete new file, copy-paste ready). This is the renumbering anchor: new §3/§5/§6/§7/§8/§9 are the verbatim rule canon from the design; §4 = old §3 minus the `PROJECT_NAME` line; §10/§11/§16 carry their specified edits; §12–§15, §17, §18 are the old sections verbatim under new numbers; §19 = old §15 with the internal `§13` self-ref changed to `§17`.

```markdown
---
name: Stack Conventions
description: >-
  Conventions for docker-stack-collection stacks: app/ layout, service and
  volume naming, sb/stackbuilder builds, environments and layering,
  extensions (oidc, s3-storage, database postgresql+pgrust), env wiring
  (${VAR:-} everywhere), .env.example hygiene, no-bind-mount volume
  policy, staged integration protocol with test gates, dockerfile_inline
  config patterns, source-built images (app/images/), OIDC/S3/step-ca
  integration rules, and upstream provenance (UPSTREAM.md). Load before
  creating or modifying any stack.
---

# Stack Conventions

Reference skill for every stack in this collection. The `stack-init`,
`stack-test`, `stack-modernize`, and `readme-gen` skills build on these rules.

- Why each decision was made: read `references/rationale.md`.
- Verbatim embedded pattern snippets (genericized; attribution by stack
  name only): read `references/patterns.md`.

## 1. Repo layout

A stack repo contains:

- `app/` — the main service (target format).
- Optional sibling project dirs: `ui/`, `server/`, `ch-ui/`, or per-module
  dirs (e.g. `loki-for-grafana/`) when the stack ships more than one project.
- `modules/` — git submodules, currently only
  `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`, declared in
  the stack-root `.gitmodules`.
- Stack-root files: `README.md` (hub style), `.gitignore`, `.gitmessage`,
  `LICENSE-APACHE`, `LICENSE-MIT`, `.gitmodules`.
- `src/<name>/` exists in older stacks but is NOT the target format (see the
  `stack-modernize` skill).

Inner structure of a project dir (e.g. `app/`):

- `components/base/` — core `docker-compose.yml` + `.env.example` + config files.
- `components/environments/<env>/` — one dir per environment variant.
- `components/extensions/<ext>/` — optional fragments (`oidc`, `s3-storage`,
  `step-ca-trust`, `database/{postgresql,pgrust}`, `smtp`, ...).
- `build/` — generated by `sb build`; NEVER edit.
- `stackbuilder.toml` — build config.
- `README.md` — component README (see the `readme-gen` skill).

## 2. sb/stackbuilder

- Rust CLI, source at `/home/archuser/projects/tools/stackbuilder`, binary `sb`.
- Only two commands matter: `sb init` and `sb build`. Config is hardcoded to
  `./stackbuilder.toml` — always run from the project dir (e.g. `app/`).
- Dual environments API: `[build.environments]` with `available = [...]` plus
  per-environment tables declaring `extensions`, `combos`, and
  `skip_base_generation`. Embedded example: the numa fragment in
  `references/patterns.md` §9.
- Database choice is expressed via named `combos` in `stackbuilder.toml`
  (e.g. `postgresql`, `pgrust`) — see §8.
- Known limitations are tracked in `STASKBUILDER.md` at the collection root.
  Workarounds in current use:
  - No cartesian matrix → hand-written named `combos` (easytier idiom).
  - App-native config files preserved via `env_file_patterns` (numa idiom;
    kanidm uses it for `override.css`).
  - Multi-file compose layering via `COMPOSE_FILE` as escape hatch.

## 3. Naming (services, containers, networks, volumes)

- Service names carry the stack identity: `<stack>-<role>` (e.g.
  `vibe-kanban-app`, `vibe-kanban-db`). NEVER generic, anonymous, or
  role-only names (`app`, `db`, `server`, `remote-db`, `electric`).
- `container_name`, when present, MUST equal the service name — no
  mismatched pairs. Either omit it (the service name is then the container
  name) or set it to exactly the service name.
- Network: `<stack>-network`. Volumes: `<stack>-<purpose>`
  (`<stack>-db`, `<stack>-data`, `<stack>-media`), always with explicit
  `name:`.
- The prefix is the literal stack name hardcoded in the compose files. Do
  NOT introduce a `PROJECT_NAME`-style variable for naming — unused vars
  are forbidden (§6).

## 4. Volume policy

- NEVER host bind mounts — they break multi-host docker contexts. Only
  allowed exception: `/var/run/docker.sock:ro` for docker-gen companions.
- Named volumes with explicit `name:`, named per §3 (`<stack>-<purpose>`).
- External volumes/networks to join the SSL stack: `step-ca-certs`,
  `step-ca-vhost`, `step-ca-network` (or `letsencrypt-*` equivalents).

## 5. Env wiring — everything overridable

- EVERY env value in EVERY compose file (base, environments, extensions)
  is `${VAR:-default}` or `${VAR:?required}`. Bare literals are forbidden —
  a value the user cannot override from `.env` without editing compose is
  a defect.
- Covers app env, DB env, infra env. The main app image follows
  `${IMAGE:-...}` (§19).
- Inline defaults must be sane standalone values; the referenced var gets
  a `.env.example` entry in the owning component (§6).

## 6. .env.example hygiene

- A variable appears in a component's `.env.example` ONLY when that
  component's compose files reference it. Zero dead vars (the
  `PROJECT_NAME` failure: declared, documented, referenced nowhere).
- Base `.env.example` = `COMPOSE_PROJECT_NAME`, `IMAGE`, `LOG_*`, and the
  app's core required vars. Nothing else.
- Optional/feature vars (oauth keys, s3, mail, provider keys, ...) live
  ONLY in the owning extension's `.env.example` fragment, and only when
  that extension is actually wired (staged protocol, §9).
- Standard key order: `COMPOSE_PROJECT_NAME`, `IMAGE`, `LOG_*`,
  `VIRTUAL_*`/`LETSENCRYPT_*`, OIDC block, `STEP_CA_*`, CA-path vars,
  `TZ=UTC`.

## 7. Environments & layering

- `forwarding` — plain ports published to the host.
- `letsencrypt` — joins the letsencrypt stack (external network/volumes).
- `step-ca` — joins the step-ca stack; structurally identical to letsencrypt,
  differs only in volume/network names.
- `devcontainer` (legacy/rare) — external workspace network.
- `internal` (rare) — own bridge network only.
- Variant selection = `cd build/<env>/<combo>/` after `sb build`. No compose
  profiles.
- Layering rule: base is environment-agnostic. Any var whose correct value
  depends on the deployment environment (public base URLs, domain-derived
  defaults, TLS settings) is declared ONLY in environment overlays — never
  in base compose and never in base `.env.example`.
- `forwarding` owns the plain/local default (e.g.
  `${<APP>_PUBLIC_BASE_URL:-http://localhost:<port>}`);
  `letsencrypt`/`step-ca` own the TLS default (e.g.
  `${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}`). Each overlay
  re-declares the var with its own default.

## 8. Database as extension (postgres ↔ pgrust)

- Postgres is NEVER a plain service in base compose. When a stack needs
  postgres, prepare it as an extension pair:
  `components/extensions/database/postgresql/` AND
  `components/extensions/database/pgrust/` — the pgrust alternative is
  ALWAYS provided.
- Dual-file idiom per variant (verbatim fragments in
  `references/patterns.md` §11):
  - `docker-compose.yml` — patches the app service only (DB env,
    `depends_on: condition: service_healthy`)
  - `docker-compose.db.yml` — the DB service `<stack>-db`
  - `.env.example` — `COMPOSE_EXTENDS=:docker-compose.db.yml`,
    `COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}`, DB vars
- pgrust is a drop-in alternative: identical service/env/mounts/
  healthcheck; only `image:` differs (`malisper/pgrust:v0.2` vs
  `postgres:alpine`).
- Version policy: do NOT copy the exact postgres version from upstream
  project instructions — the latest postgres fits almost every app.
  Default `postgres:alpine` (floating). Pin an older major ONLY with a
  documented app incompatibility.
- Mount the named volume at `/var/lib/postgresql` — the wider folder used
  by current postgres images (`/var/lib/postgresql/data` is the legacy
  narrow layout).
- Healthcheck `pg_isready` + app `depends_on: service_healthy`;
  `POSTGRES_INITDB_ARGS="--encoding=UTF8 --lc-ctype=C --lc-collate=C"`.
- Non-postgres single-type datastores (redis-as-cache, single mongo/mysql)
  may stay in base; a per-project swappable DB goes to extensions.
  Postgres is always the pair because pgrust exists.
- DB choice is expressed via named `combos` in `stackbuilder.toml` (e.g.
  `postgresql`, `pgrust`).

## 9. Staged integration protocol (base first, test gates)

Order for bringing up a new stack or adding components:

1. Prepare the database extension first (if the app needs postgres) — the
   `postgresql` variant.
2. Base implementation: app service + simple named volumes, wired to the
   DB extension. NO oidc, NO s3, no other extensions.
3. Build, deploy, test — Stage A gate (browser E2E per `stack-test`).
   MUST pass.
4. Add the `pgrust` variant; rebuild; test. If pgrust comes up without
   problems → pgrust becomes the default/base variant.
5. oidc (if the app supports it): add the extension, Stage B gate; keep
   the tested no-oidc variant as proof of the pre-OIDC step.
6. s3: the base uses simple volume mounts. Only after base works: add the
   `s3-storage` extension if the app supports S3 natively; otherwise
   s3fs-fuse — ONLY on volumes with NO database data (never mount a
   shared DB dir via s3fs).

One extension at a time; each addition is followed by its test. NEVER
wire or load oidc/s3 material before the base implementation exists and
passes its gate.

## 10. OIDC policy

- Add an `oidc` extension wherever the app supports OIDC; include it in the
  default build; keep a no-oidc variant as proof of the tested pre-OIDC
  step.
- Provider is kanidm. Issuer convention:
  `https://<kanidm-domain>/oauth2/openid/<client-name>`.
- UI-only OIDC apps (gitea, zerobyte): the provider is configured in the
  app's own web interface, NOT via env — env only enables OAuth2 support
  (gitea `GITEA__oauth2__ENABLE`). Account linking relies on matching
  email (zerobyte: "Link matching emails to existing accounts: On"). The
  per-app UI configuration steps are embedded in the `stack-test` skill
  (`references/browser-e2e.md`).
- Staged testing is MANDATORY for every stack (§9): verify the base
  deployment in the browser first (Stage A), then add/configure oidc and
  re-verify (Stage B) — procedure in the `stack-test` skill
  (`references/browser-e2e.md`).

## 11. S3 policy

- The base implementation uses simple named volumes — S3 is wired ONLY
  after the base passes its gate (staged protocol, §9).
- Prefer native S3 support: extension `s3-storage`, env-only fragment
  (gitea `GITEA__storage__*`, linkwarden `SPACES_*` var shapes — embedded
  fragments in `references/patterns.md` §8).
- Otherwise s3fs-fuse is the fallback — ONLY on volumes with NO database
  data; NEVER mount a shared DB dir via s3fs.

## 12. Config delivery

Configs reach containers WITHOUT bind mounts:

1. Preferred: `dockerfile_inline` COPY — `build: {context: ., dockerfile_inline: |}`
   with `FROM ${IMAGE:-default}` + `COPY <config> /etc/app/...`
   (exemplars: zot, ferron, kanidm base).
2. Tiny files only: compose `configs.content` written into a shared volume
   (vhost.d snippets, coturn `turnserver.conf`).

## 13. dockerfile_inline patterns

Three canonical patterns (verbatim snippets in `references/patterns.md`):

- **Config-into-image** — copy static config files at build time.
- **cert-wait + gosu** (coturn) — for services that terminate TLS themselves
  and run as non-root: `user: root`, `/bin/sh -c` entrypoint polls
  `/certs/$$COTURN_DOMAIN/key.pem` (sleep 3, `$$` escaping), chmod 644, then
  `exec gosu nobody /usr/local/bin/docker-entrypoint.sh "$@"`. Root is used
  ONLY to fix perms, then drops to the upstream user. No init containers
  (considered tech debt). No full shells in distroless images.
- **delayed-start** (kanidm) — for distroless images with no shell: the inline
  Dockerfile builds a static `sleep` binary and sets
  `ENTRYPOINT ["/bin/sleep", "${START_DELAY:-10}"]` so cert files appear
  before the real CMD runs.

## 14. step-ca integration (two pieces)

1. **Env fragment** (in the step-ca environment): adds
   `step-ca-certs:/certs` external volume + `step-ca-network` external
   network + `VIRTUAL_HOST`/`VIRTUAL_PROTO`/`LETSENCRYPT_HOST`/
   `LETSENCRYPT_EMAIL` + app TLS env, e.g.
   `ROCKET_TLS='{certs="/certs/${VIRTUAL_HOST}/fullchain.pem",key=...}'`.
   Cert path convention: `/certs/<VIRTUAL_HOST>/fullchain.pem` and `key.pem`.
2. **`step-ca-trust` extension**: env patch setting `STEP_CA_TRUST` /
   `STEP_CA_TRUST_RESTART` (vaultwarden exemplar).

## 15. nginx-proxy vhost.d tuning

- Per-host nginx tweaks via compose `configs.content` written to the shared
  `step-ca-vhost` / `letsencrypt-vhost` volume at `/vhost.d/${VIRTUAL_HOST}`
  (zot: `client_max_body_size 0;`).
- Multi-port vhosts use the `VIRTUAL_HOST_MULTIPORTS` trick (rustfs).

## 16. Operational gotcha

`stacks/` is gitignored by the collection repo and each stack is its own git
repo. Root-level glob/grep sees NOTHING inside `stacks/` — always target a
specific stack path, e.g. `stacks/<category>/<...>/<stack>/app/...`.

## 17. Upstream provenance

Every stack records WHERE its deployment configs come from in a per-stack
`UPSTREAM.md` at the stack root. Provenance must travel with the stack repo
(`stacks/` is gitignored by the collection repo). The `stack-init`,
`stack-modernize`, and `stack-test` skills maintain the file; this section is
the canonical format definition.

- One `##` section per project dir (`app/`, `ui/`, `server/`, ...) —
  multi-project stacks may track one upstream repo per project. Section
  header: `## <project-dir> — <upstream repo URL>`.
- Under each section header, an append-only log table with columns
  `date | upstream commit | image tag / digest | note`. The image column is
  required: you must always know which image version the configs were last
  verified against. Example (rendered):

  | date | upstream commit | image tag / digest | note |
  |------|-----------------|--------------------|------|
  | 2026-10-31 | abc1234 | v1.2.3 | initial dockerization |

- IRON RULE: rows are ONLY ever appended — never rewritten, reordered, or
  deleted. A `git diff` on `UPSTREAM.md` must ever show additions only
  (mid-rework you would otherwise lose the base commit of the previous
  config generation).
- Commit unrecoverable (image tag not mappable to a commit): record
  `unknown` in the commit column with a note explaining why. NEVER invent a
  hash.
- Upstream URL unknown: create the section with the URL as `unknown` and an
  empty log; the first rework session backfills it.

### Clone-in-tmp workflow (any rework session on a stack)

1. Read `UPSTREAM.md` for the repo URL and the last recorded commit.
2. Clone into a FRESH dir under `/tmp/opencode/upstreams/` — remove any
   leftover first (idempotent against crashed sessions):

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

3. Use the clone to understand the service (config files, flags,
   entrypoints). When diagnosing a regression, diff the config surface
   between the last recorded commit and HEAD:

   ```bash
   git -C /tmp/opencode/upstreams/<stack>-<project> diff <last-recorded-commit>..HEAD
   ```

4. After the session: append the new row to `UPSTREAM.md`, THEN delete the
   clone. Both ends are mandatory:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   ```

- Clones are temporary working material — NEVER commit them into the stack
  or collection repos.
- Clone fails (network, repo moved): report it and stop the provenance
  step — do not silently skip recording.

## 18. Pitfalls ledger

Recurring obstacles (sb quirks, compose, OIDC/S3/step-ca wiring, testing)
are logged in `PITFALLS.md` at the collection root — shared across all
stacks, one entry per problem with a `hits` counter and
`status: open | mitigated | fixed`.

- Before diagnosing any tooling/deploy/test obstacle, check the ledger:
  walk up from cwd to find `PITFALLS.md`; if not found, use the canonical
  path `/home/archuser/projects/docker-stack-collection/PITFALLS.md`.
- After hitting an obstacle: already recorded → `hits +1`, update `last`;
  new → append entry (`hits: 1`, `status: open`). Grep the file first to
  avoid duplicate entries.
- Fixed → `status: fixed` + `fix:` description; entries are never deleted.
- Never end a stack session with an unrecorded obstacle. Format and
  protocol are defined in the file's header.

## 19. Source-built images (`app/images/`) — NO VENDORING

When an app has no published Docker image and must be built from source:

- **NEVER vendor upstream source into the stack repo.** No git submodule of
  the upstream app, no copied source tree, no `modules/<upstream-app>`.
  `modules/` is ONLY for the ssl-automation managers. The §17 clone-in-tmp
  clone is REFERENCE-ONLY — it is never committed and never referenced by
  the build.
- The build lives in `app/images/<image>/Dockerfile` and must be **fully
  self-contained**: the Dockerfile itself downloads release
  binaries/archives or clones the upstream repo at a pinned tag/commit
  (`ARG GIT_REPO` / `ARG GIT_TAG`, or a GitHub archive URL). It must build
  with an empty build context — no local files required.
- **Wiring:** `images/` is a sibling of `components/` and is NOT part of
  the `sb` build. Build standalone:
  `docker build -t localhost/<image>:<tag> images/<image>`. Compose
  references the prebuilt image — `image: ${IMAGE:-localhost/<image>:<tag>}`
  — never a `build:` section.
- Exemplars: `open-coreui` `images/{frontend,backend,complex}` (sparse git
  clone), the vibe-kanban `images/{git-clone,release-assets}` Dockerfiles
  (older upstream layout — pattern reference only). `litellm-amd64` uses
  `COPY . .` — context-dependent, NOT the canonical pattern.
- Step-by-step procedure: the `source-image` skill.
```

**Verify:**
```bash
grep -c "^## " .opencode/skills/stack-conventions/SKILL.md        # 19 section headers
grep -n "^## " .opencode/skills/stack-conventions/SKILL.md        # sections numbered 1..19 in order
grep -n "PROJECT_NAME" .opencode/skills/stack-conventions/SKILL.md # only §3 prohibition + §6 hygiene mention
grep -n "stacks/" .opencode/skills/stack-conventions/SKILL.md     # only §16/§17 generic statements + generic example path
grep -n "§" .opencode/skills/stack-conventions/SKILL.md           # refs §3,§5,§6,§7,§8,§9,§10,§11,§17,§19 — all new numbering
```

**Commit:**
```bash
git add .opencode/skills/stack-conventions/SKILL.md
git commit -m "$(cat <<'EOF'
Restructure stack-conventions sections

Reorganized the skill into 19 lifecycle-ordered sections;
added naming, env wiring, database extension, staged
protocol, and layering rules; removed the two wrong
PROJECT_NAME rules; dropped stack path pointers.

Provided one canonical rulebook for all stack work and
retired the rules that caused the vibe-kanban violations.
EOF
)"
```

### Task 1.2: patterns.md — name-only attribution + new §11/§12/§13
**File:** `.opencode/skills/stack-conventions/references/patterns.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Three changes, in place (fragments themselves stay untouched):

**(a) Reword the header (current L3–4):**

Replace:
```markdown
Verbatim snippets. Source paths are exact — re-read them when in doubt
(`stacks/` is gitignored; target the specific path).
```
with:
```markdown
Verbatim snippets, embedded in full — this library is self-contained
(stacks move and change; skills never point into `stacks/`). `Source:`
lines are attribution by stack name only.
```

**(b) Replace all 15 `Source:` lines with name-only attribution** (exact current text → replacement; find by the old text, not line number):

| Current line | Replacement |
|---|---|
| ``Source: `stacks/development-tools/registries/container-registries/zot/app/components/base/docker-compose.yml` `` | `Source: zot stack (embedded verbatim)` |
| ``Source: `stacks/network-privacy/turn/coturn/app/components/environments/step-ca/docker-compose.yml` `` | `Source: coturn stack (embedded verbatim)` |
| ``Source: `stacks/devops/identity-management/kanidm/app/components/base/docker-compose.yml` `` | `Source: kanidm stack (embedded verbatim)` |
| ``Source: `stacks/development-tools/registries/container-registries/zot/app/components/environments/step-ca/docker-compose.yml` `` | `Source: zot stack (embedded verbatim)` |
| ``Source: `stacks/devops/s3/storage/rustfs/app/components/environments/step-ca/docker-compose.yml` `` | `Source: rustfs stack (embedded verbatim)` |
| ``Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/docker-compose.yml` `` | `Source: vaultwarden stack (embedded verbatim)` |
| ``Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/.env.example` `` | `Source: vaultwarden stack (embedded verbatim)` |
| ``Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/step-ca-trust/docker-compose.yml` `` | `Source: vaultwarden stack (embedded verbatim)` |
| ``Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/step-ca-trust/.env.example` `` | `Source: vaultwarden stack (embedded verbatim)` |
| ``Source: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/docker-compose.yml` `` | `Source: gitea stack (embedded verbatim)` |
| ``Source: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/.env.example` `` | `Source: gitea stack (embedded verbatim)` |
| ``Second exemplar (SPACES_* vars) — Source: `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/docker-compose.yml` `` | `Second exemplar (SPACES_* vars) — Source: linkwarden stack (embedded verbatim)` |
| ``Source: `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/.env.example` `` | `Source: linkwarden stack (embedded verbatim)` |
| ``Source: `stacks/network-privacy/dns/numa/app/client/stackbuilder.toml` `` | `Source: numa stack (embedded verbatim)` |
| ``Source: `stacks/devops/s3/storage/rustfs/app/components/base/docker-compose.yml` `` | `Source: rustfs stack (embedded verbatim)` |

**(c) Append three new sections** at the end of the file (after §10), verbatim:

````markdown
## 11. Database extension pair (postgresql + pgrust)

Source: convention canon (§8); genericized — no stack path

`components/extensions/database/postgresql/` — three files. The `pgrust/`
sibling directory is identical except the image default.

`docker-compose.yml` (patches the app service only):

```yaml
services:
  <stack>-app:
    environment:
      DATABASE_URL: ${DATABASE_URL:-postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@<stack>-db:5432/${POSTGRES_DB}}
    depends_on:
      <stack>-db:
        condition: service_healthy
```

`docker-compose.db.yml` (the DB service):

```yaml
services:
  <stack>-db:
    image: ${DB_IMAGE:-postgres:alpine}
    container_name: <stack>-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-<stack>}
      POSTGRES_USER: ${POSTGRES_USER:-<stack>}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
      POSTGRES_INITDB_ARGS: --encoding=UTF8 --lc-ctype=C --lc-collate=C
      TZ: ${TZ:-UTC}
    volumes:
      - <stack>-db:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "/bin/sh", "-c", "exec pg_isready -h 127.0.0.1"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  <stack>-db:
    name: <stack>-db
```

`.env.example`:

```env
# Database (postgresql variant)
COMPOSE_EXTENDS=:docker-compose.db.yml
COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}
POSTGRES_DB=<stack>
POSTGRES_USER=<stack>
POSTGRES_PASSWORD=
```

Notes:

- pgrust variant: identical service/env/mounts/healthcheck; only `image:`
  differs — `${DB_IMAGE:-malisper/pgrust:v0.2}`.
- Mount the named volume at `/var/lib/postgresql` (NOT the legacy narrow
  `/var/lib/postgresql/data`).
- The leading colon in `COMPOSE_EXTENDS=:docker-compose.db.yml` lets
  multiple extensions chain correctly.
- DB choice is a named combo in `stackbuilder.toml` (`postgresql` /
  `pgrust`); pgrust becomes the default combo when it passes the Stage A2
  gate (§9).

## 12. Env wiring — before/after

Source: convention canon (§5); vibe-kanban violations as the "before"

BEFORE (defect — hardcoded literals, not overridable):

```yaml
services:
  <stack>-app:
    environment:
      RUST_LOG: info
      SERVER_LISTEN_ADDR: 0.0.0.0:8080
```

AFTER (every value overridable from `.env`):

```yaml
services:
  <stack>-app:
    environment:
      RUST_LOG: ${RUST_LOG:-info}
      SERVER_LISTEN_ADDR: ${SERVER_LISTEN_ADDR:-0.0.0.0:8080}
```

plus the matching entries in the owning component's `.env.example`:

```env
RUST_LOG=info
SERVER_LISTEN_ADDR=0.0.0.0:8080
```

Required values use `${VAR:?required}` instead of a default. A var that
appears in `.env.example` but is referenced by no compose file is a dead
var — remove it (§6).

## 13. Environment layering — public base URL

Source: convention canon (§7); SERVER_PUBLIC_BASE_URL violation as the
"before"

BEFORE (defect — env-dependent var declared in base AND re-declared with
different defaults in overlays):

```yaml
# components/base/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL:-http://localhost:8080}
# components/environments/{letsencrypt,step-ca}/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}
```

AFTER (base declares nothing; each overlay owns its default):

```yaml
# components/base/docker-compose.yml — NOTHING (base is environment-agnostic)
# components/environments/forwarding/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL:-http://localhost:<port>}
# components/environments/letsencrypt/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}
# components/environments/step-ca/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}
```

The var never appears in base `.env.example`; each overlay documents its
default in the component README env table (sb merges no env files for
environments today).
````

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/stack-conventions/references/patterns.md   # zero hits
grep -c "^Source: " .opencode/skills/stack-conventions/references/patterns.md # 14 (13 plain + 0; the linkwarden line is inline — check total below)
grep -n "embedded verbatim" .opencode/skills/stack-conventions/references/patterns.md # 15 attribution lines
grep -n "^## " .opencode/skills/stack-conventions/references/patterns.md      # sections 1..13
```

**Commit:**
```bash
git add .opencode/skills/stack-conventions/references/patterns.md
git commit -m "$(cat <<'EOF'
Embed pattern sources and add DB fragments

Replaced 15 Source path lines with name-only
attribution; added database extension pair, env
wiring, and layering fragments as sections 11-13.

Made the pattern library self-contained so it no
longer rots when stacks move or change.
EOF
)"
```

### Task 1.3: rationale.md — add entries 15–22
**File:** `.opencode/skills/stack-conventions/references/rationale.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Append after entry 14 (verbatim):

```markdown
15. **Naming `<stack>-<role>`.** A DB of this class is assumed to be
    per-project with its own container name — user: «для таких решений
    как бд обычно предполагается, что она под каждый проект своя и со
    своим именем контейнера». Generic names (`app`, `db`, `server`)
    collide across stacks, break external references, and hide the stack
    identity in `docker ps`.
16. **Env overridability (`${VAR:-}` everywhere).** Compose files are
    generated/managed artifacts; `.env` is the user surface. A value the
    user cannot override from `.env` without editing compose is a defect.
17. **No dead vars in `.env.example`.** A declared-but-unreferenced var
    (the `PROJECT_NAME` failure) misleads every reader and agent into
    using it. `.env.example` documents exactly what compose consumes.
18. **Postgres as the `database/{postgresql,pgrust}` extension pair.** An
    alternative implementation exists (pgrust) → the DB is swappable per
    project → it is an extension, not base infrastructure. A plain base
    service hard-couples the stack to one engine.
19. **`postgres:alpine` (latest), not the upstream-pinned version.**
    Upstream project instructions pin conservative versions; the latest
    postgres fits almost every app. `/var/lib/postgresql` (wide mount) is
    the current image layout; `/var/lib/postgresql/data` is legacy.
20. **Staged protocol (base first, test gates).** Extensions compound the
    failure surface; the base must be proven working before each
    extension is added, or a failure cannot be attributed. One extension
    at a time, each followed by its test.
21. **Environment layering (base is environment-agnostic).** A var whose
    correct value depends on the deployment environment (public URLs, TLS
    defaults) has no single right default — declaring it in base
    guarantees a wrong default somewhere. Each overlay owns its default.
22. **Self-contained skills (no `stacks/` path pointers).** Stacks are
    independent repos that move and change; skills that point into them
    rot silently. Patterns are embedded verbatim; attribution is by stack
    name only.
```

**Verify:**
```bash
grep -c "^[0-9]*\." .opencode/skills/stack-conventions/references/rationale.md  # 22 numbered entries
grep -n "для таких решений" .opencode/skills/stack-conventions/references/rationale.md  # verbatim user quote present
```

**Commit:**
```bash
git add .opencode/skills/stack-conventions/references/rationale.md
git commit -m "$(cat <<'EOF'
Add rationale for new convention rules

Added entries 15-22 covering naming, env
overridability, dead vars, DB-as-extension, version
policy, staged protocol, layering, and self-contained
skills.

Recorded why each new rule exists so future sessions
never re-derive the conventions.
EOF
)"
```

### Task 1.4: source-image — embedded Dockerfile skeletons (2 files, tightly coupled)
**File 1:** `.opencode/skills/source-image/SKILL.md` (edit)
**File 2:** `.opencode/skills/source-image/references/dockerfiles.md` (NEW)
**Test:** none (docs — Verify greps below)
**Depends:** none

The SKILL.md edit points at the new reference file — create both in this task.

**File 2 — create `.opencode/skills/source-image/references/dockerfiles.md`** with exactly:

````markdown
# Source Image — Dockerfile Skeletons

Genericized canonical skeletons for `app/images/<image>/Dockerfile`. All
are self-contained: empty build context, the source fetched by the
Dockerfile itself, every input a pinned ARG. Distilled from the
collection's source-built image idioms (open-coreui sparse clone,
vibe-kanban release-assets / git-clone, litellm-amd64-conf conf layer).

## 1. Release-tarball download

Upstream publishes release archives — deterministic, no git history.

```dockerfile
ARG GITHUB_REPO=<owner>/<repo>
ARG VERSION=v1.2.3

FROM <builder-image>:<tag> AS builder
ARG GITHUB_REPO
ARG VERSION
RUN wget -qO /tmp/src.tar.gz \
      "https://github.com/${GITHUB_REPO}/archive/refs/tags/${VERSION}.tar.gz" \
 && echo "<sha256>  /tmp/src.tar.gz" | sha256sum -c - \
 && mkdir /tmp/src && tar -xzf /tmp/src.tar.gz -C /tmp/src --strip-components=1 \
 && cd /tmp/src \
 && <install toolchain + build; artifacts to /out>

FROM <runtime-image>:<tag>
COPY --from=builder /out/<artifact> /usr/local/bin/<artifact>
USER <non-root-user>
EXPOSE <port>
HEALTHCHECK CMD <health-probe>
ENTRYPOINT ["<artifact>"]
```

## 2. Pinned git-clone

No release archive, or the release tag does not compile (P-007) — clone
at a pinned commit.

```dockerfile
ARG GIT_REPO=https://github.com/<owner>/<repo>.git
ARG GIT_COMMIT=<pinned-short-sha>

FROM <builder-image>:<tag> AS builder
ARG GIT_REPO
ARG GIT_COMMIT
RUN git clone "$GIT_REPO" /src \
 && git -C /src checkout "$GIT_COMMIT" \
 && cd /src \
 && <install toolchain + build; artifacts to /out>
# Only a subdirectory needed? Clone sparse:
#   git clone --filter=blob:none --sparse "$GIT_REPO" /src \
#    && git -C /src sparse-checkout set <subdir> \
#    && git -C /src checkout "$GIT_COMMIT"

FROM <runtime-image>:<tag>
COPY --from=builder /out/<artifact> /usr/local/bin/<artifact>
USER <non-root-user>
EXPOSE <port>
HEALTHCHECK CMD <health-probe>
ENTRYPOINT ["<artifact>"]
```

## 3. Conf-layer image (`<image>-conf`)

A small stack-owned config must be baked in? Do NOT add `COPY . .` to the
app image — layer a second image on the prebuilt base instead.

```dockerfile
# app/images/<image>-conf/Dockerfile
ARG BASE=localhost/<image>:<tag>

FROM ${BASE}
COPY <config-file> /etc/<app>/<config-file>
```

Build standalone like any source image
(`docker build -t localhost/<image>-conf:<tag> images/<image>-conf`);
compose still references only `${IMAGE:-...}` — point `IMAGE` at the
conf tag in `.env`.
````

**File 1 — edit `.opencode/skills/source-image/SKILL.md`:**

1. § remaps (find by text):
   - `Load the `stack-conventions` skill first — §15 defines the hard rules this` → `... — §19 defines the hard rules this`
   - `reference-only. The clone-in-tmp clone (§13) is` → `reference-only. The clone-in-tmp clone (§17) is`
   - `order (§9). Never add a `build:` section.` → `order (§6). Never add a `build:` section.`
   - `6. **Record provenance:** append the UPSTREAM.md row (§13) — upstream` → `6. **Record provenance:** append the UPSTREAM.md row (§17) — upstream`
2. Replace the entire `## Exemplars` section (the block listing open-coreui / vibe-kanban / litellm-amd64 stack paths) with:

```markdown
## Exemplars

Canonical skeletons (release-tarball, pinned git-clone, conf-layer) are
embedded in `references/dockerfiles.md` — imitate those, not live stacks.
```

**Verify:**
```bash
test -f .opencode/skills/source-image/references/dockerfiles.md && echo OK
grep -n "stacks/" .opencode/skills/source-image/SKILL.md .opencode/skills/source-image/references/dockerfiles.md  # zero hits
grep -n "§" .opencode/skills/source-image/SKILL.md   # only §19, §17, §6, §17
```

**Commit:**
```bash
git add .opencode/skills/source-image/SKILL.md .opencode/skills/source-image/references/dockerfiles.md
git commit -m "$(cat <<'EOF'
Embed Dockerfile skeletons in source-image

Replaced exemplar stack paths with embedded
skeletons in references/dockerfiles.md; remapped
section refs to the new stack-conventions numbering.

Made the skill self-contained and consistent with
the restructured conventions.
EOF
)"
```

### Task 1.5: readme-gen — drop exemplar path pointers
**File:** `.opencode/skills/readme-gen/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Replace the entire `## Canonical exemplars` section (the block with the keycloak/kanidm README paths) with:

```markdown
## Canonical templates

`references/templates.md` (fully embedded) is the canon for both styles —
component and hub README. Module READMEs
(`modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`)
are REUSED verbatim — never rewrite them.
```

Everything else in the file stays.

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/readme-gen/SKILL.md   # zero hits
grep -n "templates.md" .opencode/skills/readme-gen/SKILL.md  # canon pointer present
```

**Commit:**
```bash
git add .opencode/skills/readme-gen/SKILL.md
git commit -m "$(cat <<'EOF'
Drop stack exemplar paths from readme-gen

Removed canonical-exemplar path pointers; declared
the embedded templates the canon.

Kept the skill valid when stacks move or change.
EOF
)"
```

### Task 1.6: kanidm-oidc — drop reference-stack pointer
**File:** `.opencode/skills/kanidm-oidc/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Two edits:

1. Replace:
```markdown
Load the `stack-conventions` skill first. Reference stack:
`stacks/devops/identity-management/kanidm/`.
```
with:
```markdown
Load the `stack-conventions` skill first.
```

2. In the Conventions section, replace `(documented in the kanidm app README)` with `(procedure in `references/cli-cookbook.md`)` — the recover-account procedure IS in the cookbook (cli-cookbook.md has the two `docker exec -it kanidmd kanidmd recover-account ...` commands). Live-instance operational facts (kanidmd container name, issuer URL convention) stay unchanged — they are not project references.

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/kanidm-oidc/SKILL.md   # zero hits
grep -n "cli-cookbook" .opencode/skills/kanidm-oidc/SKILL.md  # pointer present
```

**Commit:**
```bash
git add .opencode/skills/kanidm-oidc/SKILL.md
git commit -m "$(cat <<'EOF'
Drop stack path pointer from kanidm-oidc

Removed the reference-stack path; pointed the
recovery procedure at the embedded cli-cookbook.

Kept the skill self-contained.
EOF
)"
```

### Task 1.7: rustfs-s3 — drop reference-stack pointer
**File:** `.opencode/skills/rustfs-s3/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

Replace:
```markdown
Load the `stack-conventions` skill first. Reference stack:
`stacks/devops/s3/storage/rustfs/`.
```
with:
```markdown
Load the `stack-conventions` skill first.
```

Everything else stays (instance facts and guardrails are live-instance operational facts, not project references).

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/rustfs-s3/SKILL.md   # zero hits
```

**Commit:**
```bash
git add .opencode/skills/rustfs-s3/SKILL.md
git commit -m "$(cat <<'EOF'
Drop stack path pointer from rustfs-s3

Removed the reference-stack path line.

Kept the skill self-contained.
EOF
)"
```

### Task 1.8: rustfs-s3 cookbook — point at embedded fragments
**File:** `.opencode/skills/rustfs-s3/references/cookbook.md`
**Test:** none (docs — Verify greps below)
**Depends:** none

In the `## Wiring an app (s3-storage extension)` section, replace item 2 (the two exemplar path bullets for gitea/linkwarden) with:

```markdown
2. Copy the extension fragment shape from the embedded s3-storage
   fragments in the `stack-conventions` skill
   (`references/patterns.md` §8) — env-only fragments
   (`GITEA__storage__*` or `SPACES_*` var shapes).
```

Keep the env var name examples; drop only the two `stacks/...` paths.

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/rustfs-s3/references/cookbook.md   # zero hits
grep -n "patterns.md" .opencode/skills/rustfs-s3/references/cookbook.md  # pointer present
```

**Commit:**
```bash
git add .opencode/skills/rustfs-s3/references/cookbook.md
git commit -m "$(cat <<'EOF'
Point rustfs cookbook at embedded fragments

Replaced exemplar stack paths with a pointer to the
stack-conventions pattern library; kept the env var
name examples.

Kept the cookbook self-contained.
EOF
)"
```

## Batch 2: Rewrites + remaps (parallel — 7 implementers)

All tasks in this batch depend on Batch 1 (new § numbering from Task 1.1; patterns.md §11–§13 from Task 1.2). Tasks within the batch are independent of each other and run simultaneously.

### Task 2.1: Rewrite stack-init into the phased workflow
**File:** `.opencode/skills/stack-init/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** 1.1, 1.2

Replace the ENTIRE file with the following (complete new file, copy-paste ready). Phase 0 = old steps 1–3 verbatim except §13→§17; Phase 1 = old step 4 stripped to base-only + old steps 5–7; Phases 2–5 = the staged protocol from stack-conventions §9; the "Reference exemplars" section is DELETED, replaced by a one-line canonical-patterns pointer; the numa mention stays as attribution only (no path).

````markdown
---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection via
  the staged protocol: repo and upstream provenance, base-only scaffold,
  then database (postgresql, pgrust), oidc, and s3 extensions one at a
  time, each gated by a stack-test stage. Use when the user asks to create
  or start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every phase below depends on
it, especially §9 (staged integration protocol).

## Workflow (phased; every extension gated by a test)

Phases 0–1 establish the stack. Phases 2–5 add extensions ONE at a time,
each followed by its test gate (stack-conventions §9). NEVER scaffold
oidc/s3 material before the base passes its Stage A gate.

### Phase 0 — repo & upstream provenance

1. **Determine stack type & category.** Ask the user if unclear. Choose the
   category path `stacks/<category>/<subcategory>/<stack-name>/` following
   existing entries in `stacks.csv`.
2. **Create the stack repo.**
   ```bash
   mkdir -p stacks/<category>/<...>/<stack>
   cd stacks/<category>/<...>/<stack>
   git init
   ```
3. **Upstream provenance.** Ask the user for the upstream repo URL(s) — one
   per project dir when the stack ships more than one project. Create
   `UPSTREAM.md` at the stack root per stack-conventions §17, then clone
   each upstream repo to inspect the source:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

   - Inspect the clone (config files, flags, entrypoints) to inform the
     scaffolding in the next phase.
   - Append the first log row: today's date, the current upstream commit
     (`git -C /tmp/opencode/upstreams/<stack>-<project> rev-parse --short
     HEAD`), the image tag/digest being dockerized, note `initial
     dockerization`.
   - URL unknown: create `UPSTREAM.md` with the section and an empty log —
     the first rework session backfills it. Clone fails: report and skip
     the clone (still create `UPSTREAM.md`).
   - Delete the clone when done scaffolding:
     `rm -rf /tmp/opencode/upstreams/<stack>-<project>`

### Phase 1 — scaffold the BASE only

4. **Scaffold** exactly per `references/scaffold-checklist.md` — BASE
   pieces only:
   - `app/components/base/` — `docker-compose.yml` (service named
     `<stack>-<role>` per §3, every env value `${VAR:-}`/`${VAR:?}` per
     §5, named volumes per §4), `.env.example` (§6 hygiene), config
     examples.
   - `app/components/environments/{forwarding,letsencrypt,step-ca}/` as
     applicable (step-ca needs the certs volume + network fragment);
     environment-dependent vars live ONLY in overlays (§7).
   - `app/stackbuilder.toml` — new `[build.environments]` API; use
     `env_file_patterns` to preserve app-native config files (numa idiom).
   - `app/README.md` — delegate to the `readme-gen` skill rules.
   - Stack root: hub `README.md`, `.gitignore`, `.gitmessage`,
     `LICENSE-APACHE`, `LICENSE-MIT`; `.gitmodules` + `modules/ssl-automation`
     submodules ONLY if SSL integration is needed.
   - **No published Docker image?** Build from source via the
     `source-image` skill — `app/images/<image>/Dockerfile`, self-contained
     (fetches the source itself). NEVER vendor upstream source into the
     stack repo (no submodules, no source trees) — stack-conventions §19.
   - NO oidc, NO s3-storage, NO other extensions yet (staged protocol, §9).
5. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
6. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
7. **Build & verify the base:** `cd app/ && sb build`, then follow the
   `stack-test` skill through the Stage A gate.

### Phase 2 — database extension (postgresql variant)

8. If the app needs postgres: prepare the `database/postgresql` extension
   exactly per stack-conventions §8 — dual-file idiom, verbatim fragments
   in `stack-conventions` `references/patterns.md` §11. Wire the
   `postgresql` combo in `stackbuilder.toml`, `sb build`, deploy, and pass
   the **Stage A gate** (browser E2E: base + DB, no oidc) per `stack-test`.
   MUST pass before anything else is added.

### Phase 3 — pgrust alternative

9. Add the `database/pgrust` variant (identical except the `image:`
   default), rebuild, and run the **Stage A2 gate**. Clean pass → make
   `pgrust` the default combo (§9). Failure → keep `postgresql` default
   and record why in the component README.

### Phase 4 — oidc

10. If the app supports OIDC: add the `oidc` extension, include it in the
    default build, keep the tested no-oidc variant as proof of the
    pre-OIDC step, and pass the **Stage B gate** per `stack-test`.

### Phase 5 — s3

11. If the app needs object storage: the base already uses simple named
    volumes. Add the `s3-storage` extension if the app supports S3
    natively (env-only fragment) and run the S3 round-trip test;
    otherwise s3fs-fuse — ONLY on volumes with NO database data
    (stack-conventions §11).

## Canonical patterns

Canonical pattern fragments (base compose, environments, database pair,
oidc/s3 extensions) are embedded in the `stack-conventions` skill
(`references/patterns.md`) — imitate those, not live stacks.
````

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/stack-init/SKILL.md    # ONLY 4 generic placeholder hits (category path, mkdir, cd, csv row)
grep -n "§" .opencode/skills/stack-init/SKILL.md           # §9 §17 §3 §4 §5 §6 §7 §8 §19 §11 — new numbering only; NO §13/§15
grep -n "^### Phase" .opencode/skills/stack-init/SKILL.md  # 6 headers: Phase 0–5
grep -n "Reference exemplars" .opencode/skills/stack-init/SKILL.md  # zero hits
```

**Commit:**
```bash
git add .opencode/skills/stack-init/SKILL.md
git commit -m "$(cat <<'EOF'
Rewrite stack-init into phased workflow

Replaced the single-pass workflow with phases
0-5; scoped Phase 1 scaffolding to the base
only; gated every extension phase by a
stack-test stage; dropped exemplar stack
paths.

Enforce the staged protocol so no extension
is wired before the base passes its gate.
EOF
)"
```

### Task 2.2: scaffold-checklist — Phase 1 base-only + later extensions
**File:** `.opencode/skills/stack-init/references/scaffold-checklist.md`
**Test:** none (docs — Verify greps below)
**Depends:** 1.1, 1.2

Replace the ENTIRE file with the following (complete new file, copy-paste ready). Boilerplate now comes from the collection root; the checklist covers Phase 1 (base only); database/oidc/s3 move to a "Later extensions" section with patterns.md pointers.

```markdown
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
```

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/stack-init/references/scaffold-checklist.md  # ONLY the generic `stacks/<path>;-;unverified` row
grep -n "§" .opencode/skills/stack-init/references/scaffold-checklist.md        # stack-conventions §3–§9 + patterns.md §6–§13; the text "stack-conventions §13" or "§15" must NOT appear
grep -n "Phase 2" .opencode/skills/stack-init/references/scaffold-checklist.md  # database item present
grep -n "NOT at Phase 1" .opencode/skills/stack-init/references/scaffold-checklist.md  # later-extensions section present
```

**Commit:**
```bash
git add .opencode/skills/stack-init/references/scaffold-checklist.md
git commit -m "$(cat <<'EOF'
Rewrite scaffold checklist for phased init

Scoped the checklist to Phase 1 base-only
scaffolding; moved database, oidc, and s3
items into a later-extensions section;
sourced boilerplate from the collection
root.

Keep the checklist aligned with the staged
stack-init workflow.
EOF
)"
```

### Task 2.3: stack-modernize — DB/naming/env conformance steps
**File:** `.opencode/skills/stack-modernize/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** 1.1, 1.2

Replace the ENTIRE file with the following (complete new file, copy-paste ready). Steps 1–6 are the current ones with §13→§17 (step 2); NEW steps 7–9 are the conformance steps; old steps 7–11 are renumbered 10–14 with §15→§19 (now step 11). The frontmatter description gains the conformance scope (design adds the steps; the description must advertise them — same rationale as the stack-conventions frontmatter update the design specifies).

```markdown
---
name: Stack Modernize
description: >-
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, DB/naming/
  env conformance, artifact cleanup, README regeneration). ONLY when the
  user explicitly requests modernization.
---

# Stack Modernize

Load the `stack-conventions` skill first. Use ONLY when the user explicitly
requests modernization of a specific stack — never migrate old stacks
opportunistically.

## Scope rules

- Target: stacks still using the legacy `src/<name>/` layout or missing
  current-format pieces.
- NEVER touch pre-sb legacy stacks (e.g. elasticsearch/kibana flat compose +
  `deploy.sh`) beyond the artifact cleanup below.
- Exception: deleting `.kilocode/` and `.clinerules/` may be done
  opportunistically in ALL projects without a request.

## Procedure

1. **Inventory** the stack: read `src/<name>/` (or `app/`), note existing
   environments, extensions, READMEs, and artifacts.
2. **Upstream provenance backfill:** if `UPSTREAM.md` is missing, create it
   at the stack root per stack-conventions §17 (one section per project
   dir). Recover the current upstream commit where possible — from the
   pinned image tag/digest, the upstream release notes/changelog, or the
   user — otherwise record `unknown` with a note explaining why. NEVER
   invent a hash. Append the first log row (date, commit or `unknown`,
   image tag/digest, note `backfill at modernization`).

3. **Rename** `src/<name>/` → `app/` (git mv inside the stack repo). If the
   stack has multiple projects, split into sibling dirs (`ui/`, `server/`,
   ...) per stack-conventions §1.
4. **Modules**: move `src/ssl-automation/` → `modules/ssl-automation/` and
   declare it in the stack-root `.gitmodules` (submodule URLs:
   `https://github.com/zyrakq/{step-ca,letsencrypt}-manager-stack.git`).
5. **Environments**: add missing ones (forwarding / letsencrypt / step-ca;
   `internal` only when genuinely needed).
6. **Extensions**: add `oidc` where the app supports it (include in default
   build, keep a no-oidc variant) and `s3-storage` where applicable.
7. **DB conformance**: if postgres runs as a plain base service, move it to
   the `database/{postgresql,pgrust}` extension pair — dual-file idiom per
   stack-conventions §8 (verbatim fragments in its
   `references/patterns.md` §11): `postgres:alpine` floating default
   unless a documented app incompatibility requires older, volume mounted
   at `/var/lib/postgresql`, DB env `${POSTGRES_*:-}` with
   `POSTGRES_PASSWORD:?`, healthcheck `pg_isready` + app
   `depends_on: service_healthy`.
8. **Naming conformance**: rename services to `<stack>-<role>`, align
   `container_name` to equal the service name, network to
   `<stack>-network`, volumes to `<stack>-<purpose>` with explicit `name:`
   (stack-conventions §3).
9. **Env conformance**: purge unused vars from `.env.example` (§6), convert
   hardcoded compose env literals to `${VAR:-}`/`${VAR:?}` (§5;
   before/after fragment in patterns.md §12), and move
   environment-dependent vars (public base URLs, TLS-derived defaults)
   from base into the environment overlays (§7; layering fragment in
   patterns.md §13).
10. **stackbuilder.toml**: convert to the new `[build.environments]` API.
11. **Source-built images**: if the app has no published Docker image,
    convert any context-dependent builds to the `source-image` skill
    pattern (`app/images/<image>/Dockerfile`, self-contained). NEVER vendor
    upstream source into the stack repo — stack-conventions §19.
12. **Artifacts**: delete `.kilocode/`, `.clinerules/` everywhere in the
    stack.
13. **READMEs**: regenerate hub + component READMEs with the `readme-gen`
    skill.
14. **Verify** with the `stack-test` skill (step-ca variant first).
```

**Verify:**
```bash
grep -n "§" .opencode/skills/stack-modernize/SKILL.md   # §17 §1 §8 §3 §6 §5 §7 §19 + patterns.md §11 §12 §13; NO old §13/§15 refs
grep -n "conformance" .opencode/skills/stack-modernize/SKILL.md  # steps 7 (DB), 8 (Naming), 9 (Env)
sed -n '/## Procedure/,$p' .opencode/skills/stack-modernize/SKILL.md | grep -c "^[0-9]*\. \*\*"  # 14 numbered steps
```

**Commit:**
```bash
git add .opencode/skills/stack-modernize/SKILL.md
git commit -m "$(cat <<'EOF'
Add conformance steps to stack-modernize

Inserted DB, naming, and env conformance
steps into the procedure; renumbered the
later steps; remapped section refs to the
new conventions numbering.

Bring old stacks to the restructured rules
when modernization is requested.
EOF
)"
```

### Task 2.4: stack-test — Stage A2 gate + procedure renumber
**File:** `.opencode/skills/stack-test/SKILL.md`
**Test:** none (docs — Verify greps below)
**Depends:** 1.1

Replace the ENTIRE file with the following (complete new file, copy-paste ready). Changes vs the current file: frontmatter description advertises the staged gates; clone-in-tmp ref §13→§17 (Compat check step 3); the Staged browser E2E list gains Stage A2 and the S3-last bullet; the Procedure inserts Stage A2 as new step 7 and renumbers old 7–11 → 8–12. The `references/browser-e2e.md` §1/§2 refs are that file's OWN section numbers and stay as-is.

````markdown
---
name: Stack Test
description: >-
  Testing procedure for docker-stack-collection stacks: staged browser E2E
  gates (base+DB, then pgrust, then oidc, s3 last — one extension at a
  time), step-ca variant first, never touching the live step-ca-manager
  setup; sb build checks, compose config validation, health, cert-wait,
  OIDC and S3 verification. Use after any stack change.
---

# Stack Test

Load the `stack-conventions` skill first. This procedure is the acceptance
test for every stack change.

## Hard rules

- ALWAYS test the step-ca-manager variant first.
- The live step-ca-manager + companion + nginx-proxy + kanidm setup is
  RUNNING. NEVER modify it. If a problem is caused by it, switch to the
  forwarding variant — never touch the manager stack.
- The letsencrypt variant is NOT tested; assume analogous to step-ca minus
  the `STEP_CA_TRUST` env.

## Compat check (pre-pull)

Run this BEFORE the procedure below whenever images may have changed (after
any stack change or image update) — never verify against stale local
images:

1. Pre-pull images first, in the built environment dir:

   ```bash
   cd build/<env>/<combo>/ && docker compose pull
   ```

2. Verify the EXISTING configs still work with the freshly pulled
   containers (health, logs, core functionality), then continue with the
   normal procedure below.
3. If a new container breaks with the old configs: diff the upstream repo
   between the last recorded commit and the new one to identify what
   changed in the configuration surface — `UPSTREAM.md` has both commits;
   use the clone-in-tmp workflow in stack-conventions §17. Fix the configs
   per collection rules, re-verify, then append a new provenance row to
   `UPSTREAM.md` (append-only — never rewrite existing rows).

## Staged browser E2E

Verification is a staged pipeline; the browser is the gate between stages
(stack-conventions §9):

- **Stage A — base deployment (+ DB, no oidc):** base + the `postgresql`
  database extension when the app needs postgres; NO oidc, NO s3. After
  health checks pass, drive `https://<VIRTUAL_HOST>` with agent-browser.
  MUST pass before any further extension work.
- **Stage A2 — DB alternative (pgrust):** rebuild with the `pgrust` combo,
  same browser gate. Clean pass → `pgrust` becomes the default combo
  (stack-conventions §9). Failure → keep `postgresql` default and record
  why in the component README.
- **Stage B — oidc enabled:** env-based (rebuild with the `oidc`
  extension) or UI-based (provider configured in the app's own web UI —
  gitea, zerobyte), then re-verify in the browser.
- **S3 round-trip — always last:** only when the `s3-storage` extension is
  present, after Stage B.

Before ANY browser step: load the `agent-browser` skill, then load its
runtime content — never work from memory:

```bash
agent-browser skills get core
```

Full checklists: `references/browser-e2e.md`.

## Procedure

Follow `references/verification-procedure.md` in order. Summary:

1. `cd app/ && sb build` — check the `build/<env>/<combo>/` output structure.
2. `cd build/<env>/<combo>/ && cp .env.example .env` and edit values.
3. `docker compose config` — must validate.
4. `docker compose up --build -d`.
5. Health checks pass.
6. **Stage A browser gate** (base + DB via the postgresql extension, no
   oidc): clean TLS, local login, one core flow, screenshot artifact
   (`references/browser-e2e.md` §1).
7. **Stage A2 browser gate** (DB alternative): rebuild with the `pgrust`
   combo, run the same Stage A flow (`references/browser-e2e.md` §1); on
   a clean pass promote `pgrust` to the default combo (stack-conventions
   §9).
8. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
9. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
10. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
    `SSL_CERT_FILE` (open-webui example).
11. **Stage B** (oidc present): env-based rebuild or UI-based configuration,
    then browser login via kanidm + email-matching account linking
    (`references/browser-e2e.md` §2).
12. S3 round-trip when the `s3-storage` extension is present — always LAST.
````

**Verify:**
```bash
grep -n "§" .opencode/skills/stack-test/SKILL.md          # §17 (clone-in-tmp) + §9 (staged/promote, ×3); browser-e2e §1/§2 refs unchanged; NO §13
grep -n "Stage A2" .opencode/skills/stack-test/SKILL.md   # present in Staged E2E list AND procedure step 7
sed -n '/## Procedure/,$p' .opencode/skills/stack-test/SKILL.md | grep -c "^[0-9]*\. "  # 12 steps
grep -n "always LAST" .opencode/skills/stack-test/SKILL.md  # S3 step marked last
```

**Commit:**
```bash
git add .opencode/skills/stack-test/SKILL.md
git commit -m "$(cat <<'EOF'
Add Stage A2 gate to stack-test

Added the pgrust DB-alternative stage to the
browser E2E pipeline and procedure summary;
renumbered the procedure steps; remapped the
clone-in-tmp section ref.

Gate the pgrust promotion on a browser test
before oidc work begins.
EOF
)"
```

### Task 2.5: browser-e2e — Stage A2 subsection + drop source parentheticals
**File:** `.opencode/skills/stack-test/references/browser-e2e.md`
**Test:** none (docs — Verify greps below)
**Depends:** 1.1

FOUR precise edits (find by text, not line number). The file's own §0–§3
numbering MUST stay unchanged — Stage A2 is added as a `###` subsection at
the END of §1, so the `§1`/`§2` refs from stack-test SKILL.md and the
`§1–4` refs to verification-procedure.md keep resolving. Do NOT rewrite
the whole file.

**Edit 1 — §1 header + intro.** Replace:

```markdown
## 1. Stage A — base deployment (no oidc)

Run BEFORE adding the `oidc` extension. Gate: Stage A must pass or Stage B
is meaningless.
```

with:

```markdown
## 1. Stage A — base deployment (+ DB, no oidc)

Run BEFORE adding the `oidc` extension. When the app needs postgres, this
variant is base + the `postgresql` database extension. Gate: Stage A must
pass or Stage B is meaningless.
```

**Edit 2 — gitea parenthetical.** Replace:

```markdown
**gitea** (source: `stacks/devops/version-control/gitea/app/README.md`):
```

with:

```markdown
**gitea**:
```

**Edit 3 — zerobyte parenthetical.** Replace:

```markdown
**zerobyte** (source: `stacks/devops/backup/zerobyte/app/oidc.md` — follow it
verbatim):
```

with:

```markdown
**zerobyte** (follow the steps verbatim):
```

**Edit 4 — append the Stage A2 subsection** immediately AFTER the §1 line
`- [ ] Screenshot the working app state → run artifact.` and BEFORE the
`## 2. Stage B — oidc enabled` header:

```markdown
### Stage A2 — DB alternative (pgrust)

Run AFTER Stage A passes and BEFORE oidc — the same browser gate on the
alternative DB engine:

- [ ] Rebuild with the `pgrust` combo and redeploy
      (verification-procedure.md §1–4).
- [ ] Same Stage A flow: page loads, TLS clean, local login, one core
      flow, screenshot artifact.
- [ ] Clean pass → `pgrust` becomes the default combo (stack-conventions
      §9). Failure → keep `postgresql` as the default combo and record
      why in the component README.
```

**Verify:**
```bash
grep -n "stacks/" .opencode/skills/stack-test/references/browser-e2e.md   # zero hits
grep -n "Stage A2" .opencode/skills/stack-test/references/browser-e2e.md  # subsection present
grep -n "^## " .opencode/skills/stack-test/references/browser-e2e.md      # sections 0, 1, 2, 3 — numbering UNCHANGED
grep -n "^### " .opencode/skills/stack-test/references/browser-e2e.md     # 2a, 2b, Stage A2
```

**Commit:**
```bash
git add .opencode/skills/stack-test/references/browser-e2e.md
git commit -m "$(cat <<'EOF'
Add Stage A2 checklist to browser-e2e

Added the pgrust rebuild-and-promote
checklist under Stage A; marked Stage A as
base plus DB; dropped two source-path
parentheticals.

Keep the reference self-contained and aligned
with the staged pipeline.
EOF
)"
```

### Task 2.6: AGENTS.md — stack iron rules
**File:** `AGENTS.md` (repo root)
**Test:** none (docs — Verify greps below)
**Depends:** 1.1

TWO edits:

**Edit 1 — insert the iron-rules section** after the last line of the
`## Pitfalls ledger (PITFALLS.md)` section (the line `- Never leave an
encountered obstacle unrecorded at the end of a session.`) and BEFORE the
`## Source-built images — no vendoring (stack work)` header. Content
VERBATIM from the design:

```markdown
## Stack work — iron rules (load stack-conventions first)

Any work on a stack (create, modify, extend, modernize) MUST load the
`stack-conventions` skill BEFORE acting. Non-negotiable rules from it:

- Naming: services and containers are `<stack>-<role>` (e.g. `<stack>-db`,
  `<stack>-app`); `container_name` equals the service name; networks
  `<stack>-network`, volumes `<stack>-<purpose>`. No generic names, no
  unused `PROJECT_NAME`-style vars.
- Env: every compose env value is overridable (`${VAR:-default}` /
  `${VAR:?}`) — never hardcoded. `.env.example` holds only vars the
  compose files actually reference; optional vars live in extension
  fragments only.
- Layering: environment-dependent vars (public URLs, TLS-derived
  defaults) are declared only in environment overlays, never in base.
- Postgres: always the `database/{postgresql,pgrust}` extension pair —
  never a base-compose service; `postgres:alpine` (latest, not the
  upstream-pinned version); volume mounted at `/var/lib/postgresql`.
- Staged protocol: base implementation first → test gate → extensions
  one at a time (pgrust after base passes — becomes default if clean;
  oidc/s3 only after base passes; s3fs-fuse never on DB volumes). Never
  wire s3/oidc before the base is implemented and tested.
- Skills and agent definitions are self-contained: no path references
  into `stacks/` — patterns are embedded; stacks move and change.
```

**Edit 2 — § remap** in the `## Source-built images` section: `agents MUST
follow the `source-image` skill and stack-conventions
§15:` → `... and stack-conventions §19:` (only the number changes).

**Verify:**
```bash
grep -n "§" AGENTS.md                # ONLY §19
grep -n "iron rules" AGENTS.md       # new section header present
grep -n "PROJECT_NAME" AGENTS.md     # ONLY the iron-rules prohibition mention
```

**Commit:**
```bash
git add AGENTS.md
git commit -m "$(cat <<'EOF'
Add stack iron rules to AGENTS.md

Added the stack-work iron rules section;
updated the source-built images section ref
to the new numbering.

Put the non-negotiable stack conventions in
front of every agent working in this repo.
EOF
)"
```

### Task 2.7: PITFALLS.md — P-008 entry + § remaps
**File:** `PITFALLS.md` (repo root)
**Test:** none (docs — Verify greps below)
**Depends:** 1.1

THREE edits (Russian text per the file's format; the entry records the
vibe-kanban violation classes — historical mentions of the DELETED old
rules are explicitly marked «старый §N» so they cannot be mistaken for
live refs):

**Edit 1 — P-001 fix line:** `stack-conventions §12` → `stack-conventions
§16` (only the number changes).

**Edit 2 — P-004 fix line:** `stack-conventions §15` → `stack-conventions
§19` (only the number changes).

**Edit 3 — append P-008 at the END of the file** (after the P-007 entry):

```markdown
## P-008: mass convention violations on stack creation (naming/env/db/staged)
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: создание стеков / правила коллекции (vibe-kanban)
- symptom: при создании vibe-kanban нарушены 8 классов правил разом:
  объявлен ни разу не используемый `PROJECT_NAME`; postgres как обычный
  сервис в base-compose (без extensions/, без pgrust-альтернативы, версия
  `postgres:16-alpine` скопирована из upstream, узкий маунт
  `/var/lib/postgresql/data`); имена сервисов не совпадают с
  container_name и не несут префикса проекта (`remote-server`,
  `vk-remote-server`, `electric`); захардкоженные env-литералы в compose
  (`RUST_LOG`, `SERVER_LISTEN_ADDR`, `ELECTRIC_URL`, `POSTGRES_DB/USER`);
  мёртвые переменные в `.env.example`; всё навернуто сразу без
  тест-гейтов (19 коммитов, ни одного тестового); `SERVER_PUBLIC_BASE_URL`
  объявлен в base и переопределён с другими дефолтами в letsencrypt/
  step-ca оверлеях; 24+ ссылок на пути `stacks/` в скиллах
- cause: правила пользователя не были кодифицированы в stack-conventions
  (DB-as-extension с pgrust, `${VAR:-}` везде, префиксные имена,
  поэтапный протокол с гейтами, layering); два старых правила были прямо
  вредны (старый §3 предпочитал `${PROJECT_NAME:-<svc>}`-нейминг, старый
  §9 требовал ключ `PROJECT_NAME` в `.env.example`)
- workaround: —
- fix: stack-conventions переструктурирован в §1–§19 (naming, env wiring,
  DB-as-extension, staged protocol, layering); iron rules добавлены в
  AGENTS.md; скиллы self-contained (паттерны встроены, атрибуция только
  по имени стека); поэтапный протокол с тест-гейтами вписан в
  stack-init/stack-test
```

**Verify:**
```bash
grep -n "P-008" PITFALLS.md           # entry present, status: fixed
grep -n "§" PITFALLS.md               # §16 (P-001), §19 (P-004); P-008: «старый §3», «старый §9», §1–§19
tail -5 PITFALLS.md                   # P-008 fix block is the last entry
```

**Commit:**
```bash
git add PITFALLS.md
git commit -m "$(cat <<'EOF'
Record P-008 and remap pitfalls refs

Appended the P-008 mass convention violations
entry as fixed; remapped the P-001 and P-004
fix refs to the new conventions numbering.

Log the violation class and keep ledger refs
resolvable after the renumbering.
EOF
)"
```

---

## Batch 3: Global verification + commit safety net (sequential)

Runs AFTER all Batch 1 + Batch 2 tasks are committed. 3.1 → 3.2, strictly
sequential. All commands run from the repo root
(`/home/archuser/projects/docker-stack-collection`).

### Task 3.1: Run the design's six verification checks
**File:** none (verification; commit ONLY if a check fails and needs a fix)
**Test:** this task IS the test
**Depends:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7

Run each check; compare against the expected output. If ANY check fails,
fix the offending file per the corresponding task's spec above, re-run,
and commit the fix. If all six pass, report done — no commit needed.

**Check 1 — zero specific-stack paths under `.opencode/`:**
```bash
grep -rn "stacks/" .opencode/
```
EXPECTED — only these survivors:
- `stack-init/SKILL.md` + `stack-init/references/scaffold-checklist.md`:
  generic placeholders (`stacks/<category>/<subcategory>/<stack-name>/`,
  `stacks/<category>/<...>/<stack>`, `stacks/<path>;-;unverified`)
- `stack-conventions/SKILL.md` §16/§17: the gitignore statements and the
  generic example `stacks/<category>/<...>/<stack>/app/...`
- `stack-conventions/references/rationale.md`: the generic
  `stacks/<category>/<stack>/` placeholder and the bare word `stacks/`
  inside the entry-22 prohibition text
- `stack-conventions/references/patterns.md`: ZERO hits
ZERO real paths — nothing like `stacks/devops/...`,
`stacks/network-privacy/...`, `stacks/development-tools/...`.

**Check 2 — `PROJECT_NAME` only in prohibition/hygiene text:**
```bash
grep -rn "PROJECT_NAME" .opencode/ AGENTS.md
```
EXPECTED: `stack-conventions/SKILL.md` §3 (prohibition) + §6 (hygiene
mention), `AGENTS.md` iron rules (prohibition). Nothing else.
(PITFALLS.md P-008 mentions it as a historical record — out of this
grep's scope.)

**Check 3 — every § ref resolves to the new §1–§19 numbering:**
```bash
grep -rn "§" .opencode/ AGENTS.md PITFALLS.md STASKBUILDER.md
```
EXPECTED: refs into stack-conventions use the new numbers — §17
(provenance/clone-in-tmp), §19 (source-built images), §6 (env key order),
§8 (DB extension), §9 (staged protocol), §3/§5/§7 (rules). Explicitly OUT
OF SCOPE (unchanged by design): `browser-e2e.md` §0–§3 and
`verification-procedure.md` §1/§2 — those number stack-test's OWN
reference docs, whose section numbering this plan deliberately preserves.
`PITFALLS.md` P-008 «старый §3»/«старый §9» are marked historical records
of the deleted wrong rules. `STASKBUILDER.md`: zero § refs (verified
pre-plan).

**Check 4 — each of the 8 violation classes maps to a written rule:**
```bash
grep -n 'the `PROJECT_NAME` failure' .opencode/skills/stack-conventions/SKILL.md        # classes 1+5 → §6
grep -n 'NEVER a plain service in base compose' .opencode/skills/stack-conventions/SKILL.md  # class 2 → §8
grep -n 'NEVER generic, anonymous, or role-only' .opencode/skills/stack-conventions/SKILL.md  # class 3 → §3
grep -n 'Bare literals are forbidden' .opencode/skills/stack-conventions/SKILL.md       # class 4 → §5
grep -n 'MUST pass' .opencode/skills/stack-conventions/SKILL.md                          # class 6 → §9
grep -n 'base is environment-agnostic' .opencode/skills/stack-conventions/SKILL.md       # class 7 → §7
grep -n 'no path references' AGENTS.md                                                   # class 8 → iron rules
```
EXPECTED: every grep returns exactly one hit (classes 1+5 share the §6
rule).

**Check 5 — frontmatter + reference files valid:**
```bash
for f in .opencode/skills/*/SKILL.md; do head -1 "$f" | grep -q '^---$' || echo "BAD frontmatter: $f"; done; echo frontmatter-done
test -f .opencode/skills/source-image/references/dockerfiles.md && echo dockerfiles-ok
```
EXPECTED: `frontmatter-done` with no BAD lines; `dockerfiles-ok`.

**Check 6 — embedded fragments syntactically plausible (REVIEW, not grep):**
Read `stack-conventions/references/patterns.md` §11–§13 and
`source-image/references/dockerfiles.md` end to end: YAML uses 2-space
indentation, env fragments use `KEY=value` syntax, Dockerfile RUN
continuations use `\`, `${...}` inside single-quoted YAML values stays
single-quoted, healthcheck lists are properly quoted.

**Commit (ONLY if a fix was needed):**
```bash
git add <fixed-files>
git commit -m "$(cat <<'EOF'
Fix verification findings

<past-tense description of what was fixed>

Keep the enforcement change verifiable end
to end.
EOF
)"
```

### Task 3.2: Commit safety net
**File:** none (repo hygiene)
**Test:** `git status` clean for the edit surface
**Depends:** 3.1

```bash
git status --short
git log --oneline -25
```

EXPECTED: `git status --short` shows NOTHING under `.opencode/skills/**`,
`AGENTS.md`, `PITFALLS.md`, `thoughts/shared/**` (every task committed
itself; Batch 3 commits only when it fixed something). `git log` shows
one commit per implemented task (Tasks 1.1–2.7).

If anything in the edit surface is untracked or modified: commit it NOW
per the `.gitmessage` format (header = infinitive verb ≤50 chars;
"what" = past-tense lines; "why" = present-tense lines; English). If
nothing is left, this task is a no-op — report clean.

---

## Execution notes (for the orchestrator)

- Batch 1 (8 tasks) and Batch 2 (7 tasks) are fully parallel within their
  batch; Batch 2 starts only after ALL of Batch 1 is committed (its
  content points at the new § numbering and patterns.md §11–§13).
- Task 1.4 creates TWO files (SKILL.md edit + NEW references/dockerfiles.md)
  — one tightly-coupled task, one commit.
- ZERO edits under `stacks/` in any task. `.opencode/agents/**` and
  `~/.config/opencode/micode.jsonc` are untouched.
- Every task's Verify block is its test — these are docs/config files,
  no unit tests apply.
- If a task's find-text does not match (file drifted), STOP and report —
  do not improvise a different edit.
