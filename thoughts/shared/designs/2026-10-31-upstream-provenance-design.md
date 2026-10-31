---
date: 2026-10-31
topic: "Upstream Provenance Tracking for Stacks"
status: validated
---

# Upstream Provenance Tracking for Stacks

## Problem Statement

Skills and agents that initialize/modernize stacks never answer: where do the
deployment configs come from? When a stack's dockerization is reworked, there
is no record of:

- which upstream repository the configs were derived from;
- which upstream commit the current configs were based on;
- which container image version the configs were last verified against.

Two goals this must serve:

1. **Documentation & codebase understanding** — to dockerize a project per
   collection rules, the agent needs the project's source at hand.
2. **Regression diagnosis** — when old configs stop working with a new
   container image, a diff between the previously recorded upstream commit and
   the new one reveals what changed in the service's configuration surface.

## Constraints

- Each stack is an independent git repo; `stacks/` is gitignored in the
  collection repo. Provenance must travel with the stack.
- History must be append-only: recording a new commit hash must never destroy
  the previous one (otherwise mid-rework you lose the base version of the
  previous config generation).
- Clones of upstream repos are temporary working material only — never
  committed into the stack or collection repos.
- Prefer `/tmp/opencode` over generic `/tmp` (environment policy).
- Skills are the right place for rules: generic agents are config-only
  (`~/.config/opencode/micode.jsonc`), and `kanidm-admin`/`rustfs-admin` are
  narrow-purpose.

## Approach (chosen)

Per-stack `UPSTREAM.md` at the stack root, maintained by the skills.

- One section per project dir (`app/`, `ui/`, `server/`, ...) since
  multi-project stacks may track one upstream repo per project.
- Section header: project dir path + upstream repo URL.
- Append-only log table with columns:
  `date | upstream commit hash | image tag or digest | note (what changed / why configs were touched)`.
  The image column is required for goal 2: you must know which image version
  the configs were last verified against.
- Iron rule: **rows are only ever appended, never rewritten or deleted.**

### Clone-in-tmp workflow

At the start of any rework session on a stack:

1. Read `UPSTREAM.md` to get the repo URL and the last recorded commit.
2. Clone the upstream repo into `/tmp/opencode/upstreams/<stack>-<project>`.
3. Use the clone to understand the service (config files, flags, entrypoints)
   and, when diagnosing, diff `last-recorded-commit..HEAD`.
4. After the session: append the new row to `UPSTREAM.md`, then delete the
   clone. Both ends are mandated by the skills.

### Compat-check rule (new, in `stack-test`)

Before verifying a stack after any change or image update:

1. Pre-pull images first (`docker compose pull` in the built environment dir)
   — the agent fetches new images itself, never verifies against stale local
   images.
2. Verify that the **existing configs still work with the freshly pulled
   containers** (health, logs, core functionality per the normal
   `stack-test` procedure).
3. If the new container breaks with old configs: diff the upstream repo
   between the last recorded commit and the new relevant commit to identify
   what changed in the configuration surface; fix configs per collection
   rules; append the new provenance row.

## Components

| Skill | Change |
|---|---|
| `stack-conventions` | New section "Upstream provenance": `UPSTREAM.md` format, append-only rule, clone-in-tmp paths. All other skills build on this one, so the canonical definition lives here. |
| `stack-init` | New workflow step: ask user for upstream repo URL(s), create `UPSTREAM.md`, clone to `/tmp/opencode/upstreams/`, inspect source to inform scaffolding, record the starting commit, delete the clone. |
| `stack-modernize` | Backfill step: create `UPSTREAM.md` for existing stacks; recover the current upstream commit from the image tag where possible, otherwise record `unknown` with a note. |
| `stack-test` | Compat-check rule as described above (pre-pull + old-configs-vs-new-containers verification). |

Agent definitions need no changes.

## Data Flow

1. `stack-init` → `UPSTREAM.md` created with initial commit row.
2. Any rework (`stack-modernize` or ad-hoc) → clone → work → append row →
   clone removed.
3. Image update → `stack-test` pre-pulls → compat verified or diagnosed via
   upstream diff → new row appended.

## Error Handling

- Upstream URL unknown at init: create `UPSTREAM.md` with the section and an
  empty log; the first rework session backfills the URL.
- Commit unrecoverable (image tag not mappable to a commit): record
  `unknown` + note; never invent a hash.
- Clone fails (network, repo moved): report and stop the provenance step;
  do not silently skip recording.
- `/tmp/opencode/upstreams/` leftovers from crashed sessions: each session
  clones into a fresh dir (or removes an existing one first) — idempotent.

## Testing Strategy

- Docs-level: after editing the skills, run a dry walkthrough — pick an
  existing stack (e.g. kanidm), simulate the modernize flow, confirm the
  skill text unambiguously prescribes clone → record → append → delete.
- Behavioral: on the next real stack rework, verify `UPSTREAM.md` gains a row
  and no previous row changed (git diff shows only additions).

## Open Questions

- None blocking. Backfill accuracy for existing stacks depends on whether
  image tags map to upstream commits; `unknown` is an acceptable fallback.
