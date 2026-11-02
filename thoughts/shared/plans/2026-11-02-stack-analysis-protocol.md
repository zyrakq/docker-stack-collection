# Stack Analysis Protocol Implementation Plan

**Goal:** Add a new `stack-analysis` skill (product-lens deployment modeling → per-stack `DEPLOYMENT.md`) as the mandatory entry point of stack work, and wire it into `stack-init`, `stack-conventions`, `stack-test`, `stack-modernize`, `readme-gen`, and the project `AGENTS.md`.

**Architecture:** A new standalone skill analyzes the upstream product's deployable parts and produces a `DEPLOYMENT.md` at each stack repo root — the living contract (functional base = product parts + mandatory infra, base stage plan + functional gate scenario, extension catalog) that every other skill consumes. The base is executed autonomously as analyzed — no approval gate; unresolvable blockers on mandatory items produce recorded refusals, never silent drops. Exactly ONE user checkpoint exists: the extension catalog presented after the base gates — every entry recorded `available`, never implemented without the user's explicit confirmation. All changes are markdown/protocol files inside the collection repo — no application code, no micode agent edits.

**Design:** `thoughts/shared/designs/2026-11-02-stack-analysis-protocol-design.md`

**Execution gate:** every task below edits `.opencode/skills/**` or the
project `AGENTS.md`. Per the project `AGENTS.md`, such tasks are executed
ONLY after the user has seen this final plan and given his explicit
approval — a documented task is not consent. This plan is presented to
the user before any execution begins.

---

## Decisions made by the planner (design gaps filled)

1. **DEPLOYMENT.md placement: stack repo root** (next to `UPSTREAM.md`), not `app/`. It is a stack-level contract spanning all project dirs of multi-project stacks; `UPSTREAM.md` — its sibling provenance artifact — already lives at the root. (User decision 2026-11-02: a separate file at each stack repo root — «Мы делаем через файл DEPLOYMENT.md!».)
2. **stack-conventions section number: §20, appended after §19.** Its logical home is next to §9 (staged protocol), but inserting there would renumber §10–§19 and break every cross-skill § citation (`stack-init`, `stack-modernize`, `stack-test`, and `AGENTS.md` cite §17/§19 today). Appending avoids all renumbering; §20 cross-references §9/§3/§8/§10/§11/§17/§19 so it is discoverable from the sections it extends.
3. **Clone lifecycle:** the §17 clone-in-tmp clone survives the analysis and is kept through `stack-init` Phase 1 scaffolding (upstream config details — config files, flags, entrypoints — are still needed there), then deleted. This matches §17's "delete after the session" rule. `stack-analysis` documents the exception for the stack-init flow; in every other mode (gap mode, standalone) it deletes the clone at the end of its own run.
4. **ONE user checkpoint — the extension menu (new Phase 5 in stack-init).** It comes AFTER all base gates pass. The mandatory infra — database (postgresql → pgrust), oidc, s3 — is NOT user-selectable: these are base stages, always attempted in the staged order (db first, s3 last, s3fs-fuse never on DB volumes) and refused only on unresolvable blockers, with the refusal and reason recorded in DEPLOYMENT.md. The catalog holds everything outside the functional base — upstream features that are not product parts, optional companion parts, and non-mandated optional infra — every entry recorded `available` and implemented only after the user's explicit confirmation, one at a time, each gated. (User protocol 2026-11-02; base scope itself needs no agreement.)
5. **Existing stacks without DEPLOYMENT.md** (all of them today): `stack-test` Stage A and `stack-modernize` both route to `stack-analysis` gap mode instead of failing — the protocol is adoptable incrementally.
6. **readme-gen:** new "🧩 Product Parts" section in Template B (after Quick Start, before Project Structure) + extension status annotations in the Extensions section; rule 7's canonical section order is updated accordingly.
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
- `.opencode/skills/stack-test/references/browser-e2e.md` — 3 anchored edits (task 2.4)
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

### Task 1.1: stack-conventions §20 — Deployment model and application parts
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
  and application parts (DEPLOYMENT.md), dockerfile_inline
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

## 20. Deployment model and application parts (DEPLOYMENT.md)

Every stack records WHAT the upstream product deploys as, in a per-stack
`DEPLOYMENT.md` at the stack root (next to `UPSTREAM.md`). Produced by
the `stack-analysis` skill; consumed by `stack-init` (Phase 0),
`stack-test` (Stage A), `stack-modernize`, and `readme-gen`.

Definitions:

- **Part** — one deployable component of the upstream product (web app,
  API server, worker, scheduler, ...). One part = exactly one compose
  service, named `<stack>-<role>` (§3).
- **Functional base** — the product parts required for the product's
  core value END-TO-END PLUS the mandatory infra. Base ≠ one app
  container: a product whose core value needs N cooperating parts has an
  N-service base. Overreach guard: a single-part product stays
  single-part — every part in the base must be exercised by the
  functional gate scenario.
- **Mandatory infra** — database (postgresql+pgrust, §8), OIDC (§10),
  S3 (s3-storage, §11) — or other infra the product mandates — is
  ALWAYS part of the functional base, never an optional extension.
  Always attempted as base stages in the staged order: db first, s3
  last, s3fs-fuse never on DB volumes (§9, §11).
- **Functional gate scenario** — the cross-part end-to-end flow that
  proves the functional base; defined in DEPLOYMENT.md, executed as the
  Stage A browser gate (§9) by `stack-test`.
- **Extension catalog** — everything not in the functional base:
  upstream features that are not product parts, optional companion
  parts, and non-mandated optional infra (e.g. an optional cache), each
  with type, status, and dependencies.

DEPLOYMENT.md content spec (all six sections required):

1. `## Product parts` — every deployable part found upstream: name,
   purpose, image source (published / source-built per §19).
2. `## Interaction map` — who talks to whom; what breaks when a part is
   absent.
3. `## Functional base` — the base parts, each justified, PLUS the
   mandatory infra; any mandatory item blocked by unresolvable problems
   is recorded here as REFUSED with the reason — never silently
   dropped, never silently shrunk.
4. `## Base stage plan` — ordered implementation stages, each with its
   gate; Stage A (product parts + database) executes the functional
   gate scenario.
5. `## Extension catalog` — table: extension | type (product/infra) |
   status (`available` / `implemented` / `refused`) | dependencies.
6. `## Open hypotheses` — uncertain classifications with confidence and
   what the functional gate must observe to settle them.

Rules:

- DEPLOYMENT.md is a LIVING document: update and commit it whenever the
  model changes (model-vs-gate mismatch, reclassification, extension
  status change). Unlike `UPSTREAM.md` (§17) it is NOT append-only.
- ONE mandatory user checkpoint: the extension menu from the catalog,
  AFTER the base gates pass. Base scope itself needs NO user agreement
  — the base is executed as analyzed. Base scope the analysis cannot
  decide with confidence → 2–3 options with trade-offs to the user (an
  exception path, not a standing gate) — never silently shrink, never
  inflate.
- Confirmation rule: catalog extensions are recorded as `available` and
  NEVER implemented without the user's explicit confirmation; confirmed
  ones go one at a time, each gated.
- Mandatory-infra rule: database, S3, OIDC (or other product-mandated
  infra) are always-attempted base stages; a mandatory item blocked by
  unresolvable problems is REFUSED with the reason recorded in
  DEPLOYMENT.md — never silently dropped, never silently skipped.
- Remediation rule: an existing stack missing functional-base parts
  (including mandatory infra) completes them BEFORE any extension work
  (gap mode in the `stack-analysis` skill).
```

**Verify:** `grep -n "^## 20\." .opencode/skills/stack-conventions/SKILL.md && grep -c "stack-analysis" .opencode/skills/stack-conventions/SKILL.md`
**Commit:** `docs(skills): stack-conventions §20 — deployment model and application parts (DEPLOYMENT.md)`

### Task 1.2: NEW skill — stack-analysis/SKILL.md
**File:** `.opencode/skills/stack-analysis/SKILL.md` (new)
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** none (cites §20 created in 1.1 — same batch, content complete)

Create the directory and file with EXACTLY this content:

````markdown
---
name: Stack Analysis
description: >-
  Analyze an upstream product's deployable parts and produce the stack's
  DEPLOYMENT.md deployment model: inventory parts from the upstream repo
  (clone-in-tmp), build the interaction map, classify every part/feature
  as base or extension, define the functional base (product parts +
  mandatory infra) and its cross-part functional gate scenario, and
  assemble the extension catalog. Mandatory Phase 0 of stack-init; gap
  mode diffs existing stacks against the model. Use when creating a new
  stack, when a stack's product scope or missing parts are questioned, or
  before modernizing a stack that lacks DEPLOYMENT.md.
---

# Stack Analysis

Load the `stack-conventions` skill first — §20 defines the deployment
model this skill produces.

## Iron rules

1. **Product lens, not infra lens.** The functional base is the
   product's parts required for its core value end-to-end — ALL of
   them, however many — PLUS the mandatory infra (§20); NOT "one app
   container + DB". The base scope and stage plan are executed as
   analyzed — no approval gate.
2. **Overreach guard.** Every part added to base must be exercised by
   the functional gate scenario. A single-part product stays
   single-part — an inflated base is as wrong as a shrunken one.
3. **Never silently shrink.** Base scope the analysis cannot decide
   with confidence → present 2–3 options with trade-offs to the user
   (an exception path, not a standing gate). Undocumented/ambiguous
   parts → record as hypotheses with confidence in
   `## Open hypotheses`, validated at the functional gate.
4. **Mandatory infra is always attempted.** Database (postgresql+pgrust,
   §8), OIDC (§10), S3 (s3-storage, §11) — or other infra the product
   mandates — are ALWAYS base stages, never optional extensions. A
   mandatory item blocked by unresolvable problems is REFUSED with the
   reason recorded in DEPLOYMENT.md — never silently dropped, never
   silently skipped.
5. **No upstream access → stop and ask.** Never guess a deployment
   model.
6. **No vendoring.** The clone-in-tmp clone (§17) is reference-only and
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

3. **Inventory deployable parts** from the clone — full checklist in
   `references/analysis-checklist.md`: upstream compose files,
   Dockerfiles, workspace/crate/package structure, CLI entrypoints,
   published ports, deployment docs, release artifacts.
4. **Build the interaction map** — who talks to whom, and what breaks
   when a part is absent.
5. **Classify every part/feature**: a product part required for the
   core value → functional base; mandatory infra (database §8, oidc
   §10, s3 §11 — or other product-mandated infra) → functional base,
   always attempted (iron rule 4); everything else → extension
   catalog, recorded `available`. Justify each classification;
   uncertain ones become hypotheses (iron rule 3).
6. **Define the functional base** and the **functional gate scenario**
   (the cross-part E2E flow that proves it), then the **base stage
   plan** — ordered stages, each with its own gate; Stage A (product
   parts + database) executes the functional gate scenario.
7. **Assemble the extension catalog** — ONE catalog for everything
   outside the functional base, every entry recorded `available`, with
   type, status, dependencies. Ordering constraints preserved: db
   first, s3 last, s3fs-fuse never on DB volumes (§9, §11).
8. **Write `DEPLOYMENT.md`** at the stack root (next to `UPSTREAM.md`)
   with the six sections per §20. Commit it in the stack repo.
9. **No approval gate.** The base scope and base stage plan are
   executed as analyzed (§20) — `stack-init` scaffolds the functional
   base without further agreement. The user sees the extension catalog
   only at the extension-menu checkpoint (stack-init Phase 5), after
   the base gates pass.
10. **Delete the tmp clone** per §17 at the end of the analysis session
    (`rm -rf /tmp/opencode/upstreams/<stack>-<project>`). EXCEPTION:
    when running as `stack-init` Phase 0, the clone is kept for Phase 1
    scaffolding (upstream config details) and deleted there.

## Gap mode (existing stacks)

1. Read the stack's deployed compose services and `UPSTREAM.md`; run the
   workflow above against the upstream.
2. Diff model vs deployed: missing base parts (including mandatory
   infra), undocumented deployed services, extensions absent from the
   catalog.
3. Output a remediation plan — completing missing base parts takes
   PRIORITY over any extension work (§20 remediation rule). Extensions
   are offered from the catalog only after the base is complete and its
   functional gate passes.
4. Create or update `DEPLOYMENT.md`: already-deployed extensions marked
   `implemented`, explicitly rejected ones `refused` with a reason, the
   rest `available`.

## Exemplars

Validation cases to run mentally against any produced model:

- Mandatory-infra completeness: the base must include database, S3, and
  OIDC (or other product-mandated infra) as base stages — each either
  staged or refused with a recorded reason; none of them may appear as
  an optional catalog extension.
- Anti-overreach: a simple single-part product must come out with a
  single-part base — the analysis must not inflate it.
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

## 1. Part inventory (from the upstream clone)

- [ ] Upstream compose files (repo root and any deploy/ or docker/
      dirs): every service = a candidate part (name, image/build,
      ports, env).
- [ ] Dockerfiles at repo root and in subdirs — each buildable target
      is a candidate part.
- [ ] Workspace/crate/package structure: Cargo workspace members,
      npm/pnpm workspaces and packages, go `cmd/*` dirs — each
      deployable binary is a candidate part.
- [ ] CLI entrypoints (bin targets, `main.go` files, package.json
      `bin`) — distinguish deployable parts from build tooling.
- [ ] Published ports and listeners (config defaults, `EXPOSE`, docs).
- [ ] Deployment docs (README, docs/deploy*, k8s/helm charts, systemd
      units) — upstream's own deployment story names the parts.
- [ ] Release artifacts (per-platform binaries, per-component
      archives).

## 2. Interaction map

- [ ] For each part: what it talks to (DB, queue, other parts,
      external services), on what port/protocol.
- [ ] For each part: what breaks when it is absent — which
      user-visible feature degrades or dies.
- [ ] The data flow of the product's core value, end-to-end.

## 3. Classification (every part + notable feature)

- [ ] Product part required for the core value → functional base,
      justified by the functional gate scenario.
- [ ] Mandatory infra — database (§8), oidc (§10), s3 (§11), or other
      product-mandated infra → functional base, ALWAYS attempted;
      unresolvable blocker → refusal with the reason recorded.
- [ ] Everything else → extension catalog, recorded `available`.
- [ ] Uncertain → hypothesis with confidence (high/medium/low) + what
      the functional gate must observe to settle it.

## 4. Functional base & gate

- [ ] Functional base = the product parts required for the product's
      core value end-to-end PLUS the mandatory infra. Overreach guard:
      every part justified; single-part products stay single-part.
- [ ] Functional gate scenario: a concrete cross-part E2E flow (user
      action → expected observable result), executable with
      agent-browser per the `stack-test` skill.
- [ ] Base stage plan: ordered stages, each with its own gate; Stage A
      (product parts + database) executes the functional gate
      scenario.

## 5. Extension catalog

- [ ] One table: extension | type (product/infra) | status
      (available/implemented/refused) | dependencies.
- [ ] Ordering constraints preserved: db first, s3 last, s3fs-fuse
      never on DB volumes (§9, §11).

## 6. DEPLOYMENT.md output

- [ ] All six §20 sections present: Product parts, Interaction map,
      Functional base, Base stage plan, Extension catalog, Open
      hypotheses.
- [ ] Written at the stack root, next to `UPSTREAM.md`; committed in
      the stack repo.
- [ ] No approval gate: the base scope and stage plan are executed as
      analyzed (§20) — the user sees the catalog only at the
      extension-menu checkpoint.

## 7. Gap mode extras (existing stacks)

- [ ] Diff model vs deployed compose: missing base parts (including
      mandatory infra), undocumented deployed services, extensions
      absent from the catalog.
- [ ] Remediation plan: base parts FIRST, extensions only after the
      functional gate passes (§20 remediation rule).
- [ ] Deployed extensions marked `implemented`; explicitly rejected
      ones `refused` with a reason; the rest `available`.

## 8. Sanity checks (both directions)

- [ ] Shrunken-base check: no part whose absence breaks the core value
      sits outside the base.
- [ ] Inflated-base check: no part in the base that the functional
      gate scenario does not exercise.
- [ ] Mandatory-infra check: database, S3, OIDC (or other
      product-mandated infra) are base stages — each staged or refused
      with a recorded reason — never optional catalog extensions.
- [ ] Clone deleted: `rm -rf /tmp/opencode/upstreams/<stack>-<project>`
      (unless running as stack-init Phase 0 — the clone lives on for
      scaffolding).
````

**Verify:** `test -f .opencode/skills/stack-analysis/references/analysis-checklist.md && grep -c "^## " .opencode/skills/stack-analysis/references/analysis-checklist.md` (expect 8)
**Commit:** `docs(skills): add stack-analysis analysis-checklist reference`

---

## Batch 2: Consumer skills (parallel — 9 implementers; depends on Batch 1 for §20/stack-analysis citations to resolve)

### Task 2.1: stack-init — Phase 0 analysis, full functional base, Phase 5 extension menu
**File:** `.opencode/skills/stack-init/SKILL.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1, 1.2 (cites §20 and the `stack-analysis` skill)

Changes are pervasive (Phase 0 reworked, Phase 1 re-scoped, new Phase 5, Phases 2+ re-framed) — replace the ENTIRE file content with:

````markdown
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
````

**Verify:** `grep -c "stack-analysis" .opencode/skills/stack-init/SKILL.md && grep -n "Phase 5" .opencode/skills/stack-init/SKILL.md && grep -n "No approval gate" .opencode/skills/stack-init/SKILL.md`
**Commit:** `docs(skills): stack-init — Phase 0 stack-analysis, full functional base, Phase 5 extension menu`

### Task 2.2: stack-init scaffold checklist — functional base + staged base stages + confirmed extensions
**File:** `.opencode/skills/stack-init/references/scaffold-checklist.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 2.1 (must match the new Phase 1–5 structure)

Replace the ENTIRE file content with:

````markdown
# Stack Init — Scaffold Checklist (Phase 1: functional base)

Checklist for Phase 1 of the `stack-init` workflow — the functional base
scaffold: EVERY product part listed in the DEPLOYMENT.md
`## Functional base` section (stack-conventions §20), one compose service
per part, plus the mandatory database stage. Phases 2–4 complete the
remaining mandatory infra stages (pgrust, oidc, s3); Phase 5 is the
extension-menu confirmation — confirmed extensions are added one at a
time after that, each gated by a test (stack-conventions §9). Copy
boilerplate (`LICENSE-APACHE`, `LICENSE-MIT`, `.gitmessage`) verbatim
from the collection root — do not invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `DEPLOYMENT.md` — produced by the stack-analysis skill in Phase 0;
      committed at the stack root next to `UPSTREAM.md`; executed as
      analyzed — no approval gate (§20). Do NOT scaffold without it.
- [ ] `.gitignore` — must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from the collection root.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from the collection
      root.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir (functional base — ALL product parts)

- [ ] `components/base/docker-compose.yml` — ONE service per product
      part, each named `<stack>-<role>` (§3); base ≠ one app container
      (§20).
      Logging anchor (`x-logging` with LOG_MAX_SIZE/LOG_MAX_FILE/
      LOG_COMPRESS); named volumes with explicit `name:` (§4); no bind
      mounts; healthcheck where applicable; EVERY env value
      `${VAR:-}`/`${VAR:?}` (§5; before/after fragment in
      `stack-conventions` `references/patterns.md` §12).
- [ ] ONE image per product part: the published upstream image, or
      source-built `app/images/<image>/Dockerfile` via the
      `source-image` skill (self-contained, no vendoring — §19); compose
      references `image: ${IMAGE:-...}` per part.
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
- [ ] `components/extensions/database/postgresql/` — the database stage
      (mandatory infra, ALWAYS attempted): dual-file pair (patterns.md
      §11): `docker-compose.yml` (app patch) + `docker-compose.db.yml`
      (`<stack>-db` service) + `.env.example` (`COMPOSE_EXTENDS`/
      `COMPOSE_FILE`/`POSTGRES_*`); volume mounted at
      `/var/lib/postgresql`; `postgres:alpine` default; wire the
      `postgresql` combo in `stackbuilder.toml`. Unresolvable blocker →
      REFUSE the stage with the reason recorded in DEPLOYMENT.md.
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native
      config files (numa idiom — embedded fragment in patterns.md §9);
      per-env `extensions`/`combos`.
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Append to `stacks.csv`: `stacks/<path>;-;unverified` (semicolon-separated;
      `-` url when no remote; do not touch other rows).

## First build (Stage A gate)

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
- [ ] Stage A gate passed — the DEPLOYMENT.md functional gate scenario
      (cross-part E2E per `stack-test`) before ANY further stage work.

## Later base stages (mandatory infra — Phases 2–4, NOT at Phase 1)

Added one per phase after the Stage A gate, each followed by its test
gate (stack-conventions §9) — ALWAYS attempted; an unresolvable blocker
is REFUSED with the reason recorded in DEPLOYMENT.md. Fragment shapes
are embedded in `stack-conventions` `references/patterns.md` — never
copy from live stacks:

- [ ] pgrust — `components/extensions/database/pgrust/` (same shape as
      the postgresql stage, `malisper/pgrust:v0.2` image default);
      promote to default combo on a clean Stage A2 pass.
- [ ] oidc — `components/extensions/oidc/` (patterns.md §6) and
      `step-ca-trust/` (patterns.md §7) where applicable.
- [ ] s3 — `components/extensions/s3-storage/` (patterns.md §8) where
      the app supports S3 natively; s3fs-fuse fallback ONLY on volumes
      with NO database data.

## Confirmed extensions (ONLY after explicit user confirmation — Phase 5)

Chosen from the DEPLOYMENT.md extension catalog at the Phase 5 menu —
NEVER implemented without explicit user confirmation — then added one at
a time, each followed by its test gate (stack-conventions §9):

- [ ] Product extensions — per the DEPLOYMENT.md catalog entry: one
      service per part (`<stack>-<role>`, §3), image per §19 when
      upstream publishes none, own stage + gate; status → `implemented`
      in DEPLOYMENT.md when it lands.
- [ ] Non-mandated optional infra — implemented only on explicit user
      confirmation at the Phase 5 menu; same one-at-a-time staging and
      gating; refused with a reason if rejected, `available` if
      unselected.
````

**Verify:** `grep -n "functional base\|Functional base\|DEPLOYMENT.md" .opencode/skills/stack-init/references/scaffold-checklist.md | head -8`
**Commit:** `docs(skills): stack-init scaffold checklist — functional base, staged base stages, confirmed extensions`

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
  gates (Stage A = product parts + database running the DEPLOYMENT.md
  functional gate scenario, then the mandatory infra base stages pgrust,
  oidc, s3 in order, then confirmed extensions one at a time), step-ca
  variant first, never touching the live step-ca-manager setup; sb build
  checks, compose config validation, health, cert-wait, OIDC and S3
  verification. Use after any stack change.
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
- **Stage A — functional base (product parts + DB, no oidc):** ALL
  product parts from the stack's `DEPLOYMENT.md` (stack-conventions §20)
  + the `postgresql` database stage (mandatory infra, ALWAYS attempted —
  refusal recorded in DEPLOYMENT.md when blocked); NO oidc, NO s3, NO
  product extensions. After health checks pass, drive
  `https://<VIRTUAL_HOST>` with agent-browser and execute the
  DEPLOYMENT.md **functional gate scenario** — the cross-part
  end-to-end flow that proves the functional base, not just a
  single-container core flow. MUST pass before any further stage work.
  Model vs gate mismatch → update `DEPLOYMENT.md` (living doc, §20) and
  re-run the stage.
```

**Edit 4 — procedure step 6 (lines 84–86).** Replace:

```markdown
6. **Stage A browser gate** (base + DB via the postgresql extension, no
   oidc): clean TLS, local login, one core flow, screenshot artifact
   (`references/browser-e2e.md` §1).
```

with:

```markdown
6. **Stage A browser gate** (product parts + DB via the postgresql
   stage, no oidc): clean TLS, local login, the DEPLOYMENT.md
   functional gate scenario (cross-part E2E), screenshot artifact
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
## 1. Stage A — functional base (product parts + DB, no oidc)

Run BEFORE adding the `oidc` stage. This variant is the functional base +
the `postgresql` database stage (mandatory infra, ALWAYS attempted). The
functional base = ALL product parts from the stack's `DEPLOYMENT.md`
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
      cross-part end-to-end flow that proves the functional base
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
**Commit:** `docs(skills): browser-e2e — Stage A cross-part functional gate scenario`

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
      gate scenario (cross-part E2E, stack-conventions §20), screenshot
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
   product's deployable parts, diffs the model against the deployed
   compose services, and writes `DEPLOYMENT.md` at the stack root (§20).
   Completing missing functional-base parts — product parts AND
   mandatory infra (database, oidc, s3 — or other product-mandated
   infra), each either completed or REFUSED with the reason recorded —
   takes PRIORITY over every format extra below (§20 remediation rule):
   the stack is brought to its full functional base FIRST.
4. **Rename** `src/<name>/` → `app/` (git mv inside the stack repo). If the
   stack has multiple projects, split into sibling dirs (`ui/`, `server/`,
   ...) per stack-conventions §1.
5. **Modules**: move `src/ssl-automation/` → `modules/ssl-automation/` and
   declare it in the stack-root `.gitmodules` (submodule URLs:
   `https://github.com/zyrakq/{step-ca,letsencrypt}-manager-stack.git`).
6. **Environments**: add missing ones (forwarding / letsencrypt / step-ca;
   `internal` only when genuinely needed).
7. **Extensions**: complete the mandatory infra stages — `pgrust`
   (database pair), `oidc` where the app supports it (include in default
   build, keep a no-oidc variant), `s3-storage` where applicable — ALWAYS
   attempted, each followed by its test gate; then ONLY user-confirmed
   catalog extensions, one at a time. NEVER add a confirmed extension
   while functional-base parts are still missing (§20 remediation rule).
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
    skill — they document the base parts and extension statuses per the
    stack's `DEPLOYMENT.md` (§20).
15. **Verify** with the `stack-test` skill (step-ca variant first); Stage A
    (product parts + database) executes the DEPLOYMENT.md functional gate
    scenario (§20).
```

**Verify:** `grep -n "Deployment model gap" .opencode/skills/stack-modernize/SKILL.md && grep -cE "^[0-9]+\. \*\*" .opencode/skills/stack-modernize/SKILL.md` (expect 15)
**Commit:** `docs(skills): stack-modernize — deployment-model gap mode first, base remediation priority`

### Task 2.7: readme-gen — product parts + extension status per DEPLOYMENT.md
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
  documenting the product's base parts and extension statuses from its
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
   exactly (Quick Start → Product Parts → Project Structure →
   Available Configurations → Environment Variables → Networks →
   Security → Troubleshooting → Notes).
8. Environment variables grouped Base / Let's Encrypt / Step CA / OIDC /
   Step CA Trust, formatted `- `NAME`: description (default: X)`.
9. Document the product's base parts and every extension's status
   (`available` / `implemented` / `refused`) from the stack's
   `DEPLOYMENT.md` (stack-conventions §20) — in the Product Parts and
   Extensions sections. A stack without DEPLOYMENT.md → run the
   `stack-analysis` skill gap mode first.

## Workflow

1. Read the stack's `DEPLOYMENT.md` (base parts, extension catalog,
   statuses — §20) FIRST, then `stackbuilder.toml`, `components/**`, and
   existing READMEs to learn environments, extensions, ports, and
   variables.
2. Generate the component README(s) from the template.
3. Generate the hub README from the template.
4. Cross-check: every env var in `.env.example` files is documented; every
   documented variant exists in `stackbuilder.toml`; every DEPLOYMENT.md
   base part and catalog extension appears in the README with the correct
   status.
````

**Verify:** `grep -n "Product Parts" .opencode/skills/readme-gen/SKILL.md && grep -n "^9\. Document" .opencode/skills/readme-gen/SKILL.md`
**Commit:** `docs(skills): readme-gen — document product parts + extension status per DEPLOYMENT.md`

### Task 2.8: readme templates — Product Parts section + extension status
**File:** `.opencode/skills/readme-gen/references/templates.md`
**Test:** none (protocol markdown — verified by task 3.1)
**Depends:** 1.1 (cites §20)

Three anchored edits, all inside Template B (the component README template;
`app/README.md` → stack-root `DEPLOYMENT.md` is `../DEPLOYMENT.md`).

**Edit 1 — insert the Product Parts section (between lines 94 and 96).** Replace:

```markdown
Access: `<url>` (for forwarding mode)

## 📁 Project Structure
```

with:

```markdown
Access: `<url>` (for forwarding mode)

## 🧩 Product Parts

The product's functional base per [`DEPLOYMENT.md`](../DEPLOYMENT.md)
(stack-conventions §20) — one compose service per part:

- **<part>**: <1-2 sentence purpose — what breaks when it is absent>

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
  `available` / `implemented` / `refused`
```

**Edit 3 — append to the Rules recap (after line 181, the file's last line).** Append:

```markdown
- Keep the Product Parts section even for single-part products — one
  bullet; it ties the README to the stack's DEPLOYMENT.md contract
  (stack-conventions §20).
```

**Verify:** `grep -n "Product Parts" .opencode/skills/readme-gen/references/templates.md && grep -n "implemented" .opencode/skills/readme-gen/references/templates.md`
**Commit:** `docs(skills): readme templates — Product Parts section + extension status`

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

# stack-init: no approval gate, single Phase 5 checkpoint, checklist updated
grep -q 'No approval gate' .opencode/skills/stack-init/SKILL.md
grep -q 'Phase 5' .opencode/skills/stack-init/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-init/references/scaffold-checklist.md

# DEPLOYMENT.md contract mentioned by every consumer
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-conventions/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/stack-modernize/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/readme-gen/SKILL.md
grep -q 'DEPLOYMENT.md' .opencode/skills/readme-gen/references/templates.md
grep -q 'DEPLOYMENT.md' AGENTS.md

# readme-gen: Product Parts in both skill and templates
grep -q 'Product Parts' .opencode/skills/readme-gen/SKILL.md
grep -q 'Product Parts' .opencode/skills/readme-gen/references/templates.md

# status vocabulary: §20 names the catalog statuses; consumer skills use
# them consistently and never the retired status words
grep -q 'available' .opencode/skills/stack-conventions/SKILL.md
! grep -rq 'propos[e]d\|declin[e]d' .opencode/skills/stack-conventions/ .opencode/skills/stack-analysis/ .opencode/skills/stack-init/ .opencode/skills/stack-modernize/ .opencode/skills/readme-gen/

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
  the new `stack-analysis` skill — NOT by this plan. Validation case: the
  next real stack created or modernized under the protocol deploys the
  full functional base — every product part plus the mandatory infra
  (database, pgrust, oidc, s3), each stage passed or refused with a
  recorded reason — and passes the functional gate before any extension
  is offered; a single-part product must still come out single-part
  (anti-overreach).
