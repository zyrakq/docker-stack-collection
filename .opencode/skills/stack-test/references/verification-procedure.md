# Stack Test — Verification Procedure

Ordered checklist. Run from the generated variant dir
(`app/build/<env>/<combo>/`) unless noted. Substitute `<svc>` with the main
service name.

## 0. Preconditions

- [ ] Confirm which variant is under test; step-ca FIRST.
- [ ] Confirm you are NOT operating on the live step-ca-manager stack
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

## 5. Integrations

- [ ] OIDC (when present): login redirect reaches kanidm at
      `https://<kanidm-domain>/oauth2/openid/<client-name>`; callback
      completes; a test user from the right group can sign in.
- [ ] S3 (when present): round-trip — create bucket, put object, get object,
      delete (see `rustfs-s3` skill cookbook).

## 6. Failure handling

- [ ] Any failure caused by the live manager setup → switch to forwarding
      variant; record the finding; NEVER touch the manager stack.
- [ ] Record results in the stack's notes/PR description.
