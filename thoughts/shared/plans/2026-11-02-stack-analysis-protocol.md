# Stack Analysis Protocol Implementation Plan

**Goal:** Add a new `stack-analysis` skill (product-lens deployment modeling → per-stack `DEPLOYMENT.md`) as the mandatory entry point of stack work, and wire it into `stack-init`, `stack-conventions`, `stack-test`, `stack-modernize`, `readme-gen`, and the project `AGENTS.md`.

**Architecture:** A new standalone skill analyzes the upstream product's deployable roles and produces a `DEPLOYMENT.md` at each stack repo root — the living contract (functional base, base stage plan + functional gate scenario, extension catalog) that every other skill consumes. Two mandatory user checkpoints are added: base scope agreement before scaffolding, extension menu selection after the Stage A functional gate. All changes are markdown/protocol files inside the collection repo — no application code, no micode agent edits.

**Design:** `thoughts/shared/designs/2026-11-02-stack-analysis-protocol-design.md`

---

## Decisions made by the planner (design gaps filled)

1. **DEPLOYMENT.md placement: stack repo root** (next to `UPSTREAM.md`), not `app/`. It is a stack-level contract spanning all project dirs of multi-project stacks; `UPSTREAM.md` — its sibling provenance artifact — already lives at the root. (Resolves design open question 2.)
2. **stack-conventions section number: §20, appended after §19.** Its logical home is next to §9 (staged protocol), but inserting there would renumber §10–§19 and break every cross-skill § citation (`stack-init`, `stack-modernize`, `stack-test`, and `AGENTS.md` cite §17/§19 today). Appending avoids all renumbering; §20 cross-references §9/§3/§8/§10/§11/§17/§19 so it is discoverable from the sections it extends.
3. **Clone lifecycle:** the §17 clone-in-tmp clone survives the analysis and is kept through `stack-init` Phase 1 scaffolding (upstream config details — config files, flags, entrypoints — are still needed there), then deleted. This matches §17's "delete after the session" rule. `stack-analysis` documents the exception for the stack-init flow; in every other mode (gap mode, standalone) it deletes the clone at the end of its own run.
4. **Checkpoint 2 = new "Phase 1.5 — extension menu"** in stack-init, between the Stage A functional gate and extension work. Phases 2+ become catalog-driven instances of the menu selection; the classic infra ladder (db → pgrust → oidc → s3) stays as the default instance with its ordering constraints (db first, s3 last, s3fs-fuse never on DB volumes). One catalog holds product AND infra extensions (design open question 3: yes).
5. **Existing stacks without DEPLOYMENT.md** (all of them today): `stack-test` Stage A and `stack-modernize` both route to `stack-analysis` gap mode instead of failing — the protocol is adoptable incrementally.
6. **readme-gen:** new "🧩 Product Roles" section in Template B (after Quick Start, before Project Structure) + extension status annotations in the Extensions section; rule 7's canonical section order is updated accordingly.
7. **Edit strategy:** complete new file content where changes are pervasive (`stack-init/SKILL.md`, `scaffold-checklist.md`, `readme-gen/SKILL.md`); exact anchored find→replace blocks where changes are localized. Every block is copy-paste ready; anchors quote the current file text verbatim.
8. **No `.gitkeep` needed:** both new directories (`stack-analysis/`, `stack-analysis/references/`) contain files.

## File inventory

NEW:

- `.opencode/skills/stack-analysis/SKILL.md` (task 1.2)
- `.opencode/skills/stack-analysis/references/analysis-checklist.md` (task 1.3)

EDITED:

- `.opencode/skills/stack-conventions/SKILL.md` — append §20 + 2 small edits (task 1.1)
- `.opencode/skills/stack-init/SKILL.md` — complete workflow rewrite (task 2.1)
- `.opencode/skills/stack-init/references/scaffold-checklist.md` — complete update (task 2.2)
- `.opencode/skills/stack-test/SKILL.md` — 4 anchored edits (task 2.3)
- `.opencode/skills/stack-test/references/browser-e2e.md` — 2 anchored edits (task 2.4)
- `.opencode/skills/stack-test/references/verification-procedure.md` — 1 anchored edit (task 2.5)
- `.opencode/skills/stack-modernize/SKILL.md` — 2 anchored edits (task 2.6)
- `.opencode/skills/readme-gen/SKILL.md` — complete update (task 2.7)
- `.opencode/skills/readme-gen/references/templates.md` — 3 anchored edits (task 2.8)
- `AGENTS.md` (project root) — 1 anchored insertion (task 2.9)

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3            [definitions + new skill]
Batch 2 (parallel): 2.1 … 2.9                [consumer skills — cite §20 / stack-analysis / DEPLOYMENT.md]
Batch 3 (single):   3.1                       [cross-reference verification — depends on ALL above]
```

All Batch 1 + Batch 2 tasks are independent file writes (complete content below) — batching is for review order and §20-citation resolution, not compile deps. Batch 3 must run last.

---

## Batch 1: Foundation (parallel — 3 implementers)

### Task 1.1: stack-conventions §20 — Deployment model and application roles
**File:** `.opencode/skills/stack-conventions/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** none

Three edits to the existing file.

**Edit 1 — frontmatter description (lines 6–9).** Replace:

```markdown
  extensions (oidc, s3-storage, database postgresql+pgrust), env wiring
  (${VAR:-} everywhere), .env.example hygiene, no-bind-mount volume
  policy, staged integration protocol with test gates, dockerfile_inline
  config patterns, source-built images (app/images/), OIDC/S3/step-ca
```

with:

```markdown
  extensions (oidc, s3-storage, database postgresql+pgrust), env wiring
  (${VAR:-} everywhere), .env.example hygiene, no-bind-mount volume
  policy, staged integration protocol with test gates, deployment model
  and application roles (DEPLOYMENT.md), dockerfile_inline
  config patterns, source-built images (app/images/), OIDC/S3/step-ca
```

**Edit 2 — intro (lines 16–17).** Replace:

```markdown
Reference skill for every stack in this collection. The `stack-init`,
`stack-test`, `stack-modernize`, and `readme-gen` skills build on these rules.
```

with:

```markdown
Reference skill for every stack in this collection. The `stack-analysis`,
`stack-init`, `stack-test`, `stack-modernize`, and `readme-gen` skills
build on these rules.
```

**Edit 3 — append §20** after the last line of the file (line 368, `- Step-by-step procedure: the `source-image` skill.` — the final bullet of §19):

```markdown

## 20. Deployment model and application roles (DEPLOYMENT.md)

Every stack records WHAT the upstream product deploys as, in a per-stack
`DEPLOYMENT.md` at the stack root (next to `UPSTREAM.md`). Produced by
the `stack-analysis` skill; consumed by `stack-init` (Phase 0),
`stack-test` (Stage A), `stack-modernize`, and `readme-gen`.

Definitions:

- **Role** — one deployable component of the upstream product (web app,
  API server, worker, relay/tunnel server, host executor, ...). One role
  = exactly one compose service, named `<stack>-<role>` (§3).
- **Functional base** — the minimal set of roles that makes the
  product's core value work END-TO-END. Base ≠ one app container: a
  product whose core value needs N cooperating roles has an N-service
  base. Overreach guard: a single-role product stays single-role — every
  role in the base must be exercised by the functional gate scenario.
- **Functional gate scenario** — the cross-role end-to-end flow that
  proves the functional base; defined in DEPLOYMENT.md, executed as the
  Stage A browser gate (§9) by `stack-test`.
- **Extension catalog** — everything not in the functional base, in ONE
  catalog covering product- AND infra-extensions (database §8, oidc
  §10, s3 §11), each with type, status, and dependencies. Ordering
  constraints always hold: db first, s3 last, s3fs-fuse never on DB
  volumes (§9, §11).

DEPLOYMENT.md content spec (all six sections required):

1. `## Product roles` — every deployable role found upstream: name,
   purpose, image source (published / source-built per §19).
2. `## Interaction map` — who talks to whom; what breaks when a role is
   absent.
3. `## Functional base` — the agreed base roles, each justified.
4. `## Base stage plan` — ordered implementation stages, each with its
   gate; the final stage's gate is the functional gate scenario.
5. `## Extension catalog` — table: extension | type (product/infra) |
   status (`proposed` / `implemented` / `declined`) | dependencies.
6. `## Open hypotheses` — uncertain classifications with confidence and
   what the functional gate must observe to settle them.

Rules:

- DEPLOYMENT.md is a LIVING document: update and commit it whenever the
  model changes (model-vs-gate mismatch, reclassification, extension
  status change). Unlike `UPSTREAM.md` (§17) it is NOT append-only.
- Two MANDATORY user checkpoints: (1) base scope agreement BEFORE any
  scaffolding; (2) extension menu selection from the catalog AFTER the
  Stage A functional gate passes. Disputed base scope → 2–3 options with
  trade-offs to the user — never silently shrink, never inflate.
- Remediation rule: an existing stack missing functional-base roles
  completes them BEFORE any extension work (gap mode in the
  `stack-analysis` skill).
```

**Verify:** `grep -n "^## 20\." .opencode/skills/stack-conventions/SKILL.md && grep -c "stack-analysis" .opencode/skills/stack-conventions/SKILL.md`
**Commit:** `docs(skills): stack-conventions §20 — deployment model and application roles (DEPLOYMENT.md)`

### Task 1.2: NEW skill — stack-analysis/SKILL.md
**File:** `.opencode/skills/stack-analysis/SKILL.md` (new)
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** none (cites §20 created in 1.1 — same batch, content complete)

Create the directory and file with EXACTLY this content:

````markdown
---
name: Stack Analysis
description: >-
  Analyze an upstream product's deployable roles and produce the stack's
  DEPLOYMENT.md deployment model: inventory roles from the upstream repo
  (clone-in-tmp), build the interaction map, classify every role as
  base-required / product-extension / infra-extension, define the
  functional base and its cross-role functional gate scenario, and
  assemble the extension catalog. Mandatory Phase 0 of stack-init; gap
  mode diffs existing stacks against the model. Use when creating a new
  stack, when a stack's product scope or missing roles are questioned, or
  before modernizing a stack that lacks DEPLOYMENT.md.
---

# Stack Analysis

Load the `stack-conventions` skill first — §20 defines the deployment
model this skill produces.

## Iron rules

1. **Product lens, not infra lens.** The functional base is the minimal
   set of cooperating roles that makes the product's core value work
   end-to-end — NOT "one app container + DB". Base scope is agreed with
   the user BEFORE any scaffolding (checkpoint 1, §20).
2. **Overreach guard.** Every role added to base must be exercised by
   the functional gate scenario. A single-role product stays
   single-role — an inflated base is as wrong as a shrunken one.
3. **Never silently shrink.** Disputed base scope → present 2–3 options
   with trade-offs to the user. Undocumented/ambiguous roles → record
   as hypotheses with confidence in `## Open hypotheses`, validated at
   the functional gate.
4. **No upstream access → stop and ask.** Never guess a deployment
   model.
5. **No vendoring.** The clone-in-tmp clone (§17) is reference-only and
   temporary — never committed, never referenced by any build.

## Workflow

1. **Inputs.** New stack: upstream repo URL(s) from the user. Existing
   stack (gap mode): the stack path — read its compose files and
   `UPSTREAM.md` for the upstream URL(s).
2. **Clone upstream** per the §17 clone-in-tmp workflow (one clone per
   project dir for multi-project products):

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

3. **Inventory deployable roles** from the clone — full checklist in
   `references/analysis-checklist.md`: upstream compose files,
   Dockerfiles, workspace/crate/package structure, CLI entrypoints,
   published ports, deployment docs, release artifacts.
4. **Build the interaction map** — who talks to whom, and what breaks
   when a role is absent.
5. **Classify every role/feature**: base-required / product-extension /
   infra-extension (database §8, oidc §10, s3 §11). Justify each
   classification; uncertain ones become hypotheses (iron rule 3).
6. **Define the functional base** and the **functional gate scenario**
   (the cross-role E2E flow that proves it), then the **base stage
   plan** — ordered stages, each with its own gate; the final stage's
   gate is the functional gate scenario.
7. **Assemble the extension catalog** — ONE catalog for product AND
   infra extensions, each with type, status, dependencies. Ordering
   constraints preserved: db first, s3 last, s3fs-fuse never on DB
   volumes (§9, §11).
8. **Write `DEPLOYMENT.md`** at the stack root (next to `UPSTREAM.md`)
   with the six sections per §20. Commit it in the stack repo.
9. **Checkpoint 1 — base scope agreement.** Present the functional
   base, base stage plan, functional gate scenario, and extension
   catalog to the user. Get explicit agreement BEFORE `stack-init`
   scaffolds anything (§20).
10. **Delete the tmp clone** per §17 at the end of the analysis session
    (`rm -rf /tmp/opencode/upstreams/<stack>-<project>`). EXCEPTION:
    when running as `stack-init` Phase 0, the clone is kept for Phase 1
    scaffolding (upstream config details) and deleted there.

## Gap mode (existing stacks)

1. Read the stack's deployed compose services and `UPSTREAM.md`; run the
   workflow above against the upstream.
2. Diff model vs deployed: missing base roles, undocumented deployed
   services, extensions absent from the catalog.
3. Output a remediation plan — completing missing base roles takes
   PRIORITY over any extension work (§20 remediation rule). Extensions
   are proposed from the catalog only after the base is complete and its
   functional gate passes.
4. Create or update `DEPLOYMENT.md`: already-deployed extensions marked
   `implemented`, rejected ones `declined` with a reason, the rest
   `proposed`.

## Exemplars

Validation cases to run mentally against any produced model:

- vibe-kanban: the base must come out as remote-server + host executor
  (the relay classified with explicit rationale — base-required vs
  product-extension — recorded as a hypothesis if uncertain), plus a
  remediation plan for the existing stack.
- Anti-overreach: a simple single-role product must come out with a
  single-role base — the analysis must not inflate it.
````

**Verify:** `test -f .opencode/skills/stack-analysis/SKILL.md && head -3 .opencode/skills/stack-analysis/SKILL.md && grep -c "Load the \`stack-conventions\` skill first" .opencode/skills/stack-analysis/SKILL.md`
**Commit:** `docs(skills): add stack-analysis skill — deployment model protocol (DEPLOYMENT.md)`

### Task 1.3: NEW reference — stack-analysis/references/analysis-checklist.md
**File:** `.opencode/skills/stack-analysis/references/analysis-checklist.md` (new)
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** none

Create with EXACTLY this content:

````markdown
# Stack Analysis — Analysis Checklist

Checklist for the `stack-analysis` workflow. Work through it in order;
every produced model must pass the sanity checks in §8. Conventions:
stack-conventions §20 (deployment model), §17 (clone-in-tmp).

## 1. Role inventory (from the upstream clone)

- [ ] Upstream compose files (repo root and any deploy/ or docker/
      dirs): every service = a candidate role (name, image/build,
      ports, env).
- [ ] Dockerfiles at repo root and in subdirs — each buildable target
      is a candidate role.
- [ ] Workspace/crate/package structure: Cargo workspace members,
      npm/pnpm workspaces and packages, go `cmd/*` dirs — each
      deployable binary is a candidate role.
- [ ] CLI entrypoints (bin targets, `main.go` files, package.json
      `bin`) — distinguish deployable roles from build tooling.
- [ ] Published ports and listeners (config defaults, `EXPOSE`, docs).
- [ ] Deployment docs (README, docs/deploy*, k8s/helm charts, systemd
      units) — upstream's own deployment story names the roles.
- [ ] Release artifacts (per-platform binaries, per-component
      archives).

## 2. Interaction map

- [ ] For each role: what it talks to (DB, queue, other roles,
      external services), on what port/protocol.
- [ ] For each role: what breaks when it is absent — which
      user-visible feature degrades or dies.
- [ ] The data flow of the product's core value, end-to-end.

## 3. Classification (every role + notable feature)

- [ ] base-required — in the functional base, justified by the
      functional gate scenario.
- [ ] product-extension — optional product capability (feature flag,
      optional companion role).
- [ ] infra-extension — database (§8), oidc (§10), s3 (§11).
- [ ] Uncertain → hypothesis with confidence (high/medium/low) + what
      the functional gate must observe to settle it.

## 4. Functional base & gate

- [ ] Functional base = the minimal role set where the core value
      works end-to-end. Overreach guard: every role justified;
      single-role products stay single-role.
- [ ] Functional gate scenario: a concrete cross-role E2E flow (user
      action → expected observable result), executable with
      agent-browser per the `stack-test` skill.
- [ ] Base stage plan: ordered stages, each with its own gate; the
      final stage's gate = the functional gate scenario.

## 5. Extension catalog

- [ ] One table: extension | type (product/infra) | status
      (proposed/implemented/declined) | dependencies.
- [ ] Ordering constraints preserved: db first, s3 last, s3fs-fuse
      never on DB volumes (§9, §11).

## 6. DEPLOYMENT.md output

- [ ] All six §20 sections present: Product roles, Interaction map,
      Functional base, Base stage plan, Extension catalog, Open
      hypotheses.
- [ ] Written at the stack root, next to `UPSTREAM.md`; committed in
      the stack repo.
- [ ] Checkpoint 1 done: the user agreed the base scope BEFORE any
      scaffolding.

## 7. Gap mode extras (existing stacks)

- [ ] Diff model vs deployed compose: missing base roles, undocumented
      deployed services, extensions absent from the catalog.
- [ ] Remediation plan: base roles FIRST, extensions only after the
      functional gate passes (§20 remediation rule).
- [ ] Deployed extensions marked `implemented`; rejected ones
      `declined` with a reason.

## 8. Sanity checks (both directions)

- [ ] Shrunken-base check: no role whose absence breaks the core value
      sits outside the base.
- [ ] Inflated-base check: no role in the base that the functional
      gate scenario does not exercise.
- [ ] Clone deleted: `rm -rf /tmp/opencode/upstreams/<stack>-<project>`
      (unless running as stack-init Phase 0 — the clone lives on for
      scaffolding).
````

**Verify:** `test -f .opencode/skills/stack-analysis/references/analysis-checklist.md && grep -c "^## " .opencode/skills/stack-analysis/references/analysis-checklist.md` (expect 8)
**Commit:** `docs(skills): add stack-analysis analysis-checklist reference`

---

## Batch 2: Consumer skills (parallel — 9 implementers; depends on Batch 1 for §20/stack-analysis citations to resolve)

### Task 2.1: stack-init — Phase 0 analysis, all-base-roles scaffold, extension menu
**File:** `.opencode/skills/stack-init/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1, 1.2 (cites §20 and the `stack-analysis` skill)

Changes are pervasive (Phase 0 reworked, Phase 1 re-scoped, new Phase 1.5, Phases 2+ re-framed) — replace the ENTIRE file content with:

````markdown
---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection via
  the staged protocol: stack-analysis deployment model (DEPLOYMENT.md)
  first, scaffold of ALL base roles, functional gate, then the extension
  menu — database (postgresql, pgrust), oidc, s3, and product extensions
  one at a time, each gated by a stack-test stage. Use when the user asks
  to create or start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every phase below depends on
it, especially §9 (staged integration protocol) and §20 (deployment
model and application roles).

## Workflow (phased; every extension gated by a test)

Phase 0 produces the agreed deployment model. Phase 1 scaffolds the
WHOLE functional base (all base roles). Extensions are added ONE at a
time after the Stage A functional gate passes, each followed by its
test gate (stack-conventions §9). NEVER scaffold oidc/s3 material
before the base passes its Stage A gate.

Two MANDATORY user checkpoints (stack-conventions §20): base scope
agreement BEFORE scaffolding (Phase 0, step 5); extension menu
selection AFTER the Stage A gate (Phase 1.5).

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
     (stack-analysis iron rule 4).
4. **Run the `stack-analysis` skill** (new-stack mode) against the same
   clone(s): it inventories the upstream product's deployable roles,
   classifies them (base-required / product-extension / infra-extension),
   defines the functional base + functional gate scenario + base stage
   plan, assembles the extension catalog, and writes `DEPLOYMENT.md` at
   the stack root (stack-conventions §20). Do NOT scaffold anything yet.
5. **Checkpoint 1 — base scope agreement.** Present the DEPLOYMENT.md
   functional base, base stage plan, functional gate scenario, and
   extension catalog to the user; get explicit agreement. Disputed scope
   → 2–3 base-scope options with trade-offs — never silently shrink
   (stack-analysis iron rule 3). An AGREED `DEPLOYMENT.md` is required
   before Phase 1 — no exceptions.
6. **Clone lifecycle:** the clone(s) stay for Phase 1 — scaffolding still
   needs upstream config details (config files, flags, entrypoints).
   Delete them when scaffolding is done (§17):
   `rm -rf /tmp/opencode/upstreams/<stack>-<project>`

### Phase 1 — scaffold the functional base (ALL base roles)

7. **Scaffold** exactly per `references/scaffold-checklist.md` — the
   functional base only: EVERY role in the DEPLOYMENT.md
   `## Functional base` section, one compose service per role:
   - Service per role named `<stack>-<role>` per §3 — base ≠ one app
     container (§20); a multi-role product gets a multi-service base.
   - Image per role: the published upstream image, or source-built via
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
   - NO extensions yet — anything outside the functional base is added
     via the Phase 1.5 menu (staged protocol, §9).
8. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
9. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
10. **Build & verify the base:** `cd app/ && sb build`, then follow the
    `stack-test` skill through the Stage A gate — Stage A executes the
    DEPLOYMENT.md functional gate scenario (cross-role E2E). Model vs
    gate mismatch → update DEPLOYMENT.md (living doc, §20) and re-run
    the stage.

### Phase 1.5 — extension menu (checkpoint 2)

11. After the Stage A functional gate passes, present the extension
    catalog from DEPLOYMENT.md — product AND infra extensions, with
    dependencies and ordering constraints. The user selects; record
    selections as `proposed` and declined ones as `declined` (with a
    reason) in DEPLOYMENT.md.

### Phases 2+ — selected extensions, one at a time

Implement the selected extensions one per phase, each followed by its
test gate (stack-conventions §9). The classic infra ladder below is the
default instance of the catalog — ordering constraints always hold: db
first, s3 last, s3fs-fuse never on DB volumes.

12. **Database** (if selected; app needs postgres): prepare the
    `database/postgresql` extension exactly per stack-conventions §8 —
    dual-file idiom, verbatim fragments in `stack-conventions`
    `references/patterns.md` §11. Wire the `postgresql` combo in
    `stackbuilder.toml`, `sb build`, deploy, and pass the **Stage A
    gate** (browser E2E: base + DB, no oidc) per `stack-test`. MUST pass
    before anything else is added.
13. **pgrust alternative**: add the `database/pgrust` variant (identical
    except the `image:` default), rebuild, and run the **Stage A2 gate**.
    Clean pass → make `pgrust` the default combo (§9). Failure → keep
    `postgresql` default and record why in the component README.
14. **oidc** (if selected; app supports it): add the `oidc` extension,
    include it in the default build, keep the tested no-oidc variant as
    proof of the pre-OIDC step, and pass the **Stage B gate** per
    `stack-test`.
15. **s3** (if selected; app needs object storage): the base already uses
    simple named volumes. Add the `s3-storage` extension if the app
    supports S3 natively (env-only fragment) and run the S3 round-trip
    test; otherwise s3fs-fuse — ONLY on volumes with NO database data
    (stack-conventions §11).
16. **Product extensions** (if selected): implement per the DEPLOYMENT.md
    catalog entry — one compose service per role (`<stack>-<role>`, §3),
    image per §19 when upstream publishes none, its own stage + gate.
    Update the extension's status to `implemented` in DEPLOYMENT.md.

## Canonical patterns

Canonical pattern fragments (base compose, environments, database pair,
oidc/s3 extensions) are embedded in the `stack-conventions` skill
(`references/patterns.md`) — imitate those, not live stacks.
````

**Verify:** `grep -c "stack-analysis" .opencode/skills/stack-init/SKILL.md && grep -n "Phase 1.5" .opencode/skills/stack-init/SKILL.md && grep -n "Checkpoint 1" .opencode/skills/stack-init/SKILL.md`
**Commit:** `docs(skills): stack-init — Phase 0 stack-analysis, all-base-roles scaffold, extension menu`

### Task 2.2: stack-init scaffold checklist — functional base + catalog extensions
**File:** `.opencode/skills/stack-init/references/scaffold-checklist.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 2.1 (must match the new Phase 1/1.5 structure)

Replace the ENTIRE file content with:

````markdown
# Stack Init — Scaffold Checklist (Phase 1: functional base)

Checklist for Phase 1 of the `stack-init` workflow — the FUNCTIONAL BASE
only: every role listed in the DEPLOYMENT.md `## Functional base` section
(stack-conventions §20), one compose service per role. Extensions are
selected later from the DEPLOYMENT.md extension catalog (Phase 1.5), one
at a time, each gated by a test (stack-conventions §9). Copy boilerplate
(`LICENSE-APACHE`, `LICENSE-MIT`, `.gitmessage`) verbatim from the
collection root — do not invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `DEPLOYMENT.md` — created and AGREED with the user in Phase 0
      (stack-analysis skill); committed at the stack root next to
      `UPSTREAM.md`. Do NOT scaffold without it.
- [ ] `.gitignore` — must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from the collection root.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from the collection
      root.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir (functional base — ALL base roles)

- [ ] `components/base/docker-compose.yml` — ONE service per base role,
      each named `<stack>-<role>` (§3); base ≠ one app container (§20).
      Logging anchor (`x-logging` with LOG_MAX_SIZE/LOG_MAX_FILE/
      LOG_COMPRESS); named volumes with explicit `name:` (§4); no bind
      mounts; healthcheck where applicable; EVERY env value
      `${VAR:-}`/`${VAR:?}` (§5; before/after fragment in
      `stack-conventions` `references/patterns.md` §12).
- [ ] ONE image per base role: the published upstream image, or
      source-built `app/images/<image>/Dockerfile` via the
      `source-image` skill (self-contained, no vendoring — §19); compose
      references `image: ${IMAGE:-...}` per role.
- [ ] `components/base/.env.example` — per stack-conventions §6 key order
      and hygiene (only vars the base compose actually references).
- [ ] `components/base/` config examples (`*.example` files; delivered via
      `dockerfile_inline` COPY or `configs.content`).
- [ ] `components/environments/forwarding/` — plain ports publish; owns
      the plain/local default for env-dependent vars (§7; layering
      fragment in patterns.md §13).
- [ ] `components/environments/letsencrypt/` — external `letsencrypt-network`
      + `letsencrypt-vhost` volume + VIRTUAL_HOST/LETSENCRYPT_* env.
- [ ] `components/environments/step-ca/` — external `step-ca-network` +
      `step-ca-certs` + `step-ca-vhost` volumes + VIRTUAL_HOST/
      LETSENCRYPT_* env + app TLS env (cert paths `/certs/<VIRTUAL_HOST>/...`).
- [ ] NO env-dependent var (public base URLs, TLS-derived defaults) in
      base compose or base `.env.example` — overlays only (§7).
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native
      config files (numa idiom — embedded fragment in patterns.md §9);
      per-env `extensions`/`combos`.
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Append to `stacks.csv`: `stacks/<path>;-;unverified` (semicolon-separated;
      `-` url when no remote; do not touch other rows).

## First build (Phase 1 gate)

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
- [ ] Stage A gate passed — the DEPLOYMENT.md functional gate scenario
      (cross-role E2E per `stack-test`) before ANY extension is added.

## Later extensions (NOT at Phase 1)

Selected by the user from the DEPLOYMENT.md extension catalog after the
Stage A functional gate (checkpoint 2, §20); added one at a time, each
followed by its test gate (stack-conventions §9). Fragment shapes are
embedded in `stack-conventions` `references/patterns.md` — never copy
from live stacks:

- [ ] Database — `components/extensions/database/postgresql/` dual-file
      pair (patterns.md §11): `docker-compose.yml` (app patch) +
      `docker-compose.db.yml` (`<stack>-db` service) + `.env.example`
      (`COMPOSE_EXTENDS`/`COMPOSE_FILE`/`POSTGRES_*`); volume mounted at
      `/var/lib/postgresql`; `postgres:alpine` default.
- [ ] pgrust — `components/extensions/database/pgrust/` (same shape,
      `malisper/pgrust:v0.2` image default); promote to default combo on a
      clean Stage A2 pass.
- [ ] oidc — `components/extensions/oidc/` (patterns.md §6) and
      `step-ca-trust/` (patterns.md §7) where applicable.
- [ ] s3 — `components/extensions/s3-storage/` (patterns.md §8)
      where the app supports S3 natively; s3fs-fuse fallback ONLY on
      volumes with NO database data.
- [ ] Product extensions — per the DEPLOYMENT.md catalog entry: one
      service per role (`<stack>-<role>`, §3), image per §19 when
      upstream publishes none, own stage + gate; status → `implemented`
      in DEPLOYMENT.md.
````

**Verify:** `grep -n "functional base\|Functional base\|DEPLOYMENT.md" .opencode/skills/stack-init/references/scaffold-checklist.md | head -8`
**Commit:** `docs(skills): stack-init scaffold checklist — functional base + catalog-driven extensions`

### Task 2.3: stack-test — Stage A runs the DEPLOYMENT.md functional gate
**File:** `.opencode/skills/stack-test/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20), 1.2 (routes to stack-analysis gap mode)

Four anchored edits.

**Edit 1 — frontmatter description (lines 3–8).** Replace:

```markdown
description: >-
  Testing procedure for docker-stack-collection stacks: staged browser E2E
  gates (base+DB, then pgrust, then oidc, s3 last — one extension at a
  time), step-ca variant first, never touching the live step-ca-manager
  setup; sb build checks, compose config validation, health, cert-wait,
  OIDC and S3 verification. Use after any stack change.
```

with:

```markdown
description: >-
  Testing procedure for docker-stack-collection stacks: staged browser E2E
  gates (functional base + DB running the DEPLOYMENT.md functional gate
  scenario, then pgrust, then oidc, s3 last — one extension at a time),
  step-ca variant first, never touching the live step-ca-manager setup;
  sb build checks, compose config validation, health, cert-wait, OIDC and
  S3 verification. Use after any stack change.
```

**Edit 2 — staged E2E intro (lines 49–50).** Replace:

```markdown
Verification is a staged pipeline; the browser is the gate between stages
(stack-conventions §9):
```

with:

```markdown
Verification is a staged pipeline; the browser is the gate between stages
(stack-conventions §9). Stage A executes the functional gate scenario
from the stack's `DEPLOYMENT.md` (§20); a stack without DEPLOYMENT.md →
run the `stack-analysis` skill gap mode first.
```

**Edit 3 — Stage A bullet (lines 52–55).** Replace:

```markdown
- **Stage A — base deployment (+ DB, no oidc):** base + the `postgresql`
  database extension when the app needs postgres; NO oidc, NO s3. After
  health checks pass, drive `https://<VIRTUAL_HOST>` with agent-browser.
  MUST pass before any further extension work.
```

with:

```markdown
- **Stage A — functional base (+ DB, no oidc):** ALL base roles from the
  stack's `DEPLOYMENT.md` (stack-conventions §20) + the `postgresql`
  database extension when the app needs postgres; NO oidc, NO s3, NO
  product extensions. After health checks pass, drive
  `https://<VIRTUAL_HOST>` with agent-browser and execute the
  DEPLOYMENT.md **functional gate scenario** — the cross-role
  end-to-end flow that proves the functional base, not just a
  single-container core flow. MUST pass before any further extension
  work. Model vs gate mismatch → update `DEPLOYMENT.md` (living doc,
  §20) and re-run the stage.
```

**Edit 4 — procedure step 6 (lines 84–86).** Replace:

```markdown
6. **Stage A browser gate** (base + DB via the postgresql extension, no
   oidc): clean TLS, local login, one core flow, screenshot artifact
   (`references/browser-e2e.md` §1).
```

with:

```markdown
6. **Stage A browser gate** (functional base + DB via the postgresql
   extension, no oidc): clean TLS, local login, the DEPLOYMENT.md
   functional gate scenario (cross-role E2E), screenshot artifact
   (`references/browser-e2e.md` §1).
```

**Verify:** `grep -n "functional gate scenario" .opencode/skills/stack-test/SKILL.md && ! grep -n "one core flow" .opencode/skills/stack-test/SKILL.md`
**Commit:** `docs(skills): stack-test — Stage A executes the DEPLOYMENT.md functional gate`

### Task 2.4: browser-e2e — Stage A executes the functional gate scenario
**File:** `.opencode/skills/stack-test/references/browser-e2e.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20), 1.2 (routes to stack-analysis gap mode)

Three anchored edits.

**Edit 1 — §1 heading + intro (lines 26–30).** Replace:

```markdown
## 1. Stage A — base deployment (+ DB, no oidc)

Run BEFORE adding the `oidc` extension. When the app needs postgres, this
variant is base + the `postgresql` database extension. Gate: Stage A must
pass or Stage B is meaningless.
```

with:

```markdown
## 1. Stage A — functional base (+ DB, no oidc)

Run BEFORE adding the `oidc` extension. When the app needs postgres, this
variant is the functional base + the `postgresql` database extension. The
functional base = ALL base roles from the stack's `DEPLOYMENT.md`
(stack-conventions §20); a stack without DEPLOYMENT.md → run the
`stack-analysis` skill gap mode first. Gate: Stage A must pass or Stage B
is meaningless.
```

**Edit 2 — core-flow bullet (line 36).** Replace:

```markdown
- [ ] Exercise ONE core app flow (create/edit/delete something small).
```

with:

```markdown
- [ ] Execute the DEPLOYMENT.md **functional gate scenario** — the
      cross-role end-to-end flow that proves the functional base
      (stack-conventions §20), not just a single-container core flow.
      Model vs gate mismatch → update DEPLOYMENT.md (living doc, §20) and
      re-run the stage.
```

**Edit 3 — Stage A2 bullet (lines 46–47).** Replace:

```markdown
- [ ] Same Stage A flow: page loads, TLS clean, local login, one core
      flow, screenshot artifact.
```

with:

```markdown
- [ ] Same Stage A flow: page loads, TLS clean, local login, the
      DEPLOYMENT.md functional gate scenario, screenshot artifact.
```

**Verify:** `grep -n "functional gate scenario" .opencode/skills/stack-test/references/browser-e2e.md && ! grep -n "one core flow" .opencode/skills/stack-test/references/browser-e2e.md`
**Commit:** `docs(skills): browser-e2e — Stage A cross-role functional gate scenario`

### Task 2.5: verification-procedure — Stage A wording
**File:** `.opencode/skills/stack-test/references/verification-procedure.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20)

One anchored edit — §5 Stage A line (lines 46–48). Replace:

```markdown
- [ ] Stage A (base deploy, no oidc): browser smoke test via agent-browser —
      clean TLS, local login, one core flow, screenshot artifact
      (`browser-e2e.md` §1).
```

with:

```markdown
- [ ] Stage A (functional base, no oidc): browser smoke test via
      agent-browser — clean TLS, local login, the DEPLOYMENT.md functional
      gate scenario (cross-role E2E, stack-conventions §20), screenshot
      artifact (`browser-e2e.md` §1).
```

**Verify:** `grep -n "functional gate scenario" .opencode/skills/stack-test/references/verification-procedure.md && ! grep -n "one core flow" .opencode/skills/stack-test/references/verification-procedure.md`
**Commit:** `docs(skills): verification-procedure — Stage A functional gate wording`

### Task 2.6: stack-modernize — deployment-model gap mode, base remediation first
**File:** `.opencode/skills/stack-modernize/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20), 1.2 (routes to stack-analysis gap mode)

Two edits.

**Edit 1 — frontmatter description (lines 4–7).** Replace:

```markdown
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, DB/naming/
  env conformance, artifact cleanup, README regeneration). ONLY when the
  user explicitly requests modernization.
```

with:

```markdown
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, DB/naming/
  env conformance, artifact cleanup, README regeneration, deployment-model
  gap analysis via the stack-analysis skill when DEPLOYMENT.md is
  missing). ONLY when the user explicitly requests modernization.
```

**Edit 2 — replace the entire `## Procedure` section** (lines 25–74; the section runs to the end of the file — delete from `## Procedure` to EOF) **with:**

```markdown
## Procedure

1. **Inventory** the stack: read `src/<name>/` (or `app/`), note existing
   environments, extensions, READMEs, artifacts, and whether
   `DEPLOYMENT.md` exists at the stack root.
2. **Upstream provenance backfill:** if `UPSTREAM.md` is missing, create it
   at the stack root per stack-conventions §17 (one section per project
   dir). Recover the current upstream commit where possible — from the
   pinned image tag/digest, the upstream release notes/changelog, or the
   user — otherwise record `unknown` with a note explaining why. NEVER
   invent a hash. Append the first log row (date, commit or `unknown`,
   image tag/digest, note `backfill at modernization`).
3. **Deployment model gap:** if `DEPLOYMENT.md` is missing, run the
   `stack-analysis` skill in gap mode against the upstream (clone per
   stack-conventions §17) BEFORE any format work: it inventories the
   product's deployable roles, diffs the model against the deployed
   compose services, and writes `DEPLOYMENT.md` at the stack root (§20).
   Completing missing functional-base roles takes PRIORITY over every
   format extra below (§20 remediation rule) — the stack is brought to
   its full functional base FIRST.
4. **Rename** `src/<name>/` → `app/` (git mv inside the stack repo). If the
   stack has multiple projects, split into sibling dirs (`ui/`, `server/`,
   ...) per stack-conventions §1.
5. **Modules**: move `src/ssl-automation/` → `modules/ssl-automation/` and
   declare it in the stack-root `.gitmodules` (submodule URLs:
   `https://github.com/zyrakq/{step-ca,letsencrypt}-manager-stack.git`).
6. **Environments**: add missing ones (forwarding / letsencrypt / step-ca;
   `internal` only when genuinely needed).
7. **Extensions**: add ONLY extensions selected in the DEPLOYMENT.md
   extension catalog (§20) — `oidc` where the app supports it (include in
   default build, keep a no-oidc variant) and `s3-storage` where
   applicable. NEVER add extensions while functional-base roles are still
   missing (§20 remediation rule).
8. **DB conformance**: if postgres runs as a plain base service, move it to
   the `database/{postgresql,pgrust}` extension pair — dual-file idiom per
   stack-conventions §8 (verbatim fragments in its
   `references/patterns.md` §11): `postgres:alpine` floating default
   unless a documented app incompatibility requires older, volume mounted
   at `/var/lib/postgresql`, DB env `${POSTGRES_*:-}` with
   `POSTGRES_PASSWORD:?`, healthcheck `pg_isready` + app
   `depends_on: service_healthy`.
9. **Naming conformance**: rename services to `<stack>-<role>`, align
   `container_name` to equal the service name, network to
   `<stack>-network`, volumes to `<stack>-<purpose>` with explicit `name:`
   (stack-conventions §3).
10. **Env conformance**: purge unused vars from `.env.example` (§6), convert
    hardcoded compose env literals to `${VAR:-}`/`${VAR:?}` (§5;
    before/after fragment in patterns.md §12), and move
    environment-dependent vars (public base URLs, TLS-derived defaults)
    from base into the environment overlays (§7; layering fragment in
    patterns.md §13).
11. **stackbuilder.toml**: convert to the new `[build.environments]` API.
12. **Source-built images**: if the app has no published Docker image,
    convert any context-dependent builds to the `source-image` skill
    pattern (`app/images/<image>/Dockerfile`, self-contained). NEVER vendor
    upstream source into the stack repo — stack-conventions §19.
13. **Artifacts**: delete `.kilocode/`, `.clinerules/` everywhere in the
    stack.
14. **READMEs**: regenerate hub + component READMEs with the `readme-gen`
    skill — they document the base roles and extension statuses per the
    stack's `DEPLOYMENT.md` (§20).
15. **Verify** with the `stack-test` skill (step-ca variant first); Stage A
    executes the DEPLOYMENT.md functional gate scenario (§20).
```

**Verify:** `grep -n "Deployment model gap" .opencode/skills/stack-modernize/SKILL.md && grep -cE "^[0-9]+\. \*\*" .opencode/skills/stack-modernize/SKILL.md` (expect 15)
**Commit:** `docs(skills): stack-modernize — deployment-model gap mode first, base remediation priority`

### Task 2.7: readme-gen — product roles + extension status per DEPLOYMENT.md
**File:** `.opencode/skills/readme-gen/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20)

Changes touch the frontmatter, rules 7–9, and the workflow — replace the
ENTIRE file content with:

````markdown
---
name: Readme Gen
description: >-
  Generate or regenerate stack READMEs in the collection's two canonical
  styles: stack-root hub README and component README (~100-250 lines),
  documenting the product's base roles and extension statuses from its
  DEPLOYMENT.md. Use when creating a stack or modernizing one.
---

# Readme Gen

Load the `stack-conventions` skill first. Full templates with placeholders:
read `references/templates.md`.

## Canonical templates

`references/templates.md` (fully embedded) is the canon for both styles —
component and hub README. Module READMEs
(`modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`)
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
   exactly (Quick Start → Product Roles → Project Structure →
   Available Configurations → Environment Variables → Networks →
   Security → Troubleshooting → Notes).
8. Environment variables grouped Base / Let's Encrypt / Step CA / OIDC /
   Step CA Trust, formatted `- `NAME`: description (default: X)`.
9. Document the product's base roles and every extension's status
   (`implemented` / `proposed` / `declined`) from the stack's
   `DEPLOYMENT.md` (stack-conventions §20) — in the Product Roles and
   Extensions sections. A stack without DEPLOYMENT.md → run the
   `stack-analysis` skill gap mode first.

## Workflow

1. Read the stack's `DEPLOYMENT.md` (base roles, extension catalog,
   statuses — §20) FIRST, then `stackbuilder.toml`, `components/**`, and
   existing READMEs to learn environments, extensions, ports, and
   variables.
2. Generate the component README(s) from the template.
3. Generate the hub README from the template.
4. Cross-check: every env var in `.env.example` files is documented; every
   documented variant exists in `stackbuilder.toml`; every DEPLOYMENT.md
   base role and catalog extension appears in the README with the correct
   status.
````

**Verify:** `grep -n "Product Roles" .opencode/skills/readme-gen/SKILL.md && grep -n "^9\. Document" .opencode/skills/readme-gen/SKILL.md`
**Commit:** `docs(skills): readme-gen — document product roles + extension status per DEPLOYMENT.md`

### Task 2.8: readme templates — Product Roles section + extension status
**File:** `.opencode/skills/readme-gen/references/templates.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20)

Three anchored edits, all inside Template B (the component README template;
`app/README.md` → stack-root `DEPLOYMENT.md` is `../DEPLOYMENT.md`).

**Edit 1 — insert the Product Roles section (between lines 94 and 96).** Replace:

```markdown
Access: `<url>` (for forwarding mode)

## 📁 Project Structure
```

with:

```markdown
Access: `<url>` (for forwarding mode)

## 🧩 Product Roles

The product's functional base per [`DEPLOYMENT.md`](../DEPLOYMENT.md)
(stack-conventions §20) — one compose service per role:

- **<role>**: <1-2 sentence purpose — what breaks when it is absent>

## 📁 Project Structure
```

**Edit 2 — Extensions block with status (lines 113–115).** Replace:

```markdown
### Extensions

- **<ext-name>**: <description>
```

with:

```markdown
### Extensions

- **<ext-name>** (`<status>`): <description> — status per the extension
  catalog in [`DEPLOYMENT.md`](../DEPLOYMENT.md) (stack-conventions §20):
  `implemented` / `proposed` / `declined`
```

**Edit 3 — append to the Rules recap (after line 181, the file's last line).** Append:

```markdown
- Keep the Product Roles section even for single-role products — one
  bullet; it ties the README to the stack's DEPLOYMENT.md contract
  (stack-conventions §20).
```

**Verify:** `grep -n "Product Roles" .opencode/skills/readme-gen/references/templates.md && grep -n "implemented" .opencode/skills/readme-gen/references/templates.md`
**Commit:** `docs(skills): readme templates — Product Roles section + extension status`

### Task 2.9: AGENTS.md — stack-work iron rules gain the deployment-model rule
**File:** `AGENTS.md` (project root)
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20), 1.2 (names the stack-analysis skill)

One anchored insertion — a new FIRST bullet in the "Stack work — iron
rules" list (before the `- Naming:` bullet, line 85). Replace:

```markdown
Non-negotiable rules from it:

- Naming: services and containers are `<stack>-<role>` (e.g. `<stack>-db`,
```

with:

```markdown
Non-negotiable rules from it:

- Deployment model: any new stack — and any change to a product's role
  scope — begins with the `stack-analysis` skill; the agreed
  `DEPLOYMENT.md` (stack-conventions §20) is the contract for the
  functional base and the extension catalog. Missing functional-base
  roles are completed BEFORE any extension work; stack-test Stage A runs
  the DEPLOYMENT.md functional gate scenario.
- Naming: services and containers are `<stack>-<role>` (e.g. `<stack>-db`,
```

**Verify:** `grep -n "Deployment model:" AGENTS.md && grep -n "stack-analysis" AGENTS.md`
**Commit:** `docs(agents): stack-work iron rules — stack-analysis first, DEPLOYMENT.md contract`

---

## Batch 3: Cross-reference verification (single — depends on ALL tasks above)

### Task 3.1: protocol cross-reference verification
**File:** none (verification-only — run from the collection root)
**Test:** this task IS the test for every task above
**Depends:** 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9

Run:

```bash
set -e
cd /home/archuser/projects/docker-stack-collection

# §20 defined in stack-conventions …
grep -q '^## 20\. Deployment model' .opencode/skills/stack-conventions/SKILL.md

# … and cited by every consumer
grep -q '§20' .opencode/skills/stack-analysis/SKILL.md
grep -q '§20' .opencode/skills/stack-init/SKILL.md
grep -q '§20' .opencode/skills/stack-test/SKILL.md
grep -q '§20' .opencode/skills/stack-modernize/SKILL.md
grep -q '§20' .opencode/skills/readme-gen/SKILL.md
grep -q '§20' AGENTS.md

# new skill: files, frontmatter, opener, self-containment
test -f .opencode/skills/stack-analysis/SKILL.md
test -f .opencode/skills/stack-analysis/references/analysis-checklist.md
grep -q '^name: Stack Analysis$' .opencode/skills/stack-analysis/SKILL.md
grep -q '^description: >-$' .opencode/skills/stack-analysis/SKILL.md
grep -q 'Load the `stack-conventions` skill first' .opencode/skills/stack-analysis/SKILL.md
! grep -rq 'stacks/' .opencode/skills/stack-analysis/

# stack-test: functional gate everywhere, no 'one core flow' remnants
grep -q 'functional gate scenario' .opencode/skills/stack-test/SKILL.md
grep -q 'functional gate scenario' .opencode/skills/stack-test/references/browser-e2e.md
grep -q 'functional gate scenario' .opencode/skills/stack-test/references/verification-procedure.md
! grep -rq 'one core flow' .opencode/skills/stack-test/

# stack-init: both checkpoints + checklist updated
grep -q 'Checkpoint 1' .opencode/skills/stack-init/SKILL.md
grep -q 'Phase 1.5' .opencode/skills/stack-init/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-init/references/scaffold-checklist.md

# DEPLOYMENT.md contract mentioned by every consumer
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-conventions/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-modernize/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/readme-gen/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/readme-gen/references/templates.md
grep -q 'DEPLOYMENT.md' AGENTS.md

# readme-gen: Product Roles in both skill and templates
grep -q 'Product Roles' .opencode/skills/readme-gen/SKILL.md
grep -q 'Product Roles' .opencode/skills/readme-gen/references/templates.md

# everything committed
test -z "$(git status --porcelain)"

echo 'ALL CROSS-REFERENCE CHECKS PASSED'
```

The script exits non-zero at the first failing check. A failure means the
named file does not match the corresponding task above — fix it per that
task's content and re-run until the final line prints. No commit of its
own (verification only); commit only if a fix had to be applied.

---

## Execution notes

- All 12 tasks are markdown/protocol edits inside the collection repo —
  no application code, no micode agent definitions, no path pointers into
  `stacks/` (enforced by task 3.1).
- Batches 1 and 2 are independent file writes: run each batch's tasks in
  parallel, one implementer per task, committing per task with the message
  given in it. Batch 3 runs last, alone.
- Anchor quotes in every find→replace block match the current file text
  verbatim; if an anchor no longer matches, re-read the file and apply the
  same change at its new location before proceeding.
- DEPLOYMENT.md files themselves are created per stack later, by running
  the new `stack-analysis` skill (vibe-kanban is the validation case) —
  NOT by this plan.
