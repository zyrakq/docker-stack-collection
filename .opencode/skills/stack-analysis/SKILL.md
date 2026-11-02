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
