# Project Rules

## Artifacts must be committed immediately

Every file created under `thoughts/shared/` (design docs in `designs/`,
implementation plans in `plans/`, ledgers) MUST be committed to git in the
same session, immediately after it is written — before spawning any next
subagent (planner, executor, etc.). Never leave these files untracked or
uncommitted at the end of a response.

Checklist per workflow step:

- design doc written → `git add` + `git commit` right away
- plan written by planner → commit it right away (do not wait for executor)
- execution results → already committed by the executor; verify with
  `git status` and commit anything left untracked

## Pitfalls ledger (PITFALLS.md)

`PITFALLS.md` at this repo root is the shared log of recurring obstacles
(deployment configs, `sb`, docker compose, OIDC/S3/step-ca, stack testing).

- Before debugging an infra/tooling problem, check the ledger: walk up from
  cwd to find `PITFALLS.md`; if not found, use the canonical path
  `/home/archuser/projects/docker-stack-collection/PITFALLS.md`.
- After hitting an obstacle: if already recorded, increment its `hits` and
  update `last`; if new, append an entry (`hits: 1`, `status: open`).
- When a problem gets a real fix, set `status: fixed` and fill `fix:` —
  entries are never deleted.
- Never leave an encountered obstacle unrecorded at the end of a session.

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

## Source-built images — no vendoring (stack work)

When a stack's app has no published Docker image and must be built from
source, agents MUST follow the `source-image` skill and stack-conventions
§19:

- NEVER vendor upstream source into the stack repo — no git submodules of
  the upstream app, no copied source trees. `modules/` is ONLY for the
  ssl-automation managers. The clone-in-tmp clone is reference-only.
- The build lives in `app/images/<image>/Dockerfile`, fully self-contained:
  it downloads release binaries/archives or clones the upstream repo at a
  pinned tag/commit itself; builds with an empty build context.
- Compose references the prebuilt image via
  `image: ${IMAGE:-localhost/<image>:<tag>}` — never a `build:` section.
