---
name: Stack Modernize
description: >-
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, DB/naming/
  env conformance, artifact cleanup, README regeneration, deployment-model
  gap analysis via the stack-analysis skill when DEPLOYMENT.md is
  missing). ONLY when the user explicitly requests modernization.
---

# Stack Modernize

Load the `stack-conventions` skill first. Use ONLY when the user explicitly
requests modernization of a specific stack — never migrate old stacks
opportunistically.

## Scope rules

- Target: stacks still using the legacy `src/<name>/` layout or missing
  current-format pieces.
- NEVER touch pre-sb legacy stacks (e.g. elasticsearch/kibana flat compose +
  `deploy.sh`) beyond the artifact cleanup below.
- Exception: deleting `.kilocode/` and `.clinerules/` may be done
  opportunistically in ALL projects without a request.

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
   compose services, and writes `DEPLOYMENT.md` at the stack root (§20);
    it also flags wrong tier order and cross-host https links lacking
    `step-ca-trust`.
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
11. **stackbuilder.toml**: convert to the new `[build.environments]` API;
    drop `yaml_merger` and all comments. Also strip comments from compose,
    move base `ports:` into the forwarding overlay, add missing
    environment `.env.example` files, give secrets example values with a
    generator-command comment, delete stray `.env`/`.stackbuilder/`.
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
