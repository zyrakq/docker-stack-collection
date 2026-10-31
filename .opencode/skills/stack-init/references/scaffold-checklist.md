# Stack Init — Scaffold Checklist

Checklist for step 3 of the `stack-init` workflow. Copy boilerplate from an
existing stack (e.g. `stacks/devops/identity-management/kanidm/`) — do not
invent license/gitignore text.

## Stack root

- [ ] `README.md` — hub style (see `readme-gen` skill templates).
- [ ] `.gitignore` — copy from an existing stack; must ignore `build/`.
- [ ] `.gitmessage` — copy verbatim from an existing stack.
- [ ] `LICENSE-APACHE`, `LICENSE-MIT` — copy verbatim from an existing stack.
- [ ] `.gitmodules` + `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`
      submodules — ONLY if the stack joins an SSL stack. URLs:
      `https://github.com/zyrakq/step-ca-manager-stack.git`,
      `https://github.com/zyrakq/letsencrypt-manager-stack.git`.
- [ ] No `.kilocode/`, no `.clinerules/` — delete if scaffolding tools created them.

## app/ project dir

- [ ] `components/base/docker-compose.yml` — core service; logging anchor
      (`x-logging` with LOG_MAX_SIZE/LOG_MAX_FILE/LOG_COMPRESS), named volumes
      with explicit `name:`, no bind mounts, healthcheck where applicable.
- [ ] `components/base/.env.example` — per stack-conventions §9 key order.
- [ ] `components/base/` config examples (`*.example` files; delivered via
      `dockerfile_inline` COPY or `configs.content`).
- [ ] `components/environments/forwarding/` — plain ports publish.
- [ ] `components/environments/letsencrypt/` — external `letsencrypt-network`
      + `letsencrypt-vhost` volume + VIRTUAL_HOST/LETSENCRYPT_* env.
- [ ] `components/environments/step-ca/` — external `step-ca-network` +
      `step-ca-certs` + `step-ca-vhost` volumes + VIRTUAL_HOST/
      LETSENCRYPT_* env + app TLS env (cert paths `/certs/<VIRTUAL_HOST>/...`).
- [ ] `components/extensions/<ext>/` as applicable — `oidc`, `s3-storage`,
      `step-ca-trust` (env-only fragments; copy shape from vaultwarden/gitea).
- [ ] `stackbuilder.toml` — `[paths]` + `[build]` with the new
      `[build.environments]` API; `env_file_patterns` for app-native config
      files; per-env `extensions`/`combos` (numa exemplar).
- [ ] `README.md` — component style (see `readme-gen` skill templates).

## Collection root

- [ ] Append to `stacks.csv`: `stacks/<path>;-;unverified` (semicolon-separated;
      `-` url when no remote; do not touch other rows).

## First build

- [ ] `cd app/ && sb build` succeeds; `build/<env>/<combo>/` structure correct.
- [ ] `docker compose config` validates in each generated variant.
