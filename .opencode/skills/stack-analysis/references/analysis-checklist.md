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
