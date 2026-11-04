# STASKBUILDER — stackbuilder improvement ledger

Living ledger of improvement proposals for sb/stackbuilder (source:
`/home/archuser/projects/tools/stackbuilder/`). The skills under
`.opencode/skills/` are the single source of truth for stack conventions;
when a skill's assumption breaks (new sb version, changed layout), update
the skill AND record it here.

Status legend: `proposal` → `accepted` → `implemented` / `rejected`.

## Limitations

### L1. No cartesian product matrix — `proposal`
Variants render independently; cross-products must be hand-enumerated as
named `combos`. Combos cannot nest, parameterize, or carry env-var
overrides. Workaround: hand-written combos (easytier idiom).

### L2. No per-variant variable values — `proposal`
An environment/combo cannot set variable values used only in that variant.

### L3. Global `extensions` silently ignored with `[build.environments]` — `proposal`
When the dual environments API is used, top-level `[build] extensions` is
silently dropped instead of erroring or merging.

### L4. Opaque version-sensitive layout heuristics — `proposal`
`num_envs` / `total_variants` style layout detection is version-sensitive
and hard to predict from user code.

### L5. `.env.example` merge is concatenation, not unification — `proposal`
Duplicate keys are not unified; ordering is concatenation order.

### L6. YAML arrays are append-only — `proposal`
Cannot remove or replace base ports/volumes from an environment/extension;
only appends.

### L7. Only the literal filename `docker-compose.yml` is merged — `proposal`
Multi-file compose layering is outside the tool (COMPOSE_FILE escape hatch).

### L8. No `--config` / `--select` / `--dry-run` / `--output` — `proposal`
Config path is hardcoded to `./stackbuilder.toml`; no partial builds, no
preview, no custom output dir.

### L9. Unknown TOML keys silently ignored — `proposal`
Typo'd keys (e.g. an invalid `environments_path` seen in real stacks) are
swallowed without warning.

### L10. External `yq` required by default — `proposal`
Build fails confusingly when `yq` is missing.

### L11. Soft validation — `proposal`
A typo'd extension name degrades output silently instead of failing.

### L12. `.env` restore is exact-path only — `proposal`
No globbing/fallback when restoring `.env` files into regenerated dirs.

### L13. `sb init` does not understand the new environments API — `proposal`
Init scaffolds the old shape; new stacks need hand-written
`[build.environments]` config.

### L14. Script-style features can't be combined as extensions — `proposal`
Features needing scripts/entrypoint hooks cannot be modeled as combinable
extensions. Agents hacked them in as separate non-combinable extensions,
producing combos like `forwarding-repo-sync-X`.

## Interim workarounds (within current capabilities)

- **Optional `plugins/` dir** (one example idea for L14, not mandated) —
  `plugins/` next to `docker-compose.yml` (absent by default, git-ignored),
  a committed `plugins-available/` dir, `dockerfile_inline` COPYs from
  `plugins/`, and the base image's `entrypoint.sh` picks the scripts up.
- **Hand-written combos** — enumerate cross-products as named combos
  (easytier idiom).
- **`env_file_patterns`** — preserve app-native config files across builds
  (numa idiom: `[".env", "numa.toml"]`; kanidm: `[".env", "override.css"]`).
- **`COMPOSE_FILE` layering** — escape hatch for multi-file compose needs.
