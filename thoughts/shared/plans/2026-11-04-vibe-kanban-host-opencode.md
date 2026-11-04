# vibe-kanban host `opencode` extension Implementation Plan

**Goal:** Add ONE extension `opencode` to `stacks/self-hosting/ai-services/automation/vibe-kanban` component `app/host` that delivers opencode settings (provider API keys, `OPENCODE_CONFIG_CONTENT`, optional `opencode.json`) to the host container.

**Architecture:** Env-only settings via `${VAR:-}` in the fragment; the optional global config file is delivered with `dockerfile_inline` (FROM the unchanged base image, `COPY --chown` to `~/.config/opencode/opencode.json`), shipped as `opencode.json.example` and preserved/copied into `build/` via `env_file_patterns` (numa idiom). No new volumes (opencode state lives in `/data/opencode`). Combos `step-ca-opencode-repo-sync` / `step-ca-opencode-repo-local` (step-ca variant first).

**Design:** none (request-driven; decisions below).

Stack root (`$S`): `stacks/self-hosting/ai-services/automation/vibe-kanban`; component (`$H`): `$S/app/host`. Stack is its own git repo — commit stack files inside `$S`; this plan lives in the main repo.

## Verified against upstream (BloopAI/vibe-kanban @7c38070, 2026-11-04)
- `crates/executors/src/executors/opencode.rs`: executor spawns `npx -y opencode-ai@1.4.7 serve --hostname 127.0.0.1 --port 0` (pinned 1.4.7; the image's global `opencode-ai@latest` is NOT used unless `base_command_override`). npx downloads the package at first run (no cache volume; reinstall after container recreate is accepted).
- Env: executor sets `NPM_CONFIG_LOGLEVEL`, `NODE_NO_WARNINGS`, `NO_COLOR`, `OPENCODE_SERVER_USERNAME/PASSWORD`, `OPENCODE_PERMISSION` (when not auto-approve), then `ExecutionEnv.with_profile(cmd).apply_to_command`; no `env_clear` -> container env (provider keys) is inherited by the child. `env.rs`: profile env (`CmdOverrides.env`) overrides.
- `setup_compaction_env` READS the existing `OPENCODE_CONFIG_CONTENT` and MERGES `compaction` JSON into it (not overwrites) -> user-supplied value is supported.
- XDG: image sets `XDG_DATA_HOME=/data`, so opencode data/auth.json = `/data/opencode` (already persisted by `vibe-kanban-host-data`, NOT `~/.local/share/opencode`). Config dir = `~/.config/opencode` (= `/home/appuser/.config/opencode`).
- opencode docs (opencode.ai/docs/config): precedence remote < global `~/.config/opencode/opencode.json` < `OPENCODE_CONFIG` < project < `.opencode` < `OPENCODE_CONFIG_CONTENT`; `{env:VAR}` substitution supported in config; configs merged.

## Decisions
- Do NOT mount any volume for opencode (user decision: no npm-cache volume; a volume on `~/.config/opencode` would also shadow the COPY'd config). opencode state/auth already lives in `/data/opencode`.
- Extension overrides `image:` with `${OPENCODE_IMAGE:-localhost/vibe-kanban-host-opencode:0.1.45}` so the build does not retag the base tag; `FROM ${IMAGE:-localhost/vibe-kanban-host:0.1.45}`.
- Config file `opencode.json` default content `{}`-compatible with `{env:...}` references; keys are never baked into the image (use `{env:ANTHROPIC_API_KEY}`).
- Mutually exclusive combos unchanged: opencode combines with exactly one repo extension.

## Dependency Graph
```
Batch 1 (parallel): 1.1, 1.2, 1.3   [extension files]
Batch 2 (parallel): 2.1             [stackbuilder.toml, depends 1.x]
Batch 3 (parallel): 3.1, 3.2, 3.3, 3.4 [docs]
Batch 4 (serial):   4.1             [sb build + stack-test gate]
```

## Batch 1: Extension files

### Task 1.1: compose fragment
**File:** `$H/components/extensions/opencode/docker-compose.yml`
**Test:** `cd $H && docker compose -f components/extensions/opencode/docker-compose.yml config -q` is not meaningful alone; validated in 4.1.
**Depends:** none

```yaml
# opencode: opencode settings for the host executor (provider keys, inline config, optional opencode.json).
# Config file is baked via dockerfile_inline (no bind mounts); keys come from env only ({env:VAR} in opencode.json).
# Combine with exactly one repo extension (repo-sync | repo-local) and step-ca-trust.
services:
  vibe-kanban-host:
    image: ${OPENCODE_IMAGE:-localhost/vibe-kanban-host-opencode:0.1.45}
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE:-localhost/vibe-kanban-host:0.1.45}
        USER root
        RUN mkdir -p /home/appuser/.config/opencode \
            && chown -R 10001:10001 /home/appuser/.config
        COPY --chown=10001:10001 opencode.json /home/appuser/.config/opencode/opencode.json
        USER 10001
    environment:
      OPENCODE_CONFIG_CONTENT: ${OPENCODE_CONFIG_CONTENT:-}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
      OPENAI_API_KEY: ${OPENAI_API_KEY:-}
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:-}
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      GROQ_API_KEY: ${GROQ_API_KEY:-}
      OPENCODE_MODEL: ${OPENCODE_MODEL:-}
```
Note: empty-string `OPENCODE_CONFIG_CONTENT` must not break upstream merge — verify in 4.1 (if opencode rejects empty string, switch to omitting via `${OPENCODE_CONFIG_CONTENT:-{}}`). Check the base's final `USER` in `images/vibe-kanban-host/Dockerfile` and replace `USER 10001` with it.

**Commit (in $S):** `feat(host): add opencode extension compose fragment`

### Task 1.2: .env.example fragment
**File:** `$H/components/extensions/opencode/.env.example`
**Depends:** none

```
# opencode extension (only vars referenced by its compose fragment)
OPENCODE_IMAGE=localhost/vibe-kanban-host-opencode:0.1.45
OPENCODE_CONFIG_CONTENT=
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
OPENROUTER_API_KEY=
GEMINI_API_KEY=
GROQ_API_KEY=
OPENCODE_MODEL=
```
**Commit:** `feat(host): add opencode extension env example`

### Task 1.3: example config
**File:** `$H/components/extensions/opencode/opencode.json.example`
**Depends:** none

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "{env:OPENCODE_MODEL}",
  "autoupdate": false,
  "provider": {
    "anthropic": { "options": { "apiKey": "{env:ANTHROPIC_API_KEY}" } },
    "openrouter": { "options": { "apiKey": "{env:OPENROUTER_API_KEY}" } }
  },
  "mcp": {}
}
```
Caveat: `{env:OPENCODE_MODEL}` expands to "" when unset — in 4.1 confirm opencode tolerates it; otherwise drop the `model` key from the example and from compose/.env.example (keep them consistent).
**Commit:** `feat(host): add opencode.json example`

## Batch 2

### Task 2.1: stackbuilder.toml
**File:** `$H/stackbuilder.toml`
**Depends:** 1.1, 1.2, 1.3

Edits (exact):
- add `env_file_patterns = [".env", "opencode.json"]` under `[build]` (copy `opencode.json.example` -> `opencode.json` convention as numa; if sb requires the real file, `cp` example in 4.1 and document in README).
- `extensions = ["step-ca-trust", "repo-sync", "repo-local", "opencode"]`
- combos:
```toml
[build.combos]
step-ca-repo-sync = ["step-ca-trust", "repo-sync"]
step-ca-repo-local = ["step-ca-trust", "repo-local"]
step-ca-opencode-repo-sync = ["step-ca-trust", "opencode", "repo-sync"]
step-ca-opencode-repo-local = ["step-ca-trust", "opencode", "repo-local"]
```
- `[build.environments.step-ca]`: `combos = ["step-ca-opencode-repo-sync", "step-ca-opencode-repo-local", "step-ca-repo-sync", "step-ca-repo-local"]` (step-ca variant first; existing combos kept).

**Verify:** `cd $H && sb build` succeeds; `build/step-ca/step-ca-opencode-repo-sync/docker-compose.yml` contains the `build:` block, `user: root` entrypoint from step-ca-trust; `docker compose config -q` on each opencode combo.
**Commit:** `feat(host): wire opencode extension and combos`

## Batch 3: Docs (parallel, one file each)

- 3.1 `$S/DEPLOYMENT.md`: catalog row `| opencode (host settings: provider keys, config) | product | implemented | host; combines with one repo extension + step-ca-trust |`; remove/adjust nothing else. Also replace "extra executor CLIs" row note only if it overlaps (leave).
- 3.2 `$S/UPSTREAM.md` (append-only): row `| 2026-11-04 | 7c3807084daad0d9d315064f60fa869de254f027 | localhost/vibe-kanban-host-opencode:0.1.45 (FROM base) | opencode executor: npx opencode-ai@1.4.7, inherits env, merges OPENCODE_CONFIG_CONTENT; opencode data in /data/opencode |`.
- 3.3 `$H/README.md`: extension section: env vars table, `cp components/extensions/opencode/opencode.json.example` flow, note data in `/data/opencode`, mutual exclusivity with repo ext, combos.
- 3.4 `/home/archuser/projects/docker-stack-collection/PITFALLS.md` (main repo): append only if 4.1 hits an obstacle (e.g. build `image:` retag, empty env var, volume ownership); otherwise skip.

## Batch 4: Gate

### Task 4.1: stack-test (load `stack-test` skill first)
Step-ca variant FIRST, never touching the live step-ca-manager:
1. `cd $H && sb build`; `docker compose config -q` for both opencode combos.
2. Up `step-ca-opencode-repo-sync` with `ANTHROPIC_API_KEY=sk-test`, `OPENCODE_CONFIG_CONTENT='{"autoupdate":false}'`.
3. Checks: `docker exec vibe-kanban-host sh -c 'id; echo $ANTHROPIC_API_KEY; cat /home/appuser/.config/opencode/opencode.json'`.
4. Browser E2E (agent-browser): open host UI, create task with OPENCODE executor, verify opencode process starts (`docker exec ... ps | grep opencode-ai`), `docker exec ... npx opencode-ai@1.4.7 debug config` (as 10001) shows provider options and merged config (key resolved from env).
5. Repeat quickly for `step-ca-opencode-repo-local`; confirm `/repos` still works (repo gate not regressed).
6. Update PITFALLS.md (3.4) and README status; commit in $S; push NOTHING.
