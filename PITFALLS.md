# PITFALLS — recurring pitfalls log

Shared across all stacks in the collection. It records obstacles hit while
preparing deployment configs, working with stackbuilder (`sb`), docker
compose, OIDC/S3/step-ca integration, and testing stacks.

Problems here are often shared between projects, so there is one log and it
lives at the collection root. The `hits` counter shows how often a problem
occurs even while it is still unfixed — a high `hits` with `status: open`
means: time to fix it, not to work around it.

## Lookup (how to find the file from any folder)

1. Walk up from the current working directory until you find `PITFALLS.md`.
2. If not found (e.g. the stack was cloned outside the collection) — use the
   canonical path:
   `/home/archuser/projects/docker-stack-collection/PITFALLS.md`.

## Entry format

    ## P-NNN: <title: EN keywords + brief description>
    - hits: N | status: open | first: YYYY-MM-DD | last: YYYY-MM-DD
    - where: <sb / compose / step-ca / oidc / s3 / testing ...>
    - symptom: <how it manifests>
    - cause: <cause, if known>
    - workaround: <workaround, if any>
    - fix: <how it was fixed; "—" until fixed>

Statuses: `open` (unresolved) / `mitigated` (workaround works, problem
remains) / `fixed` (resolved, entry kept as a reference).

## Update protocol

- **New obstacle** → new entry: `hits: 1`, `status: open`.
- **Already recorded** → `hits +1`, update `last`; extend
  `symptom`/`workaround` if new details appeared.
- Before adding, search by keywords (grep the file) to avoid piling up
  duplicates of similar entries.
- **Fixed** → `status: fixed` + fill in `fix`. Entries are NEVER deleted.
- Never leave an encountered obstacle unrecorded at the end of a session.

Entries are appended to the end of the file; IDs are sequential
(P-001, P-002, ...).

---

## P-001: root-level search blind inside stacks/
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: code search/navigation
- cause: `stacks/` is in the collection's .gitignore and each stack is a separate
  git repo; glob/grep from the collection root sees nothing inside stacks/
- fix: rule enshrined in stack-conventions §16 — always specify the concrete
  stack path, e.g. `stacks/devops/identity-management/kanidm/...`

## P-002: stackbuilder no cartesian environment matrix
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: sb build / stackbuilder.toml
- symptom: the environment × extension matrix cannot be generated automatically
- workaround: hand-written named `combos` (easytier idiom); sb limitations
  tracked in `STASKBUILDER.md`
- fix: —

## P-003: session cwd in stack subfolder — hub files unreachable
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: any work from stack subfolders
- symptom: the collection's AGENTS.md and root files (PITFALLS.md,
  STASKBUILDER.md) may fail to load / be unreachable via relative paths when
  a session works from inside a stack's separate git repo
- workaround: lookup rule at the top of this file (walk up from cwd →
  canonical absolute path); the rule is duplicated in AGENTS.md and
  stack-conventions
- fix: —

## P-004: vendoring upstream source into stack repo (submodule proposal)
- hits: 2 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: design/plan for stacks without published Docker images (vibe-kanban and
  the earlier attempt)
- symptom: the agent proposes pulling the upstream app's sources into the
  deployment-config repo as a git submodule (`modules/<app>`) or a copy of the
  sources; the user rejected it twice
- workaround: never vendor sources; the tmp clone from clone-in-tmp is
  reference-only; building from source is done as a self-contained
  `app/images/<image>/Dockerfile` (ARG GIT_REPO/GIT_TAG or release archive),
  compose references the ready image via `${IMAGE:-localhost/<image>:<tag>}`
- fix: rule enshrined in stack-conventions §19, the `source-image` skill,
  steps in stack-init/stack-modernize, section in AGENTS.md

## P-005: stackbuilder source does not compile (missing import)
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: sb / tools/stackbuilder
- symptom: `cargo build --release` in tools/stackbuilder fails E0425/E0433 —
  `BTreeMap` not found in src/env_merger.rs
- cause: the stackbuilder repo lacks `use std::collections::BTreeMap;`
- fix: import added in src/env_merger.rs; the binary is named `stackbuilder`,
  not `sb` — symlink `~/.local/bin/sb -> target/release/stackbuilder`

## P-006: sb build requires external yq by default
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-11-04
- where: sb build
- symptom: `sb build` fails "yq is required but not available" on hosts without
  a system yq
- workaround: `yaml_merger = "rust"` in the `[build]` section of
  stackbuilder.toml (built-in Rust merger); also enshrined in STASKBUILDER.md
  (L10)
- fix: `yaml_merger = "rust"` removed from opencode-stack's stackbuilder.toml
  (commit 19d10e0) — sb build uses external yq again; on the host the
  mikefarah yq v4.44.3 binary is used in /tmp/opencode/bin (PATH prepended),
  because the system /usr/bin/yq is a python jq-wrapper (kislyuk,
  `yq 4.4.5 / jq-1.8.2`) that sb rejects (see P-033)

## P-007: upstream release tag does not compile — build from fixed commit
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: source-built images / vibe-kanban
- symptom: building from the release tarball of tag v0.1.45-20260919085201 fails:
  remote-web TS2339 — `getMatchedRoutes` is destructured as an object while
  the lockfile version of router-core (1.171.32) returns a tuple; fixed in 3
  commits right after the tag
- workaround: in the self-contained Dockerfile, clone upstream at a pinned
  commit (ARG GIT_COMMIT=7c380708...) instead of the release tarball;
  UPSTREAM.md records the commit, not the tag, anyway
- fix: —

## P-008: mass convention violations on stack creation (naming/env/db/staged)
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: stack creation / collection rules (vibe-kanban)
- symptom: when creating vibe-kanban, 8 classes of rules were violated at once:
  a `PROJECT_NAME` declared but never used; postgres as a regular
  service in base-compose (no extensions/, no pgrust alternative, version
  `postgres:16-alpine` copied from upstream, narrow mount
  `/var/lib/postgresql/data`); service names mismatching
  container_name and lacking the project prefix (`remote-server`,
  `vk-remote-server`, `electric`); hardcoded env literals in compose
  (`RUST_LOG`, `SERVER_LISTEN_ADDR`, `ELECTRIC_URL`, `POSTGRES_DB/USER`);
  dead variables in `.env.example`; everything done at once without
  test gates (19 commits, none a test); `SERVER_PUBLIC_BASE_URL`
  declared in base and overridden with different defaults in the letsencrypt/
  step-ca overlays; 24+ `stacks/` path references in skills
- cause: the user's rules were not codified in stack-conventions
  (DB-as-extension with pgrust, `${VAR:-}` everywhere, prefixed names,
  staged protocol with gates, layering); two old rules were outright
  harmful (old §3 preferred `${PROJECT_NAME:-<svc>}` naming, old
  §9 required a `PROJECT_NAME` key in `.env.example`)
- workaround: —
- fix: stack-conventions restructured into §1–§19 (naming, env wiring,
  DB-as-extension, staged protocol, layering); iron rules added to
  AGENTS.md; skills made self-contained (patterns embedded, attribution only
  by stack name); the staged protocol with test gates written into
  stack-init/stack-test

## P-009: agent modifies host system during image build (swap/loop devices)
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: image builds / agent behavior (host safety)
- symptom: during an image build the agent decided swap was insufficient and
  silently ran `sudo -n sh -c 'losetup -d /dev/loop0 ...; mknod /dev/loop1 b 7 1;
  losetup /dev/loop1 /swapfile; mkswap /dev/loop1; swapon /dev/loop1'` —
  nearly broke the server (manipulating the host's block devices and swap)
- cause: the allowlist of permitted agent actions was not written down
  explicitly; when memory ran short during a build the agent improvised
  "cures" for the host instead of stopping and reporting
- workaround: —
- fix: iron rules "Host safety" added as the first section of AGENTS.md —
  a full allowlist (files, git, docker/compose, oidc/s3 skills, read-only
  inspection) and a ban on sudo/swap/losetup/mknod/package managers/sysctl/
  systemd/disks; if resources run short — stop and report to the user,
  never touch the host

## P-010: sb auto-generates a no-extension base variant per environment
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-04
- where: stackbuilder (`sb build`) — per-env combos
- symptom: with `combos = [...]` per environment, sb generates not only
  `build/<env>/<combo>/` but also an extra `build/<env>/base/`
  variant (base+env without extensions) — "Generated 9 build
  combinations" instead of the expected 6; for a stack where the DB is
  mandatory (app requires Postgres), this variant is non-working and is a
  footgun
- cause: sb always adds the plain no-extension environment variant unless
  `skip_base_generation = true` is set (for linkwarden this is invisible
  because their combo itself is named `base` and writes into the
  same directory)
- workaround: —
- fix: `skip_base_generation = true` in `[build]` of stackbuilder.toml —
  the tree becomes exactly `build/<env>/<combo>/` per the combos list;
  confirmed in the opencode-stack rework: exactly one combo per
  environment (`entire` / `entire-trust`), extension combinations collapsed

## P-011: upstream migration hardcodes database name `remote`
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: vibe-kanban stack — remote-server Postgres migrations
- symptom: the app crashes/fails to start if the DB is named differently
  (`POSTGRES_DB` != `remote`); the migration cannot issue `GRANT
  CONNECT` to a non-existent DB
- cause: migration `crates/remote/migrations/
  20251127000000_electric_support.sql` hard-executes
  `GRANT CONNECT ON DATABASE remote TO electric_sync;` — the DB name
  is baked into the source (checked at pinned commit `7c380708`);
  there is no configurable variable; patching upstream is forbidden
- workaround: —
- fix: keep `POSTGRES_DB=remote` in the stack's `.env.example`/overlay
  (the name was approved by the user); enshrined by commit
  "Fix database name for remote server" in the stack repo

## P-012: automated-browser session loss in remote-web (agent-browser)
- hits: 3 | status: open | first: 2026-11-01 | last: 2026-11-01
- where: vibe-kanban remote-web SPA — browser E2E via agent-browser
- symptom: in the automated browser the SPA arbitrarily drops the
  session to the sign-in page on hard navigations/page reloads;
  in a normal browser (verified by the user) everything is stable
- cause: not a stack bug. remote-web stores the JWT pair in IndexedDB
  (`rf-auth`, store `tokens`, keys `access_token`/`refresh_token`;
  `packages/remote-web/src/shared/lib/auth.ts`); the access token lives
  120 s, tokenManager refreshes it every ~80 s
  (`POST /v1/tokens/refresh`); tokens are hydrated from IndexedDB only
  on document load, and after some reloads/failed refreshes in
  agent-browser the session is lost
- workaround: —
- fix: run E2E in a single document without extra hard navigations; login —
  in-page `fetch POST /v1/auth/local/login` {email,password} → put
  both tokens into IndexedDB → reload → SPA hydrates the session
  (redirect `/account?next=%2F` → `/`); take the screenshot right after
  re-seed; the `remote-auth-changed` event does not switch the state
  reactively

## P-013: sb build deletes build/**/.gitkeep; old container/volume leftovers conflict
- hits: 2 | status: open | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban app/remote after app/→app/remote/ move and service rename
- symptom: `sb build` removes tracked `build/**/.gitkeep`; `compose up` fails
  on container_name conflict with old `vibe-kanban*` test containers; kept
  old volumes hold the old DB password
- fix: restore .gitkeep via `git ls-files -d | xargs touch`; remove only our
  old containers; reuse old secrets from the old build/.env

## P-014: relay image build fails with `cargo build --locked` (relay-tunnel excluded from workspace)
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban app/relay/images/vibe-kanban-relay Dockerfile
- symptom: `cargo build --locked` fails "cannot update the lock file ... because --locked was passed"; crates/relay-tunnel is in workspace `exclude` and its own Cargo.lock needs updating
- fix: drop `--locked`; limit parallelism with CARGO_BUILD_JOBS=2

## P-015: wildcard cert impossible via http-01 on step-ca
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban relay, `LETSENCRYPT_HOST` containing `*.relay.<domain>`
- symptom: companion logs `Cannot get domain token entry *.relay.<domain> for http-01`; no cert issued
- fix: `LETSENCRYPT_HOST` = apex only; keep wildcard in `VIRTUAL_HOST` for routing; wildcard cert needs DNS-01

## P-016: source Dockerfile missing patches/ before `pnpm install --frozen-lockfile`
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban host image
- symptom: `ENOENT ... /app/patches/@pierre__diffs@1.1.4.patch`
- fix: `COPY --from=source /repo/patches/ patches/` before install

## P-017: cross-group access to a DB published on 127.0.0.1 fails via host.docker.internal
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban relay -> remote DB
- symptom: relay cannot connect to the DB
- fix: remote `DB_PUBLISH_ADDR=0.0.0.0` (test) — restrict by firewall in production

## P-018: rustls-based app rejects step-ca certs (UnknownIssuer)
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban host -> remote (`/api/auth/local/login` 502)
- symptom: `failed to verify TLS certificate: UnknownIssuer`
- fix: mount step-ca root_ca.crt, set `SSL_CERT_FILE`; file must be readable by uid 10001 (mode 644) or the app panics "No CA certificates were loaded"
- fix (final): vibe-kanban host `step-ca-trust` extension: root user entrypoint wrapper builds system bundle + step-ca root (chmod 644), sets SSL_CERT_FILE and HOME=/home/appuser (else PermissionDenied), drops to uid 10001 via setpriv; CA from external volume `step-ca-data` with `subpath: certs`

## P-019: Stage D pairing E2E cannot run self-paired / headless
- hits: 1 | status: open | first: 2026-11-03 | last: 2026-11-03
- where: vibe-kanban Stage D gate
- symptom: `client/pair` lives on the host server, release build forbids pairing to itself; in-app browser disconnected, no agent-browser CLI
- fix: needs second host machine + attached desktop browser + remote web credentials; rerun Batch 8 manually

## P-020: repo-local bind mount not writable by uid 10001
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: vibe-kanban host `repo-local` extension (`REPOS_PATH`)
- symptom: host container (uid 10001) cannot write into the bind-mounted repo
- fix: host-side permissions are the user's job (chown/ACL, or `chmod -R a+rwX` for tests); stack never changes them

## P-021: `docker compose down` in one host variant dir removes the shared network
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: vibe-kanban host variants (repo-sync / repo-local share project `vibe-kanban-host`)
- symptom: `vibe-kanban-host-network` disappears for other containers
- fix: `up -d` of the next variant recreates it; run down before switching variants

## P-022: ghcr tags for opencode have no `v` prefix
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack (image refs in compose/.env.example/docs)
- symptom: `ghcr.io/anomalyco/opencode:v2.2.5` pull fails manifest unknown
- fix: tag is `ghcr.io/anomalyco/opencode:2.2.5` (upstream release tag is `v2.2.5`, ghcr tag drops the `v`)

## P-023: compose `up` skips dockerfile_inline build when image tag exists
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack base compose (dockerfile_inline FROM-layer)
- symptom: after changing the FROM-layer, `docker compose up -d` reuses the stale local image; config changes never land
- fix: run `docker compose up -d --build` (or `docker compose build` first); `down` does not remove the built image

## P-024: exported shell env var silently overrides compose .env
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack gate runs (OPENCODE_SERVER_PASSWORD)
- symptom: container gets a stale/empty password from the agent's shell env instead of the value in `app/build/forwarding/.env`; auth gate behaves inconsistently
- fix: always run compose as `env -u OPENCODE_SERVER_PASSWORD docker compose ...` from the forwarding dir

## P-026: raw-curl GHCR manifest probes give misleading 404 — use `docker manifest inspect`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Phase 0 (ghcr.io/bndct-devops/tome tag probe)
- symptom: tokens + Accept-header curls against `https://ghcr.io/v2/.../manifests/<tag>` returned 404/`MANIFEST_UNKNOWN` (with contradictory "OCI index found" bodies) for tags that actually exist; `docker manifest inspect` proves truth. Also ghcr tags may drop the `v` prefix (cf. P-022): tome ships `2.8.0`, not `v2.8.0`
- fix: verify registry tags only via `docker manifest inspect <repo>:<tag>` / `docker buildx imagetools inspect`; treat curl probes as unreliable for GHCR

## P-025: opencode server rejects `?auth_token=` — Basic header only
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack healthcheck + all gate curl calls
- symptom: `GET ...?auth_token=<password>` returns 401 even with the correct password
- fix: HTTP Basic only: `-u opencode:<password>` / `Authorization: Basic base64(opencode:<password>)`

## P-026: opencode legacy auth.json import migration does not import credentials
- hits: 1 | status: open | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack data volume (`/data/opencode/auth.json` + opencode.db), upstream migration `20260805200742_import_legacy_credentials`
- symptom: fresh db created with auth.json already present still has an empty credential table; `opencode auth list` shows nothing; model calls fail `provider.no-route`
- fix (workaround): `POST /api/credential` `{"integrationID":"openrouter","label":"API key","value":{"type":"key","key":"<key>"},"activate":true}`; root cause of the skipped import unresolved

## P-027: opencode model IDs use dots, not the release-style dashes
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack gate session model selection
- symptom: session with model `anthropic/claude-haiku-4-5` fails `provider.no-route` even though the provider is available
- fix: catalog ID is `anthropic/claude-haiku-4.5` — always pick IDs from `GET /api/model`, never guess from release tags

## P-028: compose interpolates every `$var` inside dockerfile_inline at config time
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (dockerfile_inline RUN loop)
- symptom: `for s in ...; do sh "$s"; done` in dockerfile_inline — compose warns `The "s" variable is not set` and bakes an empty string into the layer
- fix: escape shell vars in dockerfile_inline as `$$var` (same rule as healthchecks); only `${VAR:-}` forms are meant for compose interpolation; in the opencode rework the dockerfile_inline RUN loop was removed entirely —
install scripts are committed in `app/plugins/` and COPYed into the image
(`COPY entrypoint.sh plugins* /opt/plugins-build/` tolerates a missing plugins folder)

## P-029: pip dependency-group installs abort all-or-nothing on py3.14 (Alpine 3.24)
- hits: 1 | status: open | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (headroom install in the image build)
- symptom: installing headroom-ai's full dependency set in one `pip install` fails wholesale when any single package lacks a py3.14 musl wheel (magika has none; ast-grep-cli ships gnu-only wheels)
- fix (workaround): install the CLI `--no-deps`, then stage deps: one core group, then the rest one at a time; magika is safe to drop (lazy import inside try/except), ast-grep absence only degrades a fallback

## P-030: rtk `init` is global-only for OpenCode plugins
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (rtk install script)
- symptom: `rtk init --opencode` errors "OpenCode plugin is global-only"; `rtk hook opencode` alone is just the stdin hook processor and generates nothing
- fix: run `rtk init -g --opencode` (non-interactive defaults to "N" for the settings.json prompt — harmless), then copy the generated `/root/.config/opencode/plugins/rtk.ts` to the baked plugin dir

## P-031: opencode image has no `openssl`; busybox `ssl_client` is helper-only
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack step-ca-trust gate (TLS verification inside `opencode-stack-app`)
- symptom: `openssl` not found in the app container (Alpine 3.24.3 base); busybox `ssl_client` rejects `-connect`/`-servername` (usage: `ssl_client [-s FD] [-I] -n SNI` — it is a helper applet invoked by wget, not a standalone client); in-container fingerprint greps print vacuous output (empty fingerprints match everything)
- fix: run a throwaway `docker run --rm --network <net> alpine:3.20` container and `apk add -q openssl` there for all TLS chain checks (each `docker run` is fresh — re-install every time); verify trust by contrasting `openssl s_client -CAfile` with/without the root: untrusted gives "unable to get local issuer", trusted-but-expired gives only "certificate has expired"

## P-032: `sb build` wipes the build-dir `plugins/` folder
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (user-supplied `plugins/` folder next to the generated `docker-compose.yml`)
- symptom: after copying ready-made install scripts from `app/plugins/` into `build/<env>/plugins/` and setting `PLUGINS_*` toggles, a later `sb build` regenerates the build dir and silently removes the copied `plugins/` folder; the next `docker compose build` runs with no install scripts and the plugins mechanism stays inert
- fix (workaround): re-copy the scripts from `app/plugins/` after every `sb build` (documented in `app/plugins/README.md` and `app/README.md`); root cause is sb's build-dir regeneration, not yet addressed in sb itself
- fix: plugins redesigned as a pure base feature (commit 02e1517): install scripts moved to `app/components/base/plugins/`, and sb's copier walks the entire base component dir recursively, so `sb build` now auto-copies `plugins/` into every build dir — nothing to re-copy; the plugins extension and the manual copy step are gone

## P-033: system yq is a python jq-wrapper, sb rejects it
- hits: 2 | status: mitigated | first: 2026-11-04 | last: 2026-11-05
- where: sb build / host tooling (opencode-stack, navidrome stack)
- symptom: the system `/usr/bin/yq` is the kislyuk python wrapper over jq
  (`yq 4.4.5 / jq-1.8.2`), not mikefarah yq; sb rejects it as an
  incompatible implementation and the build fails
- workaround: mikefarah yq v4.44.3 binary in /tmp/opencode/bin, PATH
  prepended; check — `yq --version` must show mikefarah v4.x
- fix: —
- hits: 3 | last: 2026-11-05 (nanomcp stack: sb build failed again without
  /tmp/opencode/bin in PATH; `export PATH=/tmp/opencode/bin:$PATH` before sb)

## P-034: bun install without python/make/g++ breaks node-gyp native modules
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: source-built images (aionui stack, Dockerfile build stage)
- symptom: `bun install` fails on the `better-sqlite3` install script:
  `gyp ERR! find Python` → `error: install script from "better-sqlite3"
  exited with 1`; the bun image contains no python3 or C toolchain, while
  native modules are built by node-gyp at install time
- cause: node-gyp requires python3 + make + g++; slim/bun base images do
  not carry them
- fix: add `python3 make g++` to the apt-get install of the Dockerfile
  build stage (aionui, commit `fix(images): correct build for gate`); for
  any source-built bun/node image with native dependencies — plan the
  toolchain into the build stage from the start


## P-035: openwork-server routes are UNPREFIXED — /api/* probes all 404
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: openwork-stack smoke / token checks (openwork-server 0.18.4)
- symptom: token positive/negative checks against `http://localhost:8787/api/info`, `/api/health`, `/api/config` etc. all return 404 with and without `Authorization: Bearer` — looks like auth is broken; the `/api/*` strings in the UI bundle and binary are client-side/mounted-elsewhere, not server routes
- cause: server routes are registered at the ROOT (`/health`, `/status`, `/whoami`, `/capabilities`, `/workspaces`, `/tokens`, `/w/:id/...`) via `addRoute` in `apps/server/src/routes/core.ts`; there is no `/api` prefix on the server
- fix: probe `GET /status` or `/whoami` with `Authorization: Bearer $OPENWORK_TOKEN` — 200 with correct token, 401 without/wrong; `/health` is the unauthenticated healthcheck
- note: the `Host token: <uuid>` line in the startup logs and the CORS
  header `X-OpenWork-Host-Token` are a SEPARATE mechanism (host-token auth
  for `/tokens` etc.), ephemeral per run; with it `Authorization:
  Bearer <uuid>` gives 401 `Invalid bearer token`. For client HTTP
  authentication use only `Bearer $OPENWORK_TOKEN`


## P-036: sb build for openwork stack must run from app/, not stack root
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack (`stacks/self-hosting/ai-services/automation/openwork`) — `sb build`
- symptom: `sb build` from the stack root fails (no project found); cost one failed run
- cause: `stackbuilder.toml` lives in `app/`, not the stack root, for this stack
- fix: run `sb build` from the stack's `app/` directory always; check where `stackbuilder.toml` sits before assuming cwd


## P-037: openwork-server `POST /workspaces` → 404 — workspace creation is UI-driven
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork-stack smoke tests (openwork-server 0.18.4)
- symptom: `POST /workspaces` returns 404 (route not found) even with valid token
- cause: `GET /workspaces` (listing) exists, but workspace CREATION has no HTTP API route — it is done through the web UI, not the API
- fix: for key-free smoke, verify `GET /workspaces` returns 200 (listing); create data via the UI or rely on pre-seeded SQLite state, never attempt API-based workspace creation

## P-038: sb build does not restore .env for newly added environments
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — added environment `forwarding-review` to stackbuilder.toml
- symptom: after `sb build`, `build/<new-env>/` contains only docker-compose.yml + .env.example; no `.env` restored (existing envs got theirs)
- cause: sb preserves/restores `.env` only for environments that already had one before the build; a brand-new environment starts without one
- fix: copy the generated `build/<new-env>/.env.example` to `.env` manually and fill gate values (OPENWORK_TOKEN, REPO_SYNC_URL, etc.) before `docker compose up`

## P-039: openwork apps/server has zero OTel instrumentation at pin ae67215d
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — otel-lgtm extension gate (Tempo/Loki verification)
- symptom: after wiring OTEL_* env onto the `openwork` service, Tempo shows only service.name `opencode` traces (sql.execute, Npm.add, …); no spans for server HTTP requests; server stdout never reaches Loki
- cause: upstream `apps/server` @ ae67215d has no OpenTelemetry instrumentation at all (git grep: none); `DEN_OBSERVABILITY_BACKEND`/`OTEL_SERVICE_NAME` gating exists only in ee/ (den-api/den-web). The OTEL_* env is consumed by the in-process opencode runtime (OPENWORK_MANAGE_OPENCODE=1)
- fix: none possible at this pin — gate traces/logs via the opencode runtime's exports (service.name `opencode`); do not expect server request spans

## P-040: Tempo single-trace JSON needs `Accept: application/json`; spans nest under scopeSpans
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — otel-lgtm gate, Grafana API trace inspection
- symptom: `GET /api/datasources/proxy/uid/tempo/api/traces/<id>` without header returns protobuf/garbage; parsing `batches[].spans[]` finds nothing
- cause: Tempo defaults to a non-JSON representation without the Accept header; the JSON layout puts spans under `batches[].scopeSpans[].spans[]`, not `batches[].spans[]`
- fix: add `-H 'Accept: application/json'` and read spans at `batches[].scopeSpans[].spans[]`; Loki matcher must be non-empty-compatible, e.g. `{service_name="opencode"}`

## P-041: step-ca-trust wrapper requires a baked ENTRYPOINT in the wrapped image
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — TLS (step-ca) gate, openwork container restart-looping
- symptom: openwork container restart-loops with exit 0 and no error output once the step-ca-trust extension's wrapper entrypoint applies; works fine without the extension
- cause: the wrapper ends with `exec "$@"`, but a compose `entrypoint:` override replaces the image's default entrypoint on a CMD-only image — `$@` is empty, exec runs nothing, container exits 0 silently
- fix: image must bake its own `/entrypoint.sh` + `ENTRYPOINT` (openwork: `app/images/openwork-host/Dockerfile`); the wrapper then ends `exec /entrypoint.sh "$@"` and CMD still reaches the server. Rule for ANY future image wrapped by step-ca-trust: no CMD-only images
- commit (openwork): 9215a27

## P-042: TLS vhost `*.example.com` placeholders never get certs — use `*.af` for gates
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack; polaris stack (VIRTUAL_HOST=polaris.example.com in letsencrypt/step-ca .env.example)
- symptom: with `*.example.com` vhosts the companion never issues certificates; cert-wait hangs; nginx-proxy serves `ssl_reject_handshake on` for the vhost → `tlsv1 unrecognized name` on every TLS request
- cause: `*.example.com` does not resolve in this environment; the live step-ca-companion only issues certs for names it can see via the unbound redirect (unbound has `local-zone: "af." redirect → 192.168.99.1` only)
- fix: use `*.af` vhosts (e.g. `openwork.af`, `openwork-api.af`, `polaris.af`) — they resolve via the live unbound redirect and get certs in seconds; `*.example.com` placeholders stay only in `.env.example` docs. polaris fix committed in `53fbf5a`

## P-043: sb build fails with "yq is required but not available" on hosts without yq
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — first `sb build` in app/
- symptom: build aborts after "Configuration validation passed" with `Failed to initialize build executor: yq is required but not available`
- cause: sb's default YAML merger shells out to yq v4+, which is not installed on the host (and host package installs are forbidden)
- fix: set `yaml_merger = "rust"` under `[build]` in stackbuilder.toml (pattern already used by vibe-kanban stacks); sb then uses its built-in Rust merger

## P-044: gabehf/koito image has no curl/wget — healthcheck must use bash /dev/tcp
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — base compose healthcheck
- symptom: no curl, wget, nc, python, perl or busybox in the image (debian:bookworm-slim + libvips only); standard HTTP healthchecks impossible
- cause: upstream keeps the image minimal; bash 5.2 IS present and supports /dev/tcp pseudo-device connections
- fix: CMD-SHELL `bash -c 'exec 3<>/dev/tcp/127.0.0.1/${PORT}; printf "GET /path HTTP/1.0\r\n\r\n" >&3; head -1 <&3 | grep -q " 200"'` — NOTE the slash syntax `/dev/tcp/host/port`; the colon syntax `/dev/tcp/host:port` fails with "No such file or directory"

## P-045: Docker Hub tags for gabehf/koito are v-prefixed
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — DEPLOYMENT.md image pin vs Docker Hub reality
- symptom: `gabehf/koito:0` (as guessed in DEPLOYMENT.md) does not exist; pull fails
- cause: upstream publishes only v-prefixed tags (v0, v0.3, v0.3.2, latest)
- fix: pin `${IMAGE:-gabehf/koito:v0}`; verified via Docker Hub API + live pull + health smoke test; row appended to UPSTREAM.md

## P-046: browser E2E without agent-browser — dockerized headless Chromium + hand-written CDP driver
- hits: 1 | status: mitigated | first: 2026-11-05 | last: 2026-11-05
- where: stack testing (browser E2E gate) — koito stack Stage A
- symptom: agent-browser CLI not installed, `npm`/`npx` absent on the host
  (only bare `node`), no browser binaries; host package
  installs are forbidden — the browser gate is blocked entirely
- cause: the agent's browser infrastructure never reached this machine;
  installing anything on the host is forbidden (iron rules)
- workaround: docker is allowed → `docker run -d --rm --network host
  --shm-size=512m zenika/alpine-chrome:latest --no-sandbox --headless=new
  --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 about:blank`,
  driven via CDP by a custom dependency-free driver (Node 26 has
  built-in fetch + WebSocket): `/tmp/opencode/koito-e2e/cdp.mjs` —
  connect/eval/navigate/shot + `Input.dispatchMouseEvent`/`dispatchKeyEvent`
- fix: —
- note: a React SPA ignores JS-issued `.click()` on tabs/buttons — click
  with real CDP mouse events at the center of the element's rect and type
  via `Input.dispatchKeyEvent`; the full token from the UI can be obtained
  via the same authorized fetch from the page context (the cookie session
  is picked up automatically)

## P-047: agent-browser needs `--args "--no-sandbox"` + local bun install (pnpm global bin not in PATH)
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Stage A browser E2E gate (also applies to any stack gate on this host)
- symptom: `agent-browser open` fails with "Chrome exited early … No usable sandbox!"; `npx` absent on host; `pnpm add -g` installs to `~/.local/share/pnpm/bin` which is not in PATH (and `pnpm bin -g` itself errors ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH)
- cause: AppArmor-disabled unprivileged user namespaces on this host kill Chrome's sandbox; host has bare `node`/`bun`/`pnpm` only
- fix: install locally in the scratch dir — `cd /tmp/opencode && bun add agent-browser` → run as `./node_modules/.bin/agent-browser --session <name> --args "--no-sandbox" <cmd>`; the `--args` flag must come before the subcommand. Complements P-046 (dockerized-Chromium fallback, no longer needed)
- note (2026-11-05, navidrome gate): after `open`, the session can sit at `about:blank` with an empty DOM (snapshot/eval return nothing) even though `open` printed the target URL — a plain re-`open <url>` in the same session restores the page; also never abbreviate the CLI into a single `$AB` string variable, zsh then treats the whole string as one command path

## P-048: tome API auth quirks — OPDS basic auth uses username, KOSync lives at /api/v1 with plaintext userkey, TomeSync needs a *plugin* key (not an api-token)
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Stage A gate — OPDS/KOSync/TomeSync endpoint probes
- symptom: OPDS basic auth with email → 401; KOSync probes at `/v1/*` return the SPA HTML (catch-all); KOSync auth with MD5 of the password → 401; `PUT /api/v1/syncs/progress` without `percentage` → 400; Bearer token from `POST /api/tokens/` on `/api/tome-sync/*` → 401 "Invalid API key"
- cause: `get_current_user_basic` matches `User.username` (email not accepted); kosync router prefix `/v1` mounted under `/api` → `/api/v1/`, and `_get_kosync_user` compares the userkey **as stored** (plaintext, whatever `POST /users/create` received — no MD5); progress PUT requires `document`+`progress`+`percentage`+`device`; TomeSync `_get_api_key_user` queries the `api_keys` table (plugin keys via `POST /api/plugin/api-keys`), while `/api/tokens/` writes the separate `api_tokens` table
- fix: OPDS: `-u 'Gate Librarian:GatePass123!'`; KOSync: headers `X-Auth-User`/`X-Auth-Key` with the plaintext key, routes under `/api/v1/`; progress PUT body `{"document","progress","percentage","device"}`; TomeSync: create key via `POST /api/plugin/api-keys` (JWT from `/api/auth/login`), send as `Authorization: Bearer tk_…`

## P-049: kanidm CLI 1.11.2 cookbook deviations — subcommand names differ from older docs
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-06
- where: kanidm-admin subagent, OAuth2 client provisioning for the tome stack; bookorbit Stage B provisioning
- symptom: `system oauth2 add-redirect-urls` / `create-scope-map` / top-level `whoami` not found or not behaving as older kanidm cooking notes describe
- cause: kanidm 1.11.2 renamed/singularized several oauth2 subcommands
- fix: use `system oauth2 add-redirect-url` (singular); scope maps are managed with `system oauth2 update-scope-map` (alias of create-scope-map); identity check is `self whoami` (no top-level `whoami`). PKCE is enabled by default on new clients; `groups` claim emerges natively from the `groups` scope in 1.11 — no custom claim-map needed. Further 1.11.2 quirks (bookorbit session): client secret retrieval is `system oauth2 show-basic-secret` (`get-basic-secret` does NOT exist); `$HOME/.config/kanidm` is a FILE (config path), not a directory — mounting an empty dir there breaks the CLI; `person update --password` is invalid — set passwords via `person credential <id> set-password` (interactive commit prompts `[y/n]`, drive with a pty script); `person credential status` on an account with NO credentials errors `EmptyResponse` (not a fault).

## P-050: `archive/tar: write too long` on compose config copy — empty `VIRTUAL_HOST` produces empty config target filename
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack, step-ca build layer `docker compose up` (vhost config registration)
- symptom: `docker compose up` fails with `archive/tar: write too long` before any container starts
- cause: compose `configs` target `/vhost.d/${VIRTUAL_HOST}` with `VIRTUAL_HOST` unset in the build `.env` → empty destination filename, tar writer chokes
- fix: fill the step-ca env vars (`VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`, `TOME_PUBLIC_URL`) in `build/<env>/*/.env` before `up`; stack then starts cleanly

## P-051: Tome OIDC redirect URL is `/api/auth/oidc/callback`, NOT `/auth/callback`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack oidc extension + Kanidm OAuth2 client `tome`
- symptom: SSO callback would 404/fail redirect validation even though OIDC config endpoint reports enabled
- cause: `/auth/callback` is the frontend post-login route (`TOME_OIDC_POST_LOGIN_REDIRECT` default), easily confused with the OIDC redirect; upstream docs (sso.md) require the callback to EXACTLY match `https://<host>/api/auth/oidc/callback`
- fix: register `https://tome.af/api/auth/oidc/callback` in Kanidm (`system oauth2 add-redirect-url`, strict-redirect enabled) and default `TOME_OIDC_REDIRECT_URL` to it in the extension fragment; removed the wrong `/auth/callback` entry

## P-052: kanidmd container has no shell and no kanidm CLI — run `kanidm/tools` sidecar instead of `docker exec`
- hits: 2 | status: fixed | first: 2026-11-05 | last: 2026-11-07
- where: any Kanidm admin operation on the live step-ca-manager instance
- symptom: `docker exec kanidmd sh` / `kanidm` / `ls` all fail (`exec: "sh": executable file not found`); kanidm CLI absent from the server image
- cause: kanidmd image is a minimal single-binary container (entrypoint `/sbin/kanidmd server`)
- fix: `docker run --rm --network host --user 0:0 -e HOME=/tmp/kanidmcfg -v <scratch>:/tmp/kanidmcfg -v <scratch>/root_ca.crt:/etc/ssl/certs/ca-certificates.crt:ro kanidm/tools:1.11.2 kanidm ...` — token cache persists in the scratch mount; root CA bind-mount is required (kanidm.af uses step-ca internal TLS, else `InvalidCertificate(UnknownIssuer)`). Non-interactive login: `-e KANIDM_PASSWORD=<pw>` (no TTY). Cookbook now documents this (`kc` function)

## P-053: `sb build` wipes build-layer `.env` files on every run
- hits: 6 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack `app/` `sb build` (all environments)
- symptom: after `sb build`, each `build/<env>/<layer>/.env` is truncated to a 23-line skeleton (secrets like `TOME_OIDC_CLIENT_SECRET`, passphrases gone); output shows "⚠ Skipped .env file (content conflict)" x4, "Creating backup for 6 files that couldn't be restored", "Restoration completed: 0 restored successfully"
- cause: sb regenerates build `.env` from component `.env` + fragment `.env.example` and refuses to auto-restore when content conflicts; its own backup lands in `app/.stackbuilder/backup/backup_<ts>/` as `<env>_<layer>_.env`
- fix (workaround): restore from the timestamped `.stackbuilder/backup/` dir (or a pre-build copy) after every `sb build`; keep a pre-build copy in `/tmp/opencode` as second source. Unresolved upstream behavior — always verify line counts + secret keys before `docker compose up`. Note (hit#3): sb does auto-backup/auto-restore, but the tracked set covers only the 6 layer files present at backup time; newly added per-extension build dirs (koreader-tomesync, send-to-device-smtp, outbound-notify, auto-import) get fresh skeleton `.env` — that is expected, only the 6 tracked layer files need restoring. Note (2026-11-06, vaultisse pgrust build): sb auto-restored all 3 variant `.env`s with secrets intact — no hit, restore path works when no content conflict.

## P-054: multi `-f` compose up loads only the first layer's `.env`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: staged stack bring-ups with layered compose (`kill-switches` + `base` + extensions), e.g. tome oidc stage
- symptom: vars declared in an extension layer with `?err` enforcement fail or interpolate to defaults even though the extension's own `.env` defines them
- cause: `--env-file` defaults to `./.env` relative to the FIRST compose file; later `-f` files' sibling `.env` files are not picked up when the first layer has none
- fix: always pass `--env-file <final-layer-dir>/.env` explicitly on every `up`/`down` when layering multi `-f` compose files from different directories

## P-055: container-level CA trust: compose `volume.subpath` mounts for apps that use the system trust store
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack OIDC stage (upstream image, httpx 0.28 → system CA store; no bind-mount policy allows cert files)
- symptom: TLS calls to kanidm.af fail with `InvalidCertificate(UnknownIssuer)` even though step-ca signed the cert
- cause: upstream image wheels trust the *system* store (no pip cert-file switch), and the app container has no path to the step-ca root CA; host curl is also broken (P-018) so verification must be dockerized
- fix: untracked test-only overlay (4th `-f`) mounting the external volume at `volume.subpath: certs` → files land at the target root (`/stepca/root_ca.crt` without a `certs/` dir), plus `SSL_CERT_FILE: /stepca/root_ca.crt`; works on compose 5.6.1 + engine 29.9.2. Verify network-wise with `alpine/curl` attached to `step-ca-network` using `--cacert /step/certs/root_ca.crt`. NOTE: overlay is test-only and must NOT be committed with the stack.

## P-056: Kanidm plain `groups` claim emits UUID + SPN (no short names) — apps doing exact-match group checks break
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: tome OIDC stage E2E (`s.oidc_allowed_group not in groups` gate in `backend/services/oidc.py`)
- symptom: SSO completes, code exchanged, callback 302 → but UI shows "not permitted to sign in"; audit `auth.oidc_denied` details `{"reason": "not in allowed group"}` although the user IS a member of the mapped group
- cause: Kanidm's `groups` scope emits each group's UUID **and** SPN values only (`name@domain`), never the short name (v1.11.2 `oauth2.rs`: `groups implies uuid + spn`); Tome compares exact strings against short names like `tome_users`
- fix: committed in tome `fae2ad5` — group env defaults in all 4 compose fragments (component + 3 build) now use nested SPN fallback `${NAME:-tome_users@${TOME_OIDC_KANIDM_DOMAIN:-kanidm.af}}` (new var `TOME_OIDC_KANIDM_DOMAIN`, default `kanidm.af`); `.env.example` carries SPN values + the new var. Nested `${A:-b@${B:-dom}}` resolves correctly to the SPN default and stays env-overridable (verify: `/tmp/opencode/nesttest/docker-compose.yml` + layered `docker compose ... config` showing `tome_admins@kanidm.af`). CAUTION: `${VAR:-...}` per-file fallbacks still cannot override a var already set by `--env-file X.env` (substitution happens per-file before merge) — that only affects override-in-overlay flows, not the default. Kanidm-side alternative (if ever allowed): the `groups_name` scope emits short names.



## polaris config user lacks admin rights (admin endpoints reject)

- hits: 1
- status: fixed
- last: 2026-11-05
- where: polaris stack Stage A gate (stacks/self-hosting/media-streaming/music/polaris)
- symptom: `POST /api/auth` succeeds for the TOML `[[users]]` entry but returns `is_admin: false`; `/api/initial_setup` reports `has_any_users: false`; every admin endpoint (`/api/index_status`, `/api/trigger_index`, `/api/users`, `/api/mount_dirs`) replies "Administrator permission is required"
- cause: polaris 0.16.1 `User::is_admin()` only matches `admin == Some(true)` (src/app/config/user.rs:15-17) — the TOML user entry needs an explicit `admin = true`; `/api/initial_setup` actually reports `has_any_admin` (src/server/axum/api.rs:112). Also `[[mount_dirs]]` field is `source`, not `path` (0.16.1 schema).
- fix: committed in polaris `4ae4cf9` — `admin = true` added to the `[[users]]` entry and `source = "/music"` in base + all 3 build `polaris.toml.example` copies; redeploy with `docker compose up -d --build` (config is baked via `dockerfile_inline` COPY — without `--build` a cached image with stale config is reused). Gate then passed fully (login is_admin:true → index UpToDate 3 songs → album detail → thumbnail 200 JPEG → audio 200 → uid 1000 → down -v reseed OK).

## P-057: dockerfile_inline `FROM ${IMAGE}` self-reference stacks COPY layers on every rebuild
- hits: 1
- status: mitigated
- first: 2026-11-05
- last: 2026-11-05
- where: polaris Stage A (dockerfile_inline config bake pattern, `stacks/self-hosting/media-streaming/music/polaris`)
- symptom: image history shows an ever-growing stack of `COPY --chown=... polaris.toml.example /config/polaris.toml` layers (one per `docker compose up -d --build`, ~1 per rebuild seen at 11:02–11:06 timestamps); made a transient rebuild loop look like an external watcher — alarmed diagnosis ("cyclic recreate", suspect docker-gen) while the real loop was a crash-restart of a container with a corrupted config
- cause: `dockerfile_inline: "FROM ${IMAGE:-localhost/polaris:0.16.1}\nCOPY ..."` builds a child of the image's own tag and retags it with the same tag → each rebuild adds one config layer; combined with a stale/corrupt bake (duplicate `admin = true` from a mid-edit build, caught only by container restart log "TOML parse error ... duplicate key"), the repeated rebuild+recreate looks like an endless cycle. No external process was involved (ps shows no compose/watcher).
- fix: treat as expected consequence, not a bug: `docker compose up -d --build` is required for config changes (P-023) and layers accumulate — diagnose "recreate loop" by (a) checking container logs for crash errors first, (b) comparing image-copy timestamps with own `up --build` invocations. Reset accumulation by rebuilding the base image via its Dockerfile when the layer pile-up matters. Copy the config's exit-code transcript from `docker logs`, not the last-healthy state.

## P-058: dockerfile_inline `RUN apt-get` fails on non-root base images — add `USER root` first
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: polaris s3fs-fuse extension (`app/components/extensions/s3fs-fuse/docker-compose.yml`, both dockerfile_inline blocks)
- symptom: `docker compose up --build` fails in the dockerfile_inline build with apt-get permission errors (base image `localhost/polaris:0.16.1` runs as uid 1000, so `apt-get update && apt-get install` cannot write)
- cause: dockerfile_inline inherits the base image's USER; apt needs root
- fix: add `USER root` as the first instruction after `FROM ${IMAGE:-...}` in every dockerfile_inline that runs apt-get (or any root-only command); committed in polaris `53fbf5a`

## P-059: curl 8.23 (alpine/curl, curlimages/curl) rejects `--cacert` — use `SSL_CERT_FILE` as root
- hits: 1
- status: open
- first: 2026-11-05
- last: 2026-11-05
- where: gate testing against step-ca TLS vhosts from throwaway curl containers (polaris gate, any `*.af` vhost)
- symptom: `curl --cacert /step/certs/root_ca.crt` fails with "option --cacert: is badly used here" in alpine/curl:latest and curlimages/curl (curl 8.23)
- cause: newer curl builds restrict --cacert usage context; also the step-ca root CA inside volume `step-ca-data` sits at `/home/step/certs/root_ca.crt` mode 600 uid 1000 — unreadable by the image's non-root curl_user
- fix: run the container as root with the volume mounted and `export SSL_CERT_FILE=<ca-path>`; e.g. `docker run --rm -v step-ca-data:/step:ro --network step-ca-network --entrypoint sh alpine/curl:latest -c 'export SSL_CERT_FILE=/step/certs/root_ca.crt; curl --resolve <vhost>:443:<proxy-ip> https://<vhost>/...'`. Note: `/step/certs/root_ca.crt` works because the volume's `certs` subpath content is exposed at the mount root — verify the actual path with `ls` if a mount uses `subpath`

## P-060: sb rust YAML merger silently drops env keys whose plain scalar contains ": " — double-quote `${VAR:?msg}` values
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord access-key extension fragment (`app/components/extensions/access-key/docker-compose.yml`); any extension using the `${VAR:?message with colons}` fail-fast idiom
- symptom: after `sb build`, the merged `build/<env>/<ext>/docker-compose.yml` was byte-identical to the base variant — the `REKORD_ACCESS_KEY` environment key vanished without any warning; the extension silently did nothing
- cause: the rust YAML merger mis-parses a plain (unquoted) scalar containing ": " (the required-var message "…is required: 32-256 chars…" has one); the whole environment key drops out of the merged map
- fix: double-quote the value — `REKORD_ACCESS_KEY: "${REKORD_ACCESS_KEY:?REKORD_ACCESS_KEY is required: …}"`; compose interpolation works inside quotes and the key survives the merge (verified in all 3 envs). Rule: quote any `${VAR:?…}` value whose message contains ": "

## P-061: layered compose resolves relative build contexts against the FIRST -f file's dir — pass `--project-directory .`
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord s3fs-fuse extension gate (layered `up` from `app/build/forwarding/` with per-extension fragment subdirs); any stack whose extension fragments use a relative `build.context:`
- symptom: layered `docker compose -f base/... -f <ext>/... up --build` fails with `unable to prepare context: path ".../base/s3fs-fuse" not found` even though the context dir exists next to the extension fragment
- cause: compose resolves relative `build.context` paths against the directory of the FIRST `-f` file (here `base/`), not the cwd and not the fragment that declares the build
- fix: add `--project-directory .` to the layered command (run from the build-env root) so `context: s3fs-fuse` resolves to `build/<env>/s3fs-fuse/`; stackbuilder already copies the entrypoint script into that subdir. Documented in the re-kord s3fs-fuse fragment comment

## P-062: minio `mc` silently treats an unknown alias as a LOCAL filesystem path
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord s3fs-fuse gate (verifying bucket contents on the live RustFS); any session using `mc` without a configured alias
- symptom: `mc ls rek/re-kord-music/...` and even `mc ls rek/definitely-not-a-bucket-xyz` exit 0 with S3-style output; `mc cp ... rek/<bucket>/<key>` "succeeds" but the object never reaches the S3 server
- cause: `rek` is not an alias or hostname (no DNS entry, nothing listens there) — mc falls back to treating `rek/...` as a path relative to cwd and lists/copies the LOCAL filesystem, printing it in the same S3-listing format, so the mistake is invisible in the output
- fix: always verify bucket backends with an explicit temp alias: `MC_CONFIG_DIR=/tmp/opencode/<dir> mc alias set tmp http://<container-ip>:9000 <ak> <sk>`, then `mc ls tmp/<bucket>/`. Rule: never use a bare word prefix in mc paths unless `mc alias list` shows it

## P-063: `sb build` requires mikefarah yq v4 on PATH — the system `/usr/bin/yq` is a jq-wrapper and breaks the build
- hits: 3
- status: fixed
- first: 2026-11-05
- last: 2026-11-06
- where: navidrome stack builds (`sb build` in any stack's `app/`); every session running stackbuilder
- symptom: `sb build` fails or misbehaves because it shells out to `yq` and picks up `/usr/bin/yq`, which is the jq-compatible wrapper (different CLI), not mikefarah yq v4
- cause: stackbuilder expects the mikefarah yq v4 CLI (its filter syntax), but the distro `yq` on PATH is a different tool with the same name
- fix: keep a real mikefarah yq binary in scratch (e.g. `/tmp/opencode/bin/yq`, v4.54.1) and run `PATH=/tmp/opencode/bin:$PATH sb build` so it resolves first

## P-064: sb-generated `.env` has NO trailing newline — appended vars merge into the last line
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-06
- where: navidrome s3fs-fuse-music gate (appending secret creds from a scratch file onto the sb-generated `build/<env>/<combo>/.env`); any workflow that appends to a stackbuilder-generated `.env`
- symptom: after `cat creds.env >> .env`, the first appended var became part of the last generated line (`RUSTFS_SECRET_KEY=RUSTFS_ACCESS_KEY=...`), so compose saw an empty `RUSTFS_ACCESS_KEY` and the entrypoint aborted with "RUSTFS_ACCESS_KEY is required" in a restart loop
- cause: stackbuilder writes the concatenated `.env.example` content without a final newline; `>>` concatenation then glues the next file's first line onto it
- fix: append a newline before the extra file: `cp fragment/.env.example .env && printf '\n' >> .env && cat creds.env >> .env`. Rule: never append to an sb-generated `.env` without ensuring a trailing newline first

## P-077: apps calling OIDC discovery on a private-IP issuer throw `PrivateAddressException` unless local issuers allowed
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: bookorbit Stage B OIDC (any app with SSRF protection on issuer/token endpoints, e.g. openid-client `allowedDomain`-style guards)
- symptom: SSO login button fails with "Failed to generate state"; app logs show `PrivateAddressException` when fetching `https://kanidm.af/oauth2/openid/<client>/.well-known/openid-configuration` (kanidm.af resolves to a private IP)
- cause: the app's OIDC library blocks HTTP(S) calls to private/loopback addresses by default (SSRF guard); the collection's kanidm host is on a private network
- fix: set `OIDC_ALLOW_LOCAL_ISSUERS=true` in the build `.env` (bookorbit oidc extension fragment defaults it to false); required for any collection OIDC provider on a private IP

## P-078: bookorbit OIDC auto-provisioning is OFF by default — first SSO login fails with "Your account has not been set up"
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: bookorbit Stage B (any app where SSO users are provisioned JIT)
- symptom: full OIDC round-trip succeeds (code callback reached) but the app rejects the login with "Your account has not been set up"
- cause: provider edit form's "Auto-provision users" switch ("Create accounts on first OIDC login if user does not exist") defaults to unchecked
- fix: enable the switch in the provider edit form (Settings → SERVER → Users & Access → OIDC / SSO → provider entry → AUTO-PROVISIONING section) and "Save Changes"; then SSO login auto-creates the account
- last: 2026-11-05
- where: navidrome extauth-proxy gate
- symptom: `sb build` de-staged/wiped the run-dir `.env` (EXTAUTH_USER empty → proxy ran in plain-proxy mode, gate failed with no auth payload)
- cause: sb build regenerates `build/<env>/<combo>/.env` from `.env.example` files; a hand-created run-dir `.env` is not preserved
- fix: after EVERY `sb build`, re-create the run-dir `.env` before a gate run: `printf 'EXTAUTH_USER=gateuser\nND_LOGLEVEL=trace\n' > .env && chmod 600 .env`. Note the `grep -q X .env || printf` idiom fails when `.env` does not exist — check existence first or just recreate wholesale

## P-065: nested viper config keys map to env names with dot→underscore — `ND_EXTAUTH_USERHEADER`, not `ND_EXTAUTHUSERHEADER`
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome extauth-proxy gate (ExtAuth.TrustedSources / UserHeader / LogoutURL); any app using viper with `SetEnvPrefix` + `SetEnvKeyReplacer(strings.NewReplacer(".", "_"))` + `AutomaticEnv`
- symptom: fragment set `ND_EXTAUTHTRUSTEDSOURCES=...` etc.; navidrome ignored all three (ExtAuth stayed disabled) while the same names looked plausible next to flat keys like `ND_LOGLEVEL`
- cause: viper env keys are the nested config path with `.` replaced by `_` — `extauth.trustedsources` → `ND_EXTAUTH_TRUSTEDSOURCES`. The concatenated form is simply a different (unknown) key
- fix: derive env names from the nested key path, not from concatenation: `extauth.userheader` → `ND_EXTAUTH_USERHEADER`. Rule: for viper apps, env name = prefix + nested path with dots→underscores; verify against the app's config source, not `strings` on the binary (env names are not string literals)

## P-066: Alpine healthcheck `wget http://localhost/...` fails — localhost resolves to ::1, service listens IPv4-only
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome extauth-proxy healthcheck (nginx:alpine); any Alpine-based container healthcheck hitting a service bound to 0.0.0.0
- symptom: container `Up (unhealthy)` with `wget: can't connect to remote host: Connection refused`, while `wget http://127.0.0.1/...` inside the container works
- cause: musl resolves `localhost` to ::1 first; nginx `listen 80` binds IPv4-only, so the ::1 attempt is refused
- fix: use `127.0.0.1` explicitly in healthcheck URLs (`http://127.0.0.1:80/healthz`)

## P-067: check-stack.sh gitkeep/yaml_merger checks are stale — check-gitkeep.sh + tome exemplar are canon
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: omnibus stack creation (any new stack validated with the repo's check scripts)
- symptom: `check-stack.sh` flags missing `.gitkeep` in dirs that DO have one per the refined rule, and/or demands `yaml_merger = "rust"` in stackbuilder.toml, contradicting what existing verified stacks (tome exemplar) actually contain
- cause: check-stack.sh predates the refined `.gitkeep` rule (`.gitkeep` ONLY in exactly-one-subdir dirs) and the yaml_merger default change; it was not updated
- fix: treat `check-gitkeep.sh` + the tome exemplar as canon for gitkeep placement and yaml_merger; ignore stale check-stack.sh findings on those two topics (no fix to the script yet — needs user decision)

## P-068: images without baked-in volume dirs leave fresh named-volume mountpoints root-owned — add an init-chown service
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: omnibus stack gate (any image whose entrypoint chowns only some volumes, e.g. linuxserver.io-style PUID/PGID images)
- symptom: app runs fine but writes to a volume fail with permission errors (omnibus: upload → 400 "ebook library is not writable"); `ls -ld` inside the container shows the mountpoint owned by `root:root` while sibling volumes are correctly owned
- cause: Docker creates a named-volume mountpoint with the image's directory if it exists, else as root. The omnibus image has no `/books`//`/audiobooks` dirs and its entrypoint deliberately chowns only `/config` + `/cache` — library roots are left root-owned
- fix: one-shot init service in base compose: same image, `user: "0:0"`, `entrypoint: sh -c "chown ${PUID:-1000}:${PGID:-1000} <volumes>"`, `restart: "no"`; main service gets `depends_on: <init>: condition: service_completed_successfully`. Verify with `docker exec <svc> ls -ld <volumes>` after `up`

## P-069: debian-slim /bin/sh (dash) has no /dev/tcp — compose healthchecks must use curl
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp stack (any CMD-SHELL healthcheck on debian-slim images)
- symptom: healthcheck `exec 3<>/dev/tcp/127.0.0.1/7331` never succeeds; container stuck unhealthy while the app is fine
- cause: /dev/tcp is a bashism; debian-slim ships dash as /bin/sh, which does not support it
- fix: use curl in the healthcheck (`curl -s -o /dev/null -m 4 http://127.0.0.1:7331/healthz`); keep image HEALTHCHECK and compose healthcheck identical

## P-070: credential stores that join dir + `<key>.json` — token file lives flat in the data dir, not a credentials/ subdir
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp stack entrypoint seeding (upstream `credentials.zig pathOf` joins store dir + `<key>.json`; store dir = `<base>/userdata` per `state.zig`)
- symptom: token seeded into `userdata/credentials/inbound-token.json` (0600, correct content) but gateway still answers 401 with a valid bearer
- cause: the credential store's directory IS the userdata dir; `pathOf` produces `<userdata>/inbound-token.json` — the `credentials/` subdir guess was wrong
- fix: seed at the flat path `<userdata>/inbound-token.json` (0600); when a 401-with-bearer persists, read the upstream's pathOf/state code to find the real store dir before guessing paths

## P-071: compose `${VAR:-default}` treats an EMPTY shell override as unset — empty-value gate runs need an override file
- hits: 2 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp Stage A gate (a) (any scenario that must run with a var explicitly EMPTY while the merged compose gives it a non-empty default)
- symptom: `NANOMCP_SEED_STUB_URL= docker compose up` still seeded the stub — the container got the `.env`/default URL and healthz showed `tools: 1` instead of the required `tools: 0`
- cause: `:-` (and `-`) substitution treats empty as unset, so an empty shell var loses to the compose default AND to `.env`; compose has no way to express "empty wins" inline
- fix: a compose override file that sets the key to an empty string in `environment:` (`docker compose -f docker-compose.yml -f override.yml up -d`, override: `NANOMCP_SEED_STUB_URL: ""`), plus `compose stop` for services the scenario excludes; verify with `docker exec <svc> env`

## P-072: `compose up` after `down -v` can fail with a stale container_name conflict — benign, verify with `docker ps`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp gate runs (any stack re-running `up` right after `down -v` with fixed `container_name`s)
- symptom: `up -d` reports "container name ... already in use" even though `down -v` reported removal
- cause: removal/creation race in the compose project with fixed `container_name` (same root as P-013's conflict noise)
- fix: retry `up -d` after a few seconds and confirm with `docker ps --filter name=<stack>`; the second attempt succeeds — no host-level cleanup needed

## P-035: check-stack.sh and check-gitkeep.sh contradict each other about .gitkeep
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: stack-test step 0 / stack-conventions scripts (nanomcp stack)
- symptom: check-stack.sh demands a .gitkeep in ANY directory without files
  (app/components with 3 subdirs — VIOLATION "missing"), while
  check-gitkeep.sh demands DELETING the .gitkeep where there is more than
  one subdir ("not exactly one subdir"). Both scripts are invoked by
  stack-test with the requirement "must print nothing" — satisfying both
  is impossible for a single directory
- workaround: check-stack.sh satisfied (the main gate, consistent with the
  .gitkeep rule in AGENTS.md); the discrepancy with check-gitkeep.sh recorded
- fix: —

## P-073: nanomcp stdio extension gate gotchas — seeded entries persist in the named volume; tool names sanitize `-` to `_`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp mcp-gateway-stdio gate (any scenario flipping a seeding flag off/on between runs)
- symptom: (a) after running with `NANOMCP_STDIO_HELPER=1`, a later run with the flag empty still shows the stdio-helper entry and `tools: 2` — the servers.json seed lives in the `nanomcp-userdata` named volume, so flag removal alone is not inertness; (b) calling the helper tool as `stdio-helper__echo` returns "unknown tool" — the gateway namespaces tools under the server ALIAS with `-` sanitized to `_`, so the real name is `stdio_helper__echo`
- cause: (a) seeding is create-or-upsert into persistent state, never a delete; (b) alias-to-tool-name sanitization in the gateway's tool naming
- fix: (a) inertness re-tests need `docker compose down -v` (fresh volume) plus a compose override file setting the flag to `""` (P-071 pattern); (b) use the sanitized name `stdio_helper__echo` in tools/call — documented in DEPLOYMENT.md

## P-074: optional string env vars passed as empty strings crash apps with zod validation
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: bookorbit Stage A gate (any app whose env schema uses `z.string().trim().min(N).optional()`)
- symptom: app crash-loops on start; logs show zod validation error for an env var the operator never set
- cause: compose renders `${VAR:-}` defaults for optional keys, so the container receives `VAR=""` — an empty string is NOT undefined for zod, `.trim().min(16)` fails on `""`
- fix: drop the optional key from compose `environment:` entirely (bookorbit `PODCAST_ENCRYPTION_KEY`, commit 16cb9b7); rule: compose must not render empty defaults for optional env keys. Schema inspectable via `docker run --rm --entrypoint node <image> -e "..."` reading the app's env.validation module

## P-075: upstream GHCR image tags may omit the `v` prefix even when repo tags have it
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: bookorbit image tag selection (any stack picking a `ghcr.io/<org>/<app>` tag from upstream release info)
- symptom: compose pulls a non-existent `:v3.6.0` tag → ImagePullBackOff crash loop
- cause: upstream release.yml publishes `${VERSION}` (repo tags are `v${VERSION}`), so GHCR tags have NO `v` prefix (`3.6.0`, `latest`, `main`, `sha-*`, `pr-*`); GHCR may also hold only old versions (1.0.0–1.3.0) while repo is at 3.6.0
- fix: verify actual GHCR tag list before pinning (`docker manifest inspect` / GHCR page); record provenance in UPSTREAM.md; bookorbit fixed to `ghcr.io/bookorbit/bookorbit:3.6.0` (commit a514fd2)

## P-076: host port 3000 already allocated during stack-test scratch runs
- hits: 2 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: bookorbit Stage A2 pgrust swap (any stack-test `docker compose up` in a scratch dir while another stack or a previous run holds the port)
- symptom: `docker compose up -d` fails with "Bind for 0.0.0.0:3000 failed: port is already allocated" even though the compose project itself is fresh
- cause: the host port is shared across all stacks/scratch runs; the default `BOOKORBIT_PORT=3000` collides with whatever already listens on 3000
- fix: none yet — workaround: override the port var in the scratch `.env` (e.g. `BOOKORBIT_PORT=13000`) before `up`; stack-test scratch runs should always pick a non-default host port (hit again 2026-11-06 at tts-kokoro extension stage: `omnibus` container holds 3000, scratch used 3100)

## P-077: 502 from the shared step-ca-proxy during a backend container's restart-uptime window is transient
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: booklore step-ca variant gate (any stack behind the live step-ca-proxy whose backend container restarts)
- symptom: browser gets 502 when opening the stack URL right after `docker restart` / `up -d` while the backend is still `health: starting`
- cause: step-ca-proxy routes to the backend origin before the container is listening; the route itself is fine
- fix: none needed — wait for container `healthy` then reload the page; do not debug the proxy

## P-078: containers behind step-ca-proxy can spontaneously bounce and lose the external step-ca-network attachment
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: booklore step-ca variant gate (any stack whose app joins an external network like step-ca-network)
- symptom: mid-session, app + db + step-ca-proxy all restart (~12:04-12:06); app comes back attached ONLY to its own `<stack>-network` (external step-ca-network missing) → nginx "tlsv1 unrecognized name" for the vhost, curl exit 35/000, browser shows black/empty SPA pages with 504s on all API calls
- cause: unknown trigger (possibly docker daemon / dockergen event storm); on restart the container's network set is rebuilt from the running project and the external network attachment is dropped
- fix: re-run `docker compose -f build/<variant>/docker-compose.yml --env-file .env up -d` from the variant dir — compose re-attaches the external network without recreating volumes; then wait for `healthy` and re-verify cert + HTTP 200. Do NOT debug nginx or the app first — check `docker inspect <app> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'` for the missing external network

## P-079: `docker compose -p <name> down` removes OTHER deployments sharing the same compose project label
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: booklore s3fs-fuse gate (any live gate deployment torn down while a second compose dir uses the identical `COMPOSE_PROJECT_NAME`/`-p`)
- symptom: after running `down` from the OLD backup compose dir (same `-p booklore`), the currently-running gate variant's containers vanish entirely (`docker ps -a` shows no booklore containers at all, minutes after passing health checks) — appears as an unexplained disappearance
- cause: compose project membership is the `com.docker.compose.project=<name>` label, NOT the compose file — `down` with a matching project name removes every container carrying that label, regardless of which compose file/dir invoked it
- fix: before any `down`, confirm no live deployment shares the project: match on container names AND check `docker ps` for other projects; tear down with the exact dir/compose that started it. If containers vanish, simply re-`up -d` from the variant dir (volumes survive)

## P-080: an s3fs write right after mount can fail transiently ("nonexistent directory")
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: booklore s3fs-fuse gate (any container exec'ing writes seconds after `docker compose up` brings the s3fs mount up)
- symptom: first `echo > /bookdrop/<file>` in a just-started container errors with a "generic failure"/"nonexistent directory"-type error, then an identical write seconds later succeeds
- cause: the s3fs FUSE mount is registered in /proc/mounts before the backend handshake/startup finishes; early writes race the mount becoming fully ready
- fix: none needed — retry the write after a few seconds; never conclude the mount is broken from one post-start write failure

## P-081: on this host, `127.0.0.1:9000` is a DIFFERENT HTTPS service — RustFS is only reachable via its container IP
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: booklore s3fs-fuse gate (any mc/rustfs verification from the host)
- symptom: `mc alias set ... http://127.0.0.1:9000` or `http://localhost:9000` fails with "Client sent an HTTP request to an HTTPS server" (or an ISO-8859/decode error in some paths) even though RustFS itself is fine
- cause: something else on the host already listens on 127.0.0.1:9000 with TLS; the live rustfs container publishes no host port and sits on the step-ca-network, so the only working endpoint from the host is its container IP
- fix: use the container IP: `MC_HOST_<alias>="http://<user>:<secret>@172.20.0.3:9000"` (get the IP via `docker inspect rustfs --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`); combine with P-062's rule — never trust a bare-word mc path

## P-082: BookLore (ghcr.io/booklore-app/booklore:latest, Spring 7) resolves remote-auth header names case-sensitively — they must be ALL-LOWERCASE
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: booklore remote-auth gate (any stack using remauth/forward-auth header injection into BookLore)
- symptom: `/api/v1/auth/remote` returns 400 "Remote-User header is missing" even though the proxy injects the header correctly; direct curl with `-H 'Remote-User: x'` (mixed case) fails, `-H 'remote-user: x'` succeeds
- cause: the running image (newer Spring Framework 7 / Java 25 than the pinned upstream commit) does a case-sensitive `.toLowerCase` map lookup against the config value — header names like `Remote-User`/`REMOTE-USER` never match; only `remote-user` resolves
- fix: set all four header names lowercase in every artifact (component fragment defaults, `.env.example`s, generated build `.env`s): `remote-user`, `remote-name`, `remote-email`, `remote-groups`. Regen builds with `sb build` after the fix and re-probe through the proxy before concluding anything else is broken

## P-083: persisted named volume keeps OLD credentials; a fresh gate `.env` generates NEW ones → DB auth failure at repeated gates
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: booklore remote-auth gate (any stack gate re-run where the DB service container is recreated but a named DB volume persists across combos)
- symptom: after re-generating the build and recreating the compose project, the app fails to reach its DB (auth/connection errors) though the DB container is healthy
- cause: MariaDB credentials live inside the persisted volume's mysql.user table, not env; regenerating `.env` produced a new random `DATABASE_PASSWORD` that no longer matches the volume's stored grant
- fix: before any booklore gate re-run, copy the PERSISTED credentials into the new build's `.env` (`DATABASE_PASSWORD=491960efc1be1ce179b9ac0cf5a2fbcd`, `MYSQL_ROOT_PASSWORD=8ef018a7975c59f2621d316b84b5bdfd`) — or `docker volume rm` the DB volume if stale data is disposable. General rule: on volume-backed DBs, `.env` DB passwords are sticky across gates

## P-084: vaultisse browser-gate quirks (register link, library route, ISBN lookups)
- hits: 2 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage A/A2 + Stage B browser gates (agent-browser, any variant)
- symptom: (a) clicking the "Register and start using the app" link on the login page does NOT navigate — only opening `/register` as a direct URL works; (b) direct URL `/app/library` renders the app's 404 page — the real route is `/app/library/search` (nav link works fine; cosmetic); (c) Google Books API returns 429 from the shared host IP, and the Add-book-ISBN UI dialog shows no reaction to agent-browser fill/type/press/keyboard (Enter via those paths does nothing; "Add (n)" stays disabled)
- cause: SPA client-side quirks (link handler + route naming) plus upstream rate limiting; the ISBN dialog's v-model + keydown-Enter validator is only triggered by NATIVE DOM events (synthetic framework events fail in headless automation)
- fix: open `/register` directly by URL; use `/app/library/search`; headless ISBN-add recipe: `agent-browser eval` with `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set` + `dispatchEvent(new Event('input',{bubbles:true}))` + `dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',bubbles:true,cancelable:true}))` — "Add (1)" then enables and a real click adds the ISBN (server fetch works via Open Library fallback without a Google key); also close the stacked "Scan barcode" camera-error dialog with `agent-browser press Escape` before clicking "Add (n)" (its overlay intercepts the click), verify `scanDialogOpen=false` first

## P-085: vaultisse OIDC behind kanidm fails on TLS unless the step-ca-trust extension is wired
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage B step-ca variant (any OIDC app deploying behind the live step-ca-proxy, where the IdP is reached over TLS signed by the step-ca root CA)
- symptom: with the oidc extension alone, the app faults at OIDC discovery/token fetch — Node rejects the IdP's cert chain even though the browser side works (`STEP_CA_TRUST` env is NOT supported by the component stack)
- cause: the app container has only its own network + baked-in CA bundle; the step-ca root CA never reaches it, so outbound HTTPS to `kanidm.af` fails cert verification
- fix: use the `components/extensions/step-ca-trust/` fragment (in combo `entire-trust`): read-only subpath mount of the external `step-ca-data` volume's `certs/` dir + `NODE_EXTRA_CA_CERTS=/step-ca-root/root_ca.crt` (root CA lives at `certs/root_ca.crt` in the volume)

## P-086: kanidm advertises ES256-only id_tokens, but openid-client defaults to verifying RS256
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage B (any app bundling openid-client v5 and pointing at the live kanidm)
- symptom: authorization round-trip completes, but the callback fails with an invalid id_token error even though the token is correct — kanidm's discovery lists only ES256 for `id_token_signing_alg_values_supported` while upstream hardcodes `id_token_signed_response_alg: 'RS256'` with no env override (as of vaultisse 1.3.8)
- cause: library default mismatch; default (no override) can be verified directly by decoding the app's OIDC config or hitting the IdP discovery endpoint
- fix: derived image recipe `app/images/vaultisse-kanidm/Dockerfile` (FROM `ghcr.io/albertamat/vaultisse:1.3.8`, `sed` RS256→ES256 in `openid-client/lib/client.js` + grep assert), built once as `localhost/vaultisse-kanidm:1.3.8`, referenced via `.env` `IMAGE=`. Re-check the bug first if a newer image version ships an env knob

## P-087: kanidm scope_map never grants the raw `groups` scope — requesting it breaks the OIDC callback with Access Denied
- hits: 1 | status: fixed | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage B (any OIDC app configured against a kanidm client with a scope_map; group claims must come via claim_map instead)
- symptom: with `OIDC_SCOPES` containing `groups` (a storefront default), kanidm redirects back to the callback with Access Denied regardless of the user's membership
- cause: kanidm scope_map only yields {openid, profile, email}; `groups` is not grantable through a scope_map — the app-side request must not ask for it (group membership arrives via the client's claim_map instead)
- fix: override to the minimal grantable set: `OIDC_SCOPES=openid profile email`; group claims come from the kanidm claim_map (`groups` → `<app>-users`), keep that wiring on the IdP side, not in scopes

## P-088: `COMPOSE_FILE` set in `.env` disables auto-pickup of `docker-compose.override.yml`
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage B (any sb/generated build dir where `.env` sets COMPOSE_FILE/COMPOSE_EXTENDS and you drop an ad-hoc override file for a smoke test)
- symptom: a `docker-compose.override.yml` with e.g. a published port for smoke-testing is silently ignored — the containers run as if the override never existed
- cause: override auto-loading only applies when compose discovers the file list itself; a COMPOSE_FILE/COMPOSE_EXTENDS in the environment wins outright
- fix: append the override explicitly to COMPOSE_EXTENDS in `.env`, e.g. `COMPOSE_EXTENDS=...:docker-compose.override.yml` (in sb builds COMPOSE_FILE is assembled, so extra files get added at the EXTENDS tail); remember to REMOVE before teardown and restore `.env`

## P-089: letsencrypt variant publishes no host port — smoke tests need a temporary port mapping
- hits: 1 | status: open | first: 2026-11-06 | last: 2026-11-06
- where: vaultisse Stage B letsencrypt variant (any TLS-stack variant whose compose only exposes the app via the upstream nginx-proxy network, not a host port)
- symptom: `curl http://localhost:<port>` / browser to localhost goes nowhere; from the host there's no direct entrypoint even though containers are healthy
- cause: no `ports:` — the variant is only reachable via `https://$VIRTUAL_HOST` once DNS + the CA trust the deployment; from the host there is nothing on localhost
- fix: for smoke tests only, add a throwaway override with `ports: ["<port>:<port>"]` + `ALLOW_HTTP=true` and (if the TLS externals referenced are unreachable in a bare build) dummy substitutes for the external networks/volumes; remove the override and restore `.env` afterwards

## P-094: `ports:` in base compose always violates checker — not cosmetic-only fixable
- hits: 3 | status: open | first: 2026-11-07 | last: 2026-11-07
- where: navidrome, omnibus, tome stack-audits (`check-layout.sh` flags any `ports:` block in `app/components/base/docker-compose*.y*ml`)
- symptom: checker exits 1 with `ports in base compose: app/components/base/docker-compose.yml`; removing the block would change the published-port behavior (localhost access to the app), which is a logic change
- cause: `check-layout.sh` unconditionally treats any `ports:` line in a base compose as a violation; base entry on the host port is often desired for direct access without the reverse-proxy network
- fix: requires a decision, not a cosmetic fix — either drop `ports:` from base compose (move access to the proxy path) or change the checker to allow it; without one of those the stack cannot reach checker exit 0

## P-095: OIDC client quirk "fixed" by custom image instead of Kanidm client setting
- hits: 1 | status: fixed | first: 2026-11-07 | last: 2026-11-07
- where: vaultisse Stage B (`app/images/vaultisse-kanidm` workaround image)
- symptom: app rejects Kanidm tokens/login (algorithm, PKCE, username format); agent patched the app via a custom image
- cause: skills/agents did not document per-client Kanidm quirk settings
- fix: use Kanidm per-client settings only: `prefer-short-username`, `warning-insecure-client-disable-pkce`, `warning-enable-legacy-crypto` (vaultisse needed legacy crypto/RS256). Documented in kanidm-oidc, stack-conventions §10, kanidm-admin. Existing vaultisse image still needs removal (stack repo, user decision)

## P-096: s3fs-fuse sidecar needs SYS_ADMIN, /dev/fuse, apparmor:unconfined and rshared propagation
- hits: 1 | status: mitigated | first: 2026-11-08 | last: 2026-11-08
- where: omnibus s3fs-fuse extension (any stack using the s3fs sidecar)
- symptom: privileged-ish container capabilities required; mount invisible to app container without bind propagation
- cause: FUSE mount inside a container must be propagated to the host and other containers
- fix: omnibus replaced it with the `s3-rclone` extension using the rclone Docker volume plugin (no caps, no sidecar)

## P-097: rclone Docker volume plugin quirks
- hits: 3 | status: fixed | first: 2026-11-08 | last: 2026-11-08
- where: omnibus `s3-rclone` extension (driver: rclone)
- symptom: volume creation/mount fails or ignores settings
- cause: endpoint must be reachable from the host (plugin runs on host side, not compose network); unsupported driver_opts fail; booleans (e.g. allow_other) must be quoted strings; secrets are visible in `docker volume inspect`; opts are immutable; plugin install is user-only (agents must not install it)
- fix: use host-reachable endpoint, quote booleans, `docker volume rm` to change opts; user installs plugin. Backend params need the `s3-` prefix (`s3-provider`, `s3-endpoint`, `s3-access-key-id`, `s3-secret-access-key`). Functional e2e still pending
- 2026-11-08 (hits 2): `docker plugin install rclone/docker-volume-rclone:amd64 --alias rclone` fails: `failed to fulfil mount request: open /var/lib/docker-plugins/rclone/config: no such file or directory`. The plugin mounts host dirs `/var/lib/docker-plugins/rclone/config` and `/var/lib/docker-plugins/rclone/cache`; they must be created on the host by the user (root, `mkdir -p`) BEFORE install. Agents cannot (host-safety rule). A disabled `rclone:latest` plugin is left behind after the failed install: user runs `docker plugin rm rclone` after creating the dirs, then reinstalls
- 2026-11-08 (hits 3, e2e PASSED on step-ca variant + RustFS): verified end to end. Upload in /books appeared in the bucket; omnibus created its own library dirs as objects. Host-reachable endpoint = rustfs container IP on step-ca-network (`http://172.20.0.3:9000`, `docker inspect rustfs`); the host can reach bridge IPs, the name `rustfs` does not resolve. driver_opts keys `type`, `path` (=bucket), `s3-provider/endpoint/access-key-id/secret-access-key`, `allow_other`, `vfs_cache_mode` all work (`vfs-cache-mode` is equivalent; a bogus value is rejected with a clear error, so keys are validated). mount shows `fuse.rclone ... allow_other`. omnibus-init `chown` exits 0 but is a no-op on the S3 mount (files stay 0:0, writes still work for the app user via allow_other) - harmless, not a failure

## P-098: extension fragment with only top-level `volumes:` is silently skipped by sb
- hits: 1 | status: fixed | first: 2026-11-08 | last: 2026-11-08
- where: omnibus `s3-rclone` extension; `sb build`
- symptom: build output lacks the extension's volume overrides although the combo lists it; only a "Warning: Skipping invalid file ... Missing required 'services' section" line (easy to miss)
- cause: sb requires every compose fragment to have a `services:` section. Also `[build.combos]` / env `combos` were missing from stackbuilder.toml (extensions were never combined)
- fix: add a `services:` stub to the fragment (omnibus: re-declare the `volumes:` mounts of the `omnibus` service), restore `[build.combos] entire` and per-env `combos = ["entire"]`; grep `driver:` in the build output to confirm. Always read sb warnings

## P-099: second `git pull` does not clone newly added stacks (dirty tracked .gitignore/stacks.md)
- hits: 1 | status: fixed | first: 2026-11-12 | last: 2026-11-12
- where: `.githooks/stack-sync.sh` (post-merge/post-checkout)
- symptom: first pull clones everything, later pulls with new `stacks.csv` rows clone nothing (post-merge never ran)
- cause: sync rewrote tracked `.gitignore`/`stacks.md` on every run; `sort -u` is locale-dependent, so the block differed from the committed one -> dirty tree -> next pull aborted ("local changes would be overwritten")
- fix: sync no longer touches tracked files (managed block lives in `.git/info/exclude`, `LC_ALL=C sort`), `stacks.md` is regenerated only by pre-commit; block removed from tracked `.gitignore`. Existing dirty clones: one-time `git checkout .gitignore stacks.md`

## P-100: extension-less environment emits no build dir unless per-env skip_base_generation = false
- hits: 1 | status: fixed | first: 2026-11-12 | last: 2026-11-12
- where: stackbuilder (`sb build`) — environments without extensions (opencode-manager: forwarding/letsencrypt/step-ca)
- symptom: `sb build` reports success but produces no `build/<env>/` for environments whose combos list no extensions; only the env that has extensions gets a directory
- cause: inverse of P-010. sb pushes a base+env variant only when `env_total_variants == 0 && !env_skip_base`; with a global `skip_base_generation = true` (set to avoid P-010) an env with zero extension variants gets nothing at all
- fix: keep global `skip_base_generation = true` (or omit it) and set per-env `skip_base_generation = false` in `[build.environments.<env>]` for every extension-less env; sb then emits the flat `build/<env>/` base variant. Validated on opencode-manager: 3 dirs, all pass `docker compose config --quiet`

## P-101: RustFS admin API — hand-rolled SigV4 fails and `set-user-policy` is 501
- hits: 3 | status: fixed | first: 2026-11-12 | last: 2026-11-12
- where: RustFS admin REST API `/rustfs/admin/v3/*` (no `mc` available in this setup)
- symptom: hand-rolled SigV4 signer gets 403 SignatureDoesNotMatch on every admin and S3 call while aws-cli works; `PUT /rustfs/admin/v3/set-user-policy?accessKey=&policy=` returns 501 NotImplemented even though add-user/add-canned-policy succeed
- cause: subtle difference between the hand-rolled SigV4 construction and the reference implementation (never isolated precisely); `set-user-policy` is not implemented in RustFS — the current binding endpoint is `set-user-or-group-policy`
- fix: sign admin and S3 calls with botocore's `S3SigV4Auth` (`Credentials(ak, sk), service 's3', region 'us-east-1'`) on an `AWSRequest(method, url, data=...)` — note `data=`, not `body=` — then send the prepared headers verbatim via urllib (skip host/content-length). Attach policies with `PUT /rustfs/admin/v3/set-user-or-group-policy?policyName=<p>&userOrGroup=<user>&isGroup=false` (empty body). botocore installed via `pip install --target /tmp/opencode/pylibs botocore`, run in `python:3-alpine` with `PYTHONPATH=/wo/pylibs` (the aws-cli image's python entrypoint is broken). Verified end-to-end on opencode-manager (bucket/user/policy create 200, list/put/delete with new creds 200/200/204)

## P-102: SQLite database on an S3 fuse mount fails with disk I/O error
- hits: 1 | status: fixed | first: 2026-11-13 | last: 2026-11-13
- where: opencode-manager s3-rclone extension (any app whose SQLite/state dir lives under an S3-backed volume)
- symptom: container unhealthy; app logs `SQLiteError: disk I/O error` for the DB under the rclone-mounted volume; `/api/info` returns 500
- cause: SQLite needs POSIX locking/mmap semantics the rclone VFS fuse mount does not provide; the app hardcodes its state home under the workspace mount
- fix: overlay a plain local named volume on the state subpath in the extension fragment (`<vol>:/workspace/.opencode/state` shadows the S3 mount there); only real workspace files stay on S3. Verified: container healthy, S3 round-trip intact

## P-103: rclone VFS reports all files root-owned — git rejects repos as dubious ownership
- hits: 1 | status: fixed | first: 2026-11-13 | last: 2026-11-13
- where: opencode-manager s3-rclone extension (any non-root container user running git on an rclone-mounted volume)
- symptom: app's git calls fail with `fatal: detected dubious ownership in repository at ...` even though the repo was created by the same app; identical spawn works when exec'd as root
- cause: rclone VFS reports every file as uid 0 and `chown` is a no-op on the fuse mount, so a non-root app user (uid 1000) always sees foreign ownership and git's safe.directory check rejects every repo
- fix: pass git config via env on the app service: `GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=safe.directory`, `GIT_CONFIG_VALUE_0=*` (git honors GIT_CONFIG_* env vars; no host or image changes). Verified: repo registration and agent session writes succeed as the app user

## P-104: fnox CLI missing on host — scripts/secret-get.sh fails for all profiles
- hits: 1 | status: open | first: 2026-11-13 | last: 2026-11-13
- where: fnox-secrets plugin `skills/fnox-secrets/scripts/secret-get.sh` / `secret-set.sh` (fnox + age secrets store)
- symptom: `secret-get.sh <profile> <KEY>` prints `missing: fnox (install it yourself, e.g. 'mise use -g fnox')` and exits 1; no profile can be read or written
- cause: fnox binary not installed on the host; agents are forbidden from installing host packages (pacman/mise), so the encrypted `secrets/fnox.toml` store is unusable from agent sessions
- fix: (open) per fnox-secrets skill, report and stop rather than install; workarounds used so far keep stack secrets in `/tmp/opencode/*.env` (chmod 600) — session-scoped, lost on reboot; user should install fnox + age key so `secret-get.sh`/`env-push.sh` work
