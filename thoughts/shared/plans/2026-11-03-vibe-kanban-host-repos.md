# Vibe Kanban host: git repos (repo-sync, repo-local) Implementation Plan

**Goal:** Give the `app/host` container git repos via two extensions: `repo-sync` (sidecar clone/pull into a named volume) and `repo-local` (bind mount of a local path).

**Architecture:** Upstream has no env var for the repos dir. The host image has `WORKDIR /repos`, and the UI/API discovers git repos under cwd (`GET /api/filesystem/git-repos?path=/repos`) and registers them via `POST /api/repos {path}`. Both extensions therefore mount something at `/repos` (uid 10001 must be able to write there; worktrees live in `vibe-kanban-host-worktrees`). They are mutually exclusive (both target `/repos`). Decision: repo-sync mounts volume `vibe-kanban-host-repos` at `/repos`; repo-local mounts `${REPOS_PATH:?}` at `/repos`.

**Design:** user request (no design doc). Upstream reference: clone at `/tmp/opencode/upstreams/vibe-kanban-host` @ 7c3807084daad0d9d315064f60fa869de254f027.

**Scope note:** Remote/relay work is PAUSED. Never touch the live step-ca-manager setup. Stack root = `stacks/self-hosting/ai-services/automation/vibe-kanban` (paths below relative to it; it is its own git repo, commit there).

## Dependency Graph
```
Batch 1 (parallel): 1.1 repo-sync compose, 1.2 repo-sync env, 1.3 repo-local compose, 1.4 repo-local env
Batch 2 (parallel): 2.1 stackbuilder.toml, 2.2 DEPLOYMENT.md   [depends 1.*]
Batch 3 (sequential gate): 3.1 repo-sync Stage G (step-ca)      [depends 2.*]
Batch 4 (sequential gate): 4.1 repo-local Stage H (step-ca)     [depends 3.1]
Batch 5 (parallel): 5.1 UPSTREAM.md, 5.2 PITFALLS.md, 5.3 app/host README, 5.4 cleanup [depends 4.1]
```
Environments: `repo-sync`/`repo-local` are added to the step-ca environment first (with step-ca-trust); forwarding/letsencrypt get them only after the gates pass. To test one at a time, a test build lists only one extension in `stackbuilder.toml` at a time.

---
## Batch 1: Extension fragments

### Task 1.1: repo-sync compose
**File:** `app/host/components/extensions/repo-sync/docker-compose.yml`
**Test:** `docker compose config` (Verify below)
**Depends:** none

```yaml
# repo-sync: sidecar clones/pulls a git repo into a named volume shared with the host (/repos).
# Mutually exclusive with repo-local (both mount /repos).
services:
  vibe-kanban-host:
    volumes:
      - vibe-kanban-host-repos:/repos
    depends_on:
      vibe-kanban-repo-sync:
        condition: service_started

  vibe-kanban-repo-sync:
    image: ${REPO_SYNC_IMAGE:-alpine/git:latest}
    container_name: vibe-kanban-repo-sync
    restart: unless-stopped
    user: root
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        set -eu
        URL="$${REPO_SYNC_URL}"
        BRANCH="$${REPO_SYNC_BRANCH:-main}"
        NAME="$${REPO_SYNC_DIR_NAME:-}"
        [ -n "$$NAME" ] || NAME="$$(basename "$${URL%.git}")"
        DEST="/repos/$$NAME"
        if [ -n "$${REPO_SYNC_TOKEN:-}" ]; then
          # token via https credential helper (not stored in the URL / .git/config)
          export GIT_ASKPASS=/tmp/askpass.sh
          printf '#!/bin/sh\necho "$$REPO_SYNC_TOKEN"\n' > /tmp/askpass.sh
          chmod 700 /tmp/askpass.sh
          export GIT_USERNAME="$${REPO_SYNC_USER:-x-access-token}"
          git config --global credential.username "$$GIT_USERNAME"
        fi
        if [ -n "$${REPO_SYNC_SSH_KEY:-}" ]; then
          printf '%s\n' "$$REPO_SYNC_SSH_KEY" > /tmp/id_sync
          chmod 600 /tmp/id_sync
          export GIT_SSH_COMMAND="ssh -i /tmp/id_sync -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/tmp/known_hosts"
        fi
        git config --global --add safe.directory '*'
        while true; do
          if [ -d "$$DEST/.git" ]; then
            git -C "$$DEST" fetch --prune origin "$$BRANCH" && git -C "$$DEST" merge --ff-only "origin/$$BRANCH" \
              || echo "repo-sync: pull failed (local changes?), will retry"
          else
            git clone --branch "$$BRANCH" "$$URL" "$$DEST" || echo "repo-sync: clone failed, will retry"
          fi
          chown -R 10001:10001 "$$DEST" 2>/dev/null || true
          sleep "$${REPO_SYNC_INTERVAL:-300}"
        done
    environment:
      - REPO_SYNC_URL=${REPO_SYNC_URL:?}
      - REPO_SYNC_BRANCH=${REPO_SYNC_BRANCH:-main}
      - REPO_SYNC_DIR_NAME=${REPO_SYNC_DIR_NAME:-}
      - REPO_SYNC_TOKEN=${REPO_SYNC_TOKEN:-}
      - REPO_SYNC_USER=${REPO_SYNC_USER:-x-access-token}
      - REPO_SYNC_SSH_KEY=${REPO_SYNC_SSH_KEY:-}
      - REPO_SYNC_INTERVAL=${REPO_SYNC_INTERVAL:-300}
      - TZ=${TZ:-UTC}
    volumes:
      - vibe-kanban-host-repos:/repos
    networks:
      - vibe-kanban-host-network

volumes:
  vibe-kanban-host-repos:
    name: vibe-kanban-host-repos
```
Note: GIT_ASKPASS script answers both username/password prompts with the token; for GitHub this works (token as username). Implementer: if the clone of a private https repo fails in the gate, set `REPO_SYNC_USER` handling in the askpass script (case on "Username") and record in PITFALLS.

**Verify:** see Task 2.1 gate (`sb build` + `docker compose config`).
**Commit:** `feat(host): add repo-sync extension`

### Task 1.2: repo-sync env
**File:** `app/host/components/extensions/repo-sync/.env.example`
**Depends:** none
```
# repo-sync: clone/pull a repo into the shared /repos volume
REPO_SYNC_IMAGE=alpine/git:latest
REPO_SYNC_URL=https://github.com/example/repo.git
REPO_SYNC_BRANCH=main
# Optional: directory name under /repos (default: basename of URL)
REPO_SYNC_DIR_NAME=
# Optional private access: https token OR ssh private key (multi-line escaped)
REPO_SYNC_TOKEN=
REPO_SYNC_USER=x-access-token
REPO_SYNC_SSH_KEY=
REPO_SYNC_INTERVAL=300
TZ=UTC
```
**Commit:** `feat(host): add repo-sync env`

### Task 1.3: repo-local compose
**File:** `app/host/components/extensions/repo-local/docker-compose.yml`
**Depends:** none
```yaml
# repo-local: bind-mounts a local host path as /repos in the host container.
# POLICY EXCEPTION (stack-conventions section 4, no bind mounts): deliberate. Reason: the user's
# existing working copies live on the host filesystem and must be used in place (edits visible
# both ways); a named volume would only hold a copy. Requirement: REPOS_PATH must be writable
# by uid 10001 (chown/ACL on the host side; this stack never changes host permissions).
# Mutually exclusive with repo-sync (both mount /repos).
services:
  vibe-kanban-host:
    volumes:
      - ${REPOS_PATH:?}:/repos
```
**Verify:** `REPOS_PATH=/tmp/opencode/repos docker compose config | grep -A1 /repos`
**Commit:** `feat(host): add repo-local extension`

### Task 1.4: repo-local env
**File:** `app/host/components/extensions/repo-local/.env.example`
```
# repo-local: absolute host path mounted at /repos (bind mount, deliberate policy exception; must be writable by uid 10001)
REPOS_PATH=/home/user/projects
```
**Commit:** `feat(host): add repo-local env`

---
## Batch 2: Wiring and docs (depends 1.1-1.4)

### Task 2.1: stackbuilder.toml
**File:** `app/host/stackbuilder.toml`
Change the step-ca environment (test one extension at a time during gates):
```toml
[build.environments.step-ca]
extensions = ["step-ca-trust", "repo-sync"]
```
During Stage H swap to `"repo-local"`. After both gates pass, final state: forwarding/letsencrypt/step-ca each `extensions = [...]` per choice; keep both extensions listed in none by default (mutually exclusive) — leave repo-* opt-in and document in README (users edit the list). Final committed default after gates: step-ca = `["step-ca-trust"]` plus the one chosen by the user (ask user; default repo-sync).
**Verify:** `cd app/host && sb build && docker compose -f <built step-ca compose> config >/dev/null` (use the build output path from sb; env: `REPO_SYNC_URL=https://github.com/octocat/Hello-World.git`, `VK_SHARED_API_BASE=...`, `VK_SHARED_RELAY_API_BASE=...`).
**Commit:** `feat(host): wire repo extensions`

### Task 2.2: DEPLOYMENT.md
**File:** `DEPLOYMENT.md`
Edits:
1. Add section `## Pause notice` (before "Gate findings (Stage D)") with exactly: "Remote/relay work PAUSED after Stage D. Stage D partially passed; pairing works. browser->relay->host is unverified because there is no wildcard cert. Batches 9-12 (pgrust, s3, READMEs) are deferred."
2. Extension catalog rows:
   - `repo-sync` | host | sidecar `vibe-kanban-repo-sync` clones/pulls URL@branch (token/ssh optional) into named volume `vibe-kanban-host-repos` mounted at `/repos` | status: proposed (Stage G)
   - `repo-local` | host | bind-mounts `${REPOS_PATH}` at `/repos`. POLICY EXCEPTION to no-bind-mount (§4): existing working copies must be used in place; uid 10001 must be able to write. | status: proposed (Stage H)
   - Note: mutually exclusive (both target /repos).
3. Stage plan: add Stage G (repo-sync) and Stage H (repo-local), step-ca variant first, gate = scenario below.
**Verify:** `grep -n "repo-sync\|repo-local\|PAUSED" DEPLOYMENT.md` shows all.
**Commit:** `docs: repo extensions and pause notice`

---
## Batch 3: Stage G — repo-sync (step-ca variant)
### Task 3.1
**Depends:** 2.1, 2.2. Deploy only the step-ca host variant; never touch step-ca-manager.
Steps:
1. `cd app/host && sb build`; set `.env` from built `.env.example` with a public repo `REPO_SYNC_URL=https://github.com/octocat/Hello-World.git`, `REPO_SYNC_BRANCH=master`.
2. `docker compose up -d`; `docker logs vibe-kanban-repo-sync` shows clone, no restart loop.
3. Gate (curl, inside host or via VIRTUAL_HOST with `--cacert` step-ca root):
   - `docker exec vibe-kanban-host wget -qO- 'http://127.0.0.1:3000/api/filesystem/git-repos?path=/repos'` contains `Hello-World` and `"is_git_repo":true`.
   - `docker exec vibe-kanban-host sh -c 'wget -qO- --post-data="{\"path\":\"/repos/Hello-World\"}" --header="Content-Type: application/json" http://127.0.0.1:3000/api/repos'` returns success.
   - `docker exec vibe-kanban-host sh -c 'touch /repos/Hello-World/.w && rm /repos/Hello-World/.w'` (uid 10001 writable; step-ca-trust entrypoint drops to 10001).
   - Push a new commit upstream or wait interval (set `REPO_SYNC_INTERVAL=30`); `git -C /repos/Hello-World log` advances.
   - Browser (if available): UI repo picker lists the repo.
4. Record failures in `/home/archuser/projects/docker-stack-collection/PITFALLS.md`; fix and re-run.
**Commit:** `test(host): Stage G repo-sync passed` (update DEPLOYMENT.md status).

## Batch 4: Stage H — repo-local (step-ca variant)
### Task 4.1
**Depends:** 3.1. Swap extension list to `["step-ca-trust", "repo-local"]`, `sb build`, `docker compose down` then up.
1. `mkdir -p /tmp/opencode/repos && git clone https://github.com/octocat/Hello-World.git /tmp/opencode/repos/Hello-World`; make writable for 10001 only via docker (no sudo): `docker run --rm -v /tmp/opencode/repos:/r alpine chown -R 10001:10001 /r`.
2. `.env`: `REPOS_PATH=/tmp/opencode/repos`.
3. Same curl gate as Stage G (git-repos lists the repo, POST /api/repos registers, writable by 10001).
4. If permission denied, record in PITFALLS (bind mount ownership), do not alter host permissions beyond the docker chown above.
5. Cleanup: `docker compose down`; `docker run --rm -v /tmp/opencode:/t alpine rm -rf /t/repos`.
**Commit:** `test(host): Stage H repo-local passed`; update DEPLOYMENT.md statuses; then confirm with user which default goes into forwarding/letsencrypt/step-ca.

---
## Batch 5: Wrap-up (parallel, depends 4.1)
- 5.1 `UPSTREAM.md`: append row: vibe-kanban-host, repo discovery research (clone-in-tmp), commit 7c3807084daad0d9d315064f60fa869de254f027, date 2026-11-03, finding "no repos-dir env; cwd /repos autodiscovered; /api/filesystem/git-repos, POST /api/repos".
- 5.2 `/home/archuser/projects/docker-stack-collection/PITFALLS.md`: entries for any obstacles hit (uid 10001 ownership, askpass tokens, bind mounts); increment hits if existing.
- 5.3 `app/host/README.md`: document both extensions, env tables, mutual exclusivity, bind-mount exception (use readme-gen skill, ~100-250 lines style).
- 5.4 Cleanup: `rm -rf /tmp/opencode/upstreams/vibe-kanban-host`.
**Commit:** `docs(host): repo extensions readme, upstream, pitfalls`
