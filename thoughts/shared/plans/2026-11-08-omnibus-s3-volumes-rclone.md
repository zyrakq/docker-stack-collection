# Omnibus s3-volumes (rclone Docker volume plugin) Implementation Plan

**Goal:** Replace the `s3fs-fuse` extension of omnibus (inline-built image, s3fs entrypoint, SYS_ADMIN, /dev/fuse, apparmor unconfined) with an `s3-volumes` extension that backs `/books` and `/audiobooks` with S3 named volumes via the `rclone/docker-volume-rclone` Docker volume plugin.

**Architecture:** The extension only overrides the two existing top-level volumes (`omnibus-books`, `omnibus-audiobooks`, explicit `name:` kept) by adding `driver: rclone` + `driver_opts` fed from `${VAR}`. The omnibus/omnibus-init services stay untouched (stock image, no caps, no devices). The plugin mounts FUSE on the HOST side, so the endpoint must be reachable from the host.

**Design:** none (decision made in session ses_e45a). Conventions: stack-conventions §4, §5, §6, §9, §11, §20.

STACK = `stacks/self-hosting/media-streaming/book-management/omnibus`
EXT   = `STACK/app/components/extensions/s3-volumes`

## Decisions (gap-filling)

- Extension name `s3-volumes` (generic capability, two words). Old `s3fs-fuse` dir is deleted entirely.
- Override mechanism: same top-level volume keys as base; sb merges yaml so base `name:` is kept and `driver`/`driver_opts` are added. Task 4.1 must verify via `docker compose config` that merged volumes keep `name: omnibus-books` and carry the driver.
- No `${VAR:-}` / `${VAR:?msg}`; plain `${VAR}`. Bucket names, endpoint, keys are all env.
- Agents NEVER install the plugin (host-safety). The USER runs once:
  `docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions`
- Caveats to document: `driver_opts` secrets are visible in `docker volume inspect`; plugin requires FUSE on the host; unsupported opts make volume creation fail; booleans must be quoted strings; opts are immutable per volume (remove the volume to change them); `omnibus-init` `chown` on a FUSE/S3 mount may be a no-op or fail — verify in e2e (use `allow_other`; rclone `uid`/`gid` opts only if Task 1.1 confirms support).

## Dependency Graph

```
Batch 1: 1.1 [research notes]
Batch 2 (parallel): 2.1, 2.2 [extension files]
Batch 3 (parallel): 3.1, 3.2, 3.3, 3.4 [removal + wiring + docs]
Batch 4: 4.1 [sb build, validate]
Batch 5: 5.1 [PITFALLS]
```

All workers: load `stack-conventions` first; never touch the host; never run `docker plugin ...`; never edit `.opencode/**`.

---

## Batch 1: Research

### Task 1.1: Verify rclone plugin driver_opts
**File:** `thoughts/shared/notes/2026-11-08-rclone-volume-plugin-opts.md` (create; commit immediately per AGENTS.md)
**Test:** none
**Depends:** none

Worker steps (webfetch; GitHub may 504 — use rclone.org and Docker Hub):
1. Fetch https://rclone.org/docker/ and https://hub.docker.com/r/rclone/docker-volume-rclone.
2. Record verbatim: exact `driver_opts` keys for (a) remote definition — `remote: ':s3,provider=...:bucket'` connection-string vs `type: s3` + `path`; (b) credentials/endpoint/provider keys (`provider`, `endpoint`, `access_key_id`, `secret_access_key`, `env_auth`); (c) mount opts (`allow_other`, `vfs_cache_mode`, `uid`, `gid`, `umask`, `dir_cache_time`); (d) quoting rules for booleans and colon-ending remotes; (e) options known to fail with "unsupported backend option".
3. Record the minimal working compose volume snippet verbatim, the plugin install command, requirements (FUSE on host, `/var/lib/docker-plugins/rclone/{config,cache}`).
4. End with `## Final driver_opts for omnibus`: exact keys 2.1 must use, mapped to these env names:
   `S3_VOLUMES_TYPE`, `S3_VOLUMES_PROVIDER`, `S3_VOLUMES_ENDPOINT`, `S3_VOLUMES_ACCESS_KEY`, `S3_VOLUMES_SECRET_KEY`, `S3_VOLUMES_BOOKS_BUCKET`, `S3_VOLUMES_AUDIOBOOKS_BUCKET`, `S3_VOLUMES_ALLOW_OTHER`, `S3_VOLUMES_VFS_CACHE_MODE`.

**Verify:** file exists with the `Final driver_opts` section.
**Commit:** `docs(notes): rclone volume plugin driver_opts findings`

---

## Batch 2: Extension files (parallel)

### Task 2.1: Extension compose
**File:** `EXT/docker-compose.yml`
**Test:** `docker compose config` in 4.1
**Depends:** 1.1

Use keys confirmed in 1.1. Expected shape (adjust ONLY if 1.1 contradicts; no comments, no defaults):

```yaml
volumes:
  omnibus-books:
    name: omnibus-books
    driver: rclone
    driver_opts:
      type: ${S3_VOLUMES_TYPE}
      provider: ${S3_VOLUMES_PROVIDER}
      endpoint: ${S3_VOLUMES_ENDPOINT}
      access_key_id: ${S3_VOLUMES_ACCESS_KEY}
      secret_access_key: ${S3_VOLUMES_SECRET_KEY}
      path: ${S3_VOLUMES_BOOKS_BUCKET}
      allow_other: ${S3_VOLUMES_ALLOW_OTHER}
      vfs_cache_mode: ${S3_VOLUMES_VFS_CACHE_MODE}
  omnibus-audiobooks:
    name: omnibus-audiobooks
    driver: rclone
    driver_opts:
      type: ${S3_VOLUMES_TYPE}
      provider: ${S3_VOLUMES_PROVIDER}
      endpoint: ${S3_VOLUMES_ENDPOINT}
      access_key_id: ${S3_VOLUMES_ACCESS_KEY}
      secret_access_key: ${S3_VOLUMES_SECRET_KEY}
      path: ${S3_VOLUMES_AUDIOBOOKS_BUCKET}
      allow_other: ${S3_VOLUMES_ALLOW_OTHER}
      vfs_cache_mode: ${S3_VOLUMES_VFS_CACHE_MODE}
```
No `services:`, no `networks:` (the old step-ca-network join only served container-side access to `rustfs`).

**Verify:** `yq '.' <file>` parses.
**Commit:** `feat(omnibus): add s3-volumes extension compose`

### Task 2.2: Extension .env.example
**File:** `EXT/.env.example`
**Test:** `check-style.sh`
**Depends:** 1.1

No section headers/descriptions. Only comment allowed: generator line directly above a secret. Secrets carry an example value (not empty).

```
S3_VOLUMES_TYPE=s3
S3_VOLUMES_PROVIDER=Other
S3_VOLUMES_ENDPOINT=<host-reachable-s3-endpoint-url>
S3_VOLUMES_ACCESS_KEY=omnibus-example-access-key
# openssl rand -base64 32
S3_VOLUMES_SECRET_KEY=example-secret-key-change-me
S3_VOLUMES_BOOKS_BUCKET=omnibus-books
S3_VOLUMES_AUDIOBOOKS_BUCKET=omnibus-audiobooks
S3_VOLUMES_ALLOW_OTHER=true
S3_VOLUMES_VFS_CACHE_MODE=full
```
Adjust key names/values per 1.1.

**Verify:** `.opencode/skills/stack-conventions/scripts/check-style.sh STACK` has no violations for this file.
**Commit:** `feat(omnibus): add s3-volumes env example`

---

## Batch 3: Removal, wiring, docs (parallel)

### Task 3.1: Remove old extension
**File:** `STACK/app/components/extensions/s3fs-fuse/` (delete: `docker-compose.yml`, `s3fs-entrypoint.sh`, `.env.example`)
**Test:** `git ls-files STACK/app/components/extensions | grep s3fs` empty
**Depends:** 2.1, 2.2

`git rm -r` the dir. `extensions/` still has other content, no `.gitkeep` needed.
**Commit:** `refactor(omnibus): drop s3fs-fuse extension`

### Task 3.2: stackbuilder.toml
**File:** `STACK/app/stackbuilder.toml`
**Test:** `sb build` (4.1)
**Depends:** 2.1, 2.2

Line 6 becomes `extensions = ["s3-volumes", "smtp", "prowlarr", "metrics", "api-keys"]`. Nothing else changes.
**Commit:** `refactor(omnibus): wire s3-volumes extension`

### Task 3.3: DEPLOYMENT.md
**File:** `STACK/DEPLOYMENT.md`
**Test:** `grep -i s3fs` empty
**Depends:** 1.1

- ~line 45: replace the s3fs-fuse sentence: no native S3 backend; S3 provided by the `rclone` Docker volume plugin (extension `s3-volumes`), never on `/config`.
- ~line 63 row: `| s3-volumes on `/books` + `/audiobooks` | infra | implemented | requires the `rclone` volume plugin installed on the host by the user; RustFS/S3 bucket; never on `/config` |`
**Commit:** `docs(omnibus): deployment model uses s3-volumes`

### Task 3.4: app/README.md
**File:** `STACK/app/README.md`
**Test:** `grep -i s3fs` empty
**Depends:** 1.1, 2.2

- Lines ~72-74: replace the s3fs-fuse text with **s3-volumes** (`implemented`): backs `omnibus-books`/`omnibus-audiobooks` with S3 buckets via the `rclone` Docker volume plugin (no sidecar, no extra capabilities; never on `/config`); vars `S3_VOLUMES_*`.
- Add `### S3 volumes prerequisites` under Extensions: the USER installs the plugin once on the host (agents never run it):
  ```bash
  docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions
  ```
  Requires FUSE on the host; `S3_VOLUMES_ENDPOINT` must be reachable from the HOST (compose name `rustfs` does not resolve there); driver_opts incl. the secret key are visible in `docker volume inspect`; to change opts: `docker compose down`, `docker volume rm omnibus-books omnibus-audiobooks` (bucket data stays).
- Env vars section: list `S3_VOLUMES_*`.
**Commit:** `docs(omnibus): document s3-volumes extension`

(Stack root `README.md` has no s3fs mention — untouched.)

---

## Batch 4: Build & validate

### Task 4.1: sb build + config validation
**File:** `STACK/app/build/**` (generated, committed)
**Depends:** 3.1, 3.2, 3.3, 3.4

From `STACK/app`: confirm `yq --version` is mikefarah; `sb build`. For each `build/<env>/entire*/`: `docker compose --env-file .env.example config` ONLY — no `up`, no volume creation (the plugin is not installed by agents, so config of unknown driver is just rendered). Confirm volumes have `name`, `driver: rclone`, `driver_opts`; `grep -ri -e s3fs -e SYS_ADMIN -e /dev/fuse -e apparmor build/` empty. Run `check-stack.sh STACK`. Delete `.stackbuilder/`.
Functional e2e (upload into /books, object visible in bucket, `omnibus-init` chown behavior) is PENDING until the user installs the plugin; report it.
**Commit:** `build(omnibus): regenerate with s3-volumes`

---

## Batch 5: Pitfalls

### Task 5.1: PITFALLS.md
**File:** `PITFALLS.md` (repo root)
**Depends:** 1.1, 4.1

Grep first; increment `hits`/`last` on matches, else append (`hits: 1`, header format):
1. s3fs in the app image needs SYS_ADMIN + /dev/fuse + apparmor unconfined; sidecar needs `rshared` host bind propagation → violates no-bind-mount policy. status `mitigated`, fix: docker volume plugin `rclone`.
2. rclone volume plugin: host-side mount ⇒ endpoint must be host-reachable (compose service names do not resolve); unsupported `driver_opts` fail volume creation; booleans quoted; secrets visible in `docker volume inspect`; opts immutable → `docker volume rm`; plugin install is user-only (host-safety). status `open`.
3. Any extra quirk from 1.1.
**Commit:** `docs(pitfalls): s3 volume plugin notes`

---

## NEEDS USER APPROVAL (not executable tasks — AGENTS.md: tooling definitions)

Show diffs and wait for explicit approval before touching:

1. `.opencode/skills/rustfs-s3/SKILL.md` + `references/cookbook.md` — rework or add a new skill (e.g. `s3-volumes`): bucket/user via rustfs, `S3_VOLUMES_*` fragment, host-reachable endpoint, user-installed plugin prerequisite, base-volume override pattern.
2. `.opencode/agents/rustfs-admin.md` — point at the new/reworked skill.
3. `.opencode/skills/stack-conventions/SKILL.md` — §9 (~276-277), §11 (~314-315), §20 (~492): replace s3fs-fuse fallback with s3-volumes (rclone volume plugin), still never on DB volumes; plugins are installed by the user only. Also `references/patterns.md` if it embeds an s3fs fragment.
4. `.opencode/skills/stack-init/SKILL.md` (~153, 171), `references/scaffold-checklist.md` (~105).
5. `.opencode/skills/stack-analysis/SKILL.md` (~99).
6. `.opencode/skills/stack-test/SKILL.md` (~81, 126): s3 stage precondition = plugin installed by user.
7. Root `AGENTS.md` ("s3fs-fuse never on DB volumes") — wording, user's call.
