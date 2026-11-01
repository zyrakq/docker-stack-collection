---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection via
  the staged protocol: repo and upstream provenance, base-only scaffold,
  then database (postgresql, pgrust), oidc, and s3 extensions one at a
  time, each gated by a stack-test stage. Use when the user asks to create
  or start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every phase below depends on
it, especially §9 (staged integration protocol).

## Workflow (phased; every extension gated by a test)

Phases 0–1 establish the stack. Phases 2–5 add extensions ONE at a time,
each followed by its test gate (stack-conventions §9). NEVER scaffold
oidc/s3 material before the base passes its Stage A gate.

### Phase 0 — repo & upstream provenance

1. **Determine stack type & category.** Ask the user if unclear. Choose the
   category path `stacks/<category>/<subcategory>/<stack-name>/` following
   existing entries in `stacks.csv`.
2. **Create the stack repo.**
   ```bash
   mkdir -p stacks/<category>/<...>/<stack>
   cd stacks/<category>/<...>/<stack>
   git init
   ```
3. **Upstream provenance.** Ask the user for the upstream repo URL(s) — one
   per project dir when the stack ships more than one project. Create
   `UPSTREAM.md` at the stack root per stack-conventions §17, then clone
   each upstream repo to inspect the source:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

   - Inspect the clone (config files, flags, entrypoints) to inform the
     scaffolding in the next phase.
   - Append the first log row: today's date, the current upstream commit
     (`git -C /tmp/opencode/upstreams/<stack>-<project> rev-parse --short
     HEAD`), the image tag/digest being dockerized, note `initial
     dockerization`.
   - URL unknown: create `UPSTREAM.md` with the section and an empty log —
     the first rework session backfills it. Clone fails: report and skip
     the clone (still create `UPSTREAM.md`).
   - Delete the clone when done scaffolding:
     `rm -rf /tmp/opencode/upstreams/<stack>-<project>`

### Phase 1 — scaffold the BASE only

4. **Scaffold** exactly per `references/scaffold-checklist.md` — BASE
   pieces only:
   - `app/components/base/` — `docker-compose.yml` (service named
     `<stack>-<role>` per §3, every env value `${VAR:-}`/`${VAR:?}` per
     §5, named volumes per §4), `.env.example` (§6 hygiene), config
     examples.
   - `app/components/environments/{forwarding,letsencrypt,step-ca}/` as
     applicable (step-ca needs the certs volume + network fragment);
     environment-dependent vars live ONLY in overlays (§7).
   - `app/stackbuilder.toml` — new `[build.environments]` API; use
     `env_file_patterns` to preserve app-native config files (numa idiom).
   - `app/README.md` — delegate to the `readme-gen` skill rules.
   - Stack root: hub `README.md`, `.gitignore`, `.gitmessage`,
     `LICENSE-APACHE`, `LICENSE-MIT`; `.gitmodules` + `modules/ssl-automation`
     submodules ONLY if SSL integration is needed.
   - **No published Docker image?** Build from source via the
     `source-image` skill — `app/images/<image>/Dockerfile`, self-contained
     (fetches the source itself). NEVER vendor upstream source into the
     stack repo (no submodules, no source trees) — stack-conventions §19.
   - NO oidc, NO s3-storage, NO other extensions yet (staged protocol, §9).
5. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
6. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
7. **Build & verify the base:** `cd app/ && sb build`, then follow the
   `stack-test` skill through the Stage A gate.

### Phase 2 — database extension (postgresql variant)

8. If the app needs postgres: prepare the `database/postgresql` extension
   exactly per stack-conventions §8 — dual-file idiom, verbatim fragments
   in `stack-conventions` `references/patterns.md` §11. Wire the
   `postgresql` combo in `stackbuilder.toml`, `sb build`, deploy, and pass
   the **Stage A gate** (browser E2E: base + DB, no oidc) per `stack-test`.
   MUST pass before anything else is added.

### Phase 3 — pgrust alternative

9. Add the `database/pgrust` variant (identical except the `image:`
   default), rebuild, and run the **Stage A2 gate**. Clean pass → make
   `pgrust` the default combo (§9). Failure → keep `postgresql` default
   and record why in the component README.

### Phase 4 — oidc

10. If the app supports OIDC: add the `oidc` extension, include it in the
    default build, keep the tested no-oidc variant as proof of the
    pre-OIDC step, and pass the **Stage B gate** per `stack-test`.

### Phase 5 — s3

11. If the app needs object storage: the base already uses simple named
    volumes. Add the `s3-storage` extension if the app supports S3
    natively (env-only fragment) and run the S3 round-trip test;
    otherwise s3fs-fuse — ONLY on volumes with NO database data
    (stack-conventions §11).

## Canonical patterns

Canonical pattern fragments (base compose, environments, database pair,
oidc/s3 extensions) are embedded in the `stack-conventions` skill
(`references/patterns.md`) — imitate those, not live stacks.
