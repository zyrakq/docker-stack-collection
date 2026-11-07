---
name: Kanidm OIDC
description: >-
  Cookbook for administering Kanidm (the collection's OIDC provider):
  create/modify OAuth2 clients per project, fetch client secrets, manage
  groups and test users, adjust redirect URLs/scopes/claim maps, and guarded
  admin password recovery. Use for any Kanidm or OIDC client wiring task.
---

# Kanidm OIDC

Load the `stack-conventions` skill first.

Full command cookbook: read `references/cli-cookbook.md`.

## What this covers

- Create/modify OAuth2 clients per project; fetch the client secret.
- Create groups; create test users; add users to groups.
- Adjust client settings per project: redirect URLs, scopes, claim mapping.
- Reset idm_admin/admin passwords — GUARDED procedure (see Guardrails).

## Conventions

- Issuer: `https://<kanidm-domain>/oauth2/openid/<client-name>`.
- One OAuth2 client per project, named after the project.
- Redirect URL: the app's OIDC callback on its own domain
  (e.g. vaultwarden: `https://<app-domain>/identity/connect/oidc-signin`).
- The kanidm container is `kanidmd`; admin password recovery uses
  `docker exec -it kanidmd kanidmd recover-account <admin|idm_admin>`
  (procedure in `references/cli-cookbook.md`).

- Client quirks (username format, no PKCE, RS256/legacy signing) are fixed
  ONLY via per-client Kanidm settings: `prefer-short-username`,
  `warning-insecure-client-disable-pkce`, `warning-enable-legacy-crypto`
  (see `references/cli-cookbook.md`). NEVER patch app code or build a
  custom image to work around them.

## Guardrails

- Destructive operations (password resets, client/group deletion, schema
  changes) ALWAYS require explicit user confirmation before running.
- The live kanidm instance is part of the running step-ca-manager setup —
  never modify the manager stack itself.
- For hands-off delegation use the `kanidm-admin` subagent.
