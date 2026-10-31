# Staged Browser E2E Testing for Stacks — Implementation Plan

**Goal:** Turn stack-test verification into a staged pipeline (Stage A base
deploy → browser gate → Stage B oidc) with detailed agent-browser recipes,
and codify the UI-configured OIDC policy in stack-conventions.

**Architecture:** Docs-only change to four files under `.opencode/skills/`.
A new reference (`browser-e2e.md`) owns the detailed staged procedure;
`stack-test/SKILL.md` and `verification-procedure.md` gain staged summaries
with pointers to it; `stack-conventions/SKILL.md` §7 codifies UI-only OIDC
(gitea, zerobyte), email-matching linking, and mandatory staged testing.
agent-browser is consumed, never duplicated: stack-test instructs to load the
skill + `agent-browser skills get core`.

**Design:** thoughts/shared/designs/2026-10-31-browser-e2e-testing-design.md

---

## Research findings (carry into execution)

- **agent-browser stub** (`/home/archuser/.agents/skills/agent-browser/SKILL.md`):
  discovery stub only; real content via `agent-browser skills get core`
  (`--full` for full command reference). Never copy its CLI content into
  stack-test.
- **gitea UI config** (source: `stacks/devops/version-control/gitea/app/README.md`
  lines 113–133): env only enables OAuth2 (`GITEA__oauth2__ENABLE`); provider
  configured at **Site Administration → Authentication Sources → Add new
  OAuth2 source**, Provider: OpenID Connect, Auto Discovery URL from kanidm
  issuer; redirect `https://<gitea-domain>/user/oauth2/<provider>/callback`;
  `STEP_CA_TRUST` (default true) required for gitea's outbound TLS to kanidm.
- **zerobyte UI runbook** (source: `stacks/devops/backup/zerobyte/app/oidc.md`,
  19 lines — follow verbatim): Provider ID `kanidm`; Issuer
  `https://<kanidm-domain>/oauth2/openid/zerobyte`; Discovery endpoint
  `<issuer>/.well-known/openid-configuration`; Redirect
  `${BASE_URL}/api/auth/sso/callback/${providerId}`; **"Link matching emails
  to existing accounts: On"**.
- **Env-based exemplar** (source:
  `stacks/devops/secret-control/vaultwarden/src/vaultwarden/components/extensions/oidc/.env.example`):
  `SSO_ENABLED`, `SSO_ONLY`, `SSO_SIGNUPS_MATCH_EMAIL=true`, `SSO_AUTHORITY`
  = issuer URL, `SSO_SCOPES="openid profile email"`, PKCE.
- **step-ca root CA for the browser host**: the manager companion already
  ships `stacks/devops/ssl-automation/step-ca-manager/modules/step-ca-companion/scripts/install-host-trust.sh`
  (system trust store: Arch → `/etc/ca-certificates/trust-source/anchors/` +
  `trust extract-compat`; root CA at `/home/step/certs/root_ca.crt` inside
  the step-ca container). It does NOT cover the Chromium NSS db — pin a
  `certutil` command for that (design open question resolved).
- **Style**: terse imperative checklist, matching
  `verification-procedure.md` (`- [ ]` items, short lines, backticked
  commands, prose pointers to sources by path).
- **kanidm-oidc** already says "Test login per the `stack-test` skill"
  (`references/cli-cookbook.md:75`) — no change needed there.
- No `.mindmodel/` in this project — no additional pattern constraints.

---

## Dependency Graph

```
Batch 1 (single): 1.1 [browser-e2e.md — new file, no deps]
Batch 2 (parallel): 2.1, 2.2, 2.3 [edits that reference browser-e2e.md]
```

All four files are independent edits, but the three referencing files point
at `browser-e2e.md` — write it first so cross-references resolve immediately.

---

## Batch 1: New reference (1 implementer)

### Task 1.1: Staged browser E2E reference
**File:** `.opencode/skills/stack-test/references/browser-e2e.md` (NEW)
**Test:** none (docs-only; verify with the checks below)
**Depends:** none

Create the file with EXACTLY this content:

````markdown
# Stack Test — Staged Browser E2E (agent-browser)

Browser E2E is the gate between verification stages. Load the
`agent-browser` skill first, then load its runtime content — this file never
duplicates it:

```bash
agent-browser skills get core
```

## 0. Prerequisites

- [ ] step-ca root CA trusted by the BROWSER host, not just containers:
  - System trust: run the manager companion's installer
    (`stacks/devops/ssl-automation/step-ca-manager/modules/step-ca-companion/scripts/install-host-trust.sh`)
    or manually — extract `/home/step/certs/root_ca.crt` from the step-ca
    container into `/etc/ca-certificates/trust-source/anchors/`, then
    `trust extract-compat` (Arch).
  - Chromium NSS db (the installer does NOT cover this):

    ```bash
    certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "step-ca root" -i root_ca.crt
    ```

- [ ] Cert errors in the browser at this point are a CA-trust problem, NOT an
      app bug. Fix trust first — before touching any stack config.
- [ ] Test user exists in kanidm, member of the group the OIDC client
      requires; credentials stored in the agent-browser session/auth vault.
- [ ] agent-browser session open; screenshots saved as run artifacts.

## 1. Stage A — base deployment (no oidc)

Run BEFORE adding the `oidc` extension. Gate: Stage A must pass or Stage B
is meaningless.

- [ ] Deploy the no-oidc variant (verification-procedure.md §1–4).
- [ ] Open `https://<VIRTUAL_HOST>` with agent-browser: page loads, TLS
      clean (no cert warning).
- [ ] Local login works (the app's own admin/local account).
- [ ] Exercise ONE core app flow (create/edit/delete something small).
- [ ] Screenshot the working app state → run artifact.

## 2. Stage B — oidc enabled

### 2a. Env-based (`oidc` extension; exemplar: vaultwarden `SSO_*`)

- [ ] Rebuild with the `oidc` extension, redeploy (§1–4 again).
- [ ] Browser: app's SSO button → kanidm auth page → sign in with the test
      user → callback → session active in the app.
- [ ] Email-matching assertions (exemplar `SSO_SIGNUPS_MATCH_EMAIL=true`):
  - [ ] Existing local account with the SAME email links to the OIDC
        identity (no duplicate account created).
  - [ ] Unknown email → signup path per app policy.

### 2b. UI-based (provider configured in the app's own web UI)

Configure the provider in the app UI FIRST, save, then run the same browser
login check as 2a, plus the email-linking assertion.

**gitea** (source: `stacks/devops/version-control/gitea/app/README.md`):

- [ ] Site Administration → Authentication Sources → Add new **OAuth2**
      source.
- [ ] Provider: OpenID Connect; Client ID / Client Secret from the kanidm
      client.
- [ ] OpenID Connect Auto Discovery URL:
      `https://<kanidm-domain>/oauth2/openid/<client-name>/.well-known/openid-configuration`.
- [ ] Redirect URI registered in kanidm:
      `https://<gitea-domain>/user/oauth2/<provider>/callback`.
- [ ] `STEP_CA_TRUST=true` AND `STEP_CA_TRUST_RESTART=true` REQUIRED —
      gitea's outbound TLS to kanidm must trust the step-ca chain or the
      discovery/save fails.
- [ ] Save, then sign in via the new source on the login page.

**zerobyte** (source: `stacks/devops/backup/zerobyte/app/oidc.md` — follow it
verbatim):

- [ ] Provider ID: `kanidm`.
- [ ] Issuer URL: `https://<kanidm-domain>/oauth2/openid/zerobyte`.
- [ ] Discovery endpoint:
      `https://<kanidm-domain>/oauth2/openid/zerobyte/.well-known/openid-configuration`.
- [ ] Redirect URL: `${BASE_URL}/api/auth/sso/callback/${providerId}`.
- [ ] "Link matching emails to existing accounts": **On**.
- [ ] Save, then run the browser login check.

## 3. Failure triage

| Symptom | Cause | Fix |
|---|---|---|
| Cert error / warning in the browser | CA trust not installed on the browser host | §0 prerequisites — never an app bug |
| Redirect loop / invalid callback | Wrong callback URL in the kanidm client (or app) | Match the redirect exactly: gitea `/user/oauth2/<provider>/callback`, zerobyte `${BASE_URL}/api/auth/sso/callback/${providerId}` |
| kanidm login fails / access denied | Test user not in the required group; scope map wrong | `kanidm-oidc` skill cookbook |
| UI save fails / discovery error | App cannot TLS-verify kanidm | `STEP_CA_TRUST` + `STEP_CA_TRUST_RESTART` both set; app-specific CA envs (`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`) |
| Failure caused by the live manager setup | step-ca-manager stack | Switch to the forwarding variant; NEVER touch the manager stack |
````

**Verify:**
```bash
test -f .opencode/skills/stack-test/references/browser-e2e.md
grep -c 'agent-browser skills get core' .opencode/skills/stack-test/references/browser-e2e.md  # ≥ 1
grep -c 'Link matching emails' .opencode/skills/stack-test/references/browser-e2e.md           # ≥ 1
```
**Commit:** `docs(stack-test): add staged browser E2E reference`

---

## Batch 2: Pointers + policy (parallel — 3 implementers)

### Task 2.1: stack-test SKILL.md — staged procedure summary
**File:** `.opencode/skills/stack-test/SKILL.md` (EDIT)
**Test:** none (docs-only)
**Depends:** 1.1 (references browser-e2e.md)

Replace the entire `## Procedure` section (everything from `## Procedure` to
end of file) with EXACTLY:

````markdown
## Staged browser E2E

Verification is a staged pipeline; the browser is the gate between stages:

- **Stage A — base deployment (no oidc):** after health checks pass, drive
  `https://<VIRTUAL_HOST>` with agent-browser. MUST pass before any
  extension work.
- **Stage B — oidc enabled:** env-based (rebuild with the `oidc`
  extension) or UI-based (provider configured in the app's own web UI —
  gitea, zerobyte), then re-verify in the browser.

Before ANY browser step: load the `agent-browser` skill, then load its
runtime content — never work from memory:

```bash
agent-browser skills get core
```

Full checklists: `references/browser-e2e.md`.

## Procedure

Follow `references/verification-procedure.md` in order. Summary:

1. `cd app/ && sb build` — check the `build/<env>/<combo>/` output structure.
2. `cd build/<env>/<combo>/ && cp .env.example .env` and edit values.
3. `docker compose config` — must validate.
4. `docker compose up --build -d`.
5. Health checks pass.
6. **Stage A browser gate** (base deploy, no oidc): clean TLS, local login,
   one core flow, screenshot artifact (`references/browser-e2e.md` §1).
7. TLS-terminating services: cert-wait behavior verified (kanidm
   delayed-start sleep entrypoint; coturn gosu poll loop).
8. `STEP_CA_TRUST=true` installs the CA bundle into the container;
   `STEP_CA_TRUST_RESTART=true` restarts it after install — trust is often
   not picked up on first boot, so always set BOTH.
9. Apps needing explicit cert paths: set `REQUESTS_CA_BUNDLE` /
   `SSL_CERT_FILE` (open-webui example).
10. **Stage B** (oidc present): env-based rebuild or UI-based configuration,
    then browser login via kanidm + email-matching account linking
    (`references/browser-e2e.md` §2).
11. S3 round-trip when the `s3-storage` extension is present.
````

Do NOT touch the frontmatter (description changes are out of scope) or the
Hard rules / Compat check sections.

**Verify:**
```bash
head -8 .opencode/skills/stack-test/SKILL.md | grep -q 'name: Stack Test'    # frontmatter intact
grep -c 'browser-e2e.md' .opencode/skills/stack-test/SKILL.md                # ≥ 2
grep -c 'agent-browser skills get core' .opencode/skills/stack-test/SKILL.md # ≥ 1
```
**Commit:** `docs(stack-test): stage the procedure around browser E2E gates`

### Task 2.2: verification-procedure.md — §5 Integrations staged
**File:** `.opencode/skills/stack-test/references/verification-procedure.md` (EDIT)
**Test:** none (docs-only)
**Depends:** 1.1 (references browser-e2e.md)

Replace the entire `## 5. Integrations` section with EXACTLY:

````markdown
## 5. Integrations (staged — browser E2E)

Staged per `browser-e2e.md`. Stage A MUST pass before any extension work.

- [ ] Stage A (base deploy, no oidc): browser smoke test via agent-browser —
      clean TLS, local login, one core flow, screenshot artifact
      (`browser-e2e.md` §1).
- [ ] OIDC (when present), per its configuration mode (`browser-e2e.md` §2):
  - [ ] Env-based (`oidc` extension): rebuild, redeploy, browser login via
        the SSO button → kanidm → callback → session; email-matching
        assertions.
  - [ ] UI-based (gitea, zerobyte): configure the provider in the app's web
        UI first, save, then the same browser login check + email linking.
- [ ] S3 (when present): round-trip — create bucket, put object, get object,
      delete (see `rustfs-s3` skill cookbook).
````

All other sections (§0–§4, §6) stay unchanged.

**Verify:**
```bash
grep -c 'browser-e2e.md' .opencode/skills/stack-test/references/verification-procedure.md  # ≥ 2
grep -q 'Stage A' .opencode/skills/stack-test/references/verification-procedure.md
```
**Commit:** `docs(stack-test): stage §5 Integrations around browser gates`

### Task 2.3: stack-conventions SKILL.md — §7 OIDC policy
**File:** `.opencode/skills/stack-conventions/SKILL.md` (EDIT)
**Test:** none (docs-only)
**Depends:** 1.1 (points to the stack-test procedure)

Replace the entire `## 7. OIDC policy` section with EXACTLY:

````markdown
## 7. OIDC policy

- Add an `oidc` extension wherever the app supports OIDC; include it in the
  default build; keep a no-oidc variant as proof of the tested pre-OIDC step.
- Provider is kanidm. Issuer convention:
  `https://<kanidm-domain>/oauth2/openid/<client-name>`.
- UI-only OIDC apps (gitea, zerobyte): the provider is configured in the
  app's own web interface, NOT via env — env only enables OAuth2 support
  (gitea `GITEA__oauth2__ENABLE`; zerobyte runbook
  `stacks/devops/backup/zerobyte/app/oidc.md`). Account linking relies on
  matching email (zerobyte: "Link matching emails to existing accounts: On").
- Staged testing is MANDATORY for every stack: verify the base deployment in
  the browser first (Stage A), then add/configure oidc and re-verify
  (Stage B) — procedure in the `stack-test` skill
  (`references/browser-e2e.md`).
````

All other sections stay unchanged.

**Verify:**
```bash
grep -c 'UI-only OIDC' .opencode/skills/stack-conventions/SKILL.md   # 1
grep -c 'browser-e2e.md' .opencode/skills/stack-conventions/SKILL.md # 1
```
**Commit:** `docs(stack-conventions): codify UI-configured OIDC + staged testing`

---

## Final verification (after all batches)

```bash
# 1. All four files exist/edited
ls .opencode/skills/stack-test/SKILL.md \
   .opencode/skills/stack-test/references/browser-e2e.md \
   .opencode/skills/stack-test/references/verification-procedure.md \
   .opencode/skills/stack-conventions/SKILL.md

# 2. Frontmatter untouched (descriptions out of scope)
git diff -- '.opencode/skills/*/SKILL.md' | grep '^[+-]description:'  # 0 matches

# 3. No agent-browser CLI content duplicated (only the load instruction)
grep -rn 'snapshot\|@eN\|CDP' .opencode/skills/stack-test/  # 0 matches

# 4. Cross-references resolve (files other than browser-e2e.md point to it)
grep -rn 'browser-e2e.md' .opencode/skills/ | grep -v '^\.opencode/skills/stack-test/references/browser-e2e.md'
```

## Notes for implementers

- Match the existing voice: terse imperative checklist, no marketing prose.
- `stacks/` is gitignored — the gitea/zerobyte/vaultwarden sources are
  referenced by path in prose only; never copy their content into skills.
- Do NOT modify the agent-browser skill, kanidm-oidc, or rustfs-s3 skills.
- The zerobyte redirect `${BASE_URL}/api/auth/sso/callback/${providerId}`
  contains literal `$` placeholders — keep them verbatim (it is app
  documentation syntax, not shell).
