# Upstream Provenance Tracking — Skill Documentation Plan

**Goal:** Teach the four stack skills to maintain a per-stack `UPSTREAM.md`
provenance file (append-only upstream commit/image log) and a clone-in-tmp
workflow, so stack rework and image-update regressions are diagnosable.

**Architecture:** Documentation-only change. `stack-conventions/SKILL.md`
gains the canonical "Upstream provenance" section (§13); `stack-init`,
`stack-modernize`, and `stack-test` gain one workflow step / rule each that
points back to it. No code, no agent definitions, no new files beyond the
plan itself.

**Design:** `thoughts/shared/designs/2026-10-31-upstream-provenance-design.md`

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2, 1.3, 1.4 [docs edits - no deps between files]
```

All four tasks are independent file edits (cross-references are textual, not
imports) and run in parallel. `stack-conventions` is the canonical reference;
the other three files reference it by name ("stack-conventions §13"), which
works regardless of edit order.

---

## Batch 1: Skill file edits (parallel — 4 implementers)

### Task 1.1: stack-conventions — canonical "Upstream provenance" section

**File:** `/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-conventions/SKILL.md`
**Test:** none (docs-only; verify by reading)
**Depends:** none

**Placement decision:** The file has numbered sections 1–12. Appending as
**§13** avoids renumbering (§1 is cross-referenced from
`stack-modernize/SKILL.md` line 31, and renumbering 12 sections invites
drift). §12 "Operational gotcha" reads as a closing note but appending after
it is consistent with the flat numbered style.

**Edit A — frontmatter description** (line 3–7): extend the description list
to mention the new topic, keeping the `>-` folded style:

```yaml
description: >-
  Conventions for docker-stack-collection stacks: app/ layout, sb/stackbuilder
  builds, environments and extensions, no-bind-mount volume policy,
  dockerfile_inline config patterns, OIDC/S3/step-ca integration rules,
  .env.example standards, and upstream provenance (UPSTREAM.md). Load before
  creating or modifying any stack.
```

**Edit B — append after §12** (end of file, after line 152). Exact content:

````markdown
## 13. Upstream provenance

Every stack records WHERE its deployment configs come from in a per-stack
`UPSTREAM.md` at the stack root. Provenance must travel with the stack repo
(`stacks/` is gitignored by the collection repo). The `stack-init`,
`stack-modernize`, and `stack-test` skills maintain the file; this section is
the canonical format definition.

- One `##` section per project dir (`app/`, `ui/`, `server/`, ...) —
  multi-project stacks may track one upstream repo per project. Section
  header: `## <project-dir> — <upstream repo URL>`.
- Under each section header, an append-only log table with columns
  `date | upstream commit | image tag / digest | note`. The image column is
  required: you must always know which image version the configs were last
  verified against. Example (rendered):

  | date | upstream commit | image tag / digest | note |
  |------|-----------------|--------------------|------|
  | 2026-10-31 | abc1234 | v1.2.3 | initial dockerization |

- IRON RULE: rows are ONLY ever appended — never rewritten, reordered, or
  deleted. A `git diff` on `UPSTREAM.md` must ever show additions only
  (mid-rework you would otherwise lose the base commit of the previous
  config generation).
- Commit unrecoverable (image tag not mappable to a commit): record
  `unknown` in the commit column with a note explaining why. NEVER invent a
  hash.
- Upstream URL unknown: create the section with the URL as `unknown` and an
  empty log; the first rework session backfills it.

### Clone-in-tmp workflow (any rework session on a stack)

1. Read `UPSTREAM.md` for the repo URL and the last recorded commit.
2. Clone into a FRESH dir under `/tmp/opencode/upstreams/` — remove any
   leftover first (idempotent against crashed sessions):

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

3. Use the clone to understand the service (config files, flags,
   entrypoints). When diagnosing a regression, diff the config surface
   between the last recorded commit and HEAD:

   ```bash
   git -C /tmp/opencode/upstreams/<stack>-<project> diff <last-recorded-commit>..HEAD
   ```

4. After the session: append the new row to `UPSTREAM.md`, THEN delete the
   clone. Both ends are mandatory:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   ```

- Clones are temporary working material — NEVER commit them into the stack
  or collection repos.
- Clone fails (network, repo moved): report it and stop the provenance
  step — do not silently skip recording.
````

**Verify:**
```bash
rtk grep -n "## 13. Upstream provenance" .opencode/skills/stack-conventions/SKILL.md
rtk grep -n "IRON RULE" .opencode/skills/stack-conventions/SKILL.md
rtk grep -c "^## " .opencode/skills/stack-conventions/SKILL.md   # must be 13
```
**Commit:** `docs(skills): add upstream provenance conventions (UPSTREAM.md)`

---

### Task 1.2: stack-init — provenance workflow step

**File:** `/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-init/SKILL.md`
**Test:** none (docs-only; verify by reading)
**Depends:** none

**Placement decision:** Insert as new **step 3** in the `## Workflow` list,
right after "Create the stack repo" and before "Scaffold" — the upstream
clone must exist to inform scaffolding. Renumber existing steps 3–6 → 4–7.

**Edit A — new step 3** (inserted after current step 2's bash block, before
current step 3 "Scaffold"). Exact content:

````markdown
3. **Upstream provenance.** Ask the user for the upstream repo URL(s) — one
   per project dir when the stack ships more than one project. Create
   `UPSTREAM.md` at the stack root per stack-conventions §13, then clone
   each upstream repo to inspect the source:

   ```bash
   rm -rf /tmp/opencode/upstreams/<stack>-<project>
   git clone <upstream-url> /tmp/opencode/upstreams/<stack>-<project>
   ```

   - Inspect the clone (config files, flags, entrypoints) to inform the
     scaffolding in the next step.
   - Append the first log row: today's date, the current upstream commit
     (`git -C /tmp/opencode/upstreams/<stack>-<project> rev-parse --short
     HEAD`), the image tag/digest being dockerized, note `initial
     dockerization`.
   - URL unknown: create `UPSTREAM.md` with the section and an empty log —
     the first rework session backfills it. Clone fails: report and skip
     the clone (still create `UPSTREAM.md`).
   - Delete the clone when done scaffolding:
     `rm -rf /tmp/opencode/upstreams/<stack>-<project>`
````

**Edit B — renumber** the remaining steps: `3. **Scaffold**` → `4.`,
`4. **Register in stacks.csv**` → `5.`, `5. **Clean artifacts**` → `6.`,
`6. **Build & verify**` → `7.`. No other wording changes.

**Verify:**
```bash
rtk grep -n "Upstream provenance" .opencode/skills/stack-init/SKILL.md
rtk grep -n "^[0-9]\. \*\*" .opencode/skills/stack-init/SKILL.md   # steps 1-7, in order
```
**Commit:** `docs(skills): record upstream provenance during stack init`

---

### Task 1.3: stack-modernize — UPSTREAM.md backfill step

**File:** `/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-modernize/SKILL.md`
**Test:** none (docs-only; verify by reading)
**Depends:** none

**Placement decision:** Insert as new **step 2** in `## Procedure`, right
after "Inventory" — the inventory pass already reads the stack, so the
backfill happens with the same context. Renumber existing steps 2–9 → 3–10.

**Edit A — new step 2** (inserted after current step 1 "Inventory"). Exact
content:

````markdown
2. **Upstream provenance backfill:** if `UPSTREAM.md` is missing, create it
   at the stack root per stack-conventions §13 (one section per project
   dir). Recover the current upstream commit where possible — from the
   pinned image tag/digest, the upstream release notes/changelog, or the
   user — otherwise record `unknown` with a note explaining why. NEVER
   invent a hash. Append the first log row (date, commit or `unknown`,
   image tag/digest, note `backfill at modernization`).
````

**Edit B — renumber** the remaining steps: `2. **Rename**` → `3.`,
`3. **Modules**` → `4.`, `4. **Environments**` → `5.`,
`5. **Extensions**` → `6.`, `6. **stackbuilder.toml**` → `7.`,
`7. **Artifacts**` → `8.`, `8. **READMEs**` → `9.`,
`9. **Verify**` → `10.`. No other wording changes.

**Verify:**
```bash
rtk grep -n "Upstream provenance backfill" .opencode/skills/stack-modernize/SKILL.md
rtk grep -n "^[0-9]\. \*\*" .opencode/skills/stack-modernize/SKILL.md   # steps 1-10, in order
```
**Commit:** `docs(skills): backfill UPSTREAM.md during stack modernization`

---

### Task 1.4: stack-test — compat-check rule (pre-pull)

**File:** `/home/archuser/projects/docker-stack-collection/.opencode/skills/stack-test/SKILL.md`
**Test:** none (docs-only; verify by reading)
**Depends:** none

**Placement decision:** New `##` section between `## Hard rules` and
`## Procedure` — it is a gate that runs BEFORE the normal procedure, so it
sits above it. Title: `## Compat check (pre-pull)`.

**Edit — insert after the Hard rules list** (after line 22, before
`## Procedure`). Exact content:

````markdown
## Compat check (pre-pull)

Run this BEFORE the procedure below whenever images may have changed (after
any stack change or image update) — never verify against stale local
images:

1. Pre-pull images first, in the built environment dir:

   ```bash
   cd build/<env>/<combo>/ && docker compose pull
   ```

2. Verify the EXISTING configs still work with the freshly pulled
   containers (health, logs, core functionality), then continue with the
   normal procedure below.
3. If a new container breaks with the old configs: diff the upstream repo
   between the last recorded commit and the new one to identify what
   changed in the configuration surface — `UPSTREAM.md` has both commits;
   use the clone-in-tmp workflow in stack-conventions §13. Fix the configs
   per collection rules, re-verify, then append a new provenance row to
   `UPSTREAM.md` (append-only — never rewrite existing rows).
````

**Verify:**
```bash
rtk grep -n "Compat check (pre-pull)" .opencode/skills/stack-test/SKILL.md
rtk grep -n "docker compose pull" .opencode/skills/stack-test/SKILL.md
```
**Commit:** `docs(skills): add pre-pull compat check to stack testing`

---

## Verification (after all four tasks)

Docs-level dry walkthrough per the design's testing strategy:

```bash
# All four files mention the canonical section
rtk grep -rn "stack-conventions §13" .opencode/skills/
# Canonical section defines format + iron rule + tmp path
rtk grep -n "UPSTREAM.md\|/tmp/opencode/upstreams/\|append" .opencode/skills/stack-conventions/SKILL.md
```

Then simulate the modernize flow mentally against kanidm: the skill text
must unambiguously prescribe clone → record → append → delete. Behavioral
check happens on the next real stack rework: `git diff` on a stack's
`UPSTREAM.md` must show additions only.

## Out of scope

- No changes to agent definitions (`~/.config/opencode/micode.jsonc`),
  `readme-gen`, `kanidm-admin`, `rustfs-admin`, or any `references/` files.
- No `UPSTREAM.md` files created now — they are created by the skills at
  init/modernize time.
