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
