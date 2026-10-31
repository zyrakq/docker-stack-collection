---
date: 2026-10-31
topic: "Skill set for docker-stack-collection projects"
status: validated
---

# Skill Set for Stack Initialization, Development, and Modernization

## Problem Statement

The collection has strong but undocumented conventions (sb/stackbuilder builds,
no-bind-mount policy, oidc/s3 extensions, step-ca testing flow, README
templates). Every AI session must re-derive them. We need a skill set that lets
an agent: (a) initialize new stacks of a needed type, (b) develop existing ones,
(c) bring legacy stacks to the current format, plus admin skills for kanidm
(OIDC provider) and rustfs (S3 provider).

## User-approved decisions

1. **Skills now, not MCP** — kanidm/rustfs tooling as skills with command
   cookbooks; MCP later only if limits are hit.
2. **Location**: `.opencode/skills/` at collection root. Rationale: OpenCode
   discovers config/skills through every filesystem ancestor, so skills work
   even when a session starts inside `stacks/<category>/<stack>/`. Reasons for
   decisions (specs, rationale) live as supporting files inside each skill
   directory — they travel with the skill.
3. **All skills, in phases**: Phase 1 = stack-conventions + stack-init +
   stack-test; Phase 2 = kanidm-oidc + rustfs-s3 (+ subagents kanidm-admin,
   rustfs-admin); Phase 3 = stack-modernize + readme-gen.

## Constraints

- No code from the designer; skills are markdown + optional wrapper scripts.
- Old stacks are NOT to be migrated unless explicitly requested.
- The live step-ca-manager test setup must never be modified.
- `stacks/` is gitignored by the collection repo → root-level grep/glob sees
  nothing inside stacks; each stack is its own git repo; search must target a
  specific stack path.
- Skills and their supporting docs in English (project docs are 100% English).

## Skill inventory

All under `/home/archuser/projects/docker-stack-collection/.opencode/skills/`:

### Phase 1

**1. stack-conventions** (reference skill, loaded by other skills)
Supporting file `rationale.md` = reasons for decisions. Content:
- Layout: stack repo → `app/` (main) + optional siblings (`ui/`, `server/`,
  `ch-ui/`, per-module dirs like loki-for-grafana) + `modules/` (git submodules,
  e.g. `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}` declared
  in stack-root `.gitmodules`). Legacy `src/<name>/` exists but is not the
  target format. Inner structure: `components/{base,environments[,extensions]}`
  + generated `build/` + `stackbuilder.toml` + README.md.
- sb/stackbuilder: Rust CLI at /home/archuser/projects/tools/stackbuilder
  (binary `sb`), only `sb init` / `sb build`, config hardcoded ./stackbuilder.toml.
  Dual environments API (`[build.environments]` with `available` + per-env
  `extensions`/`combos`/`skip_base_generation`). Known limitations (see
  STASKBUILDER.md): no cartesian matrix (hand-written combos are the
  workaround, cf. easytier), .env.example merge = concatenation, YAML arrays
  append-only, unknown TOML keys silently ignored (e.g. invalid
  `environments_path` in real stacks), no --config/dry-run/select.
- Volume policy: NEVER host bind mounts (breaks multi-host docker contexts;
  only allowed exception `/var/run/docker.sock:ro` for docker-gen companions).
  Named volumes with explicit `name: ${PROJECT_NAME:-<svc>}`; external
  volumes/networks to join SSL stack. Configs reach containers via
  `dockerfile_inline` COPY (preferred) or compose `configs.content` (tiny files
  only).
- dockerfile_inline patterns:
  - Config-into-image: `build: {context: ., dockerfile_inline: |}` with
    `FROM ${IMAGE:-default}` + `COPY <config> /etc/app/...` (examples: ferron,
    zot, kanidm base).
  - coturn cert-wait + gosu (stacks/network-privacy/turn/coturn/app/components/
    environments/step-ca/docker-compose.yml): `user: root`, /bin/sh -c entrypoint
    polls `/certs/$$COTURN_DOMAIN/key.pem` (sleep 3, `$$` escaping), chmod 644,
    `exec gosu nobody /usr/local/bin/docker-entrypoint.sh "$@"` — root only to
    fix perms, then drops to upstream user. No init containers (considered tech
    debt); no full shells in distroless.
  - kanidm delayed-start (distroless, no shell): inline Dockerfile builds a
    static `sleep` binary, `ENTRYPOINT ["/bin/sleep", "${START_DELAY:-10}"]`.
- Environments (variants, not dev/prod): forwarding (plain ports publish),
  letsencrypt, step-ca (external certs volume + network; structurally identical,
  differ only in volume/network names), legacy devcontainer (external workspace
  network), rare internal (own bridge only). Variant selection = cd into
  `build/<env>/<combo>/` after sb build (no compose profiles).
- OIDC policy: add `oidc` extension wherever the app supports it, include in
  default build, keep a no-oidc variant as proof of the tested pre-OIDC step.
  Provider = kanidm; issuer convention
  `https://<kanidm-domain>/oauth2/openid/<client-name>`.
- S3 policy: prefer native s3 (extension `s3-storage`, env-only fragment);
  otherwise s3fs-fuse planned, never on shared DB dirs.
- .env.example conventions: COMPOSE_PROJECT_NAME, PROJECT_NAME, IMAGE,
  LOG_MAX_SIZE/LOG_MAX_FILE/LOG_COMPRESS, VIRTUAL_PORT, VIRTUAL_HOST,
  LETSENCRYPT_HOST/EMAIL, OIDC block, STEP_CA_TRUST(_RESTART),
  REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt, SSL_CERT_FILE, TZ=UTC.
- step-ca integration (2 pieces): (1) env fragment adds
  `step-ca-certs:/certs` external volume + `step-ca-network` external network +
  VIRTUAL_HOST/VIRTUAL_PROTO/LETSENCRYPT_HOST/LETSENCRYPT_EMAIL + app TLS env
  (e.g. `ROCKET_TLS='{certs="/certs/${VIRTUAL_HOST}/fullchain.pem",key=...}'`);
  (2) `step-ca-trust` extension = STEP_CA_TRUST/STEP_CA_TRUST_RESTART env patch.
  Cert path convention: `/certs/<VIRTUAL_HOST>/fullchain.pem` and `key.pem`.
- nginx-proxy vhost.d tuning: compose configs.content written to shared
  `step-ca-vhost`/`letsencrypt-vhost` volume at `/vhost.d/${VIRTUAL_HOST}`
  (example zot: `client_max_body_size 0;`); rustfs shows the
  VIRTUAL_HOST_MULTIPORTS trick for multi-port vhosts.
- Operational gotcha: stacks/ gitignored — search inside a specific stack path.

**2. stack-init** (skill for initializing a new stack)
Workflow: determine stack type/category → create stack repo under
stacks/<category>/... → scaffold app/ (components/base with docker-compose.yml,
.env.example, config examples; environments forwarding/letsencrypt/step-ca as
applicable; extensions oidc/s3-storage/step-ca-trust as applicable) →
stackbuilder.toml (new environments API; env_file_patterns for app-native
config files, cf. numa's numa.toml trick) → README.md (delegate to readme-gen
rules) → .gitignore/.gitmessage/LICENSE-APACHE/LICENSE-MIT → add row to
stacks.csv (path;url;status, url `-` if no remote) → wire
modules/ssl-automation submodules if SSL needed → delete `.kilocode/`,
`.clinerules/` if present. Reference exemplars to imitate: kanidm (multi-project
with ui/ + mail-sender/), coturn (gosu pattern), vaultwarden (oidc +
step-ca-trust extensions), zot (config-into-image + vhost.d), distribution
(server/ + ui/registry-admin/ + real Dockerfile).

**3. stack-test** (testing procedure)
- ALWAYS test step-ca-manager variant first. The live step-ca-manager +
  companion + nginx-proxy + kanidm setup is running — NEVER modify it. If a
  problem is caused by it, switch to the forwarding variant, never touch the
  manager stack.
- letsencrypt variant is NOT tested; assume analogous to step-ca minus
  STEP_CA_TRUST env.
- STEP_CA_TRUST=true installs the CA bundle into the container;
  STEP_CA_TRUST_RESTART=true restarts it after install (trust is often not
  picked up on first boot).
- Some apps need explicit cert-path envs (example: open-webui
  REQUESTS_CA_BUNDLE / SSL_CERT_FILE).
- Services terminating TLS themselves (kanidm, coturn) need cert-wait patterns
  (kanidm delayed-start sleep entrypoint; coturn gosu poll loop).
- Verify: sb build output structure, docker compose config, up -d, health,
  OIDC login via kanidm, S3 round-trip when applicable.

### Phase 2

**4. kanidm-oidc** + subagent **kanidm-admin**
Cookbook for kanidm CLI (running container reachable under step-ca domain):
- create/modify OAuth2 clients per project, get client secret,
- create groups, create test users, add users to groups,
- adjust client settings per project (redirect URLs, scopes, claim mapping),
- reset idm_admin/admin passwords (careful, guarded procedure).
Reference stack: stacks/devops/identity-management/kanidm/. Subagent
`kanidm-admin`: executor with narrow mandate (only kanidm ops), refuses
destructive ops without explicit user confirmation.

**5. rustfs-s3** + subagent **rustfs-admin**
Cookbook for rustfs (stacks/devops/s3/storage/rustfs/: API 9000, console 9001,
RUSTFS_ACCESS_KEY/SECRET_KEY): create buckets, users/keys, policies; wire apps
via s3-storage extension env fragments (examples: gitea GITEA__storage__*,
linkwarden SPACES_*). Same guardrails as kanidm-admin.

### Phase 3

**6. stack-modernize**
Bring a started stack to current format, ONLY when explicitly requested:
src/→app/ rename, modules/ from src/ssl-automation/, add missing environments
(internal rare), add oidc/s3 extensions, remove `.kilocode/` and `.clinerules/`
(artifacts to delete in ALL projects — this part may be done opportunistically
without request), regenerate READMEs. Never touch pre-sb legacy stacks
(elasticsearch/kibana flat compose + deploy.sh) beyond the artifact cleanup.

**7. readme-gen**
Two templates distilled from the collection (canonical: keycloak component
README; hub style: kanidm/keycloak root):
- Stack-root hub README: `# 🔐 <Name> Stack`, 1-2 sentence description,
  `## 🧩 Components` (links + blurbs to app/README.md and
  modules/ssl-automation/*), `## 🚀 Quick Start` (cd app/ && sb build → cd
  build/<env>/<ext>/ → cp .env.example .env → docker compose up --build -d),
  `## 📋 Requirements`, `## 📄 License` (dual Apache-2.0/MIT verbatim).
- Component README (~100-250 lines): `# <emoji> <Service>` + one-liner "A
  modular Docker Compose configuration system for X…"; `## 🚀 Quick Start`
  (numbered sb build flow); `## 📁 Project Structure`; `## 🔧 Available
  Configurations` (### Environments / ### Extensions); `## 🔧 Environment
  Variables` grouped Base / Let's Encrypt / Step CA / OIDC / Step CA Trust,
  format `- `NAME`: description (default: X)`; `## 🌐 Networks`; `## 🔒
  Security` (⚠️ production checklist); `## 🆘 Troubleshooting`; `## 📝 Notes`
  (build/ auto-generated, do not edit).
- Rules: 100% English, emoji every heading, every command fenced with language
  tag, document letsencrypt/step-ca/OIDC variants when present, never present
  build/ as editable, reuse letsencrypt-manager/step-ca-manager module READMEs
  verbatim.

## STASKBUILDER.md

Create `/home/archuser/projects/docker-stack-collection/STASKBUILDER.md` —
living ledger of stackbuilder improvement proposals (file does not exist; the
tool's own docs live in /home/archuser/projects/tools/stackbuilder/). Seed with
the limitations found: (1) no cartesian product matrix — variants render
independently, cross-products hand-enumerated as named combos, combos can't
nest/parameterize/carry env-var overrides; (2) no per-variant variable values;
(3) global `extensions` silently ignored when [build.environments] used;
(4) opaque version-sensitive (num_envs, total_variants) layout heuristics;
(5) .env.example merge is concatenation, not unification; (6) YAML arrays
append-only (cannot remove/replace base ports/volumes); (7) only the literal
filename docker-compose.yml is merged (multi-file layering outside tool);
(8) no --config/select/dry-run/--output; (9) unknown TOML keys silently
ignored; (10) external yq required by default; (11) soft validation (typo'd
extension = silently degraded output); (12) .env restore exact-path only;
(13) init doesn't understand the new environments API. Plus the interim
workarounds within current capabilities: hand-written combos (easytier idiom),
env_file_patterns to preserve app-native configs (numa idiom), COMPOSE_FILE
layering as escape hatch.

## Subagent registration

Define `kanidm-admin` and `rustfs-admin` subagents in project
opencode config (.opencode/opencode.json `agents` field or agent definition
files — verify exact V2 format from https://opencode.ai/v2/docs/ before
writing). Skills format itself must also be verified from the V2 docs
(SKILL.md structure, frontmatter, discovery) before authoring.

## Error Handling

- If a skill's assumptions break (new sb version, changed layout), the skill is
  updated together with STASKBUILDER.md notes — skills are the single source of
  truth for conventions.
- Destructive operations (resetting admin passwords, deleting buckets/clients,
  modifying the live step-ca-manager setup) always require explicit user
  confirmation.

## Testing Strategy

- Skill validation: dry-run each skill against a reference stack (kanidm for
  init/readme, vaultwarden for oidc, coturn for cert-wait, rustfs for s3).
- stack-test skill is itself the acceptance procedure for every stack change.

## Open Questions

- Exact OpenCode V2 skills/agents file format (fetch docs during planning).
- Whether kanidm-admin/rustfs-admin need MCP wrappers later (defer).
