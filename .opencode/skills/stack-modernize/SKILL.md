---
name: Stack Modernize
description: >-
  Bring an existing stack to the current format (src/ to app/ rename,
  modules/ submodules, missing environments, oidc/s3 extensions, artifact
  cleanup, README regeneration). ONLY when the user explicitly requests
  modernization.
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
   at the stack root per stack-conventions §13 (one section per project
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
7. **stackbuilder.toml**: convert to the new `[build.environments]` API.
8. **Artifacts**: delete `.kilocode/`, `.clinerules/` everywhere in the
   stack.
9. **READMEs**: regenerate hub + component READMEs with the `readme-gen`
   skill.
10. **Verify** with the `stack-test` skill (step-ca variant first).
