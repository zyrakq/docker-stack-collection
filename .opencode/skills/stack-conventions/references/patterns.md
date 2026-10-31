# Stack Conventions — Pattern Library

Verbatim snippets. Source paths are exact — re-read them when in doubt
(`stacks/` is gitignored; target the specific path).

## 1. Config-into-image (zot)

Source: `stacks/development-tools/registries/container-registries/zot/app/components/base/docker-compose.yml`

```yaml
services:
  zot:
    image: zot
    container_name: zot
    build:
      context: .
      dockerfile_inline: |
        FROM ${IMAGE:-ghcr.io/project-zot/zot:latest}
        COPY *.json /etc/zot/
```

## 2. cert-wait + gosu (coturn)

Source: `stacks/network-privacy/turn/coturn/app/components/environments/step-ca/docker-compose.yml`

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

Source: `stacks/devops/identity-management/kanidm/app/components/base/docker-compose.yml`

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

        FROM ${IMAGE:-kanidm/server:latest}
        COPY --from=sleep-stage /src/cmd/sleep /bin/sleep
        COPY --from=override-stage /out/ /hpkg/

        ENTRYPOINT ["/bin/sleep", "${START_DELAY}"]
        CMD [ "/sbin/kanidmd", "server"]
```

## 4. vhost.d tuning via configs.content (zot)

Source: `stacks/development-tools/registries/container-registries/zot/app/components/environments/step-ca/docker-compose.yml`

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
        target: ${VHOST_PATH:-/vhost.d/${VIRTUAL_HOST}}
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

Source: `stacks/devops/s3/storage/rustfs/app/components/environments/step-ca/docker-compose.yml`

```yaml
services:
  rustfs:
    environment:
      RUSTFS_CORS_ALLOWED_ORIGINS: ${RUSTFS_CORS_ALLOWED_ORIGINS:-*}
      RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS: ${RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS:-*}
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
        target: ${VHOST_PATH:-/vhost.d/${S3_VIRTUAL_HOST}}
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

Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/docker-compose.yml`

```yaml
services:
  vaultwarden:
    environment:
      SSO_ENABLED: ${SSO_ENABLED:-true}
      SSO_ONLY: ${SSO_ONLY:-true}
      SSO_SIGNUPS_MATCH_EMAIL: ${SSO_SIGNUPS_MATCH_EMAIL:-true}
      SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION: ${SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION:-false}
      SSO_AUTH_ONLY_NOT_SESSION: ${SSO_AUTH_ONLY_NOT_SESSION:-false}
      SSO_SCOPES": ${SSO_SCOPES:-"openid profile email"}
      SSO_PKCE: ${SSO_PKCE:-true}
      SSO_AUTHORITY: ${SSO_AUTHORITY}
      SSO_CLIENT_ID: ${SSO_CLIENT_ID}
      SSO_CLIENT_SECRET: ${SSO_CLIENT_SECRET}
      SSO_CLIENT_CACHE_EXPIRATION: ${SSO_CLIENT_CACHE_EXPIRATION:-0}
      SSO_DEBUG_TOKENS: ${SSO_DEBUG_TOKENS:-false}
      LOG_LEVEL: ${LOG_LEVEL:-info}
      # SSO_AUTHORIZE_EXTRA_PARAMS: ${SSO_AUTHORIZE_EXTRA_PARAMS}
      # SSO_AUDIENCE_TRUSTED: ${SSO_AUDIENCE_TRUSTED}
      # SSO_MASTER_PASSWORD_POLICY: ${SSO_MASTER_PASSWORD_POLICY}
```

Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/.env.example`

```env
# OIDC
## https://github.com/dani-garcia/vaultwarden/wiki/Enabling-SSO-support-using-OpenId-Connect
## Redirect URL: https://idm.example.com/identity/connect/oidc-signin

SSO_ENABLED=true
SSO_ONLY=true
SSO_SIGNUPS_MATCH_EMAIL=true
SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION=false
SSO_AUTH_ONLY_NOT_SESSION=false

# Kanidm
SSO_SCOPES="openid profile email"
SSO_PKCE=true
SSO_CLIENT_ID=vaultwarden
SSO_CLIENT_SECRET=6ul1oomy2jiFFSroWanEJYbVxuP3jGz8
SSO_AUTHORITY=https://idm.example.com/oauth2/openid/vaultwarden

SSO_CLIENT_CACHE_EXPIRATION=0

SSO_DEBUG_TOKENS=false
LOG_LEVEL=info
# SSO_DEBUG_TOKENS=true
# LOG_LEVEL=info,vaultwarden::sso=debug

# SSO_AUTHORIZE_EXTRA_PARAMS=
# SSO_AUDIENCE_TRUSTED=
# SSO_MASTER_PASSWORD_POLICY=
```

## 7. step-ca-trust extension fragment (vaultwarden)

Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/step-ca-trust/docker-compose.yml`

```yaml
services:
  vaultwarden:
    environment:
      STEP_CA_TRUST: ${STEP_CA_TRUST:-true}
      STEP_CA_TRUST_RESTART: ${STEP_CA_TRUST_RESTART:-true}
```

Source: `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/step-ca-trust/.env.example`

```env
#Step CA Trust
STEP_CA_TRUST=true
STEP_CA_TRUST_RESTART=true
```

## 8. s3-storage extension fragment (gitea)

Source: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/docker-compose.yml`

```yaml
services:
  gitea:
    environment:
      GITEA__storage__STORAGE_TYPE: ${GITEA__storage__STORAGE_TYPE:-minio}
      GITEA__storage__MINIO_ENDPOINT: ${GITEA__storage__MINIO_ENDPOINT:-minio:9000}
      GITEA__storage__MINIO_ACCESS_KEY_ID: ${GITEA__storage__MINIO_ACCESS_KEY_ID}
      GITEA__storage__MINIO_SECRET_ACCESS_KEY: ${GITEA__storage__MINIO_SECRET_ACCESS_KEY}
      GITEA__storage__MINIO_IAM_ENDPOINT: ${GITEA__storage__MINIO_IAM_ENDPOINT:-}
      GITEA__storage__MINIO_BUCKET: ${GITEA__storage__MINIO_BUCKET:-gitea}
      GITEA__storage__MINIO_BASE_PATH: ${GITEA__storage__MINIO_BASE_PATH:-}
      GITEA__storage__MINIO_LOCATION: ${GITEA__storage__MINIO_LOCATION:-us-east-1}
      GITEA__storage__MINIO_USE_SSL: ${GITEA__storage__MINIO_USE_SSL:-false}
      GITEA__storage__MINIO_INSECURE_SKIP_VERIFY: ${GITEA__storage__MINIO_INSECURE_SKIP_VERIFY:-false}
      GITEA__storage__SERVE_DIRECT: ${GITEA__storage__SERVE_DIRECT:-true}
      GITEA__storage__MINIO_BUCKET_LOOKUP_TYPE: ${GITEA__storage__MINIO_BUCKET_LOOKUP_TYPE:-auto}
```

Source: `stacks/devops/version-control/gitea/app/components/extensions/s3-storage/.env.example`

```env
# S3 Storage
GITEA__storage__STORAGE_TYPE=minio
GITEA__storage__MINIO_ENDPOINT=minio:9000
GITEA__storage__MINIO_ACCESS_KEY_ID=
GITEA__storage__MINIO_SECRET_ACCESS_KEY=
GITEA__storage__MINIO_IAM_ENDPOINT=
GITEA__storage__MINIO_BUCKET=gitea
GITEA__storage__MINIO_BASE_PATH=
GITEA__storage__MINIO_LOCATION=us-east-1
GITEA__storage__MINIO_USE_SSL=false
GITEA__storage__MINIO_INSECURE_SKIP_VERIFY=false
GITEA__storage__SERVE_DIRECT=true
GITEA__storage__MINIO_BUCKET_LOOKUP_TYPE=auto
```

Second exemplar (SPACES_* vars) — Source: `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/docker-compose.yml`

```yaml
services:
  linkwarden:
    environment:
      SPACES_ENDPOINT: ${SPACES_ENDPOINT}
      SPACES_KEY: ${SPACES_KEY}
      SPACES_SECRET: ${SPACES_SECRET}
      SPACES_BUCKET_NAME: ${SPACES_BUCKET_NAME}
      SPACES_REGION: ${SPACES_REGION:-us-east-1}
      SPACES_FORCE_PATH_STYLE: ${SPACES_FORCE_PATH_STYLE:-true}
```

Source: `stacks/self-hosting/media-streaming/bookmarks/linkwarden/src/linkwarden/components/extensions/s3-storage/.env.example`

```env
# S3 Storage
SPACES_ENDPOINT=http://minio:9000
SPACES_KEY=
SPACES_SECRET=
SPACES_BUCKET_NAME=linkwarden
SPACES_REGION=us-east-1
SPACES_FORCE_PATH_STYLE=true
```

## 9. env_file_patterns + new environments API (numa)

Source: `stacks/network-privacy/dns/numa/app/client/stackbuilder.toml`

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

Source: `stacks/devops/s3/storage/rustfs/app/components/base/docker-compose.yml`

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: ${LOG_MAX_SIZE:-10m}
    max-file: ${LOG_MAX_FILE:-3}
    compress: ${LOG_COMPRESS:-true}

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
    image: ${IMAGE:-rustfs/rustfs:latest}
    restart: unless-stopped
    logging: *default-logging
    healthcheck: *default-healthcheck
    security_opt:
      - "no-new-privileges:true"
    environment:
      RUSTFS_ADDRESS: ${RUSTFS_ADDRESS}
      RUSTFS_CONSOLE_ADDRESS: ${RUSTFS_CONSOLE_ADDRESS}
      RUSTFS_CONSOLE_ENABLE: ${RUSTFS_CONSOLE_ENABLE:-true}
      RUSTFS_VOLUMES: ${RUSTFS_VOLUMES:-/data/rustfs{0..3}}
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
