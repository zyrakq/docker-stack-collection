# Stack Conventions — Pattern Library

Verbatim snippets, embedded in full — this library is self-contained
(stacks move and change; skills never point into them by path).
`Source:` lines are attribution by stack name only.

## 1. Config-into-image (zot)

Source: zot stack (embedded verbatim)

```yaml
services:
  zot:
    image: zot
    container_name: zot
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE}
        COPY *.json /etc/zot/
```

## 2. cert-wait + gosu (coturn)

Source: coturn stack (embedded verbatim)

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

## 3. delayed-start sleep entrypoint (kanidm)

Source: kanidm stack (embedded verbatim)

```yaml
services:
  kanidmd:
    container_name: kanidmd
    image: kanidmd
    build:
      context: .
      dockerfile_inline: |
        FROM alpine:latest AS sleep-stage
        RUN apk add --no-cache git build-base musl-dev bison
        RUN git clone https://anongit.hacktivis.me/git/utils-std.git /src
        WORKDIR /src
        RUN ./configure && make LDSTATIC=-static cmd/sleep

        FROM alpine:latest AS override-stage
        RUN --mount=type=bind,source=.,target=/context,ro \
            mkdir -p /out && \
            if [ -f /context/override.css ]; then \
                cp /context/override.css /out/override.css; \
            fi

        FROM ${IMAGE}
        COPY --from=sleep-stage /src/cmd/sleep /bin/sleep
        COPY --from=override-stage /out/ /hpkg/

        ENTRYPOINT ["/bin/sleep", "${START_DELAY}"]
        CMD [ "/sbin/kanidmd", "server"]
```

## 4. vhost.d tuning via configs.content (zot)

Source: zot stack (embedded verbatim)

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

## 5. Multi-port vhosts — VIRTUAL_HOST_MULTIPORTS (rustfs)

Source: rustfs stack (embedded verbatim)

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

## 6. oidc extension fragment (vaultwarden)

Source: vaultwarden stack (embedded verbatim)

```yaml
services:
  vaultwarden:
    environment:
      SSO_ENABLED: ${SSO_ENABLED}
      SSO_ONLY: ${SSO_ONLY}
      SSO_SIGNUPS_MATCH_EMAIL: ${SSO_SIGNUPS_MATCH_EMAIL}
      SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION: ${SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION}
      SSO_AUTH_ONLY_NOT_SESSION: ${SSO_AUTH_ONLY_NOT_SESSION}
      SSO_SCOPES: ${SSO_SCOPES}
      SSO_PKCE: ${SSO_PKCE}
      SSO_AUTHORITY: ${SSO_AUTHORITY}
      SSO_CLIENT_ID: ${SSO_CLIENT_ID}
      SSO_CLIENT_SECRET: ${SSO_CLIENT_SECRET}
      SSO_CLIENT_CACHE_EXPIRATION: ${SSO_CLIENT_CACHE_EXPIRATION}
      SSO_DEBUG_TOKENS: ${SSO_DEBUG_TOKENS}
      LOG_LEVEL: ${LOG_LEVEL}
```

Source: vaultwarden stack (embedded verbatim)

```env
SSO_ENABLED=true
SSO_ONLY=true
SSO_SIGNUPS_MATCH_EMAIL=true
SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION=false
SSO_AUTH_ONLY_NOT_SESSION=false

SSO_SCOPES="openid profile email"
SSO_PKCE=true
SSO_CLIENT_ID=vaultwarden
# openssl rand -base64 24
SSO_CLIENT_SECRET=6ul1oomy2jiFFSroWanEJYbVxuP3jGz8
SSO_AUTHORITY=https://idm.example.com/oauth2/openid/vaultwarden

SSO_CLIENT_CACHE_EXPIRATION=0

SSO_DEBUG_TOKENS=false
LOG_LEVEL=info
```

## 7. step-ca-trust extension fragment (vaultwarden)

Source: vaultwarden stack (embedded verbatim)

```yaml
services:
  vaultwarden:
    environment:
      STEP_CA_TRUST: ${STEP_CA_TRUST}
      STEP_CA_TRUST_RESTART: ${STEP_CA_TRUST_RESTART}
```

Source: vaultwarden stack (embedded verbatim)

```env
STEP_CA_TRUST=true
STEP_CA_TRUST_RESTART=true
```

## 8. s3-storage extension fragment (`<app>`)

```yaml
services:
  <app>:
    environment:
      <APP>__storage__STORAGE_TYPE: ${<APP>__storage__STORAGE_TYPE}
      <APP>__storage__MINIO_ENDPOINT: ${<APP>__storage__MINIO_ENDPOINT}
      <APP>__storage__MINIO_ACCESS_KEY_ID: ${<APP>__storage__MINIO_ACCESS_KEY_ID}
      <APP>__storage__MINIO_SECRET_ACCESS_KEY: ${<APP>__storage__MINIO_SECRET_ACCESS_KEY}
      <APP>__storage__MINIO_IAM_ENDPOINT: ${<APP>__storage__MINIO_IAM_ENDPOINT}
      <APP>__storage__MINIO_BUCKET: ${<APP>__storage__MINIO_BUCKET}
      <APP>__storage__MINIO_BASE_PATH: ${<APP>__storage__MINIO_BASE_PATH}
      <APP>__storage__MINIO_LOCATION: ${<APP>__storage__MINIO_LOCATION}
      <APP>__storage__MINIO_USE_SSL: ${<APP>__storage__MINIO_USE_SSL}
      <APP>__storage__MINIO_INSECURE_SKIP_VERIFY: ${<APP>__storage__MINIO_INSECURE_SKIP_VERIFY}
      <APP>__storage__SERVE_DIRECT: ${<APP>__storage__SERVE_DIRECT}
      <APP>__storage__MINIO_BUCKET_LOOKUP_TYPE: ${<APP>__storage__MINIO_BUCKET_LOOKUP_TYPE}
```

```env
<APP>__storage__STORAGE_TYPE=minio
<APP>__storage__MINIO_ENDPOINT=minio:9000
<APP>__storage__MINIO_ACCESS_KEY_ID=
<APP>__storage__MINIO_SECRET_ACCESS_KEY=
<APP>__storage__MINIO_IAM_ENDPOINT=
<APP>__storage__MINIO_BUCKET=<app>
<APP>__storage__MINIO_BASE_PATH=
<APP>__storage__MINIO_LOCATION=us-east-1
<APP>__storage__MINIO_USE_SSL=false
<APP>__storage__MINIO_INSECURE_SKIP_VERIFY=false
<APP>__storage__SERVE_DIRECT=true
<APP>__storage__MINIO_BUCKET_LOOKUP_TYPE=auto
```

Second exemplar (SPACES_* vars):

```yaml
services:
  <app>:
    environment:
      SPACES_ENDPOINT: ${SPACES_ENDPOINT}
      SPACES_KEY: ${SPACES_KEY}
      SPACES_SECRET: ${SPACES_SECRET}
      SPACES_BUCKET_NAME: ${SPACES_BUCKET_NAME}
      SPACES_REGION: ${SPACES_REGION}
      SPACES_FORCE_PATH_STYLE: ${SPACES_FORCE_PATH_STYLE}
```

```env
SPACES_ENDPOINT=http://minio:9000
SPACES_KEY=
SPACES_SECRET=
SPACES_BUCKET_NAME=<app>
SPACES_REGION=us-east-1
SPACES_FORCE_PATH_STYLE=true
```

## 9. env_file_patterns + new environments API (numa)

Source: numa stack (embedded verbatim)

```toml
[paths]
environments_path = "./environments"
extensions_dirs = ["extensions"]

[build]
skip_base_generation = true
copy_additional_files = true
env_file_patterns = [".env", "numa.toml"]
extensions = ["direct-client", "dot-client", "network-mode"]

[build.combos]
"network-client" = ["direct-client", "network-mode"]

[build.environments]
available = ["forwarding", "letsencrypt", "step-ca"]

[build.environments.forwarding]
extensions = ["direct-client", "dot-client"]
combos = ["network-client"]

[build.environments.letsencrypt]
extensions = ["direct-client", "dot-client"]
combos = []

[build.environments.step-ca]
extensions = ["direct-client", "dot-client"]
combos = []
```

## 10. Named volumes + logging anchors (rustfs base)

Source: rustfs stack (embedded verbatim)

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE}
    max-file: ${LOG_MAX_FILE}
    compress: ${LOG_COMPRESS}

x-healthcheck: &default-healthcheck
  test:
    [
      "CMD",
      "sh", "-c",
      "curl -f http://127.0.0.1:9000/health && curl -f http://127.0.0.1:9001/rustfs/console/health"
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

services:
  rustfs:
    container_name: rustfs
    image: ${IMAGE}
    restart: unless-stopped
    logging: *default-logging
    healthcheck: *default-healthcheck
    security_opt:
      - "no-new-privileges:true"
    environment:
      RUSTFS_ADDRESS: ${RUSTFS_ADDRESS}
      RUSTFS_CONSOLE_ADDRESS: ${RUSTFS_CONSOLE_ADDRESS}
      RUSTFS_CONSOLE_ENABLE: ${RUSTFS_CONSOLE_ENABLE}
      RUSTFS_VOLUMES: ${RUSTFS_VOLUMES}}
      RUSTFS_RPC_SECRET: ${RUSTFS_RPC_SECRET}
      RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY}
      RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY}
    volumes:
      - rustfs-data:/data
      - rustfs-logs:/logs

volumes:
  rustfs-data:
    name: rustfs-data
  rustfs-logs:
    name: rustfs-logs
```

## 11. Database extension pair (postgresql + pgrust)

Source: convention canon (§8); genericized — no stack path

`components/extensions/database/postgresql/` — three files. The `pgrust/`
sibling directory is identical except the image default.

`docker-compose.yml` (patches the app service only):

```yaml
services:
  <stack>:
    environment:
      DATABASE_URL: ${DATABASE_URL}:${POSTGRES_PASSWORD}@<stack>-db:5432/${POSTGRES_DB}}
    depends_on:
      <stack>-db:
        condition: service_healthy
```

`docker-compose.db.yml` (the DB service):

```yaml
services:
  <stack>-db:
    image: ${DB_IMAGE}
    container_name: <stack>-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?}
      POSTGRES_INITDB_ARGS: --encoding=UTF8 --lc-ctype=C --lc-collate=C
      TZ: ${TZ}
    volumes:
      - <stack>-db:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "/bin/sh", "-c", "exec pg_isready -h 127.0.0.1"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  <stack>-db:
    name: <stack>-db
```

`.env.example`:

```env
COMPOSE_EXTENDS=:docker-compose.db.yml
COMPOSE_FILE=docker-compose.yml${COMPOSE_EXTENDS}
POSTGRES_DB=<stack>
POSTGRES_USER=<stack>
POSTGRES_PASSWORD=
```

Notes:

- pgrust variant: identical service/env/mounts/healthcheck; only `image:`
  differs — `${DB_IMAGE}`.
- Mount the named volume at `/var/lib/postgresql` (NOT the legacy narrow
  `/var/lib/postgresql/data`).
- The leading colon in `COMPOSE_EXTENDS=:docker-compose.db.yml` lets
  multiple extensions chain correctly.
- DB choice: the `entire` combo lists `database/postgresql` or
  `database/pgrust`; pgrust replaces postgresql there when it passes the
  Stage A2 gate (§9).

## 12. Env wiring — before/after

Source: convention canon (§5); vibe-kanban violations as the "before"

BEFORE (defect — hardcoded literals, not overridable):

```yaml
services:
  <stack>:
    environment:
      RUST_LOG: info
      SERVER_LISTEN_ADDR: 0.0.0.0:8080
```

AFTER (every value overridable from `.env`):

```yaml
services:
  <stack>:
    environment:
      RUST_LOG: ${RUST_LOG}
      SERVER_LISTEN_ADDR: ${SERVER_LISTEN_ADDR}
```

plus the matching entries in the owning component's `.env.example`:

```env
RUST_LOG=info
SERVER_LISTEN_ADDR=0.0.0.0:8080
```

Required values use `${VAR:?}` instead of a default. A var that
appears in `.env.example` but is referenced by no compose file is a dead
var — remove it (§6).

## 13. Environment layering — public base URL

Source: convention canon (§7); SERVER_PUBLIC_BASE_URL violation as the
"before"

BEFORE (defect — env-dependent var declared in base AND re-declared with
different defaults in overlays):

```yaml
# components/base/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
# components/environments/{letsencrypt,step-ca}/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
```

AFTER (base declares nothing; each overlay owns its default):

```yaml
# components/base/docker-compose.yml — NOTHING (base is environment-agnostic)
# components/environments/forwarding/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
# components/environments/letsencrypt/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
# components/environments/step-ca/docker-compose.yml
environment:
  <APP>_PUBLIC_BASE_URL: ${<APP>_PUBLIC_BASE_URL}
```

The var never appears in base `.env.example`; each overlay documents its
default in the component README env table (sb merges no env files for
environments today).
