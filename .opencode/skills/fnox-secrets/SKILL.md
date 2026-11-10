---
name: Fnox Secrets
description: >-
  Where this collection keeps secrets and per-project .env files (fnox +
  age, secrets/fnox.toml) and when to read or write them. Use BEFORE asking
  the user for, or digging through a stack's .env for, any credential or
  infra value (domains, admin passwords, access keys), after generating or
  resetting any secret, and when deploying or tearing down a stack.
---

# Fnox Secrets

Single source of truth for secrets: encrypted `secrets/fnox.toml`
(committed, age-encrypted; private key lives outside the repo). One fnox
**profile per stack**. Plaintext `.env` files are git-ignored.

Which stack/profile and which keys serve each infra role (certificate
manager, SSO, S3, ...): see the root `AGENTS.md`.

## Rules

- NEVER ask the user for a value and NEVER open a stack's `.env` to find it
  before trying `scripts/secret-get.sh <profile> <KEY>`. Ask only if the
  lookup fails.
- NEVER print secrets into the final report in full; pass them to the next
  step via the tool, not via chat, unless the caller needs them to wire an app.
- Any secret you create, rotate, or recover (admin password reset, new
  access key, client secret) MUST be saved immediately with
  `scripts/secret-set.sh` — otherwise it is lost and the next agent resets it again.
- Never commit plaintext `.env`. Commit `secrets/fnox.toml` after any write.
- Do not install fnox/age on the host; if missing, report and stop.

## Commands (run from the repo root)

- Read one value: `scripts/secret-get.sh <profile> <KEY>`
- Write one value (stdin, not argv): `printf %s "$value" | scripts/secret-set.sh <profile> <KEY>`
- Save a stack's whole `.env`: `scripts/env-push.sh <stack>`
- Restore a stack's `.env`: `scripts/env-pull.sh <stack>` (`FORCE=1` to overwrite)
- First-time setup (user only): `scripts/fnox-setup.sh`

## When

- **Before work needing infra values** (domain, admin creds, S3 keys): get from the role's profile.
- **After deploying a stack** whose `.env` holds real values: `env-push.sh`.
- **Deploying a stack elsewhere / after wipe**: `env-pull.sh` into its build dir
  instead of retyping values.
- **After rotating/resetting/creating a secret**: `secret-set.sh` right away.
