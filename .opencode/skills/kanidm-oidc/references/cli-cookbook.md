# Kanidm OIDC — CLI Cookbook

The `kanidmd` container has NO shell and NO kanidm CLI (`docker exec kanidmd
kanidm ...` fails). Run the CLI from the `kanidm/tools` sidecar image; the
token cache lives in the gitignored scratch dir. Define once per shell:

```bash
S=/home/archuser/projects/docker-stack-collection/.opencode/scratch/kanidm
# root_ca.crt = step-ca root (server TLS); -H is mandatory
kc() { docker run --rm --network host --user 0:0 -e HOME=/tmp/kanidmcfg \
  -v $S:/tmp/kanidmcfg -v $S/root_ca.crt:/etc/ssl/certs/ca-certificates.crt:ro \
  kanidm/tools:1.11.2 kanidm "$@" -H https://<kanidm-host> --name idm_admin; }
```

Subcommand names can differ per version: check `kc system oauth2 --help`.

## Authentication

```bash
# Non-interactive login (no TTY needed); password from recovery or the user
docker run ... -e KANIDM_PASSWORD=<pw> ... kanidm login -H https://<kanidm-host> --name idm_admin
# (same flags as kc, plus the env var) — session is cached in $S/.cache
kc whoami
```

## OAuth2 clients (per project)

```bash
# Create a client: <client-name> <display-name> <origin-url>
kc system oauth2 create <client-name> "<Display Name>" https://<app-domain>
# Add the app's callback/redirect URL
kc system oauth2 add-redirect-urls <client-name> https://<app-domain>/<callback-path>
# List / inspect
kc system oauth2 list
kc system oauth2 get <client-name>
# Fetch the client secret (needed for the app's .env)
kc system oauth2 get-basic-secret <client-name>
# Scope map: grant scopes to a group
kc system oauth2 add-scope-map <client-name> <group-name> openid profile email
# Claim map (optional): map group claims into the token
kc system oauth2 add-claim-map <client-name> <group-name> <claim-name> <group-name>
# PKCE is on by default; only disable for clients that cannot do PKCE (guarded)
kc system oauth2 warning-insecure-client-disable-pkce <client-name>
```

## Client quirks — fix in Kanidm, NEVER in app code or images

Per-client incompatibilities are solved only with per-client Kanidm settings.
Never patch the app, never build a custom image for this.

```bash
# App wants short username (no @domain): 
kc system oauth2 prefer-short-username <client-name>
#   revert: prefer-spn-username
# App has no PKCE support (e.g. gitea):
kc system oauth2 warning-insecure-client-disable-pkce <client-name>
#   revert: enable-pkce
# App only supports RS256 / legacy signing (e.g. conduit, vaultisse):
kc system oauth2 warning-enable-legacy-crypto <client-name>
#   revert: disable-legacy-crypto
```

Symptom → fix: wrong/`user@domain` username → `prefer-short-username`;
login fails on missing/invalid `code_challenge` → disable PKCE; token
signature/algorithm (ES256) rejected → legacy crypto (RS256).

Issuer URL to put in the app's env (`SSO_AUTHORITY` or app-specific):
`https://<kanidm-domain>/oauth2/openid/<client-name>`

## Groups & users

```bash
# Create a group (one per app role, e.g. <app>-users)
kc group create <group-name>
# Create a test person
kc person create <user-name> "<Display Name>"
# Set mail (often matched by SSO_SIGNUPS_MATCH_EMAIL)
kc person update <user-name> --mail <user@example.com>
# Add user(s) to group
kc group add-members <group-name> <user-name>
# Inspect
kc group get <group-name>
```

## Password recovery (GUARDED — explicit user confirmation required)

```bash
# Recovers and prints a new password for the built-in admins
docker exec -it kanidmd kanidmd recover-account admin
docker exec -it kanidmd kanidmd recover-account idm_admin
```

Never run recovery without the user asking for it. After recovery, tell the
user to log in and change the password immediately.

## Wiring an app (checklist)

1. Create the OAuth2 client named after the project.
2. Add the redirect URL from the app's OIDC docs.
3. Add a scope map for the app's group with `openid profile email`.
4. Fetch the basic secret.
5. Fill the app's oidc extension `.env`:
   `SSO_CLIENT_ID=<client-name>`, `SSO_CLIENT_SECRET=<secret>`,
   `SSO_AUTHORITY=https://<kanidm-domain>/oauth2/openid/<client-name>`.
6. Test login per the `stack-test` skill.
