---
date: 2026-11-02
topic: "Stack Analysis Protocol — product-lens base scoping for stack skills"
status: validated
---

# Problem Statement

A stack in the collection deployed only part of the upstream product; the missing parts were documented as "intentionally out of scope" — a scope decision never surfaced to the user. Root cause is in the skill protocol layer, not the agents:

- micode agent definitions (`~/.micode-v2/src/agents/*.ts`) are project-agnostic by design — zero skill references across all 13 definitions. Stack domain rules reach every agent via the project AGENTS.md + skills injected into context.
- `stack-init` Phase 0 clones the upstream repo but inspects it only "to inform the scaffolding" (config files, flags, entrypoints) and for image build requirements (`source-image`). No step enumerates the upstream product's deployable parts.
- "Base" is defined infra-first: "app service + simple named volumes, wired to the DB extension" (stack-conventions §9) with a fixed extension ladder (postgresql → pgrust → oidc → s3). There is no product-lens definition: the minimal set of cooperating parts that makes the product functional end-to-end.
- No user checkpoints exist for base scope or extension selection — the extension order is fixed and never proposed as a menu.

# Constraints

- Skills live in `.opencode/skills/` in the collection repo. Convention: `SKILL.md` + optional `references/*.md`; frontmatter exactly `name:` (Title Case) and `description: >-` with "Use when…" trigger phrasing; every stack skill opens with "Load the `stack-conventions` skill first"; patterns embedded verbatim, no path pointers into `stacks/`.
- Project AGENTS.md iron rules stay: stack-conventions loaded before any stack work; `thoughts/shared/` artifacts committed immediately; `.gitkeep` for file-less dirs; UPSTREAM.md rows append-only; host safety allowlist.
- Do NOT edit micode agent definitions: out-of-repo (`~/.micode-v2`), require `bun run build`, and generic by design. Protocol changes belong in skills + the project AGENTS.md.
- The staged protocol with test gates is kept — the fix inserts a product-lens phase before scaffolding and a menu checkpoint after the base gate.
- Clone-in-tmp (`/tmp/opencode/upstreams/<stack>-<project>`) is the only upstream inspection mechanism; clones are deleted after use; no vendoring.

# Approach

Chosen: **new skill `stack-analysis` (mandatory Phase 0) + targeted edits** to `stack-init`, `stack-conventions`, `stack-test`, `stack-modernize`, `readme-gen`, and the project AGENTS.md. No new agents, no micode edits.

- Why: the analysis is needed in three flows — new-stack init, modernize, and remediation of existing stacks missing base parts — so it must be a standalone skill, not a phase buried in stack-init. Skills are the protocol carriers here: AGENTS.md already force-loads them; agents stay generic.
- Alternative "extend stack-init only" — rejected: covers only new stacks; remediation of existing stacks and modernize would still lack the analysis; stack-init balloons in size.
- Alternative "new stack-analyst agent" — rejected: duplicates the skill mechanism; agents cannot be force-loaded as reliably as skills; the existing project agents (kanidm-admin, rustfs-admin) are narrow allowlisted operators, not protocol carriers.

# Architecture

New lifecycle: request → `stack-analysis` (clone upstream, inventory parts, classify, write DEPLOYMENT.md — autonomously, no approval gate) → `stack-init` implements the ENTIRE base: all product parts + the mandatory infra, always included — database, S3, OIDC, or other infra the product mandates (an item blocked by unresolvable problems is refused with the reason recorded) → staged implementation with test gates, Stage A including the functional gate from the model → the single user checkpoint: the extension catalog from DEPLOYMENT.md is presented; extensions are recorded as available and NEVER implemented without the user's explicit confirmation → confirmed extensions one at a time, each gated.

**DEPLOYMENT.md** — new persistent artifact at each stack repo root (next to UPSTREAM.md): the deployment model and living contract for base scope and extension status.

# Components

1. **NEW `.opencode/skills/stack-analysis/`** (SKILL.md + `references/analysis-checklist.md`):
   - Inputs: upstream repo URL(s), or an existing stack path (gap mode).
   - Steps: clone-in-tmp per stack-conventions §17; inventory deployable parts from upstream compose files, Dockerfiles, workspace/crate/package structure, CLI entrypoints, ports, deployment docs; build the interaction map (who talks to whom, what breaks if a part is absent); classify every part/feature as base or extension; the functional base = the product's parts required for core value end-to-end PLUS the mandatory infra, always included: database (postgresql+pgrust), S3 (s3-storage), OIDC — or other infra the product mandates; any mandatory item hitting an unresolvable blocker is refused with the reason recorded in DEPLOYMENT.md — never silently dropped, never silently shrunk; define the functional gate scenario (cross-part E2E); produce the base stage plan (ordered, each stage with its gate); assemble the extension catalog with dependencies and ordering constraints; write DEPLOYMENT.md; delete the clone. No approval gate — the base scope and stage plan are executed as analyzed; the user sees the catalog only at the extension-menu checkpoint after the base gate.
   - Gap mode (existing stacks): read the current compose + UPSTREAM.md, diff against the model, output a remediation plan — completing missing base parts takes priority over any extension.
2. **stack-init (edits):** Phase 0 becomes "run stack-analysis; require a committed DEPLOYMENT.md before scaffolding". Phase 1 scaffolds ALL base parts (one compose service per part, `<stack>-<role>` naming; one image per part via source-image when upstream publishes none). Database, S3, OIDC are base stages — always attempted in the staged order (db first, s3 last, s3fs-fuse never on DB volumes), refused only on unresolvable blockers with the refusal recorded. After the base gates: present the extension catalog from DEPLOYMENT.md; nothing in it is implemented without the user's explicit confirmation; confirmed extensions go one at a time, each gated.
3. **stack-conventions (edits):** new section §20 "Deployment model and application parts": definitions (part, functional base, extension catalog); DEPLOYMENT.md required in every stack repo with a content spec; base ≠ one app container; service-per-part naming (`<stack>-<role>` service names); mandatory-infra rule — database (postgresql+pgrust), S3, OIDC, or other product-mandated infra is always part of the base, never an optional extension, and a mandatory item blocked by unresolvable problems is refused with the reason recorded; confirmation rule — catalog extensions are never implemented without the user's explicit confirmation; ONE mandatory user checkpoint (extension menu after the base gate — base scope itself needs no user agreement); remediation rule — missing base parts are completed before any extension work.
4. **stack-test (edits):** Stage A must execute the functional gate scenario from DEPLOYMENT.md (cross-part end-to-end), not just a single-container core flow.
5. **stack-modernize (edits):** if the stack lacks DEPLOYMENT.md, run stack-analysis gap mode first; base-part remediation precedes format migration extras.
6. **readme-gen (minor edit):** READMEs document product parts and extension status (available / implemented / refused) per DEPLOYMENT.md.
7. **Project AGENTS.md (edit):** extend the stack-work iron rules — any new stack, and any change affecting product parts, begins with the stack-analysis skill; the agreed DEPLOYMENT.md is the contract for base scope and the extension menu.

# Data Flow

upstream repo → `/tmp/opencode/upstreams/<stack>-<project>` (clone, deleted after) → analysis → **DEPLOYMENT.md** (committed in the stack repo; sections: Product parts, Interaction map, Functional base — product parts + mandatory infra, with recorded refusals and reasons for any mandatory item blocked unresolvably, Base stage plan + functional gate, Extension catalog with status available/implemented/refused, Open hypotheses) → stack-init consumes the model → scaffold → gates (incl. functional) → extension menu checkpoint (the only user touchpoint) → selected extensions one at a time.

# Error Handling

- Undocumented/ambiguous parts → recorded as hypotheses with confidence, validated at the functional gate; base scope the analysis cannot decide with confidence → present 2–3 options with trade-offs to the user (an exception path, not a standing gate) — never silently shrink the base.
- Model vs gate mismatch → update DEPLOYMENT.md (a living document, changes committed; unlike UPSTREAM.md it is not append-only) and re-run the failed stage.
- No upstream repo access → stop and ask the user; never guess a deployment model.
- Overreach guard: single-part products must stay single-part — the analysis must justify every part it adds to base (an inflated base is as wrong as a shrunken one).

# Testing Strategy

- Validation: the next stack created or modernized under this protocol must deploy the full functional base — all product parts + the mandatory infra (database, S3, OIDC; each either a base stage or refused with a recorded reason) — and pass the functional gate before any extension is proposed.
- Anti-overreach case: run the analysis on a simple single-part stack — base must not inflate.
- Skill hygiene checks: frontmatter triggers, "Load stack-conventions first" openers, cross-references between skills valid, no path pointers into `stacks/`, `.gitkeep` where needed, all edits committed.

# Open Questions

None — resolved by the user on 2026-11-02:

- Base scope covers ALL parts of the upstream product — however many it has; upstream features that are not product parts are recorded in the extension catalog as available.
- DEPLOYMENT.md: a separate file at each stack repo root («Мы делаем через файл DEPLOYMENT.md!»), next to UPSTREAM.md.
- Infra — database, S3, OIDC, or other product-mandated infra — is always part of the mandatory base («делаем всегда субд, s3 и oidc или другие обязательные»); unresolvable blockers → recorded refusal («Если не получается из за каких то проблем, которые не обойти, то отказываемся»), never a silent drop or shrink.
- Extensions beyond the base are only recorded as available and never touched without explicit confirmation («Остальные варианты расширения ты просто фиксируешь как доступные и не лезешь без подтверждения»).
