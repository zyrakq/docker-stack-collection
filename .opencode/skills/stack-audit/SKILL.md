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
2. FULL manual review — the scripts catch only part of the rules. Read
   every file of the stack (every compose, every `.env.example`, toml,
   .gitignore, README) and check EACH item; fix all findings:
   - folder name, `.gitkeep`, `.vscode/settings.json`, `.gitignore` content
   - `stackbuilder.toml`: no `yaml_merger`, combos only `entire`/`entire-trust`, no comments
   - no `ports:` in base; no `.env` outside `build/<env>/<combo>/`
   - every environment dir has `.env.example`; no var declared in two layers
   - no comments in compose/toml
   - every `.env.example`: no headers, no descriptions, comments only as a
     generator command directly above a secret; NO empty secrets — each has
     an example value; no dead vars; standard key order (§6)
   - no `${VAR:?text}` — only `${VAR:?}`
   - extension names short and generic (max two words, e.g. `smtp`)
   - naming (§3), env wiring with no bare literals (§5), volumes (§4),
     DB rules, images (§19), UPSTREAM.md/DEPLOYMENT.md/README present
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
