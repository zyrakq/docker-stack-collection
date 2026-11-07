---
name: stack-audit
description: >-
  Final conventions-compliance audit of a stack after e2e testing and
  teardown. Runs the automated checkers, makes cosmetic fixes (comments,
  ordering, naming of example values, stray artifacts), rebuilds with sb
  and confirms the output is consistent, commits. Does not re-test unless
  logic was reworked. Use as the last step after stack-test.
---

# Stack Audit

Load `stack-conventions` first. This skill runs AFTER stack-test and its
teardown.

## Procedure

1. Run `bash <skills-dir>/stack-conventions/scripts/check-stack.sh <stack-dir>`
   and `check-gitkeep.sh <stack-dir>`; fix every violation.
2. Manual review against stack-conventions Hard rules:
   - no `yaml_merger` in `stackbuilder.toml`
   - no `ports:` in base; no `.env` under `components/`
   - every environment dir has `.env.example`; no var declared in two
     layers (sb merges base + environment + extensions)
   - no comments in compose/toml; `.env.example` comments only as
     generator commands above secrets; every secret has an example value
   - naming, env wiring, `.env.example` hygiene (§3, §5, §6, §7)
3. Delete `.stackbuilder/`; ensure no `.env` outside `build/<env>/<combo>/` (remove strays in `components/`/app dirs); confirm no containers or
   volumes from testing remain (`docker ps -a`, `docker volume ls`).
4. If any component file changed: `cd app/ && sb build` and check that
   `build/` is regenerated; `docker compose config` must validate in each
   changed built dir. Never run compose from `components/`.
5. Commit (build output is committed; `.stackbuilder/` never).

## Re-test policy

- Cosmetic changes (comments, ordering, whitespace, example values,
  file moves that don't alter the built output) → NO re-test.
- Logic changes (ports moved between layers, env defaults, services,
  images, volumes, commands) → report them to the parent, which must
  re-run the affected stack-test stage and teardown again.

## Boundaries

Never edit agents or skills. Never touch the host. Never name other
stacks as examples.
