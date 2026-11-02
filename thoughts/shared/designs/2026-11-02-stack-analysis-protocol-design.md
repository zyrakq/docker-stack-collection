---
date: 2026-11-02
topic: "Stack Analysis Protocol — product-lens base scoping for stack skills"
status: validated
---

# Problem Statement

The vibe-kanban stack deployed only the remote-server control plane (1 of 3 upstream product roles); the host executor node and relay tunnel server are absent, documented as "intentionally out of scope" — a scope decision never surfaced to the user. Root cause is in the skill protocol layer, not the agents:

- micode agent definitions (`~/.micode-v2/src/agents/*.ts`) are project-agnostic by design — zero skill references across all 13 definitions. Stack domain rules reach every agent via the project AGENTS.md + skills injected into context.
- `stack-init` Phase 0 clones the upstream repo but inspects it only "to inform the scaffolding" (config files, flags, entrypoints) and for image build requirements (`source-image`). No step enumerates the upstream product's deployable roles.
- "Base" is defined infra-first: "app service + simple named volumes, wired to the DB extension" (stack-conventions §9) with a fixed extension ladder (postgresql → pgrust → oidc → s3). There is no product-lens definition: the minimal set of cooperating roles that makes the product functional end-to-end.
- No user checkpoints exist for base scope or extension selection — the extension order is fixed and never proposed as a menu.

# Constraints

- Skills live in `.opencode/skills/` in the collection repo. Convention: `SKILL.md` + optional `references/*.md`; frontmatter exactly `name:` (Title Case) and `description: >-` with "Use when…" trigger phrasing; every stack skill opens with "Load the `stack-conventions` skill first"; patterns embedded verbatim, no path pointers into `stacks/`.
- Project AGENTS.md iron rules stay: stack-conventions loaded before any stack work; `thoughts/shared/` artifacts committed immediately; `.gitkeep` for file-less dirs; UPSTREAM.md rows append-only; host safety allowlist.
- Do NOT edit micode agent definitions: out-of-repo (`~/.micode-v2`), require `bun run build`, and generic by design. Protocol changes belong in skills + the project AGENTS.md.
- The staged protocol with test gates is kept — the fix inserts a product-lens phase before scaffolding and a menu checkpoint after the base gate.
- Clone-in-tmp (`/tmp/opencode/upstreams/<stack>-<project>`) is the only upstream inspection mechanism; clones are deleted after use; no vendoring.

# Approach

Chosen: **new skill `stack-analysis` (mandatory Phase 0) + targeted edits** to `stack-init`, `stack-conventions`, `stack-test`, `stack-modernize`, `readme-gen`, and the project AGENTS.md. No new agents, no micode edits.

- Why: the analysis is needed in three flows — new-stack init, modernize, and remediation of existing stacks missing base roles (the vibe-kanban case) — so it must be a standalone skill, not a phase buried in stack-init. Skills are the protocol carriers here: AGENTS.md already force-loads them; agents stay generic.
- Alternative "extend stack-init only" — rejected: covers only new stacks; vibe-kanban remediation and modernize would still lack the analysis; stack-init balloons in size.
- Alternative "new stack-analyst agent" — rejected: duplicates the skill mechanism; agents cannot be force-loaded as reliably as skills; the existing project agents (kanidm-admin, rustfs-admin) are narrow allowlisted operators, not protocol carriers.

# Architecture

New lifecycle: request → `stack-analysis` (clone upstream, inventory roles, classify, write DEPLOYMENT.md, agree base scope + stage plan with the user) → `stack-init` scaffolds ALL base roles → staged implementation with test gates, Stage A including the functional gate from the model → checkpoint: extension menu from DEPLOYMENT.md, user selects → extensions one at a time, each gated.

**DEPLOYMENT.md** — new persistent artifact at each stack repo root (next to UPSTREAM.md): the deployment model and living contract for base scope and extension status.

# Components

1. **NEW `.opencode/skills/stack-analysis/`** (SKILL.md + `references/analysis-checklist.md`):
   - Inputs: upstream repo URL(s), or an existing stack path (gap mode).
   - Steps: clone-in-tmp per stack-conventions §17; inventory deployable roles from upstream compose files, Dockerfiles, workspace/crate/package structure, CLI entrypoints, ports, deployment docs; build the interaction map (who talks to whom, what breaks if a role is absent); classify every role/feature as base-required / product-extension / infra-extension (db, oidc, s3); define the functional base = minimal set where the product's core value works end-to-end; define the functional gate scenario (cross-role E2E); produce the base stage plan (ordered, each stage with its gate); assemble the extension catalog with dependencies and ordering constraints; write DEPLOYMENT.md; present base scope + stages + catalog to the user and get agreement; delete the clone.
   - Gap mode (existing stacks): read the current compose + UPSTREAM.md, diff against the model, output a remediation plan — completing missing base roles takes priority over any extension.
2. **stack-init (edits):** Phase 0 becomes "run stack-analysis; require an agreed DEPLOYMENT.md before scaffolding". Phase 1 scaffolds ALL base roles (one compose service per role, `<stack>-<role>` naming; one image per role via source-image when upstream publishes none). After the Stage A gate: present the extension menu from DEPLOYMENT.md; the user selects; implement one at a time (existing Phases 2–5 become instances of the catalog, keeping their ordering rules: db first, s3 last, s3fs-fuse never on DB volumes).
3. **stack-conventions (edits):** new section "Deployment model and application roles": definitions (role, functional base, extension catalog); DEPLOYMENT.md required in every stack repo with a content spec; base ≠ one app container; service-per-role naming; two mandatory user checkpoints (base scope before scaffold; extension menu after base gate); remediation rule — missing base roles are completed before any extension work.
4. **stack-test (edits):** Stage A must execute the functional gate scenario from DEPLOYMENT.md (cross-role end-to-end), not just a single-container core flow.
5. **stack-modernize (edits):** if the stack lacks DEPLOYMENT.md, run stack-analysis gap mode first; base-role remediation precedes format migration extras.
6. **readme-gen (minor edit):** READMEs document product roles and extension status (implemented / available / declined) per DEPLOYMENT.md.
7. **Project AGENTS.md (edit):** extend the stack-work iron rules — any new stack, and any change affecting product roles, begins with the stack-analysis skill; the agreed DEPLOYMENT.md is the contract for base scope and the extension menu.

# Data Flow

upstream repo → `/tmp/opencode/upstreams/<stack>-<project>` (clone, deleted after) → analysis → **DEPLOYMENT.md** (committed in the stack repo; sections: Product roles, Interaction map, Functional base, Base stage plan + functional gate, Extension catalog with status proposed/implemented/declined, Open hypotheses) → user agreement → stack-init consumes the model → scaffold → gates (incl. functional) → extension menu checkpoint → selected extensions one at a time.

# Error Handling

- Undocumented/ambiguous roles → recorded as hypotheses with confidence, validated at the functional gate; disputed base scope → present 2–3 base-scope options with trade-offs to the user — never silently shrink the base.
- Model vs gate mismatch → update DEPLOYMENT.md (a living document, changes committed; unlike UPSTREAM.md it is not append-only) and re-run the failed stage.
- No upstream repo access → stop and ask the user; never guess a deployment model.
- Overreach guard: single-role products must stay single-role — the analysis must justify every role it adds to base (an inflated base is as wrong as a shrunken one).

# Testing Strategy

- Validation case: vibe-kanban gap-mode analysis must yield base = remote-server + host (relay classified with explicit rationale: base-required vs product-extension), plus a remediation plan for the existing stack.
- Anti-overreach case: run the analysis on a simple single-role stack — base must not inflate.
- Skill hygiene checks: frontmatter triggers, "Load stack-conventions first" openers, cross-references between skills valid, no path pointers into `stacks/`, `.gitkeep` where needed, all edits committed.

# Open Questions

- Relay classification for vibe-kanban (base vs extension) — resolved with the user during the validation run.
- DEPLOYMENT.md placement: stack repo root (leaning) vs `app/` — final call during planning.
- Whether infra extensions appear in the same menu as product extensions (leaning: yes — one catalog, ordering constraints preserved).
