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
