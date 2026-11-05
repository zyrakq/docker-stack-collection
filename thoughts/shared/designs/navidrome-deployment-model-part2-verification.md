# navidrome deployment model — Part 2: source verification & gap checklist

Date: 2026-11-05. Companion to the stack's DEPLOYMENT.md (deployment-model
artifact). Every claim in the model was re-verified line-by-line against the
upstream clone (tag v0.64.2, commit `7c1e68a1`) kept reference-only in
`/tmp/opencode` (Phase 0 exception — do not delete, do not vendor).

## 1. Claim verification (model → clone)

| # | model claim | clone evidence | verdict |
|---|-------------|----------------|---------|
| 1 | Image base `alpine:3.22` with ffmpeg, mpv, curl, sqlite, libwebp | upstream `Dockerfile` final stage: `apk add -U --no-cache curl ffmpeg mpv sqlite libwebp libwebpdemux libwebpmux` | ✅ confirmed |
| 2 | `VOLUME ["/data","/music"]`, env `ND_MUSICFOLDER=/music`, `ND_DATAFOLDER=/data`, `ND_CONFIGFILE=/data/navidrome.toml`, `ND_PORT=4533`, `EXPOSE ${ND_PORT}`, `ENTRYPOINT ["/app/navidrome"]` | Dockerfile: `VOLUME`, `ENV ND_*`, `EXPOSE`, `WORKDIR /app`, `ENTRYPOINT`; plus `touch /.nddockerenv` marker (Docker detection) not mentioned in model — harmless, add nothing | ✅ confirmed |
| 3 | libwebp lineage in gate step 2 "playback-adjacent artwork" | Dockerfile builds the musl binary specifically so native libwebp resolves via dlopen (`verify-binary.sh` fails else); readme not needed — model wording stands | ✅ confirmed |
| 4 | SQLite-only: `db/db.go` driver `mattn/go-sqlite3`, `Dialect = "sqlite3"`, `sql.Open(Driver, Path)` | `db/db.go` L12 import `mattn/go-sqlite3`, L27–28 `Dialect = "sqlite3"`, `Driver = Dialect + "_custom"`, L61 `sql.Open(Driver, Path)`; goose `SetDialect(Dialect)`; no other driver anywhere | ✅ confirmed — database REFUSED justified |
| 5 | ExtAuth surface: `ExtAuth.TrustedSources`, `ExtAuth.UserHeader`, `ExtAuth.LogoutURL` in `server/middlewares.go` | `server/middlewares.go` L173–177: forwarding headers honoured only when peer ∈ `ExtAuth.TrustedSources`; `conf/configuration.go` L114 `ExtAuth extAuthOptions`, L293–295 fields `TrustedSources/UserHeader/LogoutURL`; legacy names remapped (`ReverseProxyWhitelist`→`ExtAuth.TrustedSources`, `ReverseProxyUserHeader`→`ExtAuth.UserHeader`) | ✅ confirmed — OIDC REFUSED justified; extauth-proxy row fields correct |
| 6 | Jukebox: `Jukebox.Enabled` + mpv | `conf/configuration.go` L119 `Jukebox jukeboxOptions`; defaults `mpvpath=""` (PATH-resolved → image's mpv), `mpvcmdtemplate="mpv --audio-device=%d --no-audio-display %f --input-ipc-server=%s"`, `jukebox.devices=[]` | ✅ confirmed; **refines** the container-audio hypothesis: mpv binds a concrete `--audio-device` from `jukebox.devices`; null-sink device definable via config (`ADD` subcommand in jukebox API), no ALSA/Pulse socket needed for a null/experimental sink |
| 7 | LastFM scrobbling config | `conf/configuration.go` L125 `LastFM lastfmOptions` (+ `LastFM.Language/Languages` handling, `Enabled` flag) | ✅ confirmed — catalog row fields correct |
| 8 | ListenBrainz integration | L127 `ListenBrainz listenBrainzOptions`, L812 `Server.ListenBrainz.Enabled` defaulting off | ✅ confirmed |
| 9 | Transcoding engine (embedded ffmpeg) | transcodingOptions struct (MaxConcurrent / MaxConcurrentPerUser / EnableCancellation); `viper.SetDefault("ffmpegpath", "")` → PATH resolution → image-bundled ffmpeg; per-subsonic transcode machinery in `server/subsonic/transcode.go` | ✅ confirmed; model's implicit "config surface is only `Jukebox.Enabled`-style toggles" holds — no enable-transcode flag needed in base compose |
| 10 | Subsonic API surface / gate step 4 `GET /rest/ping` | `server/subsonic/api.go` L108 `h(r, "ping", api.Ping)` | ✅ confirmed |
| 11 | Port 4533 default | Dockerfile `ND_PORT=4533` + EXPOSE | ✅ confirmed |
| 12 | Named volumes `navidrome-music` / `navidrome-data`, no bind mounts | convention-side mapping of the two container paths; no bind-mount requirement anywhere upstream | ✅ confirmed |

No model claim was falsified. One refinement (hypothesis #6) feeds back into
the model's open-hypotheses list.

## 2. Missing functional-base pieces (to close next, in order)

Functional base = product part + volumes only (db/OIDC/S3 refused). The gate
is achievable with the published image once these files exist:

1. **Stack scaffold** — the stack repo currently has only `DEPLOYMENT.md`
   and `UPSTREAM.md`. Needed (stack-conventions layout):
   - `app/components/base/docker-compose.yml` — service `navidrome`
     (container_name equal), network `navidrome-network`, volumes
     `navidrome-music:rw` (mounted `/music`) and `navidrome-data:rw`
     (mounted `/data`), port mapping from `${NAVINDROME_PORT:-4533}`-style
     `${VAR:-}`-overridable var; image
     `ghcr.io/navidrome/navidrome:${NAVIDROME_TAG-V0.64.2-style var}`; no
     `build:` section; no hardcoded values.
   - `stackbuilder.toml` at stack root (yaml_merger must NOT be "rust").
   - `.gitignore` (`.env`, runtime junk), `.vscode/settings.json`,
     `README.md`, `LICENSE-APACHE`/`LICENSE-MIT` as applicable, `.gitmodules`
     only if ssl-automation submodules are actually wired (defer until vhost
     exposure is requested).
   - `.env.example` — only vars the compose files reference.
   - Directories containing only directories get `.gitkeep` per repo rule.
2. **Environment overlays** — base declares nothing URL-derived; vhost/
   TLS-derived defaults go to an environment overlay, not the base compose.
   Native `ND_*` envs are NOT environment-dependent: ND_MODE-style vars
   belong in base only if overridable with `${VAR:-}`.
3. **music-seed extension (required-for-gate)** — needs a small fixture set
   of audio files (few MP3/FLAC with embedded ID3/Vorbis tags + cover art)
   placed in the `navidrome-music` named volume at first start. Implementation
   still requires user confirmation before building; the DEPLOYMENT.md gate
   reads: without seed files, first-run admin creation succeeds but scan
   finds an empty library and gate step 2 (album browse) cannot pass.
4. **Base vs extension env split** —
   - base: port, image tag, TZ-ish app envs — all `${VAR:-default}`.
   - extauth-proxy fragment: `ND_EXTAUTHTRUSTEDSOURCES`,
     `ND_EXTAUTHUSERHEADER`, `ND_EXTAUTHLOGOUTURL` — only in the extension
     fragment (optional vars live in extension fragments only).
   - lastfm fragment: LastFM API key/secret vars; listenbrainz fragment:
     ListenBrainz base/token vars.
   - s3fs-fuse-music fragment: mounts `navidrome-music` via FUSE into the
     navidrome container — never applied to a DB volume (none exists here;
     data stays SQLite in `navidrome-data`).
5. **Stage A test gate** — single stage; scenario exactly as in
   DEPLOYMENT.md §Base stage plan (first-run admin → scan → album play →
   `rest/ping`). No step-ca-trust link for the functional base; SSL joins
   later through the standard letsencrypt/step-ca environments when vhost
   exposure is requested.

## 3. Verdict

DEPLOYMENT.md is source-accurate. No edits required. Next concrete action
(when user confirms): scaffold the stack per §2.1 and implement music-seed,
then run the Stage A gate.
