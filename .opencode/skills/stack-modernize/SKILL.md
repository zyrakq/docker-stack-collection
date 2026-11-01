---
name: Stack Modernize
description: >-
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, DB/naming/
  env conformance, artifact cleanup, README regeneration). ONLY when the
  user explicitly requests modernization.
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
   environments, extensions, READMEs, and artifacts.
2. **Upstream provenance backfill:** if `UPSTREAM.md` is missing, create it
   at the stack root per stack-conventions §17 (one section per project
   dir). Recover the current upstream commit where possible — from the
   pinned image tag/digest, the upstream release notes/changelog, or the
   user — otherwise record `unknown` with a note explaining why. NEVER
   invent a hash. Append the first log row (date, commit or `unknown`,
   image tag/digest, note `backfill at modernization`).

3. **Rename** `src/<name>/` → `app/` (git mv inside the stack repo). If the
   stack has multiple projects, split into sibling dirs (`ui/`, `server/`,
   ...) per stack-conventions §1.
4. **Modules**: move `src/ssl-automation/` → `modules/ssl-automation/` and
   declare it in the stack-root `.gitmodules` (submodule URLs:
   `https://github.com/zyrakq/{step-ca,letsencrypt}-manager-stack.git`).
5. **Environments**: add missing ones (forwarding / letsencrypt / step-ca;
   `internal` only when genuinely needed).
6. **Extensions**: add `oidc` where the app supports it (include in default
   build, keep a no-oidc variant) and `s3-storage` where applicable.
7. **DB conformance**: if postgres runs as a plain base service, move it to
   the `database/{postgresql,pgrust}` extension pair — dual-file idiom per
   stack-conventions §8 (verbatim fragments in its
   `references/patterns.md` §11): `postgres:alpine` floating default
   unless a documented app incompatibility requires older, volume mounted
   at `/var/lib/postgresql`, DB env `${POSTGRES_*:-}` with
   `POSTGRES_PASSWORD:?`, healthcheck `pg_isready` + app
   `depends_on: service_healthy`.
8. **Naming conformance**: rename services to `<stack>-<role>`, align
   `container_name` to equal the service name, network to
   `<stack>-network`, volumes to `<stack>-<purpose>` with explicit `name:`
   (stack-conventions §3).
9. **Env conformance**: purge unused vars from `.env.example` (§6), convert
   hardcoded compose env literals to `${VAR:-}`/`${VAR:?}` (§5;
   before/after fragment in patterns.md §12), and move
   environment-dependent vars (public base URLs, TLS-derived defaults)
   from base into the environment overlays (§7; layering fragment in
   patterns.md §13).
10. **stackbuilder.toml**: convert to the new `[build.environments]` API.
11. **Source-built images**: if the app has no published Docker image,
    convert any context-dependent builds to the `source-image` skill
    pattern (`app/images/<image>/Dockerfile`, self-contained). NEVER vendor
    upstream source into the stack repo — stack-conventions §19.
12. **Artifacts**: delete `.kilocode/`, `.clinerules/` everywhere in the
    stack.
13. **READMEs**: regenerate hub + component READMEs with the `readme-gen`
    skill.
14. **Verify** with the `stack-test` skill (step-ca variant first).
