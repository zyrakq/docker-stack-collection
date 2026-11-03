---
date: 2026-11-03
topic: "Skills/agents: core-first planning and cross-host step-ca-trust"
status: proposed (awaiting user approval — AGENTS.md forbids editing skills without it)
---

# Problem

Observed on vibe-kanban (not touched by this plan):
1. Plan started with `remote` (commercial/multi-user layer) instead of `host`
   (the self-sufficient unit with the UI and the core work).
2. `step-ca-trust` was never considered although parts of the product may
   live on another host and call each other by https domain.

# Principles

- Logic lives in `stack-analysis` + `stack-analyst` (own session). The parent
  (stack-init / commander) only receives a <=25-line summary and derives its
  plan from DEPLOYMENT.md — it does not re-judge the architecture.
- No new skills. Net growth ~60 lines of ~1130 (~5%). Embedded rules, no
  stack names as examples.

# Rules to add

R1 Core-first. Every part gets a tier:
   - core: delivers the product's core value alone, incl. its primary UI
     (a "self-sufficient unit");
   - ring-N: only adds sharing, multi-tenancy, remote access, sync,
     billing, relay/proxy for the core.
   Test question: "which part alone gives a user the main interface and
   main work?" Implementation order = core outward; each ring is its own
   group with its own gate. Core's gate is STANDALONE (no ring present).
   Overreach guard stays (every base part is exercised by a gate).

R2 Split criterion (when a group becomes its own component under app/):
   independently useful/deployable AND plausibly on another host (separate
   release/scale). Small helpers (db, cache, sync sidecar) stay inside
   their group, not separate components. Pairs of groups on one host
   share nothing but declared links.

R3 Cross-group links. DEPLOYMENT.md lists each link between groups:
   protocol, direction, whether it goes by public https domain. A group
   that may be on another host and calls another group by https domain
   => `step-ca-trust` extension is MANDATORY for that group (not a menu
   item), and the link gate runs over the domains in step-ca. Not
   applied to intra-group links (db etc.).

# File changes (all need approval)

| File | Change | ~lines |
|---|---|---|
| skills/stack-analysis/SKILL.md | workflow step: tier parts (R1), group + split (R2), list links (R3); 2 iron rules | +15 |
| skills/stack-analysis/references/analysis-checklist.md | tier/group/link checklist + 2 anonymous exemplars (core-first; cross-host trust) | +14 |
| skills/stack-conventions/SKILL.md §20 | defs: tier, group, link; DEPLOYMENT.md `## Functional base` lists groups (tier, may-split, links); `## Base stage plan` ordered core-first, one gate per group | +14 |
| skills/stack-conventions/SKILL.md §14 | step-ca-trust mandatory when R3 applies | +3 |
| skills/stack-init/SKILL.md Phase 1 | "scaffold ALL parts" -> "scaffold group by group per DEPLOYMENT.md order; core standalone first; each gated"; trust ext with the group | +/-10 |
| skills/stack-test/SKILL.md | Stage A = core standalone gate; later stage = cross-group gate over domains | +5 |
| skills/stack-modernize/SKILL.md | gap mode checks tiers and link->trust | +3 |
| agents/stack-analyst.md | summary must include groups, order, mandatory trust links | +3 |

# Verification

Dry-run on two paper cases (no stacks named in skills): (a) product with a
UI-bearing local unit plus optional multi-user server -> local unit is
Stage A; (b) product split into two cross-host groups -> trust required,
link gate over domains. Re-run stack-analyst on the vibe-kanban upstream
into /tmp only and compare its DEPLOYMENT.md order with expectation
(host -> remote -> relay).
