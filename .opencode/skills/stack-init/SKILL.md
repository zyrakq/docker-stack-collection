---
name: Stack Init
description: >-
  Initialize a new Docker Compose stack repo in docker-stack-collection:
  scaffold app/ components, stackbuilder.toml, READMEs, licenses, and
  register the stack in stacks.csv. Use when the user asks to create or
  start a new stack.
---

# Stack Init

Load the `stack-conventions` skill first — every step below depends on it.

## Workflow

1. **Determine stack type & category.** Ask the user if unclear. Choose the
   category path `stacks/<category>/<subcategory>/<stack-name>/` following
   existing entries in `stacks.csv`.
2. **Create the stack repo.**
   ```bash
   mkdir -p stacks/<category>/<...>/<stack>
   cd stacks/<category>/<...>/<stack>
   git init
   ```
3. **Scaffold** exactly per `references/scaffold-checklist.md`:
   - `app/components/base/` — `docker-compose.yml`, `.env.example`, config
     examples.
   - `app/components/environments/{forwarding,letsencrypt,step-ca}/` as
     applicable (step-ca needs the certs volume + network fragment).
   - `app/components/extensions/{oidc,s3-storage,step-ca-trust}/` as
     applicable.
   - `app/stackbuilder.toml` — new `[build.environments]` API; use
     `env_file_patterns` to preserve app-native config files (numa idiom).
   - `app/README.md` — delegate to the `readme-gen` skill rules.
   - Stack root: hub `README.md`, `.gitignore`, `.gitmessage`,
     `LICENSE-APACHE`, `LICENSE-MIT`; `.gitmodules` + `modules/ssl-automation`
     submodules ONLY if SSL integration is needed.
4. **Register in stacks.csv** (collection root): append the row
   `stacks/<category>/<...>/<stack>;-;unverified` — url is `-` when there is
   no remote yet.
5. **Clean artifacts:** delete `.kilocode/`, `.clinerules/` if present.
6. **Build & verify:** `cd app/ && sb build`, then follow the `stack-test`
   skill.

## Reference exemplars (imitate, do not copy blindly)

- `stacks/devops/identity-management/kanidm/` — multi-project (app/ + ui/ +
  mail-sender/), `env_file_patterns` for `override.css`.
- `stacks/network-privacy/turn/coturn/` — gosu cert-wait pattern.
- `stacks/devops/secret-control/vaultwarden/` — oidc + step-ca-trust
  extensions.
- `stacks/development-tools/registries/container-registries/zot/` —
  config-into-image + vhost.d.
- `stacks/development-tools/registries/container-registries/distribution/` —
  server/ + ui/ multi-project with a real Dockerfile.
