# Project Rules

## Artifacts must be committed immediately

Every file created under `thoughts/shared/` (design docs in `designs/`,
implementation plans in `plans/`, ledgers) MUST be committed to git in the
same session, immediately after it is written — before spawning any next
subagent (planner, executor, etc.). Never leave these files untracked or
uncommitted at the end of a response.

Checklist per workflow step:

- design doc written → `git add` + `git commit` right away
- plan written by planner → commit it right away (do not wait for executor)
- execution results → already committed by the executor; verify with
  `git status` and commit anything left untracked

## Pitfalls ledger (PITFALLS.md)

`PITFALLS.md` at this repo root is the shared log of recurring obstacles
(deployment configs, `sb`, docker compose, OIDC/S3/step-ca, stack testing).

- Before debugging an infra/tooling problem, check the ledger: walk up from
  cwd to find `PITFALLS.md`; if not found, use the canonical path
  `/home/archuser/projects/docker-stack-collection/PITFALLS.md`.
- After hitting an obstacle: if already recorded, increment its `hits` and
  update `last`; if new, append an entry (`hits: 1`, `status: open`).
- When a problem gets a real fix, set `status: fixed` and fill `fix:` —
  entries are never deleted.
- Never leave an encountered obstacle unrecorded at the end of a session.
