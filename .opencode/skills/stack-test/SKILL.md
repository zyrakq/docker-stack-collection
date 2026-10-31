---
name: Stack Test
description: >-
  Testing procedure for docker-stack-collection stacks: step-ca variant
  first, never touching the live step-ca-manager setup; sb build checks,
  compose config validation, health, cert-wait, OIDC and S3 verification.
  Use after any stack change.
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
   use the clone-in-tmp workflow in stack-conventions §13. Fix the configs
   per collection rules, re-verify, then append a new provenance row to
   `UPSTREAM.md` (append-only — never rewrite existing rows).

## Staged browser E2E

Verification is a staged pipeline; the browser is the gate between stages:

- **Stage A — base deployment (no oidc):** after health checks pass, drive
  `https://<VIRTUAL_HOST>` with agent-browser. MUST pass before any
  extension work.
- **Stage B — oidc enabled:** env-based (rebuild with the `oidc`
  extension) or UI-based (provider configured in the app's own web UI —
  gitea, zerobyte), then re-verify in the browser.

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
6. **Stage A browser gate** (base deploy, no oidc): clean TLS, local login,
   one core flow, screenshot artifact (`references/browser-e2e.md` §1).
7. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
8. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
9. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
   `SSL_CERT_FILE` (open-webui example).
10. **Stage B** (oidc present): env-based rebuild or UI-based configuration,
    then browser login via kanidm + email-matching account linking
    (`references/browser-e2e.md` §2).
11. S3 round-trip when the `s3-storage` extension is present.
