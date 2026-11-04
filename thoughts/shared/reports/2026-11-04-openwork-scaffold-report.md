# openwork Stack — Base Scaffold Report

**Plan:** `thoughts/shared/plans/openwork-scaffold.md`
**Stack repo:** `stacks/self-hosting/ai-services/automation/openwork` (master)
**Date:** 2026-11-04
**Result:** Batches 1–3 complete; Stage A smoke PASSED; stack torn down with named volumes retained for the real `stack-test` gate run.

## Batch 1 — Foundation

| Task | Status | Commit(s) | Notes |
|------|--------|-----------|-------|
| 1.1 Repo hygiene mirror | ✅ | `251ac25` | ssl-automation submodules + hygiene files |
| 1.2 stackbuilder.toml | ✅ | `4251121` | later amended in `e8b4c3b` (see deviation D2) |
| 1.3 .gitignore | ✅ | `251ac25` | committed together with 1.1 |
| 1.4 openwork-host image | ✅ | `b07dde8` + fix `2643707` | fix: dropped stale plugin-dir assertion from CMD (deviation D4) |
| 1.5 openwork-web image | ✅ | `6ecf2d8` | |

## Batch 2 — Base, overlays, extension fragments

| Task | Status | Commit | Notes |
|------|--------|--------|-------|
| 2.1 Base compose | ✅ | `3ae5eb6` | volumes `openwork-data`/`openwork-workspace` (name:), healthcheck curl `/health` |
| 2.2 Base .env.example | ✅ | `613ee78` | |
| 2.3 Forwarding overlay | ✅ | `9e06eba` | |
| 2.4 Forwarding .env.example | ✅ | `43eebd4` | |
| 2.5 Letsencrypt overlay | ✅ | `dbd1e49` | |
| 2.6 Letsencrypt .env.example | ✅ | `14b4732` | |
| 2.7 Step-ca overlay | ✅ | `df914d5` | |
| 2.8 Step-ca .env.example | ✅ | `0e2e109` | |
| 2.9 model-keys fragment | ✅ | `ca4d0f2` | |
| 2.10 model-keys .env.example | ✅ | `eae853b` | |
| 2.11 repo-sync fragment | ✅ | `bb16ee5` + fix `76bdd9c` | verbatim-from-sibling (D3); fix added missing x-logging anchor |
| 2.12 repo-sync .env.example | ✅ | `39cb9fb` | |
| 2.13 repo-local fragment | ✅ | `8f16685` | |
| 2.14 repo-local .env.example | ✅ | `ad2c741` | |
| 2.15 step-ca-trust fragment | ✅ | `0dcfdd2` | |
| 2.16 step-ca-trust .env.example | ✅ | `fb5c0ed` | |

Plus `e15dcb3`/`9f65c58`: .gitkeep placeholders for component dirs.

## Batch 3 — Docs + integration verification

| Task | Status | Commit(s) | Notes |
|------|--------|-----------|-------|
| 3.1 app README | ✅ | `b675ae9` + `12e1b6e` | second commit appended the catalog-status paragraph (D1) |
| 3.2 Root README | ✅ | `c585a1b` | message says `(3.2)` without `Task` prefix — minor format slip |
| 3.3 Integration verification | ✅ | `e8b4c3b` | build outputs + `yaml_merger = "rust"` sb fix (D2); smoke below |

## Stage A smoke results (all PASS)

- `sb build` succeeds; per-env `docker compose config -q` passes for forwarding / letsencrypt / step-ca.
- Stack up: `openwork`, `openwork-web` healthy; `openwork-stack-repo-sync` running.
- `GET /health` → 200 unauthenticated; UI `:8080/` → 200.
- Token positive: `GET /whoami` + `Authorization: Bearer $OPENWORK_TOKEN` → 200 `{"ok":true,"actor":{"type":"remote",...,"scope":"collaborator"}}`.
- Token negative: wrong token and missing token → 401 `Invalid bearer token`.
- Persistence: marker `/workspace/smoke-project/marker.txt` survived `docker compose restart`; `/whoami` 200 after restart.
- Teardown: `docker compose down` removes containers + `openwork-network`, keeps BOTH named volumes (empirically re-verified with an up→down cycle).

## Deviations

- **D1 — 3.1 committed twice:** `b675ae9` added the app README; `12e1b6e` appended the catalog-status paragraph as a follow-up edit instead of amending.
- **D2 — 3.3 scope creep:** `e8b4c3b` (build outputs) also carries the stackbuilder `yaml_merger = "rust"` fix required to make `sb build` pass on this host.
- **D3 — repo-sync verbatim exception:** sidecar script copied verbatim from the sibling opencode stack per plan binding; it initially lacked the x-logging anchor, fixed in `76bdd9c`.
- **D4 — extra fix commit:** `2643707` dropped a stale plugin-dir assertion from the openwork-host image CMD discovered during 1.4 verification.
- **External event (not a deviation):** during smoke, all containers vanished and both volumes were deleted/recreated by an external cause (likely a parallel agent); persistence test was redone cleanly and passed. Recorded as investigated, not stack behavior.

## Pitfalls

- **P-035** recorded: openwork-server routes are UNPREFIXED (`/whoami`, `/status`, `/capabilities`, `/tokens`, `/workspace/:id/...`); `/api/*` probes all 404 (fail-closed). Auth is strictly `Authorization: Bearer $OPENWORK_TOKEN`; the startup `Host token: <uuid>` line / `X-OpenWork-Host-Token` header are a separate ephemeral mechanism, not usable for client HTTP auth.

## End state

- Stack repo clean, all work committed.
- Smoke containers and `openwork-network` removed; named volumes `openwork-data` and `openwork-workspace` retained for the real `stack-test` Stage A run.
- `build/forwarding/.env` (gitignored) holds the throwaway smoke values (`OPENWORK_TOKEN=test`, TLS vars).
