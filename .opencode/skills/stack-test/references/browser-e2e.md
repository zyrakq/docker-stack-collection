# Stack Test — Staged Browser E2E (agent-browser)

Browser E2E is the gate between verification stages. Load the
`agent-browser` skill first, then load its runtime content — this file never
duplicates it:

```bash
agent-browser skills get core
```

## 0. Prerequisites

- [ ] step-ca root CA is already trusted at the HOST level (the manager
      companion's `install-host-trust.sh` has been run). Assume browser TLS is
      clean — do not re-install trust.
- [ ] If a cert error still appears in the browser, it is a CA-trust problem,
      NOT an app bug: fix host trust first (extract `/home/step/certs/root_ca.crt`
      from the step-ca container into `/etc/ca-certificates/trust-source/anchors/`,
      then `trust extract-compat`; for Chromium add it to the NSS db:
      `certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "step-ca root" -i root_ca.crt`)
      — before touching any stack config.
- [ ] Test user exists in kanidm, member of the group the OIDC client
      requires; credentials stored in the agent-browser session/auth vault.
- [ ] agent-browser session open; screenshots saved as run artifacts.

## 1. Stage A — functional base (product parts + DB, no oidc)

Run BEFORE adding the `oidc` stage. This variant is the functional base +
the `postgresql` database stage (mandatory infra, ALWAYS attempted). The
functional base = ALL product parts from the stack's `DEPLOYMENT.md`
(stack-conventions §20); a stack without DEPLOYMENT.md → run the
`stack-analysis` skill gap mode first. Gate: Stage A must pass or Stage B
is meaningless.

- [ ] Deploy the no-oidc variant (verification-procedure.md §1–4).
- [ ] Open `https://<VIRTUAL_HOST>` with agent-browser: page loads, TLS
      clean (no cert warning).
- [ ] Local login works (the app's own admin/local account).
- [ ] Execute the DEPLOYMENT.md **functional gate scenario** — the
      cross-part end-to-end flow that proves the functional base
      (stack-conventions §20), not just a single-container core flow.
      Model vs gate mismatch → update DEPLOYMENT.md (living doc, §20) and
      re-run the stage.
- [ ] Screenshot the working app state → run artifact.

### Stage A2 — DB alternative (pgrust)

Run AFTER Stage A passes and BEFORE oidc — the same browser gate on the
alternative DB engine:

- [ ] Rebuild with the `pgrust` combo and redeploy
      (verification-procedure.md §1–4).
- [ ] Same Stage A flow: page loads, TLS clean, local login, the
      DEPLOYMENT.md functional gate scenario, screenshot artifact.
- [ ] Clean pass → `pgrust` becomes the default combo (stack-conventions
      §9). Failure → keep `postgresql` as the default combo and record
      why in the component README.

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

**Generic UI-only app** (adapt to the app's UI):

- [ ] Open the app's authentication/SSO settings, add an **OpenID Connect**
      provider; Client ID / Client Secret from the kanidm client.
- [ ] Discovery/issuer URL:
      `https://<kanidm-domain>/oauth2/openid/<client-name>/.well-known/openid-configuration`.
- [ ] Redirect URI registered in kanidm must equal the callback URL the app
      shows/documents.
- [ ] Enable the app's "link matching emails to existing accounts" option.
- [ ] If the app's outbound TLS to kanidm fails: `STEP_CA_TRUST=true` AND
      `STEP_CA_TRUST_RESTART=true` REQUIRED (trust the step-ca chain).
- [ ] Save, then sign in via the new provider on the login page.

## 3. Failure triage

| Symptom | Cause | Fix |
|---|---|---|
| Cert error / warning in the browser | CA trust not installed on the browser host | §0 prerequisites — never an app bug |
| Redirect loop / invalid callback | Wrong callback URL in the kanidm client (or app) | Match the redirect exactly to the app's documented callback URL |
| kanidm login fails / access denied | Test user not in the required group; scope map wrong | `kanidm-oidc` skill cookbook |
| UI save fails / discovery error | App cannot TLS-verify kanidm | `STEP_CA_TRUST` + `STEP_CA_TRUST_RESTART` both set; app-specific CA envs (`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`) |
| Failure caused by the live manager setup | step-ca-manager stack | Switch to the forwarding variant; NEVER touch the manager stack |
