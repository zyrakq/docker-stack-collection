---
date: 2026-11-01
topic: "Conventions enforcement: naming, env wiring, DB extensions (pgrust), staged protocol, layering, self-contained skills"
status: validated
---

# Problem Statement

The vibe-kanban stack creation (2026-10-31/11-01) violated the user's conventions wholesale. Audit confirmed 8 violation classes; the root causes live in the collection's own skill/config layer, NOT in the stack:

1. **Rules never codified.** The user's explanations (session 2026-10-31, found verbatim in session history) never made it into `stack-conventions`: DB-as-extension with pgrust alternative, `${VAR:-}` override requirement, project-prefixed naming, staged base-first protocol, environment layering. The skills had no rule to follow.
2. **Two existing rules were actively wrong** and directly caused violations:
   - old §3: "prefer `${PROJECT_NAME:-<svc>}`-style naming when the stack defines `PROJECT_NAME`" → dead `PROJECT_NAME` var in vibe-kanban
   - old §9: listed `PROJECT_NAME` as a standard `.env.example` key
   The vibe-kanban design doc (2026-10-31) faithfully copied both.
3. **Skills are reference lists, not skills.** 24+ path pointers into `stacks/` across skills (several already stale — legacy `src/` layout). If stacks move or change, the skills rot.
4. **No staged protocol.** stack-init scaffolded all extensions "as applicable" up front, with no test gates between base and extensions.

The 8 user-reported violation classes (evidence: vibe-kanban audit):

| # | Violation | Confirmed evidence |
|---|-----------|--------------------|
| 1 | `PROJECT_NAME` declared, never referenced | `app/components/base/.env.example:6`, zero compose refs |
| 2 | postgres as plain base service; no extensions dir; no pgrust alternative; version pinned from upstream (`postgres:16-alpine`); narrow mount `/var/lib/postgresql/data` | base compose `:54–74` |
| 3 | service names ≠ container_name; role-only non-project-prefixed names (`remote-server`/`vk-remote-server`, `electric`) | base compose `:10,:55,:77` |
| 4 | hardcoded env literals in compose (`RUST_LOG`, `SERVER_LISTEN_ADDR`, `ELECTRIC_URL`, `POSTGRES_DB/USER`, electric env block) | base compose `:18,:21–22,:61–62,:84–90` |
| 5 | dead vars in `.env.example` | `PROJECT_NAME` |
| 6 | everything wired at once, no test gates (design/plan prescribed extensions up front; no test commits exist) | git log: 19 commits, zero test/verify commits |
| 7 | `SERVER_PUBLIC_BASE_URL` in base AND re-declared with different defaults in letsencrypt/step-ca overlays | base `.env.example:24`, overlays `:9` |
| 8 | project-path references in skills/agent descriptions | 24+ hits across `.opencode/` |

vibe-kanban itself is NOT touched (user decision); a future `stack-modernize` run brings it to the new format.

# Constraints

- Do NOT modify anything under `stacks/` (vibe-kanban stays as-is).
- Skills and agent definitions must be self-contained after this change: zero path pointers into `stacks/`; patterns embedded verbatim with genericized placeholders; stack names allowed only as attribution.
- Docs stay English; the PITFALLS.md entry follows its existing (Russian) format.
- `~/.config/opencode/micode.jsonc` is global model config, verified clean of stack references — untouched. Agent enforcement lands in repo `AGENTS.md` (loaded by every agent working in this repo).
- Existing embedded fragments in `patterns.md` stay; only `Source:` attribution lines change.
- Renumbering stack-conventions §1–§15 → §1–§19 requires updating every `§` cross-reference (15 refs: §1×1, §9×2, §12×1, §13×6 incl. self-ref at SKILL.md:249, §15×5) across `AGENTS.md`, `source-image`, `stack-init`, `stack-modernize`, `stack-test`, `stack-conventions` itself, `PITFALLS.md`.
- Every created/modified file is committed immediately (repo AGENTS.md rule).
- No new subagents/skills — fix the existing ones (YAGNI).

# Approach

Single canonical rulebook + enforcement layer:

1. **Restructure `stack-conventions/SKILL.md`** (renumber to §1–§19) so every rule lives in one place, ordered by the stack lifecycle. The two wrong rules (old §3 PROJECT_NAME preference, old §9 PROJECT_NAME key) are deleted/replaced.
2. **Embed, don't point**: all canonical patterns become verbatim fragments inside skill references; `Source:` lines become name-only attribution.
3. **Enforcement in repo `AGENTS.md`**: compact iron-rules block (always in context for any agent in this repo) + mandatory `stack-conventions` load before stack work. This IS the "subagents" fix — the micode agents (planner/executor/implementer/reviewer) have no project links (verified) and obey repo AGENTS.md.
4. **Staged protocol with test gates** woven through stack-conventions (§9), stack-init (phases), stack-test (stages).
5. **PITFALLS.md P-008** records the violation class; fix = this change.

# Architecture

## Rule canon — new/rewritten stack-conventions sections (verbatim target text)

### §3 Naming (services, containers, networks, volumes)

- Service names carry the stack identity: `<stack>-<role>` (e.g. `vibe-kanban-app`, `vibe-kanban-db`). NEVER generic, anonymous, or role-only names (`app`, `db`, `server`, `remote-db`, `electric`).
- `container_name`, when present, MUST equal the service name — no mismatched pairs. Either omit it (the service name is then the container name) or set it to exactly the service name.
- Network: `<stack>-network`. Volumes: `<stack>-<purpose>` (`<stack>-db`, `<stack>-data`, `<stack>-media`), always with explicit `name:`.
- The prefix is the literal stack name hardcoded in the compose files. Do NOT introduce a `PROJECT_NAME`-style variable for naming — unused vars are forbidden (§6).

### §5 Env wiring — everything overridable

- EVERY env value in EVERY compose file (base, environments, extensions) is `${VAR:-default}` or `${VAR:?required}`. Bare literals are forbidden — a value the user cannot override from `.env` without editing compose is a defect.
- Covers app env, DB env, infra env. The main app image follows `${IMAGE:-...}` (§19).
- Inline defaults must be sane standalone values; the referenced var gets a `.env.example` entry in the owning component (§6).

### §6 .env.example hygiene

- A variable appears in a component's `.env.example` ONLY when that component's compose files reference it. Zero dead vars (the `PROJECT_NAME` failure: declared, documented, referenced nowhere).
- Base `.env.example` = `COMPOSE_PROJECT_NAME`, `IMAGE`, `LOG_*`, and the app's core required vars. Nothing else.
- Optional/feature vars (oauth keys, s3, mail, provider keys, ...) live ONLY in the owning extension's `.env.example` fragment, and only when that extension is actually wired (staged protocol, §9).
- Standard key order (kept from old §9): `COMPOSE_PROJECT_NAME`, `IMAGE`, `LOG_*`, `VIRTUAL_*`/`LETSENCRYPT_*`, OIDC block, `STEP_CA_*`, CA-path vars, `TZ=UTC`.

### §7 Environments & layering

- Variant list unchanged: `forwarding` / `letsencrypt` / `step-ca` (+ rare `devcontainer`/`internal`); selection via `cd build/<env>/<combo>/`.
- NEW — layering rule: base is environment-agnostic. Any var whose correct value depends on the deployment environment (public base URLs, domain-derived defaults, TLS settings) is declared ONLY in environment overlays — never in base compose and never in base `.env.example`.
- `forwarding` owns the plain/local default (e.g. `${<APP>_PUBLIC_BASE_URL:-http://localhost:<port>}`); `letsencrypt`/`step-ca` own the TLS default (e.g. `${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}`). Each overlay re-declares the var with its own default.

### §8 Database as extension (postgres ↔ pgrust)

- Postgres is NEVER a plain service in base compose. When a stack needs postgres, prepare it as an extension pair: `components/extensions/database/postgresql/` AND `components/extensions/database/pgrust/` — the pgrust alternative is ALWAYS provided.
- Dual-file idiom per variant (verbatim fragments in `references/patterns.md` §11):
  - `docker-compose.yml` — patches the app service only (DB env, `depends_on: condition: service_healthy`)
  - `docker-compose.db.yml` — the DB service `<stack>-db`
  - `.env.example` — `COMPOSE_EXTENDS=:docker-compose.db.yml`, `COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}`, DB vars
- pgrust is a drop-in alternative: identical service/env/mounts/healthcheck; only `image:` differs (`malisper/pgrust:v0.2` vs `postgres:alpine`).
- Version policy: do NOT copy the exact postgres version from upstream project instructions — the latest postgres fits almost every app. Default `postgres:alpine` (floating). Pin an older major ONLY with a documented app incompatibility.
- Mount the named volume at `/var/lib/postgresql` — the wider folder used by current postgres images (`/var/lib/postgresql/data` is the legacy narrow layout).
- Healthcheck `pg_isready` + app `depends_on: service_healthy`; `POSTGRES_INITDB_ARGS="--encoding=UTF8 --lc-ctype=C --lc-collate=C"`.
- Non-postgres single-type datastores (redis-as-cache, single mongo/mysql) may stay in base; a per-project swappable DB goes to extensions. Postgres is always the pair because pgrust exists.
- DB choice is expressed via named `combos` in `stackbuilder.toml` (e.g. `postgresql`, `pgrust`).

### §9 Staged integration protocol (base first, test gates)

Order for bringing up a new stack or adding components:

1. Prepare the database extension first (if the app needs postgres) — the `postgresql` variant.
2. Base implementation: app service + simple named volumes, wired to the DB extension. NO oidc, NO s3, no other extensions.
3. Build, deploy, test — Stage A gate (browser E2E per `stack-test`). MUST pass.
4. Add the `pgrust` variant; rebuild; test. If pgrust comes up without problems → pgrust becomes the default/base variant.
5. oidc (if the app supports it): add the extension, Stage B gate; keep the tested no-oidc variant as proof of the pre-OIDC step.
6. s3: the base uses simple volume mounts. Only after base works: add the `s3-storage` extension if the app supports S3 natively; otherwise s3fs-fuse — ONLY on volumes with NO database data (never mount a shared DB dir via s3fs).

One extension at a time; each addition is followed by its test. NEVER wire or load oidc/s3 material before the base implementation exists and passes its gate.

## Section renumbering map (old → new)

| old | new | change |
|-----|-----|--------|
| §1 Repo layout | §1 | extensions list gains `database/{postgresql,pgrust}` |
| §2 sb/stackbuilder | §2 | drop numa path pointer (L52); note DB combos wiring |
| — | §3 | NEW Naming |
| §3 Volume policy | §4 | PROJECT_NAME line REMOVED |
| — | §5 | NEW Env wiring |
| §9 .env.example | §6 | rewritten hygiene (order kept) |
| §6 Environments | §7 | + layering rule |
| — | §8 | NEW Database as extension |
| — | §9 | NEW Staged integration protocol |
| §7 OIDC policy | §10 | drop zerobyte runbook path (L115) |
| §8 S3 policy | §11 | expand: volumes-first staging, s3fuse non-DB only |
| §4 Config delivery | §12 | unchanged |
| §5 dockerfile_inline | §13 | unchanged |
| §10 step-ca | §14 | unchanged |
| §11 vhost.d | §15 | unchanged |
| §12 Operational gotcha | §16 | genericize example path (L163) |
| §13 Upstream provenance | §17 | unchanged |
| §14 Pitfalls ledger | §18 | unchanged |
| §15 Source-built images | §19 | unchanged |

Frontmatter description updated to advertise the new scope (naming, env wiring, DB extensions, staged protocol) for skill matching.

## Enforcement — AGENTS.md iron rules (new section, verbatim target text)

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

Also update the existing `stack-conventions §15` reference in AGENTS.md (source-built images section) → §19.

# Components (per-file change map)

1. **`.opencode/skills/stack-conventions/SKILL.md`** — full restructure per the renumbering map; new §3/§5/§6/§7/§8/§9 text as above; §1 extensions list + `database/{postgresql,pgrust}`; §2 drop path at L52 (point to the embedded fragment in `references/patterns.md` §9); §10 drop zerobyte runbook path at L115 (browser-e2e.md embeds the steps); §16 genericize the example path at L163 to `stacks/<category>/<...>/<stack>/app/...`; internal `§13` self-ref at L249 → §17; frontmatter description updated.
2. **`.opencode/skills/stack-conventions/references/patterns.md`** — replace all 15 `Source:` lines (L8, 24, 76, 109, 144, 186, 210, 244, 254, 264, 284, 302, 316, 330, 364) with name-only attribution (e.g. `Source: zot stack (embedded verbatim)`); ADD §11 "Database extension pair (postgresql + pgrust)" with the dual-file fragments (db service: `<stack>-db`, `image: postgres:alpine` / `malisper/pgrust:v0.2`, env `${POSTGRES_*:-}` with `POSTGRES_PASSWORD:?`, `POSTGRES_INITDB_ARGS`, `TZ`, volume `<stack>-db:/var/lib/postgresql`, healthcheck `["CMD-SHELL", "/bin/sh", "-c", "exec pg_isready -h 127.0.0.1"]` 5s/5s/5; app patch: DB URL composition `postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@<stack>-db:5432/${POSTGRES_DB}` + `depends_on: service_healthy`; env fragment: `COMPOSE_EXTENDS=:docker-compose.db.yml`, `COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS:-}`, `POSTGRES_*`); ADD §12 "Env wiring before/after" (hardcoded literal → `${VAR:-default}` + matching `.env.example` entry); ADD §13 "Environment layering" (base declares nothing; forwarding overlay `${<APP>_PUBLIC_BASE_URL:-http://localhost:<port>}`; letsencrypt/step-ca `${<APP>_PUBLIC_BASE_URL:-https://${VIRTUAL_HOST}}`).
3. **`.opencode/skills/stack-conventions/references/rationale.md`** — add rationale entries: naming (per-project DB identity, user's verbatim «для таких решений как бд обычно предполагается, что она под каждый проект своя и со своим именем контейнера»), env overridability, no dead vars, DB-as-extension/pgrust (alternative implementation exists → swappable → extension), version policy (upstream pins are conservative; latest usually fits; wider mount folder in latest postgres), staged protocol (base must be proven before extensions compound the failure surface), layering (base is environment-agnostic by definition), self-contained skills (stacks are independent repos that move and change).
4. **`.opencode/skills/stack-init/SKILL.md`** — replace the Workflow with phased flow + test gates: Phase 0 repo & provenance (as today: category, git init, UPSTREAM.md, clone-in-tmp); Phase 1 scaffold base ONLY (base compose app service + named volumes per §3/§5, environments, stackbuilder.toml, READMEs via readme-gen, stack-root files, stacks.csv row, source-image per §19 if no published image); Phase 2 database extension FIRST if postgres needed (prepare `database/postgresql` dual-file, wire base combo, `sb build`, deploy, Stage A gate — NO oidc/s3 yet); Phase 3 pgrust variant after Stage A passes (add, rebuild, test; if clean → default combo per §9); Phase 4 oidc extension + Stage B gate (keep tested no-oidc variant); Phase 5 s3 (base already on volumes; add `s3-storage` if supported + round-trip test; s3fuse only non-DB volumes per §11). DELETE the "Reference exemplars" section (L71–81); replace with one line: canonical patterns are embedded in `stack-conventions` `references/patterns.md` — imitate those, not live stacks. Update §13→§17, §15→§19 refs. Keep the numa name mention at L59 as attribution only.
5. **`.opencode/skills/stack-init/references/scaffold-checklist.md`** — L4: boilerplate sources become the collection root (`LICENSE-APACHE`, `LICENSE-MIT`, `.gitmessage` copied verbatim from the collection root; `.gitignore` must ignore `build/`); L34: extension fragment shapes come from the embedded fragments in stack-conventions `references/patterns.md` (not vaultwarden/gitea); L37: keep or reword the numa mention to point at patterns.md §9; add checklist items for the database extension pair (dual-file + env fragment) marked "Phase 2"; note extensions oidc/s3 are NOT scaffolded at Phase 1 (staged protocol).
6. **`.opencode/skills/stack-modernize/SKILL.md`** — add conformance steps to the Procedure (after current step 6): DB → if postgres is a plain base service, move to the `database/{postgresql,pgrust}` extension pair (dual-file, `postgres:alpine` float unless documented requirement, `/var/lib/postgresql` mount); Naming → rename services to `<stack>-<role>`, align `container_name`, network/volume names; Env → purge unused vars from `.env.example`, convert hardcoded compose env to `${VAR:-}`, move env-dependent vars from base to overlays. Update §13→§17, §15→§19, §1 refs.
7. **`.opencode/skills/stack-test/SKILL.md`** — Staged browser E2E becomes: Stage A base deployment (+ DB via postgresql extension, no oidc); Stage A2 DB alternative — rebuild with the pgrust combo, same browser gate, if clean → pgrust becomes the default combo; Stage B oidc (existing); S3 round-trip last (existing). Procedure summary updated accordingly (insert the A2 step between current steps 6 and 10). Update §13→§17 ref.
8. **`.opencode/skills/stack-test/references/browser-e2e.md`** — drop the two source-path parentheticals (L55 gitea README, L70 zerobyte oidc.md — steps are already embedded); add a short "Stage A2 — DB alternative (pgrust)" checklist (rebuild with pgrust combo, same Stage A flow, promote on pass).
9. **`.opencode/skills/source-image/SKILL.md`** — replace the Exemplars path list (L71–78) with a pointer to a NEW `references/dockerfiles.md` containing three genericized embedded skeletons: release-tarball download (ARG version/tag, fetch archive, verify, install), pinned git-clone (ARG GIT_REPO/GIT_TAG or commit, sparse clone, build), conf-layer image (`<image>-conf` layered on the base image). Skeletons derived from the skill's own Iron rules/Workflow text; no stack paths.
10. **`.opencode/skills/readme-gen/SKILL.md`** — delete the three canonical-exemplar path pointers (L16–18); `references/templates.md` (already fully embedded) is the canon.
11. **`.opencode/skills/kanidm-oidc/SKILL.md`** — delete the "Reference stack:" lines (L12–13); reword L32 ("documented in the kanidm app README") to reference the cookbook itself. Live-instance operational facts (kanidmd container, issuer URLs) stay — they are not project references.
12. **`.opencode/skills/rustfs-s3/SKILL.md`** — delete the "Reference stack:" lines (L11–12). **`references/cookbook.md`** — L51–53: drop the gitea/linkwarden extension paths, keep the env var name examples (`GITEA__storage__*`, `SPACES_*`).
13. **`AGENTS.md`** (repo root) — add the iron-rules section (verbatim above); update `stack-conventions §15` → §19.
14. **`PITFALLS.md`** — append P-008 (Russian, matching the file's entry format): mass convention violations during stack creation (vibe-kanban evidence, the 8 classes), `hits: 1`, `status: fixed`, `fix:` conventions restructured + iron rules in AGENTS.md.

# Data Flow

New-stack session lifecycle under the fixed system:

1. Any agent session in this repo loads `AGENTS.md` → sees the iron rules + "load stack-conventions first".
2. New stack: stack-init Phase 0–5, each extension phase gated by the corresponding stack-test stage; nothing is wired before its gate passes.
3. Rework/modernize: stack-modernize conformance steps bring old stacks to §1–§19.
4. Skill authors: AGENTS.md self-contained rule; patterns embedded via `patterns.md` / `dockerfiles.md` / `templates.md`.

# Error Handling

- App genuinely requires an older postgres major → allowed exception; must be documented (UPSTREAM.md note or component README); default remains latest.
- stackbuilder cannot merge per-environment `.env.example` fragments (environments contribute no env files today) → overlays carry inline `${VAR:-env-default}` defaults; the var is documented in the component README env table. Revisit if stackbuilder gains environment env fragments (STASKBUILDER.md territory).
- pgrust fails for an app (incompatibility) → postgresql stays the default combo; record why in the component README.
- `COMPOSE_EXTENDS` append idiom: use the leading-colon form (`:docker-compose.db.yml`) so multiple extensions chain correctly.

# Testing Strategy

Verification of this change itself (all greps run from repo root):

1. `grep -rn "stacks/" .opencode/` → only generic `stacks/<category>/...` layout placeholders and the §16 gitignore-gotcha generic example remain; zero specific-stack paths.
2. `grep -rn "PROJECT_NAME" .opencode/ AGENTS.md` → appears only in prohibition/hygiene text.
3. `grep -rn "§" .opencode/ AGENTS.md PITFALLS.md STASKBUILDER.md` → every ref resolves to the new §1–§19 numbering.
4. 8-point checklist: each user violation class maps to a written rule (table in Problem Statement ↔ rule canon).
5. Every modified skill keeps valid frontmatter (name/description) and internal `references/*.md` paths that exist.
6. Reviewer checks the new embedded fragments for syntactically plausible YAML/env (indentation, quoting).

# Open Questions

None blocking. Assumptions: (a) pgrust promotion = pgrust combo becomes the default in `stackbuilder.toml`; (b) attribution by stack name (no path) is acceptable; (c) live-instance operational facts (kanidmd container, rustfs endpoint, issuer URL templates) are not "project references" and stay.
