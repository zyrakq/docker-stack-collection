---
date: 2026-10-31
topic: "Staged Browser E2E Testing for Stacks"
status: validated
---

# Staged Browser E2E Testing for Stacks (stack-test extension)

## Problem Statement

Stacks in this collection are deployment configs for web projects: the primary
interaction surface is the browser. Yet the `stack-test` skill verifies OIDC
login as a single manual checklist line with no named tooling, and treats
"testing" as a flat checklist rather than a staged pipeline.

Two structural gaps:

1. **No staging.** The collection already keeps a no-oidc variant "as proof of
   the tested pre-OIDC step" (stack-conventions §7), but the test procedure
   never states this sequence explicitly: verify the base deployment in the
   browser first, *then* add the oidc extension and re-verify with it.
2. **No UI-configured OIDC path.** Some apps do not support OIDC via env at
   all — the provider must be configured in the app's own web UI. Known cases:
   **gitea** (Site Administration → Authentication Sources → OAuth2) and
   **zerobyte** (runbook `app/oidc.md`, with "Link matching emails to existing
   accounts: On"). Testing these requires driving the app's UI, then verifying
   account linking via email matching. stack-test has no recipe for this.

Browser automation exists in the environment as the `agent-browser` skill, but
there is zero cross-reference between `stack-test` and `agent-browser`.

## Constraints

- Docs-only change: skills under `.opencode/skills/` (SKILL.md + references).
  No code, no agent definition changes.
- Hard rules of stack-test remain untouched: step-ca-manager variant first,
  never modify the live manager stack.
- Skill descriptions (frontmatter) are explicitly out of scope this round —
  the user flagged them as imperfect but wants the simpler extension first.
- agent-browser skill is a discovery stub: real workflow content is loaded at
  runtime via `agent-browser skills get core`. stack-test must instruct to load
  it, not duplicate its content.
- `stacks/` is gitignored; stack examples (gitea, zerobyte, vaultwarden) are
  referenced by path in prose only.

## Approach

Turn stack-test verification into a **staged pipeline where browser E2E via
agent-browser is the gate between stages**:

- **Stage A — base deployment (no oidc):** deploy without the `oidc`
  extension; after health checks pass, drive `https://<VIRTUAL_HOST>` with
  agent-browser: page loads with clean TLS, local admin login works, one core
  app flow is exercised. Screenshot kept as run artifact.
- **Stage B — oidc enabled:** two sub-paths:
  - **Env-based** (exemplar: vaultwarden `SSO_*` extension): rebuild with the
    `oidc` extension, redeploy, then browser login via the app's SSO button →
    kanidm auth page → test user from the correct group → callback → session.
    Verify email-matching behavior (`SSO_SIGNUPS_MATCH_EMAIL=true`).
  - **UI-based** (gitea, zerobyte): first configure the provider in the app's
    own UI, save, then run the same browser login check, and verify that an
    existing local account links to the OIDC identity via matching email.

## Architecture

Change lands in four files:

1. **`.opencode/skills/stack-test/SKILL.md`** — add a "Staged browser E2E"
   section to the Procedure summary: Stage A gate before extension work,
   Stage B after; instruct to load the `agent-browser` skill (and its runtime
   content via `agent-browser skills get core`) before any browser step.
2. **`.opencode/skills/stack-test/references/browser-e2e.md`** (NEW) — the
   detailed staged procedure:
   - Prerequisites: step-ca root CA trusted by the browser (system trust store
     + Chromium NSS db). Cert errors at this point mean CA trust, not an app
     bug. Test user credentials held in the agent-browser session/auth vault.
   - Stage A checklist (base deploy smoke test, screenshot artifact).
   - Stage B env-based checklist (SSO button → kanidm → callback → session;
     email-match linking assertions).
   - Stage B UI-based recipes: gitea (Site Administration → Authentication
     Sources → OAuth2; redirect `https://<gitea-domain>/user/oauth2/<provider>/callback`;
     STEP_CA_TRUST required for the app's outbound TLS to kanidm) and zerobyte
     (follow `stacks/devops/backup/zerobyte/app/oidc.md`: provider id `kanidm`,
     issuer `https://<kanidm-domain>/oauth2/openid/zerobyte`, discovery URL,
     redirect `${BASE_URL}/api/auth/sso/callback/${providerId}`,
     "Link matching emails to existing accounts: On").
   - Failure triage table: cert error → CA trust; redirect loop → wrong
     callback URL in kanidm client; kanidm login fails → group/scope map;
     UI save fails → STEP_CA_TRUST missing.
3. **`.opencode/skills/stack-test/references/verification-procedure.md`** —
   §5 Integrations becomes staged: base-browser check first (pointer to
   browser-e2e.md Stage A), then OIDC per its configuration mode with pointer
   to Stage B.
4. **`.opencode/skills/stack-conventions/SKILL.md` §7** — codify: apps with
   UI-only OIDC (gitea, zerobyte) are configured in their web interface, not
   via env; account linking relies on email matching; staged testing (base
   first, oidc second) is mandatory for every stack.

## Components

- **stack-test skill** — owns the staged procedure and browser E2E reference.
- **agent-browser skill** — consumed, not modified: stack-test points to it
  and defers all CLI specifics to its runtime-loaded content.
- **stack-conventions skill** — owns the policy statement (§7 amendment).
- **kanidm-oidc / rustfs-s3 skills** — unchanged; kanidm-oidc already says
  "Test login per the stack-test skill", which now resolves to the staged flow.

## Data Flow

Deploy (no oidc) → health checks → browser Stage A gate → add oidc
(env rebuild or UI configuration) → redeploy/save → browser Stage B gate →
run artifact = screenshots + notes recorded per stack-test §6 failure handling.

## Error Handling

- Browser-level cert errors are classified as CA-trust setup problems, never
  app bugs — triage first, before touching stack config.
- OIDC failures map to a triage table in browser-e2e.md (see Architecture §2).
- Manager-stack-caused failures still follow the existing rule: switch to the
  forwarding variant, never touch the manager stack.

## Testing Strategy

Docs-only change, verified by:

- Each edited SKILL.md parses (valid YAML frontmatter, headings consistent
  with existing skill style).
- Cross-references resolve: stack-test ↔ agent-browser, browser-e2e.md exists,
  verification-procedure.md points to it, stack-conventions §7 amended.
- No duplication of agent-browser runtime content in stack-test.

## Open Questions

- Exact commands for installing the step-ca root CA into the system + NSS
  trust stores are to be pinned down at execution time (planner may check how
  other docs reference CA trust, e.g. STEP_CA_TRUST sections).
- Whether the gitea stack should eventually gain an `oidc` extension that only
  sets `GITEA__oauth2__ENABLE=true` (UI does the rest) — deferred; not needed
  for this testing-focused change.
