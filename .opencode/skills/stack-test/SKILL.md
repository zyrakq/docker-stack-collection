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

## Procedure

Follow `references/verification-procedure.md` in order. Summary:

1. `cd app/ && sb build` — check the `build/<env>/<combo>/` output structure.
2. `cd build/<env>/<combo>/ && cp .env.example .env` and edit values.
3. `docker compose config` — must validate.
4. `docker compose up --build -d`.
5. Health checks pass.
6. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
7. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
8. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
   `SSL_CERT_FILE` (open-webui example).
9. OIDC login via kanidm when the `oidc` extension is present.
10. S3 round-trip when the `s3-storage` extension is present.
