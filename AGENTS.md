# Project Rules

## Host safety — iron rules (NEVER touch the host system)

Agents in this repo are guests on the user's machine. The host is NOT ours
to reconfigure. The complete allowlist of host-level actions:

- edit/create files inside this repo (scratch work in `/tmp/opencode`)
- git operations (clone into /tmp, add, commit, push, pull)
- read-only inspection: logs, `free -h`, `df -h`, `docker ps/logs/stats`
- `docker` / `docker compose` commands as permitted by stack-conventions
- commands from the `kanidm-oidc` and `rustfs-s3` skills

Everything else on the host is FORBIDDEN, no exceptions, no improvisation:

- `sudo` / `doas` / `su` in ANY form (including `sudo -n sh -c '...'`)
- swap and block devices: `mkswap`, `swapon`, `swapoff`, `losetup`, `mknod`,
  `/swapfile`, loop devices
- host package managers: `pacman`, `apt`, `dnf`, `cargo install`, `pip install`
- system config: `sysctl`, `modprobe`, `mount`/`umount`, writing to `/etc`,
  `systemctl`, udev rules, kernel modules
- disks and partitions: `fdisk`, `parted`, `mkfs`, `dd` to devices
- killing or restarting system services/processes outside our docker scope

If a build or test fails due to memory/disk/CPU pressure: do NOT "fix" the
host. Report the failure to the user with observed numbers, suggest options
(less build parallelism, smaller image, retry later), and STOP.

Incident 2026-11-01: during an image build an agent ran
`sudo -n sh -c 'losetup ...; mknod /dev/loop1 ...; mkswap ...; swapon ...'`
to "add swap" and nearly broke the server. This section exists because of
that. Never repeat anything like it.

## Agents and skills — never redefine without explicit user confirmation

Agents and skills are the user's tooling, NOT ours to change on our own
initiative.

- Agent definitions OUTSIDE this repo (e.g. under the home directory) are
  never touched by agents working here — not modified, not rewritten, not
  deleted. No confirmation makes this allowed; it is simply out of scope.
- Redefining, rewriting, restructuring, or deleting project-level agents
  and skills (`.opencode/skills/**`, any agent/skill config inside this
  repo) is FORBIDDEN without the user's explicit confirmation FIRST.

This applies even when a plan or design doc lists such edits as tasks: a
documented task is NOT consent. Show the user exactly what will change and
wait for his explicit approval before touching any of these files. Edits to
stack repos and `thoughts/shared/` documents follow the normal workflow —
this rule is about tooling definitions only.

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

## File-less directories need a .gitkeep

Git does not track empty directories, and IDEs hide or collapse a folder
whose only content is another folder — intermediate directories disappear
from the project tree. Rule:

- Whenever a directory contains only other directories, put an empty `.gitkeep` file in it and commit it.
- Apply this everywhere you create or restructure directories — in this
  repo and in stack repos. If you add `a/b/c.txt` and `a` would contain
  nothing but `b`, also create `a/.gitkeep`.
- `.gitkeep` is a pure placeholder: empty file, never referenced by
  configs, scripts, or tooling.
- Respect `.gitignore` as everywhere else: if the directory's contents
  are ignored (e.g. cloned stack repos under `stacks/`), do not force-add
  anything.

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

- Deployment model: any new stack — and any change to a product's part
  scope — begins with the `stack-analysis` skill; the committed
  `DEPLOYMENT.md` (stack-conventions §20) is the contract for the
  functional base (product parts + mandatory infra) and the extension
  catalog. Mandatory infra (database, OIDC, S3 — or other
  product-mandated infra) is ALWAYS attempted — refusal only with the
  reason recorded; every other extension needs explicit user
  confirmation before implementation. Missing functional-base parts are
  completed BEFORE any extension work; stack-test Stage A (product
  parts + database) runs the DEPLOYMENT.md functional gate scenario.
- Naming: the main product service/container is exactly `<stack>`; other
  parts are `<stack>-<role>` (e.g. `<stack>-db`). The `-app` suffix is
  BANNED — never `<stack>-app`. `container_name` equals the service name; networks
  `<stack>-network`, volumes `<stack>-<purpose>`. No generic names, no
  unused `PROJECT_NAME`-style vars.
- Env: every compose env value is overridable (`${VAR}` /
  `${VAR:?}`), defaults only in `.env.example` — never hardcoded. `.env.example` holds only vars the
  compose files actually reference; optional vars live in extension
  fragments only.
- Layering: environment-dependent vars (public URLs, TLS-derived
  defaults) are declared only in environment overlays, never in base.
- Postgres: always the `database/{postgresql,pgrust}` extension pair —
  never a base-compose service; `postgres:alpine` (latest, not the
  upstream-pinned version); volume mounted at `/var/lib/postgresql`.
- Staged protocol: base implementation first → test gate → extensions
  one at a time (pgrust after base passes — becomes default if clean;
  oidc/s3 only after base passes; rclone s3-rclone never on DB volumes). Never
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
