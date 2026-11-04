# OpenCode Stack Rework — Implementation Plan

**Goal:** Rework `stacks/self-hosting/ai-services/automation/opencode-stack` to the single-combo stackbuilder format with a user-supplied `plugins/` folder mechanism (STASKBUILDER L14 resolution).

**Architecture:** One base combo (`entire` / `entire-trust`) replaces the 12-combo cross-product. The plugins extension becomes inert-by-default: a committed `app/plugins/` folder holds ready-made install scripts; users copy them into a git-ignored `plugins/` folder next to the generated `docker-compose.yml`; the fragment's `dockerfile_inline` COPYs that folder (tolerating absence via the verified glob trick) and runs `install-*.sh` at build time; the BASE entrypoint gains the marker-injection block (inert without `/opt/plugins/.installed`). Build outputs are committed.

**Design:** User-mandated rework items (7, no scope changes) + STASKBUILDER.md L14 + PITFALLS.md P-022…P-031. Gitea precedent: `stacks/devops/version-control/gitea/app/stackbuilder.toml`.

**Repos touched:**
- Stack repo: `stacks/self-hosting/ai-services/automation/opencode-stack` (independent git repo, `main`) — tasks 1.x–3.1, 4.1–4.3
- Collection repo: `STASKBUILDER.md`, `PITFALLS.md` — tasks 4.4, 4.5 (separate commits)

---

## Design decisions (gap-fills by planner)

1. **How `app/plugins/` scripts reach the build context:** they DON'T automatically. The user copies them: `mkdir -p app/build/<env>/<combo>/plugins && cp app/plugins/*.sh app/build/<env>/<combo>/plugins/`. The folder's presence IS the opt-in (matches the L14 workaround sketch). Documented in `app/plugins/README.md` and `app/README.md`.
2. **COPY absence handling:** glob trick (empirically verified): `COPY entrypoint.sh plugins* /opt/plugins-build/` succeeds when `plugins/` is absent because the COPY has another matching source (BuildKit tolerates one non-matching glob among multiple sources). No `.dockerignore` needed.
3. **RUN convention:** every `install-*.sh` in the copied folder runs via `sh "$s"` (no exec bit needed); loop guards `[ -f "$s" ] || continue` so a folder without install scripts doesn't fail. Users can add their own `install-*.sh` alongside the ready-made ones.
4. **Base entrypoint injection:** the marker block from the old plugins `entrypoint.sh` moves verbatim into `app/components/base/entrypoint.sh`, guarded by `[ -d /opt/plugins/.installed ]` — inert in base-only builds. The step-ca-trust inline entrypoint chain (`exec /entrypoint.sh`) keeps working unchanged.
5. **`repo-local` stays out of combos** (swap-in alternative, postgresql↔pgrust §8 idiom): to switch, replace `"repo-sync"` with `"repo-local"` in the combo list in `stackbuilder.toml` and rebuild.
6. **`.env` stays gitignored** after `build/` is committed (conventions: stack `.gitignore` holds only `.env` + `.stackbuilder/`, plus the new user-plugins pattern). Committed build dirs contain no `.env`.
7. **Plugins extension dir keeps** `docker-compose.yml` (rewritten) + `.env.example` (unchanged, documents `PLUGINS_*` toggles); its `entrypoint.sh`, `common.sh`, `install-*.sh` are moved out.

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4, 1.5        [rewrites/configs — no deps]
Batch 2 (parallel): 2.1, 2.2, 2.3, 2.4, 2.5, 2.6   [script moves — depends on 1.2]
Batch 3:            3.1                             [rebuild + commit outputs — depends on all]
Batch 4 (parallel): 4.1, 4.2, 4.3, 4.4, 4.5        [docs — depends on 3.1]
```

**sb invocation note:** `sb` reads `./stackbuilder.toml` from cwd — always run from `app/`. One `sb build` generates ALL environments. Build layout: `app/build/<env>/<combo>/`.

---

## Batch 1: Rewrites & configs (parallel — 5 implementers)

### Task 1.1: Base entrypoint gains plugin marker injection
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/app/components/base/entrypoint.sh`
**Test:** none (shell syntax check)
**Depends:** none

Replace the ENTIRE file with:

```sh
#!/bin/sh
# Baked entrypoint: translate env vars into `opencode serve` flags.
# Upstream serve accepts only --hostname/--port/--cors (repeatable) flags.
# Plugin injection (inert unless the plugins extension baked markers under
# /opt/plugins/.installed): marker contents are concatenated into
# OPENCODE_CONFIG_CONTENT (virtual config doc, upstream v2.2.5
# packages/core/src/config.ts) — never written to the persistent config
# volume /data/config; skipped when OPENCODE_CONFIG_CONTENT is already set.
set -eu
ARGS="--hostname ${OPENCODE_SERVE_HOSTNAME:-0.0.0.0} --port ${OPENCODE_SERVE_PORT:-4096}"
for origin in ${OPENCODE_CORS_ORIGIN:-}; do
  ARGS="$ARGS --cors $origin"
done
if [ -z "${OPENCODE_CONFIG_CONTENT:-}" ] && [ -d /opt/plugins/.installed ]; then
  entries=""
  for marker in /opt/plugins/.installed/*; do
    [ -f "$marker" ] || continue
    entry="$(cat "$marker")"
    [ -n "$entry" ] || continue
    [ -z "$entries" ] || entries="$entries, "
    entries="$entries\"$entry\""
  done
  if [ -n "$entries" ]; then
    export OPENCODE_CONFIG_CONTENT="{\"plugins\": [$entries]}"
  fi
fi
exec opencode serve $ARGS
```

**Verify:** `sh -n stacks/self-hosting/ai-services/automation/opencode-stack/app/components/base/entrypoint.sh`
**Commit (stack repo):** `feat(app): add plugin marker injection to base entrypoint`

### Task 1.2: Plugins extension fragment — COPY optional plugins/ folder
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/app/components/extensions/plugins/docker-compose.yml`
**Test:** none (validated by rebuild in 3.1)
**Depends:** none

Replace the ENTIRE file with:

```yaml
# plugins extension: inert by default. It activates ONLY when a `plugins/`
# folder exists next to this docker-compose.yml (git-ignored, absent by
# default): copy the ready-made scripts from app/plugins/ (and/or your own
# install-*.sh) into it, set the PLUGINS_* toggles in .env, and rebuild the
# image. The toggles are consumed here (compose interpolates
# dockerfile_inline at config time) and baked as ENV so the install scripts
# see them. Install scripts drop marker files in /opt/plugins/.installed
# (content = literal plugin config entry); the BASE entrypoint reads them
# and exports OPENCODE_CONFIG_CONTENT={"plugins":[...]} — no runtime writes
# to the persistent config volume /data/config. This build mapping fully
# replaces the base dockerfile_inline (scalar override in the sb merger)
# and replicates the base layer (XDG roots, entrypoint) on top.
services:
  opencode-stack-app:
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE:-ghcr.io/anomalyco/opencode:2.2.5}
        # Pin all XDG roots + the config dir onto the persistent data volume
        # (same as the base layer).
        ENV XDG_DATA_HOME=/data \
            XDG_STATE_HOME=/data/state \
            XDG_CACHE_HOME=/data/cache \
            OPENCODE_CONFIG_DIR=/data/config
        # Plugin toggles, baked at build time (empty = disabled).
        ENV PLUGINS_MICODE=${PLUGINS_MICODE:-} \
            PLUGINS_DCP=${PLUGINS_DCP:-} \
            PLUGINS_RTK=${PLUGINS_RTK:-} \
            PLUGINS_HEADROOM=${PLUGINS_HEADROOM:-}
        RUN mkdir -p /data/opencode /data/state /data/cache /data/config /projects
        COPY entrypoint.sh /entrypoint.sh
        # entrypoint.sh is always present in the build dir (sb copies it from
        # the base component); plugins*/ matches the optional sibling folder —
        # absence is tolerated because the COPY has another matching source.
        COPY entrypoint.sh plugins* /opt/plugins-build/
        RUN chmod +x /entrypoint.sh \
          && if [ -d /opt/plugins-build/plugins ]; then \
               for s in /opt/plugins-build/plugins/install-*.sh; do \
                 [ -f "$$s" ] || continue; \
                 sh "$$s"; \
               done; \
             fi \
          && rm -rf /opt/plugins-build
        ENTRYPOINT ["/entrypoint.sh"]
```

Note the `$$s` escaping (compose interpolates `${...}` inside dockerfile_inline; `$$` → literal `$`, PITFALLS P-028).

**Verify:** YAML sanity — `docker compose -f stacks/self-hosting/ai-services/automation/opencode-stack/app/components/extensions/plugins/docker-compose.yml config -q` may fail on required vars; instead defer to 3.1. Quick check: file parses as YAML (`python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>`).
**Commit (stack repo):** `feat(app): plugins fragment COPYs optional plugins/ folder`

### Task 1.3: stackbuilder.toml — single combo, gitea format
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/app/stackbuilder.toml`
**Test:** none (validated by rebuild in 3.1)
**Depends:** none

Replace the ENTIRE file with:

```toml
[paths]
environments_path = "./environments"
extensions_dirs = ["extensions"]

[build]
skip_base_generation = true
copy_additional_files = true
env_file_patterns = [".env"]
# Documentation only (gitea idiom): the full extension menu. Combos below
# select from it. repo-local is a swap-in ALTERNATIVE to repo-sync (both own
# /projects — never list both): to switch, replace "repo-sync" with
# "repo-local" in the combo and rebuild. plugins is inert without a plugins/
# folder in the build dir (see app/plugins/README.md). step-ca-trust is
# MANDATORY in every step-ca combo and never listed outside step-ca.
extensions = ["repo-sync", "repo-local", "plugins", "step-ca-trust"]

[build.combos]
entire = ["repo-sync", "plugins"]
entire-trust = ["repo-sync", "plugins", "step-ca-trust"]

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
extensions = []
combos = ["entire"]

[build.environments.letsencrypt]
extensions = []
combos = ["entire"]

[build.environments.step-ca]
extensions = []
combos = ["entire-trust"]
```

`yaml_merger = "rust"` is REMOVED (forbidden). No `[build.environments.<env>] extensions` cross-products — one combo per environment.

**Verify:** none standalone; 3.1 is the gate.
**Commit (stack repo):** `refactor(app): single-combo stackbuilder config (gitea format)`

### Task 1.4: .gitignore — track build/, ignore user plugins folders
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/.gitignore`
**Test:** none
**Depends:** none

Replace the ENTIRE file with:

```
.env
.stackbuilder/
/app/build/*/*/plugins/
```

`build/` line REMOVED (build outputs get committed in 3.1). `.env` (unanchored) also keeps build-dir `.env` files out of the commits. The anchored pattern ignores user-copied `plugins/` folders in the 2-level-deep build layout.

**Verify:** `git -C stacks/self-hosting/ai-services/automation/opencode-stack check-ignore -v app/build/forwarding/entire/plugins/x` (after 3.1 creates dirs; otherwise skip).
**Commit (stack repo):** `chore: track build outputs, ignore user plugins folders`

### Task 1.5: .vscode/settings.json (gitea precedent)
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/.vscode/settings.json`
**Test:** none
**Depends:** none

Create with (identical to `stacks/devops/version-control/gitea/.vscode/settings.json`):

```json
{
  "git.openRepositoryInParentFolders": "never",
  "git.detectSubmodules": false,
  "git.scanRepositories": [],
  "git.autoRepositoryDetection": false,
  "files.associations": {
    "LICENSE-APACHE": "plaintext",
    "LICENSE-MIT": "plaintext",
    ".gitmessage": "plaintext"
  },
  "[dockerfile]": {
    "editor.formatOnSave": false
  },
  "files.exclude": {
    "**/.git": false
  }
}
```

**Verify:** `python3 -m json.tool stacks/self-hosting/ai-services/automation/opencode-stack/.vscode/settings.json`
**Commit (stack repo):** `chore: add vscode settings (gitea precedent)`

---

## Batch 2: Move plugin scripts to app/plugins/ (parallel — 6 implementers)

All moves are content-unchanged `git mv` (run inside the stack repo). Depends on 1.2 (old fragment no longer references these files).

### Task 2.1: Move common.sh
**File:** `app/components/extensions/plugins/common.sh` → `app/plugins/common.sh`
**Depends:** 1.2

```bash
cd stacks/self-hosting/ai-services/automation/opencode-stack
mkdir -p app/plugins && git mv app/components/extensions/plugins/common.sh app/plugins/common.sh
```

Content unchanged (helpers: `plugins_enabled`, `plugins_mark`, `plugins_marked`, `fetch_retry`).
**Verify:** `sh -n app/plugins/common.sh`
**Commit (stack repo):** `refactor(app): move plugin common.sh to app/plugins`

### Task 2.2: Move install-micode.sh
**File:** `app/components/extensions/plugins/install-micode.sh` → `app/plugins/install-micode.sh`
**Depends:** 1.2

Same `git mv` pattern as 2.1. Content unchanged (micode @ commit `2469fea962ba2d5926e8172b237a72750e16688c`, v2-adapter standalone copy + `npm install --omit=dev`).
**Verify:** `sh -n app/plugins/install-micode.sh`
**Commit (stack repo):** `refactor(app): move install-micode.sh to app/plugins`

### Task 2.3: Move install-dcp.sh
**File:** `app/components/extensions/plugins/install-dcp.sh` → `app/plugins/install-dcp.sh`
**Depends:** 1.2

Same `git mv` pattern. Content unchanged (`@tarquinen/opencode-dcp@3.2.0`, registry-validated, runtime install).
**Verify:** `sh -n app/plugins/install-dcp.sh`
**Commit (stack repo):** `refactor(app): move install-dcp.sh to app/plugins`

### Task 2.4: Move install-rtk.sh
**File:** `app/components/extensions/plugins/install-rtk.sh` → `app/plugins/install-rtk.sh`
**Depends:** 1.2

Same `git mv` pattern. Content unchanged (rtk v1.1.0 musl binary, sha256 `9454ad1b…c9378d`, `rtk init -g --opencode` → shim copy).
**Verify:** `sh -n app/plugins/install-rtk.sh`
**Commit (stack repo):** `refactor(app): move install-rtk.sh to app/plugins`

### Task 2.5: Move install-headroom.sh
**File:** `app/components/extensions/plugins/install-headroom.sh` → `app/plugins/install-headroom.sh`
**Depends:** 1.2

Same `git mv` pattern. Content unchanged (`headroom-ai==0.20.15`, staged pip `--no-deps`, no marker).
**Verify:** `sh -n app/plugins/install-headroom.sh`
**Commit (stack repo):** `refactor(app): move install-headroom.sh to app/plugins`

### Task 2.6: app/plugins/README.md
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/app/plugins/README.md`
**Depends:** 2.1–2.5 (folder exists)

Create with:

```markdown
# app/plugins — ready-made OpenCode plugin install scripts

Ready-made install scripts for the `plugins` extension. They are NOT used
from this folder directly: copy them into the build dir's `plugins/` folder
(git-ignored, absent by default) next to `docker-compose.yml`:

    mkdir -p app/build/<env>/<combo>/plugins
    cp app/plugins/*.sh app/build/<env>/<combo>/plugins/

Then set the per-plugin toggles in `.env` (see the plugins extension
`.env.example`): `PLUGINS_MICODE` / `PLUGINS_DCP` / `PLUGINS_RTK` /
`PLUGINS_HEADROOM`, and `docker compose build`.

`docker compose build` runs every `install-*.sh` found in the folder at
image build time; the base entrypoint injects the resulting plugin entries
via `OPENCODE_CONFIG_CONTENT`. Add your own `install-*.sh` scripts
alongside — same convention, same marker mechanism (see `common.sh`).

⚠️ `sb build` regenerates the build dirs and wipes `plugins/` folders —
re-copy after every rebuild.
```

**Verify:** file exists; links/paths match reality.
**Commit (stack repo):** `docs(app): plugins folder usage readme`

---

## Batch 3: Rebuild & commit build outputs

### Task 3.1: Rebuild all 3 env outputs and commit them
**File:** `app/build/**` (generated)
**Depends:** 1.1–1.5, 2.1–2.6

```bash
cd stacks/self-hosting/ai-services/automation/opencode-stack
rm -rf app/build          # removes the stale 12-combo layout
cd app && sb build        # sb reads ./stackbuilder.toml from cwd
cd ..
find app/build -maxdepth 3 -type d | sort
# expect exactly: app/build/{forwarding,letsencrypt}/entire and app/build/step-ca/entire-trust
```

Verify each generated dir (compose config with a dummy required var; `.env` must NOT exist in committed tree):

```bash
for d in app/build/forwarding/entire app/build/letsencrypt/entire app/build/step-ca/entire-trust; do
  (cd "$d" && OPENCODE_SERVER_PASSWORD=x docker compose config -q && echo "OK $d")
done
git status --short | grep -E '\.env$' && echo "FAIL: .env staged" || echo "OK: no .env staged"
```

Then commit the build outputs:

```bash
git add app/build && git commit -m "chore(app): rebuild committed build outputs (entire combos)"
```

**Optional deeper gate (recommended, needs Docker):** in `app/build/forwarding/entire`, `mkdir plugins && cp ../../plugins/*.sh plugins/`, `cp .env.example .env`, set `OPENCODE_SERVER_PASSWORD` + all four `PLUGINS_*` toggles, `docker compose build` — expect all 4 install scripts to run and markers to appear. This is the full stack-test Stage A pre-check; the complete browser E2E gate is a separate stack-test run, not part of this plan.
**Commit (stack repo):** included above.

---

## Batch 4: Docs & ledgers (parallel — 5 implementers)

### Task 4.1: DEPLOYMENT.md — plugins row + combo names
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/DEPLOYMENT.md`
**Depends:** 3.1

- Line ~121 (`plugins` catalog row): rewrite the mechanism description — user-supplied git-ignored `plugins/` folder next to the generated `docker-compose.yml` (absent by default), ready-made scripts committed at `app/plugins/` (copied in by the user), fragment `dockerfile_inline` replicates the base layer + `COPY entrypoint.sh plugins* /opt/plugins-build/` (absence-tolerant glob) + `RUN` of every `install-*.sh`, base entrypoint does the `OPENCODE_CONFIG_CONTENT` marker injection (no extension-local entrypoint anymore). Keep all pins/versions and the gate evidence sentence; update the gate combo reference to `step-ca/entire-trust`.
- Grep the whole file for old combo names (`-repo-sync`, `-repo-local`, `-plugins`, e.g. `step-ca-repo-sync` in the `step-ca-trust` row ~line 122) and replace with the new combo names (`entire`, `entire-trust`).
- Line ~112 (`repo-local`, `plugins`, and `step-ca-trust` are implemented…): keep, only adjust combo wording if it names old combos.

**Verify:** `grep -nE '(forwarding|letsencrypt|step-ca)-(repo-sync|repo-local|repo-sync-plugins)' DEPLOYMENT.md` returns nothing.
**Commit (stack repo):** `docs: deployment model for plugins-folder mechanism + entire combos`

### Task 4.2: app/README.md — plugins mechanism + new build paths
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/app/README.md`
**Depends:** 3.1

- Quick Start step 2 paths: `build/forwarding/` → `build/forwarding/entire/` (same for letsencrypt; step-ca → `build/step-ca/entire-trust/`).
- Project Structure: add `plugins/` (ready-made install scripts, copied into build-dir `plugins/` folders) alongside components/.
- Extensions section: rewrite the `plugins` bullet (line ~99) to the new mechanism (inert without folder; copy from `app/plugins/`; toggles; base entrypoint injection; sb rebuild wipes the folder — re-copy). Note `repo-local` is a swap-in alternative (edit the combo in `stackbuilder.toml`), and combos are now `entire` / `entire-trust`.
- Replace "`sb build` generates all combo directories under `build/`" wording with the single-combo-per-env layout.

**Verify:** `grep -n 'build/forwarding/$' app/README.md` returns nothing; plugins bullet mentions `app/plugins/`.
**Commit (stack repo):** `docs(app): plugins-folder mechanism and entire-combo paths`

### Task 4.3: Stack-root README — quick start path
**File:** `stacks/self-hosting/ai-services/automation/opencode-stack/README.md`
**Depends:** 3.1

Quick Start: `cd build/forwarding` → `cd build/forwarding/entire` (mention `letsencrypt/entire`, `step-ca/entire-trust`). Components section: mention the committed `app/plugins/` folder + optional build-dir `plugins/` mechanism in the OpenCode Server bullet.

**Verify:** `grep -n 'cd build/forwarding$' README.md` returns nothing.
**Commit (stack repo):** `docs: quick start paths for entire combos`

### Task 4.4: STASKBUILDER.md L14 → settled (collection repo)
**File:** `STASKBUILDER.md` (collection repo root)
**Depends:** 3.1

Line 60: change `### L14. Script-style features can't be combined as extensions — \`proposal\`` to `— \`settled\`` and append a resolution paragraph:

> Resolved in opencode-stack: script-style features ship as a committed
> `app/plugins/` folder of ready-made install scripts; users opt in by
> copying them into a git-ignored `plugins/` folder next to the generated
> `docker-compose.yml`; the extension's `dockerfile_inline` COPYs that
> folder (absence-tolerant glob) and runs `install-*.sh` at build time; the
> base image's `entrypoint.sh` does the config injection. Combos collapsed
> to one per environment (`entire` / `entire-trust`).

Keep the "Interim workarounds" bullet (historical record). Match the status vocabulary of sibling entries.

**Verify:** `grep -n 'L14' STASKBUILDER.md` shows `settled`.
**Commit (collection repo):** `docs(staskbuilder): settle L14 via opencode plugins-folder rework`

### Task 4.5: PITFALLS.md — close entries fixed by this rework (collection repo)
**File:** `PITFALLS.md` (collection repo root)
**Depends:** 3.1

Review P-022…P-031 (lines ~272–335). For each entry the rework resolves, set `status: fixed` and fill `fix:` (entries are never deleted). Expected closures: the `yaml_merger = "rust"` prohibition entry (removed in 1.3), the combo-explosion / script-style-extension entries (single combo + plugins folder), and any entry about committed build outputs or the COPY-absence trick — set `hits` unchanged, update `last` to today. Leave entries unrelated to this rework untouched. If a new obstacle was hit during 3.1 (e.g. sb behavior surprises), append a new entry (`hits: 1`, `status: open`).

**Verify:** `grep -n 'status: fixed' PITFALLS.md` includes the rework-related IDs; no entry deleted.
**Commit (collection repo):** `docs(pitfalls): close entries fixed by opencode-stack rework`

---

## Risks & notes for implementers

- **sb rebuild wipes user `plugins/` folders** in build dirs — documented in `app/plugins/README.md` and `app/README.md`; re-copy after rebuild.
- **Stale 12-combo dirs** are removed by `rm -rf app/build` in 3.1 before rebuild; verify only 4 dirs remain (3 envs × 1 combo each).
- **L3 (top-level extensions silently ignored with the environments API)** — documented intentionally in STASKBUILDER; extensions must live in `app/components/extensions/` (unchanged here).
- **step-ca-trust chaining** relies on `/entrypoint.sh` being the base entrypoint — preserved by 1.1 + 1.2 (fragment still COPYs `entrypoint.sh` to `/entrypoint.sh`).
- **Base image** `ghcr.io/anomalyco/opencode:2.2.5` (no `v` prefix, P-022); alpine/busybox, no node/npm/git/pip — install scripts `apk add` as needed (unchanged).
- **No scope changes:** exactly the 7 mandated items; no agents/skills edits; no host-level actions.
- **Commits:** stack-repo tasks commit in the stack repo; 4.4/4.5 commit in the collection repo. Never commit `.env`.
