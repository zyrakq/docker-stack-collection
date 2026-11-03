---
name: Stack Test
description: >-
  Testing procedure for docker-stack-collection stacks: staged browser E2E
  gates (Stage A = product parts + database running the DEPLOYMENT.md
  functional gate scenario, then the mandatory infra base stages pgrust,
  oidc, s3 in order, then confirmed extensions one at a time), step-ca
  variant first, never touching the live step-ca-manager setup; sb build
  checks, compose config validation, health, cert-wait, OIDC and S3
  verification. Use after any stack change.
---

# Stack Test

Load the `stack-conventions` skill first. This procedure is the acceptance
test for every stack change.

## Hard rules

- ALWAYS test the step-ca-manager variant first.
- The live step-ca-manager + companion + nginx-proxy + kanidm setup is
  RUNNING. NEVER modify it. If a problem is caused by it, switch to the
  forwarding variant — never touch the manager stack.
- The letsencrypt variant is NOT tested; assume analogous to step-ca minus
  the `STEP_CA_TRUST` env.

## Compat check (pre-pull)

Run this BEFORE the procedure below whenever images may have changed (after
any stack change or image update) — never verify against stale local
images:

1. Pre-pull images first, in the built environment dir:

   ```bash
   cd build/<env>/<combo>/ && docker compose pull
   ```

2. Verify the EXISTING configs still work with the freshly pulled
   containers (health, logs, core functionality), then continue with the
   normal procedure below.
3. If a new container breaks with the old configs: diff the upstream repo
   between the last recorded commit and the new one to identify what
   changed in the configuration surface — `UPSTREAM.md` has both commits;
   use the clone-in-tmp workflow in stack-conventions §17. Fix the configs
   per collection rules, re-verify, then append a new provenance row to
   `UPSTREAM.md` (append-only — never rewrite existing rows).

## Staged browser E2E

Verification is a staged pipeline; the browser is the gate between stages
(stack-conventions §9). Stage A executes the functional gate scenario
from the stack's `DEPLOYMENT.md` (§20); a stack without DEPLOYMENT.md →
run the `stack-analysis` skill gap mode first.

- **Stage A — functional base (product parts + DB, no oidc):** ALL
  product parts from the stack's `DEPLOYMENT.md` (stack-conventions §20)
  + the `postgresql` database stage (mandatory infra, ALWAYS attempted —
  refusal recorded in DEPLOYMENT.md when blocked); NO oidc, NO s3, NO
  product extensions. Tier order: Stage A is the CORE group standalone
  (no outer rings); then one gate per outer group, then a cross-group
  link gate — calls between groups by step-ca domain succeed with
  `step-ca-trust` applied. A gate that cannot run for lack of a
  prerequisite (data, agent, credentials) is NOT passed: promote the
  needed extension to `required-for-gate` in DEPLOYMENT.md, implement
  it, re-run — never advance to an outer ring over an unexercised core. After health checks pass, drive
  `https://<VIRTUAL_HOST>` with agent-browser and execute the
  DEPLOYMENT.md **functional gate scenario** — the cross-part
  end-to-end flow that proves the functional base, not just a
  single-container core flow. MUST pass before any further stage work.
  Model vs gate mismatch → update `DEPLOYMENT.md` (living doc, §20) and
  re-run the stage.
- **Stage A2 — DB alternative (pgrust):** rebuild with the `pgrust` combo,
  same browser gate. Clean pass → `pgrust` becomes the default combo
  (stack-conventions §9). Failure → keep `postgresql` default and record
  why in the component README.
- **Stage B — oidc enabled:** env-based (rebuild with the `oidc`
  extension) or UI-based (provider configured in the app's own web UI —
  gitea, zerobyte), then re-verify in the browser.
- **S3 round-trip — always last:** only when the `s3-storage` extension is
  present, after Stage B.

Before ANY browser step: load the `agent-browser` skill, then load its
runtime content — never work from memory:

```bash
agent-browser skills get core
```

Full checklists: `references/browser-e2e.md`.

## Procedure

Follow `references/verification-procedure.md` in order. Summary:

1. `cd app/ && sb build` — check the `build/<env>/<combo>/` output structure.
2. `cd build/<env>/<combo>/ && cp .env.example .env` and edit values.
3. `docker compose config` — must validate.
4. `docker compose up --build -d`.
5. Health checks pass.
6. **Stage A browser gate** (product parts + DB via the postgresql
   stage, no oidc): clean TLS, local login, the DEPLOYMENT.md
   functional gate scenario (cross-part E2E), screenshot artifact
   (`references/browser-e2e.md` §1).
7. **Stage A2 browser gate** (DB alternative): rebuild with the `pgrust`
   combo, run the same Stage A flow (`references/browser-e2e.md` §1); on
   a clean pass promote `pgrust` to the default combo (stack-conventions
   §9).
8. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
9. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
10. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
    `SSL_CERT_FILE` (open-webui example).
11. **Stage B** (oidc present): env-based rebuild or UI-based configuration,
    then browser login via kanidm + email-matching account linking
    (`references/browser-e2e.md` §2).
12. S3 round-trip when the `s3-storage` extension is present — always LAST.
