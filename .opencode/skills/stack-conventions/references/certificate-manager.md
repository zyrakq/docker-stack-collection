# Certificate manager convention — step-ca-manager family

**Pluggable part of stack-conventions.** The certificate manager is an infra
role; the concrete project for the role is named in the repo `AGENTS.md`
role table.

- Load this file ONLY when the role table names `step-ca-manager` (this
  convention covers both `step-ca-manager` and `letsencrypt-manager` — they
  are one family and one convention).
- For any other certificate-manager project: do NOT load or apply this
  file. Ask the project owner to supply their own convention file (same
  scope: submodules, environments, external volumes/networks, env wiring,
  trust extension, vhost tuning) and put it next to this one.
- Everything in `SKILL.md` that mentions "SSL environments" or the
  "certificate-manager convention" is defined here.
- `scripts/check-layout.sh` (SSL-submodule check) and the `letsencrypt` /
  `step-ca` environment names in `scripts/check-stack.sh` belong to this
  convention and are replaced together with it.

## 1. `modules/` submodules (SKILL.md §1)

- `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}`, declared in
  the stack-root `.gitmodules`. MANDATORY whenever the stack has a
  `letsencrypt` or `step-ca` environment under `app/components/environments/`
  (any project dir): BOTH submodules must be declared in `.gitmodules`
  (URLs `https://github.com/zyrakq/step-ca-manager-stack.git`,
  `https://github.com/zyrakq/letsencrypt-manager-stack.git`) and present
  under `modules/ssl-automation/` (`git submodule add`, then
  `git submodule update --init`). An SSL environment without the submodules
  is a violation (`check-layout.sh` flags it).
- Never create, edit or delete files inside these submodules (SKILL.md
  hard rules, `.gitkeep` entry).

## 2. `stackbuilder.toml` combos

- Besides the base combo `entire`, add `entire-trust` (= `entire` +
  `"step-ca-trust"`) only when `step-ca` environments need it.
- Environments `forwarding`/`letsencrypt` use `entire`; `step-ca` uses
  `entire-trust`. No other combo names.

## 3. Extension name exception

`step-ca-trust` is the one fixed extension name longer than two words.

## 4. External volumes/networks (SKILL.md §4)

To join the SSL stack, a stack declares as external: `step-ca-certs`,
`step-ca-vhost`, `step-ca-network` (or the `letsencrypt-*` equivalents).

## 5. Environments & layering (SKILL.md §7)

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

## 6. `.env.example` key order (SKILL.md §6)

Standard order includes `VIRTUAL_*`/`LETSENCRYPT_*` after `LOG_*`, and
`STEP_CA_*` after the OIDC block (before CA-path vars).

## 7. step-ca integration (SKILL.md §14, two pieces)

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

## 8. nginx-proxy vhost.d tuning (SKILL.md §15)

- Per-host nginx tweaks via compose `configs.content` written to the shared
  `step-ca-vhost` / `letsencrypt-vhost` volume at `/vhost.d/${VIRTUAL_HOST}`
  (e.g. `client_max_body_size 0;` for a registry).
- Multi-port vhosts use the `VIRTUAL_HOST_MULTIPORTS` trick.
- Verbatim snippets: `references/patterns.md` §4–§5 (they use the
  `step-ca-*` volume/network names of this convention).
