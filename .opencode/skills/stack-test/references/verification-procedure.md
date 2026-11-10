# Stack Test — Verification Procedure

Ordered checklist. Run from the generated variant dir
(`app/build/<env>/<combo>/`) unless noted. Substitute `<svc>` with the main
service name.

## 0. Preconditions

- [ ] Confirm which variant is under test; step-ca FIRST.
- [ ] Confirm you are NOT operating on the live certificate-manager stack (see AGENTS.md role table)
      (read-only at most). If a failure is caused by the manager setup,
      switch to the forwarding variant and note it — never modify the manager.

## 1. Build

- [ ] `cd app/ && sb build` exits 0.
- [ ] Expected `build/<env>/<combo>/` dirs exist (check `stackbuilder.toml`).
- [ ] Spot-check one generated `docker-compose.yml`: no bind mounts, named
      volumes have explicit `name:`, external networks/volumes correct.

## 2. Configure

- [ ] `cp .env.example .env`; fill required values (domains, secrets).
- [ ] step-ca variant: `STEP_CA_TRUST=true` AND `STEP_CA_TRUST_RESTART=true`.

## 3. Validate & deploy

- [ ] `docker compose config` exits 0.
- [ ] `docker compose up --build -d` exits 0.
- [ ] `docker compose ps` — all services running/healthy.

## 4. Health & TLS

- [ ] Healthcheck passes (`docker inspect --format '{{.State.Health.Status}}' <svc>`).
- [ ] TLS-terminating services: cert files appear at
      `/certs/<VIRTUAL_HOST>/{fullchain.pem,key.pem}`; cert-wait pattern
      observable in logs (`docker logs <svc>`).
- [ ] `STEP_CA_TRUST` bundle installed inside the container; if the app
      still rejects the CA, check app-specific envs (`REQUESTS_CA_BUNDLE`,
      `SSL_CERT_FILE` — open-webui example) and the RESTART flag.

## 5. Integrations (staged — browser E2E)

Staged per `browser-e2e.md`. Stage A MUST pass before any extension work.

- [ ] Stage A (functional base, no oidc): browser smoke test via
      agent-browser — clean TLS, local login, the DEPLOYMENT.md functional
      gate scenario (cross-part E2E, stack-conventions §20), screenshot
      artifact (`browser-e2e.md` §1).
- [ ] OIDC (when present), per its configuration mode (`browser-e2e.md` §2):
  - [ ] Env-based (`oidc` extension): rebuild, redeploy, browser login via
        the SSO button → kanidm → callback → session; email-matching
        assertions.
  - [ ] UI-based: configure the provider in the app's web
        UI first, save, then the same browser login check + email linking.
- [ ] S3 (when present): round-trip — create bucket, put object, get object,
      delete (see `rustfs-s3` skill cookbook).

## 6. Teardown and audit

- [ ] `docker compose down -v --remove-orphans` in each built dir used;
      `.env` only in build dirs; `.stackbuilder/` deleted; `docker ps -a` clean.
- [ ] Conventions audit by `stack-auditor` (cosmetic fixes; no re-test
      unless logic was reworked).

## 7. Failure handling

- [ ] Any failure caused by the live manager setup → switch to forwarding
      variant; record the finding; NEVER touch the manager stack.
- [ ] Record results in the stack's notes/PR description.
