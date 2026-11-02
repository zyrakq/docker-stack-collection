---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection via
  the staged protocol: stack-analysis deployment model (DEPLOYMENT.md)
  first, scaffold of the entire functional base (ALL product parts +
  the database stage), functional gate, then the remaining mandatory
  infra stages (pgrust, oidc, s3), then the extension menu — confirmed
  extensions one at a time, each gated by a stack-test stage. Use when
  the user asks to create or start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every phase below depends on
it, especially §9 (staged integration protocol) and §20 (deployment
model and application parts).

## Workflow (phased; every stage gated by a test)

Phase 0 produces the deployment model (DEPLOYMENT.md — committed, no
approval gate). Phase 1 scaffolds the ENTIRE functional base: ALL
product parts plus the mandatory database stage. Phases 2–4 complete
the remaining mandatory infra stages (pgrust, oidc, s3). Phase 5
presents the extension catalog — the ONE user checkpoint. Confirmed
extensions are added ONE at a time after that, each followed by its
test gate (stack-conventions §9). NEVER scaffold catalog extensions
before the base stages pass their gates.

ONE mandatory user checkpoint (stack-conventions §20): the extension
menu from the DEPLOYMENT.md catalog, AFTER all base gates pass (Phase
5). Base scope itself needs NO user agreement — it is executed as
analyzed; a base stage blocked by unresolvable problems is REFUSED
with the reason recorded in DEPLOYMENT.md, never silently skipped.

### Phase 0 — deployment model & upstream provenance

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
   each upstream repo:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

   - Append the first log row: today's date, the current upstream commit
     (`git -C /tmp/opencode/upstreams/<stack>-<project> rev-parse --short
     HEAD`), the image tag/digest being dockerized, note `initial
     dockerization`.
   - URL unknown: create `UPSTREAM.md` with the section and an empty log —
     the first rework session backfills it. Clone fails (network, repo
     moved): report and STOP — never guess a deployment model
     (stack-analysis iron rule 5).
4. **Run the `stack-analysis` skill** (new-stack mode) against the same
   clone(s): it inventories the upstream product's deployable parts,
   classifies them (functional base vs extension catalog), defines the
   functional base (product parts + mandatory infra) + functional gate
   scenario + base stage plan, assembles the extension catalog, and
   writes `DEPLOYMENT.md` at the stack root (stack-conventions §20). Do
   NOT scaffold anything yet.
5. **No approval gate.** The committed `DEPLOYMENT.md` IS the base
   contract — Phase 1 executes it as analyzed (§20). Base scope the
   analysis could not decide with confidence → 2–3 options with
   trade-offs to the user — never silently shrink (stack-analysis iron
   rule 3).
6. **Clone lifecycle:** the clone(s) stay for Phase 1 — scaffolding still
   needs upstream config details (config files, flags, entrypoints).
   Delete them when scaffolding is done (§17):
   `rm -rf /tmp/opencode/upstreams/<stack>-<project>`

### Phase 1 — scaffold the functional base (ALL product parts + database)

7. **Scaffold** exactly per `references/scaffold-checklist.md` — the
   product parts only: EVERY part in the DEPLOYMENT.md
   `## Functional base` section, one compose service per part:
   - Service per part named `<stack>-<role>` per §3 — base ≠ one app
     container (§20); a multi-part product gets a multi-service base.
   - Image per part: the published upstream image, or source-built via
     the `source-image` skill — `app/images/<image>/Dockerfile`,
     self-contained (fetches the source itself). NEVER vendor upstream
     source into the stack repo (no submodules, no source trees) —
     stack-conventions §19.
   - `app/components/base/` — `docker-compose.yml` (every env value
     `${VAR:-}`/`${VAR:?}` per §5, named volumes per §4), `.env.example`
     (§6 hygiene), config examples.
   - `app/components/environments/{forwarding,letsencrypt,step-ca}/` as
     applicable (step-ca needs the certs volume + network fragment);
     environment-dependent vars live ONLY in overlays (§7).
   - `app/stackbuilder.toml` — new `[build.environments]` API; use
     `env_file_patterns` to preserve app-native config files (numa idiom).
   - `app/README.md` — delegate to the `readme-gen` skill rules.
   - Stack root: hub `README.md`, `.gitignore`, `.gitmessage`,
     `LICENSE-APACHE`, `LICENSE-MIT`; `.gitmodules` + `modules/ssl-automation`
     submodules ONLY if SSL integration is needed.
   - NO catalog extensions yet — anything outside the functional base is
     offered at the Phase 5 menu (staged protocol, §9).
8. **Database stage (mandatory infra, always attempted):** prepare the
   `database/postgresql` extension exactly per stack-conventions §8 —
   dual-file idiom, verbatim fragments in `stack-conventions`
   `references/patterns.md` §11; wire the `postgresql` combo in
   `stackbuilder.toml`. Unresolvable blocker → REFUSE the stage with
   the reason recorded in DEPLOYMENT.md (§20) — never silently skip.
9. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
10. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
11. **Build & verify the base:** `cd app/ && sb build`, then follow the
    `stack-test` skill through the Stage A gate — Stage A (product
    parts + database) executes the DEPLOYMENT.md functional gate
    scenario (cross-part E2E). Model vs gate mismatch → update
    DEPLOYMENT.md (living doc, §20) and re-run the stage.

### Phase 2 — pgrust stage (mandatory infra, always attempted)

12. Add the `database/pgrust` variant (identical except the `image:`
    default), rebuild, and run the **Stage A2 gate**. Clean pass → make
    `pgrust` the default combo (§9). Failure → keep `postgresql` default
    and record why in the component README.

### Phase 3 — oidc stage (mandatory infra, always attempted)

13. Add the `oidc` extension, include it in the default build, keep the
    tested no-oidc variant as proof of the pre-OIDC step, and pass the
    **Stage B gate** per `stack-test`. The app has no auth layer at all
    → unresolvable blocker: REFUSE the stage with the reason recorded
    in DEPLOYMENT.md (§20) — never silently skip.

### Phase 4 — s3 stage (mandatory infra, always attempted, LAST)

14. The base already uses simple named volumes. Add the `s3-storage`
    extension if the app supports S3 natively (env-only fragment) and
    run the S3 round-trip test; otherwise s3fs-fuse — ONLY on volumes
    with NO database data (stack-conventions §11). Unresolvable blocker
    → REFUSE the stage with the reason recorded in DEPLOYMENT.md (§20).

### Phase 5 — extension menu (the ONE user checkpoint)

15. After ALL base gates pass, present the extension catalog from
    DEPLOYMENT.md — product extensions and non-mandated optional infra,
    with dependencies and ordering constraints. The user confirms a
    selection; NOTHING is implemented without that explicit
    confirmation. Record outcomes in DEPLOYMENT.md: confirmed →
    `implemented` when landed; explicitly rejected → `refused` with a
    reason; unselected → remain `available`.

### Phases 6+ — confirmed extensions, one at a time

Implement the confirmed extensions one per phase, each followed by its
test gate (stack-conventions §9). Ordering constraints always hold: db
first, s3 last, s3fs-fuse never on DB volumes. A product extension goes
in per its DEPLOYMENT.md catalog entry — one compose service per part
(`<stack>-<role>`, §3), image per §19 when upstream publishes none, its
own stage + gate; its status becomes `implemented` in DEPLOYMENT.md when
it lands.

## Canonical patterns

Canonical pattern fragments (base compose, environments, database pair,
oidc/s3 extensions) are embedded in the `stack-conventions` skill
(`references/patterns.md`) — imitate those, not live stacks.
