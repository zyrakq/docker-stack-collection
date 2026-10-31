# Stack Skills Implementation Plan

**Goal:** Author the OpenCode V2 skill set (7 skills + 2 subagent definitions) and the `STASKBUILDER.md` improvement ledger that encode the collection's stack conventions, so any agent session can initialize, develop, test, and modernize stacks without re-deriving conventions.

**Architecture:** Markdown-only deliverables — skills as `.opencode/skills/<id>/SKILL.md` with supporting docs in `references/`, subagents as `.opencode/agents/<name>.md`, and a root-level `STASKBUILDER.md` ledger. No application code. Phase order per design: Phase 1 (stack-conventions, stack-init, stack-test), Phase 2 (kanidm-oidc, rustfs-s3, subagents), Phase 3 (stack-modernize, readme-gen).

**Design:** `thoughts/shared/designs/2026-10-31-stack-skills-design.md`

---

## Verified formats (OpenCode V2 docs, fetched 2026-10-31)

**Skills** (https://opencode.ai/v2/docs/skills):
- Location: `.opencode/skills/<skill-id>/SKILL.md`. Skill ID = directory name (lowercase kebab-case). Frontmatter `name` is display-only.
- Frontmatter: `name` (display), `description` (REQUIRED for model discovery — skills without one are not advertised), optional `metadata.opencode/autoinvoke: false`.
- Supporting files live beside `SKILL.md`; paths written inside the skill are relative to the directory containing `SKILL.md`. Recommended layout: `SKILL.md` + `references/*.md`.
- Discovery: project `.opencode/skills` is searched from the project root toward the current directory — so skills work even when a session starts inside `stacks/<category>/<stack>/`. This validates the design's location decision; no extra config needed.

**Agents** (https://opencode.ai/v2/docs/agents):
- Location: `.opencode/agents/<name>.md`. Frontmatter: `description`, `mode: subagent`, optional `model`, `permissions` (ordered list of `{action, resource, effect}`; **last matching rule wins** — broad deny rules first, narrow allows after). Markdown body = the agent's system prompt.
- Do NOT use legacy fields (`temperature`, `tools`, `prompt`, `maxSteps`, ...).
- Relevant permission actions: `shell`, `edit`, `read`, `glob`, `grep`, `subagent`, `skill`.

---

## Notes for implementers (read first)

- All content in English (project docs are 100% English).
- `stacks/` is gitignored by the parent repo and each stack is its own git repo. Root-level glob/grep sees NOTHING inside `stacks/` — always read reference files by their exact path.
- These are markdown deliverables: there is no test framework. Each task's "Verify" is a structural check (frontmatter present, required fields, referenced files exist). Write file → run verify → fix if needed.
- READ-ONLY on `stacks/`: reference stacks are consulted, never modified. The live step-ca-manager + companion + nginx-proxy + kanidm setup is RUNNING — never touch it.
- `.opencode/` is part of the parent repo (not gitignored) — skills are committed here.
- Every skill body must instruct loading `stack-conventions` where it depends on conventions (except stack-conventions itself).

## Reference material (exact paths, read before authoring)

| What | Path |
| --- | --- |
| Hub README exemplar | `stacks/devops/identity-management/kanidm/README.md` |
| Canonical component README | `stacks/devops/identity-management/keycloak/src/keycloak/README.md` |
| Multi-project layout + env_file_patterns | `stacks/devops/identity-management/kanidm/` (app/, ui/, mail-sender/, `app/stackbuilder.toml`) |
| gosu cert-wait pattern | `stacks/network-privacy/turn/coturn/app/components/environments/step-ca/docker-compose.yml` |
| oidc + step-ca-trust extensions | `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/{oidc,step-ca-trust}/` |
| config-into-image + vhost.d | `stacks/development-tools/registries/container-registries/zot/app/components/{base,environments/step-ca}/` |
| S3 + VIRTUAL_HOST_MULTIPORTS | `stacks/devops/s3/storage/rustfs/app/components/{base,environments/step-ca}/` |
| s3-storage extension (gitea) | `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/` |
| s3-storage extension (linkwarden) | `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/` |
| New environments API + combos | `stacks/network-privacy/dns/numa/app/client/stackbuilder.toml` |
| Multi-project + real Dockerfile | `stacks/development-tools/registries/container-registries/distribution/` (server/, ui/) |
| stackbuilder source | `/home/archuser/projects/tools/stackbuilder/` (binary `sb`) |

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8   [Phase 1 skills + STASKBUILDER.md — no deps]
Batch 2 (parallel): 2.1, 2.2, 2.3, 2.4, 2.5, 2.6             [Phase 2 skills + subagents — no file deps]
Batch 3 (parallel): 3.1, 3.2, 3.3                            [Phase 3 skills — no file deps]
```

File-level dependencies are nil (all files are new and independent); the batches follow the design's phase order because later skills reference earlier ones by skill ID at runtime.

---

## Batch 1: Phase 1 — Foundation skills + ledger (parallel — 8 implementers)

### Task 1.1: stack-conventions skill (main file)
**File:** `.opencode/skills/stack-conventions/SKILL.md`
**Test:** none (markdown — verify structurally)
**Depends:** none

```markdown
---
name: Stack Conventions
description: >-
  Conventions for docker-stack-collection stacks: app/ layout, sb/stackbuilder
  builds, environments and extensions, no-bind-mount volume policy,
  dockerfile_inline config patterns, OIDC/S3/step-ca integration rules, and
  .env.example standards. Load before creating or modifying any stack.
---

# Stack Conventions

Reference skill for every stack in this collection. The `stack-init`,
`stack-test`, `stack-modernize`, and `readme-gen` skills build on these rules.

- Why each decision was made: read `references/rationale.md`.
- Verbatim pattern snippets with exact source paths: read `references/patterns.md`.

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
  `step-ca-trust`, `smtp`, ...).
- `build/` — generated by `sb build`; NEVER edit.
- `stackbuilder.toml` — build config.
- `README.md` — component README (see the `readme-gen` skill).

## 2. sb/stackbuilder

- Rust CLI, source at `/home/archuser/projects/tools/stackbuilder`, binary `sb`.
- Only two commands matter: `sb init` and `sb build`. Config is hardcoded to
  `./stackbuilder.toml` — always run from the project dir (e.g. `app/`).
- Dual environments API: `[build.environments]` with `available = [...]` plus
  per-environment tables declaring `extensions`, `combos`, and
  `skip_base_generation`. Example: `stacks/network-privacy/dns/numa/app/client/stackbuilder.toml`.
- Known limitations are tracked in `STASKBUILDER.md` at the collection root.
  Workarounds in current use:
  - No cartesian matrix → hand-written named `combos` (easytier idiom).
  - App-native config files preserved via `env_file_patterns` (numa idiom;
    kanidm uses it for `override.css`).
  - Multi-file compose layering via `COMPOSE_FILE` as escape hatch.

## 3. Volume policy

- NEVER host bind mounts — they break multi-host docker contexts. Only
  allowed exception: `/var/run/docker.sock:ro` for docker-gen companions.
- Named volumes with explicit `name:` (e.g. `name: kanidm-data`); prefer
  `${PROJECT_NAME:-<svc>}`-style naming when the stack defines `PROJECT_NAME`.
- External volumes/networks to join the SSL stack: `step-ca-certs`,
  `step-ca-vhost`, `step-ca-network` (or `letsencrypt-*` equivalents).

## 4. Config delivery

Configs reach containers WITHOUT bind mounts:

1. Preferred: `dockerfile_inline` COPY — `build: {context: ., dockerfile_inline: |}`
   with `FROM ${IMAGE:-default}` + `COPY <config> /etc/app/...`
   (exemplars: zot, ferron, kanidm base).
2. Tiny files only: compose `configs.content` written into a shared volume
   (vhost.d snippets, coturn `turnserver.conf`).

## 5. dockerfile_inline patterns

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

## 6. Environments (variants, not dev/prod)

- `forwarding` — plain ports published to the host.
- `letsencrypt` — joins the letsencrypt stack (external network/volumes).
- `step-ca` — joins the step-ca stack; structurally identical to letsencrypt,
  differs only in volume/network names.
- `devcontainer` (legacy/rare) — external workspace network.
- `internal` (rare) — own bridge network only.
- Variant selection = `cd build/<env>/<combo>/` after `sb build`. No compose
  profiles.

## 7. OIDC policy

- Add an `oidc` extension wherever the app supports OIDC; include it in the
  default build; keep a no-oidc variant as proof of the tested pre-OIDC step.
- Provider is kanidm. Issuer convention:
  `https://<kanidm-domain>/oauth2/openid/<client-name>`.

## 8. S3 policy

- Prefer native S3 support: extension `s3-storage`, env-only fragment
  (gitea `GITEA__storage__*`, linkwarden `SPACES_*`).
- Otherwise s3fs-fuse is the planned fallback — never on shared DB dirs.

## 9. .env.example conventions

Standard keys, in this order where applicable:

- `COMPOSE_PROJECT_NAME`, `PROJECT_NAME`, `IMAGE`
- `LOG_MAX_SIZE` / `LOG_MAX_FILE` / `LOG_COMPRESS`
- `VIRTUAL_PORT`, `VIRTUAL_HOST`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`
- OIDC block (`SSO_*` or app-specific, incl. `SSO_AUTHORITY` = issuer URL)
- `STEP_CA_TRUST` / `STEP_CA_TRUST_RESTART`
- `REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`, `SSL_CERT_FILE`
  (only for apps needing explicit CA paths, e.g. open-webui)
- `TZ=UTC`

## 10. step-ca integration (two pieces)

1. **Env fragment** (in the step-ca environment): adds
   `step-ca-certs:/certs` external volume + `step-ca-network` external
   network + `VIRTUAL_HOST`/`VIRTUAL_PROTO`/`LETSENCRYPT_HOST`/
   `LETSENCRYPT_EMAIL` + app TLS env, e.g.
   `ROCKET_TLS='{certs="/certs/${VIRTUAL_HOST}/fullchain.pem",key=...}'`.
   Cert path convention: `/certs/<VIRTUAL_HOST>/fullchain.pem` and `key.pem`.
2. **`step-ca-trust` extension**: env patch setting `STEP_CA_TRUST` /
   `STEP_CA_TRUST_RESTART` (vaultwarden exemplar).

## 11. nginx-proxy vhost.d tuning

- Per-host nginx tweaks via compose `configs.content` written to the shared
  `step-ca-vhost` / `letsencrypt-vhost` volume at `/vhost.d/${VIRTUAL_HOST}`
  (zot: `client_max_body_size 0;`).
- Multi-port vhosts use the `VIRTUAL_HOST_MULTIPORTS` trick (rustfs).

## 12. Operational gotcha

`stacks/` is gitignored by the collection repo and each stack is its own git
repo. Root-level glob/grep sees NOTHING inside `stacks/` — always target a
specific stack path, e.g. `stacks/devops/identity-management/kanidm/app/...`.
```

**Verify:**
```bash
f=.opencode/skills/stack-conventions/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q '^description:' "$f" && grep -q 'references/rationale.md' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-conventions reference skill`

---

### Task 1.2: stack-conventions rationale
**File:** `.opencode/skills/stack-conventions/references/rationale.md`
**Test:** none
**Depends:** none

```markdown
# Stack Conventions — Rationale

Reasons behind each convention in `SKILL.md`. When an assumption breaks
(new sb version, changed layout), update the skill AND note it in
`STASKBUILDER.md` — the skills are the single source of truth.

1. **Skills, not MCP.** Kanidm/rustfs tooling is command-cookbook shaped;
   skills carry it without server infrastructure. MCP only if limits are hit.
2. **Location `.opencode/skills/` at collection root.** OpenCode discovers
   project skills from the project root toward the current directory, so
   skills work even when a session starts inside `stacks/<category>/<stack>/`.
   Specs and rationale live as supporting files inside each skill directory —
   they travel with the skill.
3. **No host bind mounts.** Bind mounts break multi-host docker contexts and
   couple a stack to one machine's filesystem. Named volumes are portable and
   survive `docker compose down`.
4. **`dockerfile_inline` COPY preferred over `configs.content`.** Baked-in
   config is immutable at runtime and needs no host path; `configs.content`
   is reserved for tiny files because it inlines content into the compose
   file itself.
5. **Environments are variants, not dev/prod.** The same service code is
   deployed against different integration surfaces (plain ports, Let's
   Encrypt, step-ca). Naming them dev/prod would misrepresent the model.
6. **Variant selection by directory, not compose profiles.** `sb build`
   renders each variant into `build/<env>/<combo>/`; selecting by `cd` keeps
   generated files self-contained and diffable.
7. **OIDC in the default build + no-oidc variant kept.** OIDC is the tested
   end state for apps that support it; the no-oidc variant proves the
   pre-OIDC step still builds and runs.
8. **step-ca tested first.** The live step-ca-manager setup exists and is
   running; the letsencrypt variant is untested and assumed analogous minus
   `STEP_CA_TRUST`.
9. **`STEP_CA_TRUST_RESTART=true`.** Trust is often not picked up on first
   boot; the restart after bundle install makes it deterministic.
10. **gosu cert-wait.** TLS-terminating non-root services cannot read
    root-owned certs. Root is used only to wait + chmod, then the process
    drops to the upstream user via `exec gosu` (no lingering root process).
11. **No init containers.** Considered tech debt; the sleep-entrypoint and
    gosu patterns solve the same problems inside one container.
12. **`src/<name>/` is legacy, `app/` is target.** `app/` matches the
    stackbuilder-native layout and the multi-project sibling convention.
13. **Old stacks are NOT migrated unless explicitly requested.** Migration
    churn without a driver creates diff noise; `stack-modernize` exists for
    when it IS requested.
14. **Skills + `STASKBUILDER.md` as single source of truth.** When reality
    drifts from a skill, both are updated together so the next session never
    re-derives conventions.
```

**Verify:**
```bash
f=.opencode/skills/stack-conventions/references/rationale.md
test -s "$f" && grep -q 'STASKBUILDER' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-conventions rationale`

---

### Task 1.3: stack-conventions pattern library
**File:** `.opencode/skills/stack-conventions/references/patterns.md`
**Test:** none
**Depends:** none

Content: verbatim snippets copied EXACTLY from the listed source files (implementer must re-read each source file and paste it verbatim — do not paraphrase YAML). Structure:

```markdown
# Stack Conventions — Pattern Library

Verbatim snippets. Source paths are exact — re-read them when in doubt
(`stacks/` is gitignored; target the specific path).

## 1. Config-into-image (zot)
Source: `stacks/development-tools/registries/container-registries/zot/app/components/base/docker-compose.yml`
(verbatim `services:` + `build.dockerfile_inline` block with `FROM ${IMAGE:-...}` + `COPY *.json /etc/zot/`)

## 2. cert-wait + gosu (coturn)
Source: `stacks/network-privacy/turn/coturn/app/components/environments/step-ca/docker-compose.yml`
(verbatim: `user: root`, `/bin/sh -c` entrypoint polling `/certs/$$COTURN_DOMAIN/key.pem`,
sleep 3, `chmod 644`, `exec gosu nobody ...`, `step-ca-certs:/certs` external volume)

## 3. delayed-start sleep entrypoint (kanidm)
Source: `stacks/devops/identity-management/kanidm/app/components/base/docker-compose.yml`
(verbatim: multi-stage inline Dockerfile building static `sleep`, `COPY --from=override-stage`
for override.css, `ENTRYPOINT ["/bin/sleep", "${START_DELAY}"]`, `CMD ["/sbin/kanidmd", "server"]`)

## 4. vhost.d tuning via configs.content (zot)
Source: `stacks/development-tools/registries/container-registries/zot/app/components/environments/step-ca/docker-compose.yml`
(verbatim: `configs.vhost.content: client_max_body_size 0; chunked_transfer_encoding on;`,
target `/vhost.d/${VIRTUAL_HOST}`, external `step-ca-vhost` volume + `step-ca-network`)

## 5. Multi-port vhosts — VIRTUAL_HOST_MULTIPORTS (rustfs)
Source: `stacks/devops/s3/storage/rustfs/app/components/environments/step-ca/docker-compose.yml`
(verbatim `VIRTUAL_HOST_MULTIPORTS` block mapping UI + S3 hosts/ports)

## 6. oidc extension fragment (vaultwarden)
Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/docker-compose.yml`
(+ its `.env.example`: SSO_* block, SSO_AUTHORITY = kanidm issuer URL)

## 7. step-ca-trust extension fragment (vaultwarden)
Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/step-ca-trust/docker-compose.yml`
(+ `.env.example`: STEP_CA_TRUST / STEP_CA_TRUST_RESTART)

## 8. s3-storage extension fragment (gitea)
Source: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/docker-compose.yml`
(+ `.env.example`: GITEA__storage__* block). Second exemplar (SPACES_* vars):
`stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/`

## 9. env_file_patterns + new environments API (numa)
Source: `stacks/network-privacy/dns/numa/app/client/stackbuilder.toml`
(verbatim: `[build]` with `env_file_patterns = [".env", "numa.toml"]`,
`[build.combos]`, `[build.environments]` with per-env `extensions`/`combos`)

## 10. Named volumes + logging anchors (rustfs base)
Source: `stacks/devops/s3/storage/rustfs/app/components/base/docker-compose.yml`
(verbatim: `x-logging`/`x-healthcheck` anchors, named volumes with explicit `name:`)
```

**Verify:**
```bash
f=.opencode/skills/stack-conventions/references/patterns.md
test -s "$f" && grep -q 'coturn' "$f" && grep -q 'kanidm' "$f" && grep -q 'rustfs' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-conventions pattern library`

---

### Task 1.4: stack-init skill (main file)
**File:** `.opencode/skills/stack-init/SKILL.md`
**Test:** none
**Depends:** none

```markdown
---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection:
  scaffold app/ components, stackbuilder.toml, READMEs, licenses, and
  register the stack in stacks.csv. Use when the user asks to create or
  start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every step below depends on it.

## Workflow

1. **Determine stack type & category.** Ask the user if unclear. Choose the
   category path `stacks/<category>/<subcategory>/<stack-name>/` following
   existing entries in `stacks.csv`.
2. **Create the stack repo.**
   ```bash
   mkdir -p stacks/<category>/<...>/<stack>
   cd stacks/<category>/<...>/<stack>
   git init
   ```
3. **Scaffold** exactly per `references/scaffold-checklist.md`:
   - `app/components/base/` — `docker-compose.yml`, `.env.example`, config
     examples.
   - `app/components/environments/{forwarding,letsencrypt,step-ca}/` as
     applicable (step-ca needs the certs volume + network fragment).
   - `app/components/extensions/{oidc,s3-storage,step-ca-trust}/` as
     applicable.
   - `app/stackbuilder.toml` — new `[build.environments]` API; use
     `env_file_patterns` to preserve app-native config files (numa idiom).
   - `app/README.md` — delegate to the `readme-gen` skill rules.
   - Stack root: hub `README.md`, `.gitignore`, `.gitmessage`,
     `LICENSE-APACHE`, `LICENSE-MIT`; `.gitmodules` + `modules/ssl-automation`
     submodules ONLY if SSL integration is needed.
4. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
5. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
6. **Build & verify:** `cd app/ && sb build`, then follow the `stack-test`
   skill.

## Reference exemplars (imitate, do not copy blindly)

- `stacks/devops/identity-management/kanidm/` — multi-project (app/ + ui/ +
  mail-sender/), `env_file_patterns` for `override.css`.
- `stacks/network-privacy/turn/coturn/` — gosu cert-wait pattern.
- `stacks/devops/secret-control/vaultwarden/` — oidc + step-ca-trust
  extensions.
- `stacks/development-tools/registries/container-registries/zot/` —
  config-into-image + vhost.d.
- `stacks/development-tools/registries/container-registries/distribution/` —
  server/ + ui/ multi-project with a real Dockerfile.
```

**Verify:**
```bash
f=.opencode/skills/stack-init/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q '^description:' "$f" && grep -q 'scaffold-checklist.md' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-init skill`

---

### Task 1.5: stack-init scaffold checklist
**File:** `.opencode/skills/stack-init/references/scaffold-checklist.md`
**Test:** none
**Depends:** none

Content (implementer writes in full):

```markdown
# Stack Init — Scaffold Checklist

Checklist for step 3 of the `stack-init` workflow. Copy boilerplate from an
existing stack (e.g. `stacks/devops/identity-management/kanidm/`) — do not
invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `.gitignore` — copy from an existing stack; must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from an existing stack.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from an existing stack.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir

- [ ] `components/base/docker-compose.yml` — core service; logging anchor
      (`x-logging` with LOG_MAX_SIZE/LOG_MAX_FILE/LOG_COMPRESS), named volumes
      with explicit `name:`, no bind mounts, healthcheck where applicable.
- [ ] `components/base/.env.example` — per stack-conventions §9 key order.
- [ ] `components/base/` config examples (`*.example` files; delivered via
      `dockerfile_inline` COPY or `configs.content`).
- [ ] `components/environments/forwarding/` — plain ports publish.
- [ ] `components/environments/letsencrypt/` — external `letsencrypt-network`
      + `letsencrypt-vhost` volume + VIRTUAL_HOST/LETSENCRYPT_* env.
- [ ] `components/environments/step-ca/` — external `step-ca-network` +
      `step-ca-certs` + `step-ca-vhost` volumes + VIRTUAL_HOST/
      LETSENCRYPT_* env + app TLS env (cert paths `/certs/<VIRTUAL_HOST>/...`).
- [ ] `components/extensions/<ext>/` as applicable — `oidc`, `s3-storage`,
      `step-ca-trust` (env-only fragments; copy shape from vaultwarden/gitea).
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native config
      files; per-env `extensions`/`combos` (numa exemplar).
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Append to `stacks.csv`: `stacks/<path>;-;unverified` (semicolon-separated;
      `-` url when no remote; do not touch other rows).

## First build

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
```

**Verify:**
```bash
f=.opencode/skills/stack-init/references/scaffold-checklist.md
test -s "$f" && grep -q 'stacks.csv' "$f" && grep -q 'step-ca-trust' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-init scaffold checklist`

---

### Task 1.6: stack-test skill (main file)
**File:** `.opencode/skills/stack-test/SKILL.md`
**Test:** none
**Depends:** none

```markdown
---
name: Stack Test
description: >-
  Testing procedure for docker-stack-collection stacks: step-ca variant
  first, never touching the live step-ca-manager setup; sb build checks,
  compose config validation, health, cert-wait, OIDC and S3 verification.
  Use after any stack change.
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

## Procedure

Follow `references/verification-procedure.md` in order. Summary:

1. `cd app/ && sb build` — check the `build/<env>/<combo>/` output structure.
2. `cd build/<env>/<combo>/ && cp .env.example .env` and edit values.
3. `docker compose config` — must validate.
4. `docker compose up --build -d`.
5. Health checks pass.
6. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
7. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
8. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
   `SSL_CERT_FILE` (open-webui example).
9. OIDC login via kanidm when the `oidc` extension is present.
10. S3 round-trip when the `s3-storage` extension is present.
```

**Verify:**
```bash
f=.opencode/skills/stack-test/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q 'verification-procedure.md' "$f" && grep -q 'NEVER modify' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-test skill`

---

### Task 1.7: stack-test verification procedure
**File:** `.opencode/skills/stack-test/references/verification-procedure.md`
**Test:** none
**Depends:** none

Content (implementer writes in full):

```markdown
# Stack Test — Verification Procedure

Ordered checklist. Run from the generated variant dir
(`app/build/<env>/<combo>/`) unless noted. Substitute `<svc>` with the main
service name.

## 0. Preconditions

- [ ] Confirm which variant is under test; step-ca FIRST.
- [ ] Confirm you are NOT operating on the live step-ca-manager stack
      (read-only at most). If a failure is caused by the manager setup,
      switch to the forwarding variant and note it — never modify the manager.

## 1. Build

- [ ] `cd app/ && sb build` exits 0.
- [ ] Expected `build/<env>/<combo>/` dirs exist (check `stackbuilder.toml`).
- [ ] Spot-check one generated `docker-compose.yml`: no bind mounts, named
      volumes have explicit `name:`, external networks/volumes correct.

## 2. Configure

- [ ] `cp .env.example .env`; fill required values (domains, secrets).
- [ ] step-ca variant: `STEP_CA_TRUST=true` AND `STEP_CA_TRUST_RESTART=true`.

## 3. Validate & deploy

- [ ] `docker compose config` exits 0.
- [ ] `docker compose up --build -d` exits 0.
- [ ] `docker compose ps` — all services running/healthy.

## 4. Health & TLS

- [ ] Healthcheck passes (`docker inspect --format '{{.State.Health.Status}}' <svc>`).
- [ ] TLS-terminating services: cert files appear at
      `/certs/<VIRTUAL_HOST>/{fullchain.pem,key.pem}`; cert-wait pattern
      observable in logs (`docker logs <svc>`).
- [ ] `STEP_CA_TRUST` bundle installed inside the container; if the app
      still rejects the CA, check app-specific envs (`REQUESTS_CA_BUNDLE`,
      `SSL_CERT_FILE` — open-webui example) and the RESTART flag.

## 5. Integrations

- [ ] OIDC (when present): login redirect reaches kanidm at
      `https://<kanidm-domain>/oauth2/openid/<client-name>`; callback
      completes; a test user from the right group can sign in.
- [ ] S3 (when present): round-trip — create bucket, put object, get object,
      delete (see `rustfs-s3` skill cookbook).

## 6. Failure handling

- [ ] Any failure caused by the live manager setup → switch to forwarding
      variant; record the finding; NEVER touch the manager stack.
- [ ] Record results in the stack's notes/PR description.
```

**Verify:**
```bash
f=.opencode/skills/stack-test/references/verification-procedure.md
test -s "$f" && grep -q 'STEP_CA_TRUST_RESTART' "$f" && grep -q 'forwarding' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-test verification procedure`

---

### Task 1.8: STASKBUILDER.md ledger
**File:** `STASKBUILDER.md` (repo root)
**Test:** none
**Depends:** none

```markdown
# STASKBUILDER — stackbuilder improvement ledger

Living ledger of improvement proposals for sb/stackbuilder (source:
`/home/archuser/projects/tools/stackbuilder/`). The skills under
`.opencode/skills/` are the single source of truth for stack conventions;
when a skill's assumption breaks (new sb version, changed layout), update
the skill AND record it here.

Status legend: `proposal` → `accepted` → `implemented` / `rejected`.

## Limitations

### L1. No cartesian product matrix — `proposal`
Variants render independently; cross-products must be hand-enumerated as
named `combos`. Combos cannot nest, parameterize, or carry env-var
overrides. Workaround: hand-written combos (easytier idiom).

### L2. No per-variant variable values — `proposal`
An environment/combo cannot set variable values used only in that variant.

### L3. Global `extensions` silently ignored with `[build.environments]` — `proposal`
When the dual environments API is used, top-level `[build] extensions` is
silently dropped instead of erroring or merging.

### L4. Opaque version-sensitive layout heuristics — `proposal`
`num_envs` / `total_variants` style layout detection is version-sensitive
and hard to predict from user code.

### L5. `.env.example` merge is concatenation, not unification — `proposal`
Duplicate keys are not unified; ordering is concatenation order.

### L6. YAML arrays are append-only — `proposal`
Cannot remove or replace base ports/volumes from an environment/extension;
only appends.

### L7. Only the literal filename `docker-compose.yml` is merged — `proposal`
Multi-file compose layering is outside the tool (COMPOSE_FILE escape hatch).

### L8. No `--config` / `--select` / `--dry-run` / `--output` — `proposal`
Config path is hardcoded to `./stackbuilder.toml`; no partial builds, no
preview, no custom output dir.

### L9. Unknown TOML keys silently ignored — `proposal`
Typo'd keys (e.g. an invalid `environments_path` seen in real stacks) are
swallowed without warning.

### L10. External `yq` required by default — `proposal`
Build fails confusingly when `yq` is missing.

### L11. Soft validation — `proposal`
A typo'd extension name degrades output silently instead of failing.

### L12. `.env` restore is exact-path only — `proposal`
No globbing/fallback when restoring `.env` files into regenerated dirs.

### L13. `sb init` does not understand the new environments API — `proposal`
Init scaffolds the old shape; new stacks need hand-written
`[build.environments]` config.

## Interim workarounds (within current capabilities)

- **Hand-written combos** — enumerate cross-products as named combos
  (easytier idiom).
- **`env_file_patterns`** — preserve app-native config files across builds
  (numa idiom: `[".env", "numa.toml"]`; kanidm: `[".env", "override.css"]`).
- **`COMPOSE_FILE` layering** — escape hatch for multi-file compose needs.
```

**Verify:**
```bash
test -s STASKBUILDER.md && grep -q 'L13' STASKBUILDER.md && grep -q 'easytier' STASKBUILDER.md && echo OK
```
**Commit:** `feat: add STASKBUILDER improvement ledger`

---

## Batch 2: Phase 2 — Admin skills + subagents (parallel — 6 implementers)

### Task 2.1: kanidm-oidc skill (main file)
**File:** `.opencode/skills/kanidm-oidc/SKILL.md`
**Test:** none
**Depends:** none (runtime: loads `stack-conventions`)

```markdown
---
name: Kanidm OIDC
description: >-
  Cookbook for administering Kanidm (the collection's OIDC provider):
  create/modify OAuth2 clients per project, fetch client secrets, manage
  groups and test users, adjust redirect URLs/scopes/claim maps, and guarded
  admin password recovery. Use for any Kanidm or OIDC client wiring task.
---

# Kanidm OIDC

Load the `stack-conventions` skill first. Reference stack:
`stacks/devops/identity-management/kanidm/`.

Full command cookbook: read `references/cli-cookbook.md`.

## What this covers

- Create/modify OAuth2 clients per project; fetch the client secret.
- Create groups; create test users; add users to groups.
- Adjust client settings per project: redirect URLs, scopes, claim mapping.
- Reset idm_admin/admin passwords — GUARDED procedure (see Guardrails).

## Conventions

- Issuer: `https://<kanidm-domain>/oauth2/openid/<client-name>`.
- One OAuth2 client per project, named after the project.
- Redirect URL: the app's OIDC callback on its own domain
  (e.g. vaultwarden: `https://<app-domain>/identity/connect/oidc-signin`).
- The kanidm container is `kanidmd`; admin password recovery uses
  `docker exec -it kanidmd kanidmd recover-account <admin|idm_admin>`
  (documented in the kanidm app README).

## Guardrails

- Destructive operations (password resets, client/group deletion, schema
  changes) ALWAYS require explicit user confirmation before running.
- The live kanidm instance is part of the running step-ca-manager setup —
  never modify the manager stack itself.
- For hands-off delegation use the `kanidm-admin` subagent.
```

**Verify:**
```bash
f=.opencode/skills/kanidm-oidc/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q 'cli-cookbook.md' "$f" && grep -q 'kanidm-admin' "$f" && echo OK
```
**Commit:** `feat(skills): add kanidm-oidc skill`

---

### Task 2.2: kanidm-oidc CLI cookbook
**File:** `.opencode/skills/kanidm-oidc/references/cli-cookbook.md`
**Test:** none
**Depends:** none

Content (implementer writes in full; command shapes below are the baseline —
verify against the installed version with `docker exec kanidmd kanidm --help`
and adjust flags before pasting into a runbook):

```markdown
# Kanidm OIDC — CLI Cookbook

All commands run inside the `kanidmd` container via `docker exec`. The CLI
authenticates against the server's own origin; log in as an admin identity
first. Verify exact flags with `docker exec kanidmd kanidm --help` — the CLI
evolves between versions.

## Authentication

```bash
# Interactive login as an identity (prompts for password)
docker exec -it kanidmd kanidm login --name idm_admin
# Who am I
docker exec -it kanidmd kanidm whoami --name idm_admin
```

## OAuth2 clients (per project)

```bash
# Create a client: <client-name> <display-name> <origin-url>
docker exec -it kanidmd kanidm system oauth2 create <client-name> "<Display Name>" https://<app-domain>
# Add the app's callback/redirect URL
docker exec -it kanidmd kanidm system oauth2 add-redirect-urls <client-name> https://<app-domain>/<callback-path>
# List / inspect
docker exec -it kanidmd kanidm system oauth2 list
docker exec -it kanidmd kanidm system oauth2 get <client-name>
# Fetch the client secret (needed for the app's .env)
docker exec -it kanidmd kanidm system oauth2 get-basic-secret <client-name>
# Scope map: grant scopes to a group
docker exec -it kanidmd kanidm system oauth2 add-scope-map <client-name> <group-name> openid profile email
# Claim map (optional): map group claims into the token
docker exec -it kanidmd kanidm system oauth2 add-claim-map <client-name> <group-name> <claim-name> <group-name>
# PKCE is on by default; only disable for clients that cannot do PKCE (guarded)
docker exec -it kanidmd kanidm system oauth2 warning-insecure-client-disable-pkce <client-name>
```

Issuer URL to put in the app's env (`SSO_AUTHORITY` or app-specific):
`https://<kanidm-domain>/oauth2/openid/<client-name>`

## Groups & users

```bash
# Create a group (one per app role, e.g. <app>-users)
docker exec -it kanidmd kanidm group create <group-name>
# Create a test person
docker exec -it kanidmd kanidm person create <user-name> "<Display Name>"
# Set mail (often matched by SSO_SIGNUPS_MATCH_EMAIL)
docker exec -it kanidmd kanidm person update <user-name> --mail <user@example.com>
# Add user(s) to group
docker exec -it kanidmd kanidm group add-members <group-name> <user-name>
# Inspect
docker exec -it kanidmd kanidm group get <group-name>
```

## Password recovery (GUARDED — explicit user confirmation required)

```bash
# Recovers and prints a new password for the built-in admins
docker exec -it kanidmd kanidmd recover-account admin
docker exec -it kanidmd kanidmd recover-account idm_admin
```

Never run recovery without the user asking for it. After recovery, tell the
user to log in and change the password immediately.

## Wiring an app (checklist)

1. Create the OAuth2 client named after the project.
2. Add the redirect URL from the app's OIDC docs.
3. Add a scope map for the app's group with `openid profile email`.
4. Fetch the basic secret.
5. Fill the app's oidc extension `.env`:
   `SSO_CLIENT_ID=<client-name>`, `SSO_CLIENT_SECRET=<secret>`,
   `SSO_AUTHORITY=https://<kanidm-domain>/oauth2/openid/<client-name>`.
6. Test login per the `stack-test` skill.
```

**Verify:**
```bash
f=.opencode/skills/kanidm-oidc/references/cli-cookbook.md
test -s "$f" && grep -q 'get-basic-secret' "$f" && grep -q 'recover-account' "$f" && echo OK
```
**Commit:** `feat(skills): add kanidm CLI cookbook`

---

### Task 2.3: rustfs-s3 skill (main file)
**File:** `.opencode/skills/rustfs-s3/SKILL.md`
**Test:** none
**Depends:** none (runtime: loads `stack-conventions`)

```markdown
---
name: RustFS S3
description: >-
  Cookbook for administering RustFS (the collection's S3 provider): create
  buckets, users/keys, and policies; wire apps via s3-storage extension env
  fragments. Use for any RustFS or S3 storage wiring task.
---

# RustFS S3

Load the `stack-conventions` skill first. Reference stack:
`stacks/devops/s3/storage/rustfs/`.

Full command cookbook: read `references/cookbook.md`.

## What this covers

- Create buckets, users/keys, and policies on the rustfs instance.
- Wire apps via the `s3-storage` extension env fragments
  (gitea `GITEA__storage__*`, linkwarden `SPACES_*`).

## Instance facts

- API on port 9000, console on 9001 (step-ca variant: `S3_VIRTUAL_HOST` /
  `UI_VIRTUAL_HOST` via `VIRTUAL_HOST_MULTIPORTS`).
- Credentials: `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` from the stack's
  `.env` (never from `.env.example` defaults in production).

## Guardrails

- Destructive operations (deleting buckets/objects/users/policies) ALWAYS
  require explicit user confirmation.
- The live instance may back real apps — never delete data to "free space"
  without confirmation.
- For hands-off delegation use the `rustfs-admin` subagent.
```

**Verify:**
```bash
f=.opencode/skills/rustfs-s3/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q 'cookbook.md' "$f" && grep -q 'rustfs-admin' "$f" && echo OK
```
**Commit:** `feat(skills): add rustfs-s3 skill`

---

### Task 2.4: rustfs-s3 cookbook
**File:** `.opencode/skills/rustfs-s3/references/cookbook.md`
**Test:** none
**Depends:** none

Content (implementer writes in full):

```markdown
# RustFS S3 — Cookbook

RustFS is S3-compatible: use the MinIO client (`mc`) or `aws` CLI against
endpoint `http://<s3-endpoint>:9000` (or the S3 virtual host on the step-ca
variant). Alias setup:

```bash
mc alias set rustfs http://<s3-endpoint>:9000 "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
```

## Buckets

```bash
mc mb rustfs/<bucket>
mc ls rustfs
mc ls --recursive rustfs/<bucket>
```

## Users / keys / policies

```bash
# Create a user with its own keypair
mc admin user add rustfs <username>
# Policy: write JSON, then create + attach
mc admin policy create rustfs <policy-name> <policy.json>
mc admin policy attach rustfs <policy-name> --user <username>
# List
mc admin user list rustfs
mc admin policy list rustfs
```

Minimal read-write bucket policy JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::<bucket>", "arn:aws:s3:::<bucket>/*"]
    }
  ]
}
```

## Wiring an app (s3-storage extension)

1. Create the bucket + a dedicated user/policy (least privilege).
2. Copy the extension fragment shape from an exemplar:
   - gitea: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/`
     (`GITEA__storage__MINIO_ENDPOINT`, `..._ACCESS_KEY_ID`, `..._BUCKET`, ...)
   - linkwarden: `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/`
     (`SPACES_*` vars)
3. Fill the app's `.env` with endpoint, key id, secret, bucket.
4. Verify with a round-trip per the `stack-test` skill (put/get/delete).

## Round-trip smoke test

```bash
echo test | mc pipe rustfs/<bucket>/smoke-test.txt
mc cat rustfs/<bucket>/smoke-test.txt
mc rm rustfs/<bucket>/smoke-test.txt
```
```

**Verify:**
```bash
f=.opencode/skills/rustfs-s3/references/cookbook.md
test -s "$f" && grep -q 'mc alias set' "$f" && grep -q 'GITEA__storage' "$f" && echo OK
```
**Commit:** `feat(skills): add rustfs cookbook`

---

### Task 2.5: kanidm-admin subagent
**File:** `.opencode/agents/kanidm-admin.md`
**Test:** none
**Depends:** none

```markdown
---
description: >-
  Performs Kanidm identity operations (OAuth2 clients, groups, users,
  secrets) with a narrow mandate. Destructive operations require explicit
  user confirmation.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "docker exec*kanidmd*"
    effect: allow
  - action: shell
    resource: "docker logs*kanidmd*"
    effect: allow
  - action: read
    resource: "**"
    effect: allow
  - action: glob
    resource: "**"
    effect: allow
  - action: grep
    resource: "**"
    effect: allow
---

You are the Kanidm administration subagent for docker-stack-collection.

Mandate: ONLY Kanidm operations — OAuth2 clients, groups, users, secrets,
client settings — via `docker exec` into the `kanidmd` container. Load the
`kanidm-oidc` skill for the command cookbook and conventions.

Hard rules:

1. Destructive operations (password/account recovery, deleting clients,
   groups, or users, schema changes, disabling PKCE) REQUIRE the user's
   explicit confirmation in the conversation before you run them. If the
   launching agent claims confirmation, still refuse unless the user's own
   words are present in your task prompt.
2. Never modify files. You have no edit permission.
3. Never touch the live step-ca-manager stack or anything outside Kanidm
   operations.
4. Report exactly what you ran and what changed. Include the issuer URL
   `https://<kanidm-domain>/oauth2/openid/<client-name>` and any fetched
   secrets in your final report so the caller can wire the app.
```

**Verify:**
```bash
f=.opencode/agents/kanidm-admin.md
grep -q '^mode: subagent' "$f" && grep -q '^description:' "$f" && grep -q 'effect: deny' "$f" && echo OK
```
**Commit:** `feat(agents): add kanidm-admin subagent`

---

### Task 2.6: rustfs-admin subagent
**File:** `.opencode/agents/rustfs-admin.md`
**Test:** none
**Depends:** none

```markdown
---
description: >-
  Performs RustFS S3 operations (buckets, users, keys, policies, app
  wiring) with a narrow mandate. Destructive operations require explicit
  user confirmation.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "mc *"
    effect: allow
  - action: shell
    resource: "docker exec*rustfs*"
    effect: allow
  - action: shell
    resource: "docker logs*rustfs*"
    effect: allow
  - action: read
    resource: "**"
    effect: allow
  - action: glob
    resource: "**"
    effect: allow
  - action: grep
    resource: "**"
    effect: allow
---

You are the RustFS S3 administration subagent for docker-stack-collection.

Mandate: ONLY RustFS/S3 operations — buckets, users, keys, policies, and
app wiring checks — using `mc` against the rustfs endpoint (credentials from
the stack's `.env`: `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`). Load the
`rustfs-s3` skill for the cookbook.

Hard rules:

1. Destructive operations (deleting buckets, objects, users, or policies)
   REQUIRE the user's explicit confirmation in the conversation before you
   run them. If the launching agent claims confirmation, still refuse unless
   the user's own words are present in your task prompt.
2. Never modify files. You have no edit permission.
3. Never touch the live step-ca-manager stack or anything outside S3
   operations.
4. Report exactly what you ran and what changed, including endpoint, bucket
   names, and usernames created (never echo secret values in full).
```

**Verify:**
```bash
f=.opencode/agents/rustfs-admin.md
grep -q '^mode: subagent' "$f" && grep -q '^description:' "$f" && grep -q 'effect: deny' "$f" && echo OK
```
**Commit:** `feat(agents): add rustfs-admin subagent`

---

## Batch 3: Phase 3 — Modernization + README generation (parallel — 3 implementers)

### Task 3.1: stack-modernize skill
**File:** `.opencode/skills/stack-modernize/SKILL.md`
**Test:** none
**Depends:** none (runtime: loads `stack-conventions`, `readme-gen`)

```markdown
---
name: Stack Modernize
description: >-
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, artifact
  cleanup, README regeneration). ONLY when the user explicitly requests
  modernization.
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
2. **Rename** `src/<name>/` → `app/` (git mv inside the stack repo). If the
   stack has multiple projects, split into sibling dirs (`ui/`, `server/`,
   ...) per stack-conventions §1.
3. **Modules**: move `src/ssl-automation/` → `modules/ssl-automation/` and
   declare it in the stack-root `.gitmodules` (submodule URLs:
   `https://github.com/zyrakq/{step-ca,letsencrypt}-manager-stack.git`).
4. **Environments**: add missing ones (forwarding / letsencrypt / step-ca;
   `internal` only when genuinely needed).
5. **Extensions**: add `oidc` where the app supports it (include in default
   build, keep a no-oidc variant) and `s3-storage` where applicable.
6. **stackbuilder.toml**: convert to the new `[build.environments]` API.
7. **Artifacts**: delete `.kilocode/`, `.clinerules/` everywhere in the
   stack.
8. **READMEs**: regenerate hub + component READMEs with the `readme-gen`
   skill.
9. **Verify** with the `stack-test` skill (step-ca variant first).
```

**Verify:**
```bash
f=.opencode/skills/stack-modernize/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q 'ONLY when the user explicitly' "$f" && grep -q 'readme-gen' "$f" && echo OK
```
**Commit:** `feat(skills): add stack-modernize skill`

---

### Task 3.2: readme-gen skill (main file)
**File:** `.opencode/skills/readme-gen/SKILL.md`
**Test:** none
**Depends:** none (runtime: loads `stack-conventions`)

```markdown
---
name: Readme Gen
description: >-
  Generate or regenerate stack READMEs in the collection's two canonical
  styles: stack-root hub README and component README (~100-250 lines).
  Use when creating a stack or modernizing one.
---

# Readme Gen

Load the `stack-conventions` skill first. Full templates with placeholders:
read `references/templates.md`.

## Canonical exemplars

- Component README (canonical): `stacks/devops/identity-management/keycloak/src/keycloak/README.md`
- Hub README (canonical): `stacks/devops/identity-management/kanidm/README.md`
  (also `stacks/devops/identity-management/keycloak/README.md`)
- Module READMEs (`modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`)
  are REUSED verbatim — never rewrite them.

## Rules

1. 100% English.
2. An emoji on EVERY heading.
3. Every command fenced with a language tag (```bash, ```sh, ...).
4. Document letsencrypt / step-ca / OIDC variants when present.
5. NEVER present `build/` as editable — it is auto-generated; say so in Notes.
6. Hub README links each component (`app/README.md`,
   `modules/ssl-automation/*`) with a one-two sentence blurb.
7. Component README is ~100-250 lines and follows the template section order
   exactly (Quick Start → Project Structure → Available Configurations →
   Environment Variables → Networks → Security → Troubleshooting → Notes).
8. Environment variables grouped Base / Let's Encrypt / Step CA / OIDC /
   Step CA Trust, formatted `- `NAME`: description (default: X)`.

## Workflow

1. Read the stack's `stackbuilder.toml`, `components/**`, and existing
   READMEs to learn environments, extensions, ports, and variables.
2. Generate the component README(s) from the template.
3. Generate the hub README from the template.
4. Cross-check: every env var in `.env.example` files is documented; every
   documented variant exists in `stackbuilder.toml`.
```

**Verify:**
```bash
f=.opencode/skills/readme-gen/SKILL.md
head -1 "$f" | grep -q '^---$' && grep -q 'templates.md' "$f" && grep -q 'keycloak' "$f" && echo OK
```
**Commit:** `feat(skills): add readme-gen skill`

---

### Task 3.3: readme-gen templates
**File:** `.opencode/skills/readme-gen/references/templates.md`
**Test:** none
**Depends:** none

Content (implementer writes in full, distilled from the canonical exemplars):

````markdown
# Readme Gen — Templates

## Template A: Stack-root hub README

```markdown
# <emoji> <Name> Stack

<1-2 sentence description of the complete stack.>

## 🧩 Components

### <emoji> [<Component Name>](app/)

<1-2 sentence blurb.>

### 🌐 [Let's Encrypt Manager](modules/ssl-automation/letsencrypt-manager/)

Automatic SSL certificate generation and renewal using Let's Encrypt for
production deployments with internet access.

### 🔒 [Step CA Manager](modules/ssl-automation/step-ca-manager/)

Self-signed trusted certificate authority for virtual Docker networks
without internet access. Automatically manages and distributes CA
certificates within isolated environments.

## 🚀 Quick Start

Each component has its own README with detailed setup instructions. Choose
the certificate management solution that fits your deployment scenario.

<Optional: numbered example deployment flow — cd app/ && sb build →
cd build/<env>/<ext>/ → cp .env.example .env → docker compose up --build -d>

## 📋 Requirements

- Docker & Docker Compose
- Domain name (for production deployments)
- Email address (for Let's Encrypt)

## 📄 License

This project is dual-licensed under:

- [Apache License 2.0](LICENSE-APACHE)
- [MIT License](LICENSE-MIT)
```

## Template B: Component README (~100-250 lines)

```markdown
# <emoji> <Service Name>

A modular Docker Compose configuration system for <X> with <key
capabilities>.

## 🚀 Quick Start

### 1. Build Configurations

```bash
sb build
```

This will create all combinations in the `build/` directory based on
[`stackbuilder.toml`](stackbuilder.toml).

### 2. Choose Your Configuration

```bash
# For development with port forwarding
cd build/forwarding/<combo>/

# For production with Let's Encrypt SSL
cd build/letsencrypt/<combo>/

# For production with Step CA SSL
cd build/step-ca/<combo>/
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 4. Deploy

```bash
docker compose up --build -d
```

Access: `<url>` (for forwarding mode)

## 📁 Project Structure

- [`components/`](components/) — Source compose components
  - [`base/`](components/base/) — Base <service> configuration
  - [`environments/`](components/environments/) — Environment-specific configurations
  - [`extensions/`](components/extensions/) — Extension components (if present)
- [`build/`](build/) — Generated configurations (auto-generated, ready to deploy)
- [`stackbuilder.toml`](stackbuilder.toml) — Build configuration for stackbuilder

## 🔧 Available Configurations

### Environments

- **forwarding**: <description>
- **letsencrypt**: <description>
- **step-ca**: <description>

### Extensions

- **<ext-name>**: <description>

## 🔧 Environment Variables

### Base Configuration

- `COMPOSE_PROJECT_NAME`: Project name for Docker Compose
- `IMAGE`: Docker image (default: <default>)

### Let's Encrypt Configuration

- `VIRTUAL_PORT`: Port for nginx-proxy (default: <port>)
- `VIRTUAL_HOST`: Domain for nginx-proxy
- `LETSENCRYPT_HOST`: Domain for SSL certificate
- `LETSENCRYPT_EMAIL`: Email for certificate registration

### Step CA Configuration

- <same VIRTUAL_*/LETSENCRYPT_* set + app TLS env vars>

### OIDC Configuration

- `SSO_CLIENT_ID`: OAuth2 client name in kanidm
- `SSO_CLIENT_SECRET`: OAuth2 client secret
- `SSO_AUTHORITY`: Issuer URL (`https://<kanidm-domain>/oauth2/openid/<client-name>`)

### Step CA Trust Configuration

- `STEP_CA_TRUST`: Install the CA bundle into the container (default: true)
- `STEP_CA_TRUST_RESTART`: Restart the service after install (default: true)

## 🌐 Networks

- **forwarding**: `<name>` (internal)
- **letsencrypt**: `letsencrypt-network` (external)
- **step-ca**: `step-ca-network` (external)

## 🔒 Security

⚠️ **Production Checklist:**

- <checklist items>

## 🆘 Troubleshooting

**Build Issues:**
- <items>

**SSL Issues:**
- **Let's Encrypt**: Verify domain DNS and letsencrypt-manager
- **Step CA**: Check step-ca-manager and virtual network config

## 📝 Notes

- The `build/` directory is automatically generated and should not be edited manually
- Environment variables in generated files use `$VARIABLE_NAME` format for proper interpolation
- Each generated configuration includes a complete `docker-compose.yml` and `.env.example`
- Use `sb build` to regenerate all configurations after modifying components
```

## Rules recap

- Emoji on every heading; 100% English; every command fenced with a language tag.
- Reuse `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`
  verbatim when linking modules — never paraphrase them.
- Omit sections for features the stack does not have (e.g. no Extensions
  section when there are none) but keep the ORDER of remaining sections.
````

**Verify:**
```bash
f=.opencode/skills/readme-gen/references/templates.md
test -s "$f" && grep -q 'Template A' "$f" && grep -q 'Template B' "$f" && grep -q 'STEP_CA_TRUST_RESTART' "$f" && echo OK
```
**Commit:** `feat(skills): add readme-gen templates`

---

## Final integration verification (after all batches)

```bash
# 1. All skill files exist with valid frontmatter
for f in stack-conventions stack-init stack-test kanidm-oidc rustfs-s3 stack-modernize readme-gen; do
  p=".opencode/skills/$f/SKILL.md"
  test -f "$p" && head -1 "$p" | grep -q '^---$' && grep -q '^description:' "$p" \
    && echo "skill OK: $f" || echo "skill FAIL: $f"
done

# 2. Subagents valid
for f in kanidm-admin rustfs-admin; do
  p=".opencode/agents/$f.md"
  test -f "$p" && grep -q '^mode: subagent' "$p" && grep -q '^description:' "$p" \
    && echo "agent OK: $f" || echo "agent FAIL: $f"
done

# 3. Ledger exists
test -s STASKBUILDER.md && echo "ledger OK"

# 4. No accidental writes into stacks/
git status --porcelain stacks/ | grep . && echo "WARNING: stacks/ modified" || echo "stacks/ clean"
```

Optional live check (if the `opencode` CLI is available): start a session in
`stacks/devops/identity-management/kanidm/` and confirm the skills are
discoverable (ancestor discovery) — validates the design's location decision.

## Dry-run validation matrix (design's testing strategy)

| Skill | Reference stack | What to check |
| --- | --- | --- |
| stack-init / readme-gen | `stacks/devops/identity-management/kanidm/` | checklist matches reality; templates reproduce existing READMEs |
| stack-test | `stacks/devops/secret-control/vaultwarden/` (oidc), `stacks/network-privacy/turn/coturn/` (cert-wait) | procedure steps executable |
| kanidm-oidc | `stacks/devops/identity-management/kanidm/` | CLI flags match installed version |
| rustfs-s3 | `stacks/devops/s3/storage/rustfs/` | mc commands work against endpoint |
| stack-modernize | any `src/`-layout stack (read-only walkthrough) | procedure matches actual legacy layout |
