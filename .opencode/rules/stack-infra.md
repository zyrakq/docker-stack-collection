# Stack infrastructure conventions (this project)

Project-specific layout and compose conventions for the stacks in this
repository: certificate-manager submodules, environments, external
volumes/networks, trust extension, and the standard compose fragments that
use them. This is project context. It is not part of any plugin or agent.

- The generic stack workflow (skills of the `graver` plugin) refers to the
  "certificate manager" role. This file defines it for this project; the
  concrete projects per role are in the `AGENTS.md` role table.
- Tool behaviour (how the step-ca env vars work, how certificates are
  issued, manual trust when `STEP_CA_TRUST` fails, why the restart is
  needed): `step-ca-trust` skill of the `step-ca` plugin.
- OIDC client wiring and issuer URLs: `kanidm-oidc` skill of the `kanidm`
  plugin. S3 wiring: `rustfs-s3` skill of the `rustfs` plugin.
- Applies to both `step-ca-manager` and `letsencrypt-manager` (one family).
  If the role is filled by another project, replace this file.

## 1. `modules/` submodules (stack-conventions §1)

- `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`, declared in
  the stack-root `.gitmodules`. MANDATORY whenever the stack has a
  `letsencrypt` or `step-ca` environment under `app/components/environments/`
  (any project dir): BOTH submodules must be declared in `.gitmodules`
  (URLs `https://github.com/zyrakq/step-ca-manager-stack.git`,
  `https://github.com/zyrakq/letsencrypt-manager-stack.git`) and present
  under `modules/ssl-automation/` (`git submodule add`, then
  `git submodule update --init`). An SSL environment without the submodules
  is a violation (`check-layout.sh` flags it; its names come from `.opencode/stack-layout.env`).
- Never create, edit or delete files inside these submodules (stack-conventions
  hard rules, `.gitkeep` entry).

## 2. `stackbuilder.toml` combos

- Besides the base combo `entire`, add `entire-trust` (= `entire` +
  `"step-ca-trust"`) only when `step-ca` environments need it.
- Environments `forwarding`/`letsencrypt` use `entire`; `step-ca` uses
  `entire-trust`. No other combo names.

## 3. Extension name exception

`step-ca-trust` is the one fixed extension name longer than two words.

## 4. External volumes/networks (stack-conventions §4)

To join the SSL stack, a stack declares as external: `step-ca-certs`,
`step-ca-vhost`, `step-ca-network` (or the `letsencrypt-*` equivalents).

## 5. Environments & layering (stack-conventions §7)

- `letsencrypt` — joins the letsencrypt stack (external network/volumes).
- `step-ca` — joins the step-ca stack; structurally identical to
  `letsencrypt`, differs only in volume/network names.
- TLS-dependent values: `forwarding` owns the plain/local value
  (`<APP>_PUBLIC_BASE_URL=http://localhost:<port>`); `letsencrypt`/`step-ca`
  own the TLS one (`https://<host>`). Each overlay re-declares the var in
  its own `.env.example`; compose uses plain `${<APP>_PUBLIC_BASE_URL}`.
  `${VIRTUAL_HOST}` only in environment overlays.
- Testing order: `step-ca` first (the live setup exists); the `letsencrypt`
  variant is assumed analogous minus `STEP_CA_TRUST`.

## 6. `.env.example` key order (stack-conventions §6)

Standard order includes `VIRTUAL_*`/`LETSENCRYPT_*` after `LOG_*`, and
`STEP_CA_*` after the OIDC block (before CA-path vars).

## 7. step-ca integration (stack-conventions §14, two pieces)

1. **Env fragment** (in the step-ca environment): adds
   `step-ca-certs:/certs` external volume + `step-ca-network` external
   network + `VIRTUAL_HOST`/`VIRTUAL_PROTO`/`LETSENCRYPT_HOST`/
   `LETSENCRYPT_EMAIL` + app TLS env, e.g.
   `ROCKET_TLS='{certs="/certs/${VIRTUAL_HOST}/fullchain.pem",key=...}'`.
   Cert path convention: `/certs/<VIRTUAL_HOST>/fullchain.pem` and `key.pem`.
2. **`step-ca-trust` extension**: env patch setting `STEP_CA_TRUST` /
   `STEP_CA_TRUST_RESTART`. MANDATORY (DEPLOYMENT.md model, SKILL.md §20)
   for a group that may run on another host and calls another group by
   public https domain. Fragment:

   ```yaml
   services:
     <service>:
       environment:
         STEP_CA_TRUST: ${STEP_CA_TRUST}
         STEP_CA_TRUST_RESTART: ${STEP_CA_TRUST_RESTART}
   ```

   ```env
   STEP_CA_TRUST=true
   STEP_CA_TRUST_RESTART=true
   ```

   Why `STEP_CA_TRUST_RESTART=true`: trust is often not picked up on first
   boot; the restart after bundle install makes it deterministic.

## 8. nginx-proxy vhost.d tuning (stack-conventions §15)

- Per-host nginx tweaks via compose `configs.content` written to the shared
  `step-ca-vhost` / `letsencrypt-vhost` volume at `/vhost.d/${VIRTUAL_HOST}`
  (e.g. `client_max_body_size 0;` for a registry).
- Multi-port vhosts use the `VIRTUAL_HOST_MULTIPORTS` trick.
- Verbatim snippets: §9 and §10 below.

## 9. Standard fragment: cert-wait + gosu (TLS-terminating service)

```yaml
services:
  coturn:
    user: root
    environment:
      COTURN_DOMAIN: ${COTURN_DOMAIN}
      VIRTUAL_HOST: ${COTURN_DOMAIN}
      VIRTUAL_PORT: 3478
      LETSENCRYPT_HOST: ${COTURN_DOMAIN}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    entrypoint:
      - /bin/sh
      - -c
      - |
        set -x
        echo "==> COTURN_DOMAIN='$$COTURN_DOMAIN'"
        KEY_PATH="/certs/$$COTURN_DOMAIN/key.pem"

        while [ ! -f "$$KEY_PATH" ]; do
          echo "Waiting for $$KEY_PATH..."
          sleep 3
        done

        chmod 644 "$$KEY_PATH" 2>/dev/null || true
        echo "Permissions fixed. Starting as nobody..."

        if [ $# -eq 0 ]; then
          set -- --log-file=stdout --external-ip=$(detect-external-ip)
        fi

        exec gosu nobody /usr/local/bin/docker-entrypoint.sh "$@"
    volumes:
      - step-ca-certs:/certs

configs:
  turnserver:
    content: |
      use-auth-secret
      static-auth-secret=${COTURN_SECRET_KEY}
      realm=${COTURN_DOMAIN}
      cert=/certs/${COTURN_DOMAIN}/fullchain.pem
      pkey=/certs/${COTURN_DOMAIN}/key.pem

volumes:
  step-ca-certs:
    external: true
```

## 10. Standard fragment: vhost.d tuning via configs.content

```yaml
services:
  zot:
    environment:
      VIRTUAL_HOST: ${VIRTUAL_HOST}
      VIRTUAL_PORT: ${VIRTUAL_PORT}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    configs:
      - source: vhost
        target: ${VHOST_PATH}}
    volumes:
      - step-ca-vhost:/vhost.d
    networks:
      - step-ca-network

volumes:
  step-ca-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
      chunked_transfer_encoding on;

networks:
  step-ca-network:
    external: true
```

## 11. Standard fragment: multi-port vhosts

```yaml
services:
  rustfs:
    environment:
      RUSTFS_CORS_ALLOWED_ORIGINS: ${RUSTFS_CORS_ALLOWED_ORIGINS}
      RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS: ${RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS}
      VIRTUAL_HOST_MULTIPORTS: |-
        ${UI_VIRTUAL_HOST}:
          "/":
            port: ${UI_VIRTUAL_PORT}
        ${S3_VIRTUAL_HOST}:
          "/":
            port: ${S3_VIRTUAL_PORT}
      LETSENCRYPT_HOST: ${LETSENCRYPT_HOST}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    configs:
      - source: vhost
        target: ${VHOST_PATH}}
    volumes:
      - step-ca-vhost:/vhost.d
    networks:
      - step-ca-network

volumes:
  step-ca-vhost:
    external: true

configs:
  vhost:
    content: |
      client_max_body_size 0;
      chunked_transfer_encoding on;

networks:
  step-ca-network:
    external: true
```

## 12. Environment names in `stackbuilder.toml`

```toml
[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
extensions = [...]
[build.environments.letsencrypt]
extensions = [...]
[build.environments.step-ca]
extensions = [...]
```

## 13. Environment layering — public base URL

Base declares nothing; each overlay owns its default:

```yaml
# components/base/docker-compose.yml — NOTHING (base is environment-agnostic)
# components/environments/{forwarding,letsencrypt,step-ca}/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
```

The var never appears in base `.env.example`; each overlay documents its
default in the component README env table.
