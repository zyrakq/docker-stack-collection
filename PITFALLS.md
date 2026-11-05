# PITFALLS — журнал повторяющихся граблей

Общий для всех стеков коллекции. Сюда записываются препятствия, возникающие
при подготовке конфигов развертывания, работе со stackbuilder (`sb`),
docker compose, OIDC/S3/step-ca интеграцией и тестировании стеков.

Проблемы здесь часто общие между проектами, поэтому журнал один и лежит
в корне коллекции. Счетчик `hits` показывает, насколько часто проблема
встречается, даже если она ещё не исправлена — большой `hits` при
`status: open` означает: пора чинить, а не обходить.

## Lookup (как найти файл из любой папки)

1. Идти вверх от текущей рабочей директории, пока не найдётся `PITFALLS.md`.
2. Если не найден (например, стек клонирован вне коллекции) — использовать
   канонический путь:
   `/home/archuser/projects/docker-stack-collection/PITFALLS.md`.

## Формат записи

    ## P-NNN: <заголовок: EN-ключевые слова + краткое RU описание>
    - hits: N | status: open | first: ГГГГ-ММ-ДД | last: ГГГГ-ММ-ДД
    - where: <sb / compose / step-ca / oidc / s3 / тестирование ...>
    - symptom: <как проявляется>
    - cause: <причина, если известна>
    - workaround: <обход, если есть>
    - fix: <как исправлено; "—" пока не исправлено>

Статусы: `open` (не решено) / `mitigated` (обход работает, проблема осталась) /
`fixed` (устранено, запись остаётся как справочник).

## Протокол обновления

- **Новое препятствие** → новая запись: `hits: 1`, `status: open`.
- **Уже записанное** → `hits +1`, обновить `last`; дополнить
  `symptom`/`workaround`, если появились новые детали.
- Перед добавлением искать по ключевым словам (grep по файлу), чтобы не
  плодить дубли похожих записей.
- **Исправлено** → `status: fixed` + заполнить `fix`. Записи НЕ удаляются.
- Не оставлять столкнутое препятствие незаписанным в конце сессии.

Записи добавляются в конец файла, ID — сквозные (P-001, P-002, ...).

---

## P-001: root-level search blind inside stacks/
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: поиск/навигация по коду
- cause: `stacks/` в .gitignore коллекции, каждый стек — отдельный git-репозиторий;
  glob/grep из корня коллекции ничего не видит внутри stacks/
- fix: правило зафиксировано в stack-conventions §16 — всегда указывать
  конкретный путь стека, например `stacks/devops/identity-management/kanidm/...`

## P-002: stackbuilder no cartesian environment matrix
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: sb build / stackbuilder.toml
- symptom: нельзя автоматически сгенерировать матрицу окружение × расширение
- workaround: hand-written именованные `combos` (easytier idiom); ограничения
  sb tracked в `STASKBUILDER.md`
- fix: —

## P-003: session cwd in stack subfolder — hub files unreachable
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: любая работа из субпапок стеков
- symptom: AGENTS.md коллекции и корневые файлы (PITFALLS.md, STASKBUILDER.md)
  могут не подгружаться / быть недоступны по относительным путям, когда сессия
  работает изнутри отдельного git-репозитория стека
- workaround: lookup-правило в шапке этого файла (идти вверх от cwd →
  канонический абсолютный путь); правило продублировано в AGENTS.md и
  stack-conventions
- fix: —

## P-004: vendoring upstream source into stack repo (submodule proposal)
- hits: 2 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: дизайн/план стеков без опубликованных Docker-образов (vibe-kanban и
  предыдущая попытка)
- symptom: агент предлагает втащить исходники upstream-приложения в репозиторий
  deployment-конфигов как git-подмодуль (`modules/<app>`) или копию исходников;
  пользователь отклонил дважды
- workaround: исходники не вендорим никогда; tmp-клон из clone-in-tmp —
  reference-only; сборка из исходников оформляется self-contained
  `app/images/<image>/Dockerfile` (ARG GIT_REPO/GIT_TAG или релизный архив),
  compose ссылается на готовый образ через `${IMAGE:-localhost/<image>:<tag>}`
- fix: правило зафиксировано в stack-conventions §19, скилл `source-image`,
  шаги в stack-init/stack-modernize, секция в AGENTS.md

## P-005: stackbuilder source does not compile (missing import)
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-10-31
- where: sb / tools/stackbuilder
- symptom: `cargo build --release` в tools/stackbuilder падает E0425/E0433 —
  `BTreeMap` не найден в src/env_merger.rs
- cause: в репозитории stackbuilder отсутствует `use std::collections::BTreeMap;`
- fix: добавлен импорт в src/env_merger.rs; бинарник называется `stackbuilder`,
  а не `sb` — симлинк `~/.local/bin/sb -> target/release/stackbuilder`

## P-006: sb build requires external yq by default
- hits: 1 | status: fixed | first: 2026-10-31 | last: 2026-11-04
- where: sb build
- symptom: `sb build` падает "yq is required but not available" на хостах без
  системного yq
- workaround: `yaml_merger = "rust"` в `[build]` секции stackbuilder.toml
  (встроенный Rust-мерджер); также зафиксировано в STASKBUILDER.md (L10)
- fix: `yaml_merger = "rust"` удалён из stackbuilder.toml opencode-stack
  (commit 19d10e0) — sb build снова использует внешний yq; на хосте
  используется бинарник mikefarah yq v4.44.3 в /tmp/opencode/bin (PATH
  prepended), т.к. системный /usr/bin/yq — python jq-wrapper (kislyuk,
  `yq 4.4.5 / jq-1.8.2`), который sb отвергает (см. P-033)

## P-007: upstream release tag does not compile — build from fixed commit
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: source-built images / vibe-kanban
- symptom: сборка из релизного tarball тега v0.1.45-20260919085201 падает:
  remote-web TS2339 — `getMatchedRoutes` деструктурируется как объект, а
  lockfile-версия router-core (1.171.32) возвращает tuple; исправлено в 3
  коммитах сразу после тега
- workaround: в self-contained Dockerfile клонировать upstream на pinned
  commit (ARG GIT_COMMIT=7c380708...) вместо релизного tarball; UPSTREAM.md
  и так записывает коммит, а не тег
- fix: —

## P-008: mass convention violations on stack creation (naming/env/db/staged)
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: создание стеков / правила коллекции (vibe-kanban)
- symptom: при создании vibe-kanban нарушены 8 классов правил разом:
  объявлен ни разу не используемый `PROJECT_NAME`; postgres как обычный
  сервис в base-compose (без extensions/, без pgrust-альтернативы, версия
  `postgres:16-alpine` скопирована из upstream, узкий маунт
  `/var/lib/postgresql/data`); имена сервисов не совпадают с
  container_name и не несут префикса проекта (`remote-server`,
  `vk-remote-server`, `electric`); захардкоженные env-литералы в compose
  (`RUST_LOG`, `SERVER_LISTEN_ADDR`, `ELECTRIC_URL`, `POSTGRES_DB/USER`);
  мёртвые переменные в `.env.example`; всё навернуто сразу без
  тест-гейтов (19 коммитов, ни одного тестового); `SERVER_PUBLIC_BASE_URL`
  объявлен в base и переопределён с другими дефолтами в letsencrypt/
  step-ca оверлеях; 24+ ссылок на пути `stacks/` в скиллах
- cause: правила пользователя не были кодифицированы в stack-conventions
  (DB-as-extension с pgrust, `${VAR:-}` везде, префиксные имена,
  поэтапный протокол с гейтами, layering); два старых правила были прямо
  вредны (старый §3 предпочитал `${PROJECT_NAME:-<svc>}`-нейминг, старый
  §9 требовал ключ `PROJECT_NAME` в `.env.example`)
- workaround: —
- fix: stack-conventions переструктурирован в §1–§19 (naming, env wiring,
  DB-as-extension, staged protocol, layering); iron rules добавлены в
  AGENTS.md; скиллы self-contained (паттерны встроены, атрибуция только
  по имени стека); поэтапный протокол с тест-гейтами вписан в
  stack-init/stack-test

## P-009: agent modifies host system during image build (swap/loop devices)
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: сборка образов / поведение агентов (host safety)
- symptom: при сборке образа агент решил, что не хватает swap, и молча
  выполнил `sudo -n sh -c 'losetup -d /dev/loop0 ...; mknod /dev/loop1 b 7 1;
  losetup /dev/loop1 /swapfile; mkswap /dev/loop1; swapon /dev/loop1'` —
  чуть не сломал сервер (манипуляции с блочными устройствами и swap хоста)
- cause: allowlist допустимых действий агента не был прописан явно; при
  нехватке памяти на сборке агент импровизировал "лечение" хоста вместо
  остановки и репорта
- workaround: —
- fix: iron rules «Host safety» добавлены первой секцией в AGENTS.md —
  полный allowlist (файлы, git, docker/compose, скиллы oidc/s3, read-only
  инспекция) и запрет sudo/swap/losetup/mknod/пакетных менеджеров/sysctl/
  systemd/дисков; при нехватке ресурсов — стоп и репорт пользователю,
  хост не трогать

## P-010: sb auto-generates a no-extension base variant per environment
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-04
- where: stackbuilder (`sb build`) — per-env combos
- symptom: при `combos = [...]` на окружение sb генерирует не только
  `build/<env>/<combo>/`, но и дополнительный вариант
  `build/<env>/base/` (base+env без расширений) — «Generated 9 build
  combinations» вместо ожидаемых 6; для стека, где БД обязательна
  (app требует Postgres), этот вариант нерабочий и является footgun'ом
- cause: sb всегда добавляет plain-вариант окружения без расширений,
  если не установлен `skip_base_generation = true` (у linkwarden это
  незаметно, потому что их комбо само называется `base` и пишет в тот
  же каталог)
- workaround: —
- fix: `skip_base_generation = true` в `[build]` stackbuilder.toml —
  дерево становится ровно `build/<env>/<combo>/` по списку combos;
  подтверждено в opencode-stack rework: ровно один комбо на окружение
  (`entire` / `entire-trust`), комбинации расширений схлопнуты

## P-011: upstream migration hardcodes database name `remote`
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
- where: vibe-kanban stack — remote-server Postgres migrations
- symptom: приложение падает/не стартует, если БД названа иначе
  (`POSTGRES_DB` != `remote`); миграция не может выдать `GRANT
  CONNECT` несуществующей БД
- cause: миграция `crates/remote/migrations/
  20251127000000_electric_support.sql` жёстко выполняет
  `GRANT CONNECT ON DATABASE remote TO electric_sync;` — имя БД
  зашито в исходник (проверено на pinned commit `7c380708`),
  конфигурируемой переменной нет; патчить апстрим запрещено
- workaround: —
- fix: держать `POSTGRES_DB=remote` в `.env.example`/overlay стека
  (имя одобрено пользователем); зафиксировано коммитом
  "Fix database name for remote server" в репозитории стека

## P-012: automated-browser session loss in remote-web (agent-browser)
- hits: 3 | status: open | first: 2026-11-01 | last: 2026-11-01
- where: vibe-kanban remote-web SPA — browser E2E через agent-browser
- symptom: в автоматизированном браузере SPA произвольно отбрасывает
  сессию на страницу sign-in при hard-навигациях/перезагрузках
  страницы; в обычном браузере (проверено пользователем) всё стабильно
- cause: не баг стека. remote-web хранит JWT-пару в IndexedDB
  (`rf-auth`, store `tokens`, ключи `access_token`/`refresh_token`;
  `packages/remote-web/src/shared/lib/auth.ts`); access-token живёт
  120 c, tokenManager автообновляет каждые ~80 c
  (`POST /v1/tokens/refresh`); токены гидрируются из IndexedDB только
  при загрузке документа, а при некоторых reload/сбоях refresh в
  agent-browser сессия теряется
- workaround: —
- fix: E2E вести одним документом без лишних hard-навигаций; логин —
  in-page `fetch POST /v1/auth/local/login` {email,password} → положить
  оба токена в IndexedDB → reload → SPA гидратит сессию
  (redirect `/account?next=%2F` → `/`); скриншот снимать сразу после
  re-seed; событие `remote-auth-changed` состояние реактивно не
  переключает

## P-013: sb build deletes build/**/.gitkeep; old container/volume leftovers conflict
- hits: 2 | status: open | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban app/remote after app/→app/remote/ move and service rename
- symptom: `sb build` removes tracked `build/**/.gitkeep`; `compose up` fails
  on container_name conflict with old `vibe-kanban*` test containers; kept
  old volumes hold the old DB password
- fix: restore .gitkeep via `git ls-files -d | xargs touch`; remove only our
  old containers; reuse old secrets from the old build/.env

## P-014: relay image build fails with `cargo build --locked` (relay-tunnel excluded from workspace)
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban app/relay/images/vibe-kanban-relay Dockerfile
- symptom: `cargo build --locked` fails "cannot update the lock file ... because --locked was passed"; crates/relay-tunnel is in workspace `exclude` and its own Cargo.lock needs updating
- fix: drop `--locked`; limit parallelism with CARGO_BUILD_JOBS=2

## P-015: wildcard cert impossible via http-01 on step-ca
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban relay, `LETSENCRYPT_HOST` containing `*.relay.<domain>`
- symptom: companion logs `Cannot get domain token entry *.relay.<domain> for http-01`; no cert issued
- fix: `LETSENCRYPT_HOST` = apex only; keep wildcard in `VIRTUAL_HOST` for routing; wildcard cert needs DNS-01

## P-016: source Dockerfile missing patches/ before `pnpm install --frozen-lockfile`
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban host image
- symptom: `ENOENT ... /app/patches/@pierre__diffs@1.1.4.patch`
- fix: `COPY --from=source /repo/patches/ patches/` before install

## P-017: cross-group access to a DB published on 127.0.0.1 fails via host.docker.internal
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban relay -> remote DB
- symptom: relay cannot connect to the DB
- fix: remote `DB_PUBLISH_ADDR=0.0.0.0` (test) — restrict by firewall in production

## P-018: rustls-based app rejects step-ca certs (UnknownIssuer)
- hits: 1 | status: fixed | first: 2026-11-02 | last: 2026-11-02
- where: vibe-kanban host -> remote (`/api/auth/local/login` 502)
- symptom: `failed to verify TLS certificate: UnknownIssuer`
- fix: mount step-ca root_ca.crt, set `SSL_CERT_FILE`; file must be readable by uid 10001 (mode 644) or the app panics "No CA certificates were loaded"
- fix (final): vibe-kanban host `step-ca-trust` extension: root user entrypoint wrapper builds system bundle + step-ca root (chmod 644), sets SSL_CERT_FILE and HOME=/home/appuser (else PermissionDenied), drops to uid 10001 via setpriv; CA from external volume `step-ca-data` with `subpath: certs`

## P-019: Stage D pairing E2E cannot run self-paired / headless
- hits: 1 | status: open | first: 2026-11-03 | last: 2026-11-03
- where: vibe-kanban Stage D gate
- symptom: `client/pair` lives on the host server, release build forbids pairing to itself; in-app browser disconnected, no agent-browser CLI
- fix: needs second host machine + attached desktop browser + remote web credentials; rerun Batch 8 manually

## P-020: repo-local bind mount not writable by uid 10001
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: vibe-kanban host `repo-local` extension (`REPOS_PATH`)
- symptom: host container (uid 10001) cannot write into the bind-mounted repo
- fix: host-side permissions are the user's job (chown/ACL, or `chmod -R a+rwX` for tests); stack never changes them

## P-021: `docker compose down` in one host variant dir removes the shared network
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: vibe-kanban host variants (repo-sync / repo-local share project `vibe-kanban-host`)
- symptom: `vibe-kanban-host-network` disappears for other containers
- fix: `up -d` of the next variant recreates it; run down before switching variants

## P-022: ghcr tags for opencode have no `v` prefix
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack (image refs in compose/.env.example/docs)
- symptom: `ghcr.io/anomalyco/opencode:v2.2.5` pull fails manifest unknown
- fix: tag is `ghcr.io/anomalyco/opencode:2.2.5` (upstream release tag is `v2.2.5`, ghcr tag drops the `v`)

## P-023: compose `up` skips dockerfile_inline build when image tag exists
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack base compose (dockerfile_inline FROM-layer)
- symptom: after changing the FROM-layer, `docker compose up -d` reuses the stale local image; config changes never land
- fix: run `docker compose up -d --build` (or `docker compose build` first); `down` does not remove the built image

## P-024: exported shell env var silently overrides compose .env
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack gate runs (OPENCODE_SERVER_PASSWORD)
- symptom: container gets a stale/empty password from the agent's shell env instead of the value in `app/build/forwarding/.env`; auth gate behaves inconsistently
- fix: always run compose as `env -u OPENCODE_SERVER_PASSWORD docker compose ...` from the forwarding dir

## P-026: raw-curl GHCR manifest probes give misleading 404 — use `docker manifest inspect`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Phase 0 (ghcr.io/bndct-devops/tome tag probe)
- symptom: tokens + Accept-header curls against `https://ghcr.io/v2/.../manifests/<tag>` returned 404/`MANIFEST_UNKNOWN` (with contradictory "OCI index found" bodies) for tags that actually exist; `docker manifest inspect` proves truth. Also ghcr tags may drop the `v` prefix (cf. P-022): tome ships `2.8.0`, not `v2.8.0`
- fix: verify registry tags only via `docker manifest inspect <repo>:<tag>` / `docker buildx imagetools inspect`; treat curl probes as unreliable for GHCR

## P-025: opencode server rejects `?auth_token=` — Basic header only
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack healthcheck + all gate curl calls
- symptom: `GET ...?auth_token=<password>` returns 401 even with the correct password
- fix: HTTP Basic only: `-u opencode:<password>` / `Authorization: Basic base64(opencode:<password>)`

## P-026: opencode legacy auth.json import migration does not import credentials
- hits: 1 | status: open | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack data volume (`/data/opencode/auth.json` + opencode.db), upstream migration `20260805200742_import_legacy_credentials`
- symptom: fresh db created with auth.json already present still has an empty credential table; `opencode auth list` shows nothing; model calls fail `provider.no-route`
- fix (workaround): `POST /api/credential` `{"integrationID":"openrouter","label":"API key","value":{"type":"key","key":"<key>"},"activate":true}`; root cause of the skipped import unresolved

## P-027: opencode model IDs use dots, not the release-style dashes
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack gate session model selection
- symptom: session with model `anthropic/claude-haiku-4-5` fails `provider.no-route` even though the provider is available
- fix: catalog ID is `anthropic/claude-haiku-4.5` — always pick IDs from `GET /api/model`, never guess from release tags

## P-028: compose interpolates every `$var` inside dockerfile_inline at config time
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (dockerfile_inline RUN loop)
- symptom: `for s in ...; do sh "$s"; done` in dockerfile_inline — compose warns `The "s" variable is not set` and bakes an empty string into the layer
- fix: escape shell vars in dockerfile_inline as `$$var` (same rule as healthchecks); only `${VAR:-}` forms are meant for compose interpolation; в opencode rework dockerfile_inline RUN-цикл удалён полностью — скрипты установки коммичены в `app/plugins/` и COPY-ятся в образ (`COPY entrypoint.sh plugins* /opt/plugins-build/` терпит отсутствие папки plugins)

## P-029: pip dependency-group installs abort all-or-nothing on py3.14 (Alpine 3.24)
- hits: 1 | status: open | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (headroom install in the image build)
- symptom: installing headroom-ai's full dependency set in one `pip install` fails wholesale when any single package lacks a py3.14 musl wheel (magika has none; ast-grep-cli ships gnu-only wheels)
- fix (workaround): install the CLI `--no-deps`, then stage deps: one core group, then the rest one at a time; magika is safe to drop (lazy import inside try/except), ast-grep absence only degrades a fallback

## P-030: rtk `init` is global-only for OpenCode plugins
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (rtk install script)
- symptom: `rtk init --opencode` errors "OpenCode plugin is global-only"; `rtk hook opencode` alone is just the stdin hook processor and generates nothing
- fix: run `rtk init -g --opencode` (non-interactive defaults to "N" for the settings.json prompt — harmless), then copy the generated `/root/.config/opencode/plugins/rtk.ts` to the baked plugin dir

## P-031: opencode image has no `openssl`; busybox `ssl_client` is helper-only
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack step-ca-trust gate (TLS verification inside `opencode-stack-app`)
- symptom: `openssl` not found in the app container (Alpine 3.24.3 base); busybox `ssl_client` rejects `-connect`/`-servername` (usage: `ssl_client [-s FD] [-I] -n SNI` — it is a helper applet invoked by wget, not a standalone client); in-container fingerprint greps print vacuous output (empty fingerprints match everything)
- fix: run a throwaway `docker run --rm --network <net> alpine:3.20` container and `apk add -q openssl` there for all TLS chain checks (each `docker run` is fresh — re-install every time); verify trust by contrasting `openssl s_client -CAfile` with/without the root: untrusted gives "unable to get local issuer", trusted-but-expired gives only "certificate has expired"

## P-032: `sb build` wipes the build-dir `plugins/` folder
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: opencode-stack plugins extension (user-supplied `plugins/` folder next to the generated `docker-compose.yml`)
- symptom: after copying ready-made install scripts from `app/plugins/` into `build/<env>/plugins/` and setting `PLUGINS_*` toggles, a later `sb build` regenerates the build dir and silently removes the copied `plugins/` folder; the next `docker compose build` runs with no install scripts and the plugins mechanism stays inert
- fix (workaround): re-copy the scripts from `app/plugins/` after every `sb build` (documented in `app/plugins/README.md` and `app/README.md`); root cause is sb's build-dir regeneration, not yet addressed in sb itself
- fix: plugins redesigned as a pure base feature (commit 02e1517): install scripts moved to `app/components/base/plugins/`, and sb's copier walks the entire base component dir recursively, so `sb build` now auto-copies `plugins/` into every build dir — nothing to re-copy; the plugins extension and the manual copy step are gone

## P-033: системный yq — это python jq-wrapper, sb его отвергает
- hits: 2 | status: mitigated | first: 2026-11-04 | last: 2026-11-05
- where: sb build / host tooling (opencode-stack, navidrome stack)
- symptom: системный `/usr/bin/yq` — это kislyuk python-обёртка над jq
  (`yq 4.4.5 / jq-1.8.2`), а не mikefarah yq; sb отвергает его как
  несовместимую реализацию и сборка падает
- workaround: бинарник mikefarah yq v4.44.3 в /tmp/opencode/bin, PATH
  prepended; проверка — `yq --version` должен показывать mikefarah v4.x
- fix: —

## P-034: bun install без python/make/g++ ломает node-gyp нативные модули
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: source-built images (aionui stack, Dockerfile build stage)
- symptom: `bun install` падает на install-скрипте `better-sqlite3`:
  `gyp ERR! find Python` → `error: install script from "better-sqlite3"
  exited with 1`; bun-образ не содержит python3 и C-тулчейн, а нативные
  модули собираются node-gyp на этапе install
- cause: node-gyp требует python3 + make + g++; slim/bun базовые образы их
  не несут
- fix: добавить `python3 make g++` в apt-get install build-стадии
  Dockerfile (aionui, commit `fix(images): correct build for gate`); для
  любых source-built образов на bun/node с нативными зависимостями —
  сразу закладывать тулчейн в build-стадию


## P-035: openwork-server routes are UNPREFIXED — /api/* probes all 404
- hits: 1 | status: fixed | first: 2026-11-04 | last: 2026-11-04
- where: openwork-stack smoke / token checks (openwork-server 0.18.4)
- symptom: token positive/negative checks against `http://localhost:8787/api/info`, `/api/health`, `/api/config` etc. all return 404 with and without `Authorization: Bearer` — looks like auth is broken; the `/api/*` strings in the UI bundle and binary are client-side/mounted-elsewhere, not server routes
- cause: server routes are registered at the ROOT (`/health`, `/status`, `/whoami`, `/capabilities`, `/workspaces`, `/tokens`, `/w/:id/...`) via `addRoute` in `apps/server/src/routes/core.ts`; there is no `/api` prefix on the server
- fix: probe `GET /status` or `/whoami` with `Authorization: Bearer $OPENWORK_TOKEN` — 200 with correct token, 401 without/wrong; `/health` is the unauthenticated healthcheck
- note: строка `Host token: <uuid>` в логах старта и CORS-заголовок
  `X-OpenWork-Host-Token` — ОТДЕЛЬНЫЙ механизм (host-token auth для
  `/tokens` и т.п.), эфемерный на каждый запуск; с ним `Authorization:
  Bearer <uuid>` даёт 401 `Invalid bearer token`. Для HTTP-аутентификации
  клиента использовать только `Bearer $OPENWORK_TOKEN`


## P-036: sb build for openwork stack must run from app/, not stack root
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack (`stacks/self-hosting/ai-services/automation/openwork`) — `sb build`
- symptom: `sb build` from the stack root fails (no project found); cost one failed run
- cause: `stackbuilder.toml` lives in `app/`, not the stack root, for this stack
- fix: run `sb build` from the stack's `app/` directory always; check where `stackbuilder.toml` sits before assuming cwd


## P-037: openwork-server `POST /workspaces` → 404 — workspace creation is UI-driven
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork-stack smoke tests (openwork-server 0.18.4)
- symptom: `POST /workspaces` returns 404 (route not found) even with valid token
- cause: `GET /workspaces` (listing) exists, but workspace CREATION has no HTTP API route — it is done through the web UI, not the API
- fix: for key-free smoke, verify `GET /workspaces` returns 200 (listing); create data via the UI or rely on pre-seeded SQLite state, never attempt API-based workspace creation

## P-038: sb build does not restore .env for newly added environments
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — added environment `forwarding-review` to stackbuilder.toml
- symptom: after `sb build`, `build/<new-env>/` contains only docker-compose.yml + .env.example; no `.env` restored (existing envs got theirs)
- cause: sb preserves/restores `.env` only for environments that already had one before the build; a brand-new environment starts without one
- fix: copy the generated `build/<new-env>/.env.example` to `.env` manually and fill gate values (OPENWORK_TOKEN, REPO_SYNC_URL, etc.) before `docker compose up`

## P-039: openwork apps/server has zero OTel instrumentation at pin ae67215d
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — otel-lgtm extension gate (Tempo/Loki verification)
- symptom: after wiring OTEL_* env onto the `openwork` service, Tempo shows only service.name `opencode` traces (sql.execute, Npm.add, …); no spans for server HTTP requests; server stdout never reaches Loki
- cause: upstream `apps/server` @ ae67215d has no OpenTelemetry instrumentation at all (git grep: none); `DEN_OBSERVABILITY_BACKEND`/`OTEL_SERVICE_NAME` gating exists only in ee/ (den-api/den-web). The OTEL_* env is consumed by the in-process opencode runtime (OPENWORK_MANAGE_OPENCODE=1)
- fix: none possible at this pin — gate traces/logs via the opencode runtime's exports (service.name `opencode`); do not expect server request spans

## P-040: Tempo single-trace JSON needs `Accept: application/json`; spans nest under scopeSpans
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — otel-lgtm gate, Grafana API trace inspection
- symptom: `GET /api/datasources/proxy/uid/tempo/api/traces/<id>` without header returns protobuf/garbage; parsing `batches[].spans[]` finds nothing
- cause: Tempo defaults to a non-JSON representation without the Accept header; the JSON layout puts spans under `batches[].scopeSpans[].spans[]`, not `batches[].spans[]`
- fix: add `-H 'Accept: application/json'` and read spans at `batches[].scopeSpans[].spans[]`; Loki matcher must be non-empty-compatible, e.g. `{service_name="opencode"}`

## P-041: step-ca-trust wrapper requires a baked ENTRYPOINT in the wrapped image
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — TLS (step-ca) gate, openwork container restart-looping
- symptom: openwork container restart-loops with exit 0 and no error output once the step-ca-trust extension's wrapper entrypoint applies; works fine without the extension
- cause: the wrapper ends with `exec "$@"`, but a compose `entrypoint:` override replaces the image's default entrypoint on a CMD-only image — `$@` is empty, exec runs nothing, container exits 0 silently
- fix: image must bake its own `/entrypoint.sh` + `ENTRYPOINT` (openwork: `app/images/openwork-host/Dockerfile`); the wrapper then ends `exec /entrypoint.sh "$@"` and CMD still reaches the server. Rule for ANY future image wrapped by step-ca-trust: no CMD-only images
- commit (openwork): 9215a27

## P-042: TLS vhost `*.example.com` placeholders never get certs — use `*.af` for gates
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack; polaris stack (VIRTUAL_HOST=polaris.example.com in letsencrypt/step-ca .env.example)
- symptom: with `*.example.com` vhosts the companion never issues certificates; cert-wait hangs; nginx-proxy serves `ssl_reject_handshake on` for the vhost → `tlsv1 unrecognized name` on every TLS request
- cause: `*.example.com` does not resolve in this environment; the live step-ca-companion only issues certs for names it can see via the unbound redirect (unbound has `local-zone: "af." redirect → 192.168.99.1` only)
- fix: use `*.af` vhosts (e.g. `openwork.af`, `openwork-api.af`, `polaris.af`) — they resolve via the live unbound redirect and get certs in seconds; `*.example.com` placeholders stay only in `.env.example` docs. polaris fix committed in `53fbf5a`

## P-043: sb build fails with "yq is required but not available" on hosts without yq
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — first `sb build` in app/
- symptom: build aborts after "Configuration validation passed" with `Failed to initialize build executor: yq is required but not available`
- cause: sb's default YAML merger shells out to yq v4+, which is not installed on the host (and host package installs are forbidden)
- fix: set `yaml_merger = "rust"` under `[build]` in stackbuilder.toml (pattern already used by vibe-kanban stacks); sb then uses its built-in Rust merger

## P-044: gabehf/koito image has no curl/wget — healthcheck must use bash /dev/tcp
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — base compose healthcheck
- symptom: no curl, wget, nc, python, perl or busybox in the image (debian:bookworm-slim + libvips only); standard HTTP healthchecks impossible
- cause: upstream keeps the image minimal; bash 5.2 IS present and supports /dev/tcp pseudo-device connections
- fix: CMD-SHELL `bash -c 'exec 3<>/dev/tcp/127.0.0.1/${PORT}; printf "GET /path HTTP/1.0\r\n\r\n" >&3; head -1 <&3 | grep -q " 200"'` — NOTE the slash syntax `/dev/tcp/host/port`; the colon syntax `/dev/tcp/host:port` fails with "No such file or directory"

## P-045: Docker Hub tags for gabehf/koito are v-prefixed
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: koito stack — DEPLOYMENT.md image pin vs Docker Hub reality
- symptom: `gabehf/koito:0` (as guessed in DEPLOYMENT.md) does not exist; pull fails
- cause: upstream publishes only v-prefixed tags (v0, v0.3, v0.3.2, latest)
- fix: pin `${IMAGE:-gabehf/koito:v0}`; verified via Docker Hub API + live pull + health smoke test; row appended to UPSTREAM.md

## P-046: браузерный E2E без agent-browser — dockerized headless Chromium + самописный CDP-драйвер
- hits: 1 | status: mitigated | first: 2026-11-05 | last: 2026-11-05
- where: стек-тестирование (browser E2E gate) — koito stack Stage A
- symptom: agent-browser CLI не установлен, `npm`/`npx` на хосте отсутствуют
  (есть только bare `node`), браузерных бинарников нет; host package
  installs запрещены — браузерный gate заблокирован целиком
- cause: браузерная инфраструктура агента не доехала до этой машины; ставить
  ничего на хост нельзя (iron rules)
- workaround: docker-разрешено → `docker run -d --rm --network host
  --shm-size=512m zenika/alpine-chrome:latest --no-sandbox --headless=new
  --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 about:blank`,
  управлять через CDP собственным dependency-free драйвером (Node 26 имеет
  встроенные fetch + WebSocket): `/tmp/opencode/koito-e2e/cdp.mjs` —
  connect/eval/navigate/shot + `Input.dispatchMouseEvent`/`dispatchKeyEvent`
- fix: —
- note: React SPA игнорирует JS-овый `.click()` на табах/кнопках — нужно
  щёлкать настоящими CDP mouse-событиями по центру rect элемента и печатать
  через `Input.dispatchKeyEvent`; полный токен из UI можно достать тем же
  авторизованным fetch из контекста страницы (cookie сессии подхватывается
  автоматически)

## P-047: agent-browser needs `--args "--no-sandbox"` + local bun install (pnpm global bin not in PATH)
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Stage A browser E2E gate (also applies to any stack gate on this host)
- symptom: `agent-browser open` fails with "Chrome exited early … No usable sandbox!"; `npx` absent on host; `pnpm add -g` installs to `~/.local/share/pnpm/bin` which is not in PATH (and `pnpm bin -g` itself errors ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH)
- cause: AppArmor-disabled unprivileged user namespaces on this host kill Chrome's sandbox; host has bare `node`/`bun`/`pnpm` only
- fix: install locally in the scratch dir — `cd /tmp/opencode && bun add agent-browser` → run as `./node_modules/.bin/agent-browser --session <name> --args "--no-sandbox" <cmd>`; the `--args` flag must come before the subcommand. Complements P-046 (dockerized-Chromium fallback, no longer needed)
- note (2026-11-05, navidrome gate): after `open`, the session can sit at `about:blank` with an empty DOM (snapshot/eval return nothing) even though `open` printed the target URL — a plain re-`open <url>` in the same session restores the page; also never abbreviate the CLI into a single `$AB` string variable, zsh then treats the whole string as one command path

## P-048: tome API auth quirks — OPDS basic auth uses username, KOSync lives at /api/v1 with plaintext userkey, TomeSync needs a *plugin* key (not an api-token)
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack Stage A gate — OPDS/KOSync/TomeSync endpoint probes
- symptom: OPDS basic auth with email → 401; KOSync probes at `/v1/*` return the SPA HTML (catch-all); KOSync auth with MD5 of the password → 401; `PUT /api/v1/syncs/progress` without `percentage` → 400; Bearer token from `POST /api/tokens/` on `/api/tome-sync/*` → 401 "Invalid API key"
- cause: `get_current_user_basic` matches `User.username` (email not accepted); kosync router prefix `/v1` mounted under `/api` → `/api/v1/`, and `_get_kosync_user` compares the userkey **as stored** (plaintext, whatever `POST /users/create` received — no MD5); progress PUT requires `document`+`progress`+`percentage`+`device`; TomeSync `_get_api_key_user` queries the `api_keys` table (plugin keys via `POST /api/plugin/api-keys`), while `/api/tokens/` writes the separate `api_tokens` table
- fix: OPDS: `-u 'Gate Librarian:GatePass123!'`; KOSync: headers `X-Auth-User`/`X-Auth-Key` with the plaintext key, routes under `/api/v1/`; progress PUT body `{"document","progress","percentage","device"}`; TomeSync: create key via `POST /api/plugin/api-keys` (JWT from `/api/auth/login`), send as `Authorization: Bearer tk_…`

## P-049: kanidm CLI 1.11.2 cookbook deviations — subcommand names differ from older docs
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: kanidm-admin subagent, OAuth2 client provisioning for the tome stack
- symptom: `system oauth2 add-redirect-urls` / `create-scope-map` / top-level `whoami` not found or not behaving as older kanidm cooking notes describe
- cause: kanidm 1.11.2 renamed/singularized several oauth2 subcommands
- fix: use `system oauth2 add-redirect-url` (singular); scope maps are managed with `system oauth2 update-scope-map` (alias of create-scope-map); identity check is `self whoami` (no top-level `whoami`). PKCE is enabled by default on new clients; `groups` claim emerges natively from the `groups` scope in 1.11 — no custom claim-map needed.

## P-050: `archive/tar: write too long` on compose config copy — empty `VIRTUAL_HOST` produces empty config target filename
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack, step-ca build layer `docker compose up` (vhost config registration)
- symptom: `docker compose up` fails with `archive/tar: write too long` before any container starts
- cause: compose `configs` target `/vhost.d/${VIRTUAL_HOST}` with `VIRTUAL_HOST` unset in the build `.env` → empty destination filename, tar writer chokes
- fix: fill the step-ca env vars (`VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST`, `LETSENCRYPT_EMAIL`, `TOME_PUBLIC_URL`) in `build/<env>/*/.env` before `up`; stack then starts cleanly

## P-051: Tome OIDC redirect URL is `/api/auth/oidc/callback`, NOT `/auth/callback`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack oidc extension + Kanidm OAuth2 client `tome`
- symptom: SSO callback would 404/fail redirect validation even though OIDC config endpoint reports enabled
- cause: `/auth/callback` is the frontend post-login route (`TOME_OIDC_POST_LOGIN_REDIRECT` default), easily confused with the OIDC redirect; upstream docs (sso.md) require the callback to EXACTLY match `https://<host>/api/auth/oidc/callback`
- fix: register `https://tome.af/api/auth/oidc/callback` in Kanidm (`system oauth2 add-redirect-url`, strict-redirect enabled) and default `TOME_OIDC_REDIRECT_URL` to it in the extension fragment; removed the wrong `/auth/callback` entry

## P-052: kanidmd container has no shell and no kanidm CLI — run `kanidm/tools` sidecar instead of `docker exec`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: any Kanidm admin operation on the live step-ca-manager instance
- symptom: `docker exec kanidmd sh` / `kanidm` / `ls` all fail (`exec: "sh": executable file not found`); kanidm CLI absent from the server image
- cause: kanidmd image is a minimal single-binary container (entrypoint `/sbin/kanidmd server`)
- fix: `docker run --rm --network host --user 0:0 -e HOME=/tmp/kanidmcfg -v <scratch>:/tmp/kanidmcfg -v <scratch>/root_ca.crt:/etc/ssl/certs/ca-certificates.crt:ro kanidm/tools:1.11.2 kanidm ...` — token cache persists in the scratch mount; root CA bind-mount is required (kanidm.af uses step-ca internal TLS, else `InvalidCertificate(UnknownIssuer)`)

## P-053: `sb build` wipes build-layer `.env` files on every run
- hits: 6 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack `app/` `sb build` (all environments)
- symptom: after `sb build`, each `build/<env>/<layer>/.env` is truncated to a 23-line skeleton (secrets like `TOME_OIDC_CLIENT_SECRET`, passphrases gone); output shows "⚠ Skipped .env file (content conflict)" x4, "Creating backup for 6 files that couldn't be restored", "Restoration completed: 0 restored successfully"
- cause: sb regenerates build `.env` from component `.env` + fragment `.env.example` and refuses to auto-restore when content conflicts; its own backup lands in `app/.stackbuilder/backup/backup_<ts>/` as `<env>_<layer>_.env`
- fix (workaround): restore from the timestamped `.stackbuilder/backup/` dir (or a pre-build copy) after every `sb build`; keep a pre-build copy in `/tmp/opencode` as second source. Unresolved upstream behavior — always verify line counts + secret keys before `docker compose up`. Note (hit#3): sb does auto-backup/auto-restore, but the tracked set covers only the 6 layer files present at backup time; newly added per-extension build dirs (koreader-tomesync, send-to-device-smtp, outbound-notify, auto-import) get fresh skeleton `.env` — that is expected, only the 6 tracked layer files need restoring.

## P-054: multi `-f` compose up loads only the first layer's `.env`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: staged stack bring-ups with layered compose (`kill-switches` + `base` + extensions), e.g. tome oidc stage
- symptom: vars declared in an extension layer with `?err` enforcement fail or interpolate to defaults even though the extension's own `.env` defines them
- cause: `--env-file` defaults to `./.env` relative to the FIRST compose file; later `-f` files' sibling `.env` files are not picked up when the first layer has none
- fix: always pass `--env-file <final-layer-dir>/.env` explicitly on every `up`/`down` when layering multi `-f` compose files from different directories

## P-055: container-level CA trust: compose `volume.subpath` mounts for apps that use the system trust store
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: tome stack OIDC stage (upstream image, httpx 0.28 → system CA store; no bind-mount policy allows cert files)
- symptom: TLS calls to kanidm.af fail with `InvalidCertificate(UnknownIssuer)` even though step-ca signed the cert
- cause: upstream image wheels trust the *system* store (no pip cert-file switch), and the app container has no path to the step-ca root CA; host curl is also broken (P-018) so verification must be dockerized
- fix: untracked test-only overlay (4th `-f`) mounting the external volume at `volume.subpath: certs` → files land at the target root (`/stepca/root_ca.crt` without a `certs/` dir), plus `SSL_CERT_FILE: /stepca/root_ca.crt`; works on compose 5.6.1 + engine 29.9.2. Verify network-wise with `alpine/curl` attached to `step-ca-network` using `--cacert /step/certs/root_ca.crt`. NOTE: overlay is test-only and must NOT be committed with the stack.

## P-056: Kanidm plain `groups` claim emits UUID + SPN (no short names) — apps doing exact-match group checks break
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: tome OIDC stage E2E (`s.oidc_allowed_group not in groups` gate in `backend/services/oidc.py`)
- symptom: SSO completes, code exchanged, callback 302 → but UI shows "not permitted to sign in"; audit `auth.oidc_denied` details `{"reason": "not in allowed group"}` although the user IS a member of the mapped group
- cause: Kanidm's `groups` scope emits each group's UUID **and** SPN values only (`name@domain`), never the short name (v1.11.2 `oauth2.rs`: `groups implies uuid + spn`); Tome compares exact strings against short names like `tome_users`
- fix: committed in tome `fae2ad5` — group env defaults in all 4 compose fragments (component + 3 build) now use nested SPN fallback `${NAME:-tome_users@${TOME_OIDC_KANIDM_DOMAIN:-kanidm.af}}` (new var `TOME_OIDC_KANIDM_DOMAIN`, default `kanidm.af`); `.env.example` carries SPN values + the new var. Nested `${A:-b@${B:-dom}}` resolves correctly to the SPN default and stays env-overridable (verify: `/tmp/opencode/nesttest/docker-compose.yml` + layered `docker compose ... config` showing `tome_admins@kanidm.af`). CAUTION: `${VAR:-...}` per-file fallbacks still cannot override a var already set by `--env-file X.env` (substitution happens per-file before merge) — that only affects override-in-overlay flows, not the default. Kanidm-side alternative (if ever allowed): the `groups_name` scope emits short names.



## polaris config user lacks admin rights (admin endpoints reject)

- hits: 1
- status: fixed
- last: 2026-11-05
- where: polaris stack Stage A gate (stacks/self-hosting/media-streaming/music/polaris)
- symptom: `POST /api/auth` succeeds for the TOML `[[users]]` entry but returns `is_admin: false`; `/api/initial_setup` reports `has_any_users: false`; every admin endpoint (`/api/index_status`, `/api/trigger_index`, `/api/users`, `/api/mount_dirs`) replies "Administrator permission is required"
- cause: polaris 0.16.1 `User::is_admin()` only matches `admin == Some(true)` (src/app/config/user.rs:15-17) — the TOML user entry needs an explicit `admin = true`; `/api/initial_setup` actually reports `has_any_admin` (src/server/axum/api.rs:112). Also `[[mount_dirs]]` field is `source`, not `path` (0.16.1 schema).
- fix: committed in polaris `4ae4cf9` — `admin = true` added to the `[[users]]` entry and `source = "/music"` in base + all 3 build `polaris.toml.example` copies; redeploy with `docker compose up -d --build` (config is baked via `dockerfile_inline` COPY — without `--build` a cached image with stale config is reused). Gate then passed fully (login is_admin:true → index UpToDate 3 songs → album detail → thumbnail 200 JPEG → audio 200 → uid 1000 → down -v reseed OK).

## P-057: dockerfile_inline `FROM ${IMAGE}` self-reference stacks COPY layers on every rebuild
- hits: 1
- status: mitigated
- first: 2026-11-05
- last: 2026-11-05
- where: polaris Stage A (dockerfile_inline config bake pattern, `stacks/self-hosting/media-streaming/music/polaris`)
- symptom: image history shows an ever-growing stack of `COPY --chown=... polaris.toml.example /config/polaris.toml` layers (one per `docker compose up -d --build`, ~1 per rebuild seen at 11:02–11:06 timestamps); made a transient rebuild loop look like an external watcher — alarmed diagnosis ("cyclic recreate", suspect docker-gen) while the real loop was a crash-restart of a container with a corrupted config
- cause: `dockerfile_inline: "FROM ${IMAGE:-localhost/polaris:0.16.1}\nCOPY ..."` builds a child of the image's own tag and retags it with the same tag → each rebuild adds one config layer; combined with a stale/corrupt bake (duplicate `admin = true` from a mid-edit build, caught only by container restart log "TOML parse error ... duplicate key"), the repeated rebuild+recreate looks like an endless cycle. No external process was involved (ps shows no compose/watcher).
- fix: treat as expected consequence, not a bug: `docker compose up -d --build` is required for config changes (P-023) and layers accumulate — diagnose "recreate loop" by (a) checking container logs for crash errors first, (b) comparing image-copy timestamps with own `up --build` invocations. Reset accumulation by rebuilding the base image via its Dockerfile when the layer pile-up matters. Copy the config's exit-code transcript from `docker logs`, not the last-healthy state.

## P-058: dockerfile_inline `RUN apt-get` fails on non-root base images — add `USER root` first
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: polaris s3fs-fuse extension (`app/components/extensions/s3fs-fuse/docker-compose.yml`, both dockerfile_inline blocks)
- symptom: `docker compose up --build` fails in the dockerfile_inline build with apt-get permission errors (base image `localhost/polaris:0.16.1` runs as uid 1000, so `apt-get update && apt-get install` cannot write)
- cause: dockerfile_inline inherits the base image's USER; apt needs root
- fix: add `USER root` as the first instruction after `FROM ${IMAGE:-...}` in every dockerfile_inline that runs apt-get (or any root-only command); committed in polaris `53fbf5a`

## P-059: curl 8.23 (alpine/curl, curlimages/curl) rejects `--cacert` — use `SSL_CERT_FILE` as root
- hits: 1
- status: open
- first: 2026-11-05
- last: 2026-11-05
- where: gate testing against step-ca TLS vhosts from throwaway curl containers (polaris gate, any `*.af` vhost)
- symptom: `curl --cacert /step/certs/root_ca.crt` fails with "option --cacert: is badly used here" in alpine/curl:latest and curlimages/curl (curl 8.23)
- cause: newer curl builds restrict --cacert usage context; also the step-ca root CA inside volume `step-ca-data` sits at `/home/step/certs/root_ca.crt` mode 600 uid 1000 — unreadable by the image's non-root curl_user
- fix: run the container as root with the volume mounted and `export SSL_CERT_FILE=<ca-path>`; e.g. `docker run --rm -v step-ca-data:/step:ro --network step-ca-network --entrypoint sh alpine/curl:latest -c 'export SSL_CERT_FILE=/step/certs/root_ca.crt; curl --resolve <vhost>:443:<proxy-ip> https://<vhost>/...'`. Note: `/step/certs/root_ca.crt` works because the volume's `certs` subpath content is exposed at the mount root — verify the actual path with `ls` if a mount uses `subpath`

## P-060: sb rust YAML merger silently drops env keys whose plain scalar contains ": " — double-quote `${VAR:?msg}` values
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord access-key extension fragment (`app/components/extensions/access-key/docker-compose.yml`); any extension using the `${VAR:?message with colons}` fail-fast idiom
- symptom: after `sb build`, the merged `build/<env>/<ext>/docker-compose.yml` was byte-identical to the base variant — the `REKORD_ACCESS_KEY` environment key vanished without any warning; the extension silently did nothing
- cause: the rust YAML merger mis-parses a plain (unquoted) scalar containing ": " (the required-var message "…is required: 32-256 chars…" has one); the whole environment key drops out of the merged map
- fix: double-quote the value — `REKORD_ACCESS_KEY: "${REKORD_ACCESS_KEY:?REKORD_ACCESS_KEY is required: …}"`; compose interpolation works inside quotes and the key survives the merge (verified in all 3 envs). Rule: quote any `${VAR:?…}` value whose message contains ": "

## P-061: layered compose resolves relative build contexts against the FIRST -f file's dir — pass `--project-directory .`
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord s3fs-fuse extension gate (layered `up` from `app/build/forwarding/` with per-extension fragment subdirs); any stack whose extension fragments use a relative `build.context:`
- symptom: layered `docker compose -f base/... -f <ext>/... up --build` fails with `unable to prepare context: path ".../base/s3fs-fuse" not found` even though the context dir exists next to the extension fragment
- cause: compose resolves relative `build.context` paths against the directory of the FIRST `-f` file (here `base/`), not the cwd and not the fragment that declares the build
- fix: add `--project-directory .` to the layered command (run from the build-env root) so `context: s3fs-fuse` resolves to `build/<env>/s3fs-fuse/`; stackbuilder already copies the entrypoint script into that subdir. Documented in the re-kord s3fs-fuse fragment comment

## P-062: minio `mc` silently treats an unknown alias as a LOCAL filesystem path
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: re-kord s3fs-fuse gate (verifying bucket contents on the live RustFS); any session using `mc` without a configured alias
- symptom: `mc ls rek/re-kord-music/...` and even `mc ls rek/definitely-not-a-bucket-xyz` exit 0 with S3-style output; `mc cp ... rek/<bucket>/<key>` "succeeds" but the object never reaches the S3 server
- cause: `rek` is not an alias or hostname (no DNS entry, nothing listens there) — mc falls back to treating `rek/...` as a path relative to cwd and lists/copies the LOCAL filesystem, printing it in the same S3-listing format, so the mistake is invisible in the output
- fix: always verify bucket backends with an explicit temp alias: `MC_CONFIG_DIR=/tmp/opencode/<dir> mc alias set tmp http://<container-ip>:9000 <ak> <sk>`, then `mc ls tmp/<bucket>/`. Rule: never use a bare word prefix in mc paths unless `mc alias list` shows it

## P-063: `sb build` requires mikefarah yq v4 on PATH — the system `/usr/bin/yq` is a jq-wrapper and breaks the build
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome stack builds (`sb build` in any stack's `app/`); every session running stackbuilder
- symptom: `sb build` fails or misbehaves because it shells out to `yq` and picks up `/usr/bin/yq`, which is the jq-compatible wrapper (different CLI), not mikefarah yq v4
- cause: stackbuilder expects the mikefarah yq v4 CLI (its filter syntax), but the distro `yq` on PATH is a different tool with the same name
- fix: keep a real mikefarah yq binary in scratch (e.g. `/tmp/opencode/bin/yq`, v4.54.1) and run `PATH=/tmp/opencode/bin:$PATH sb build` so it resolves first

## P-064: sb-generated `.env` has NO trailing newline — appended vars merge into the last line
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome s3fs-fuse-music gate (appending secret creds from a scratch file onto the sb-generated `build/<env>/<combo>/.env`); any workflow that appends to a stackbuilder-generated `.env`
- symptom: after `cat creds.env >> .env`, the first appended var became part of the last generated line (`RUSTFS_SECRET_KEY=RUSTFS_ACCESS_KEY=...`), so compose saw an empty `RUSTFS_ACCESS_KEY` and the entrypoint aborted with "RUSTFS_ACCESS_KEY is required" in a restart loop
- cause: stackbuilder writes the concatenated `.env.example` content without a final newline; `>>` concatenation then glues the next file's first line onto it
- fix: append a newline before the extra file: `cp fragment/.env.example .env && printf '\n' >> .env && cat creds.env >> .env`. Rule: never append to an sb-generated `.env` without ensuring a trailing newline first
- last: 2026-11-05
- where: navidrome extauth-proxy gate
- symptom: `sb build` de-staged/wiped the run-dir `.env` (EXTAUTH_USER empty → proxy ran in plain-proxy mode, gate failed with no auth payload)
- cause: sb build regenerates `build/<env>/<combo>/.env` from `.env.example` files; a hand-created run-dir `.env` is not preserved
- fix: after EVERY `sb build`, re-create the run-dir `.env` before a gate run: `printf 'EXTAUTH_USER=gateuser\nND_LOGLEVEL=trace\n' > .env && chmod 600 .env`. Note the `grep -q X .env || printf` idiom fails when `.env` does not exist — check existence first or just recreate wholesale

## P-065: nested viper config keys map to env names with dot→underscore — `ND_EXTAUTH_USERHEADER`, not `ND_EXTAUTHUSERHEADER`
- hits: 2
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome extauth-proxy gate (ExtAuth.TrustedSources / UserHeader / LogoutURL); any app using viper with `SetEnvPrefix` + `SetEnvKeyReplacer(strings.NewReplacer(".", "_"))` + `AutomaticEnv`
- symptom: fragment set `ND_EXTAUTHTRUSTEDSOURCES=...` etc.; navidrome ignored all three (ExtAuth stayed disabled) while the same names looked plausible next to flat keys like `ND_LOGLEVEL`
- cause: viper env keys are the nested config path with `.` replaced by `_` — `extauth.trustedsources` → `ND_EXTAUTH_TRUSTEDSOURCES`. The concatenated form is simply a different (unknown) key
- fix: derive env names from the nested key path, not from concatenation: `extauth.userheader` → `ND_EXTAUTH_USERHEADER`. Rule: for viper apps, env name = prefix + nested path with dots→underscores; verify against the app's config source, not `strings` on the binary (env names are not string literals)

## P-066: Alpine healthcheck `wget http://localhost/...` fails — localhost resolves to ::1, service listens IPv4-only
- hits: 1
- status: fixed
- first: 2026-11-05
- last: 2026-11-05
- where: navidrome extauth-proxy healthcheck (nginx:alpine); any Alpine-based container healthcheck hitting a service bound to 0.0.0.0
- symptom: container `Up (unhealthy)` with `wget: can't connect to remote host: Connection refused`, while `wget http://127.0.0.1/...` inside the container works
- cause: musl resolves `localhost` to ::1 first; nginx `listen 80` binds IPv4-only, so the ::1 attempt is refused
- fix: use `127.0.0.1` explicitly in healthcheck URLs (`http://127.0.0.1:80/healthz`)

## P-067: check-stack.sh gitkeep/yaml_merger checks are stale — check-gitkeep.sh + tome exemplar are canon
- hits: 2 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: omnibus stack creation (any new stack validated with the repo's check scripts)
- symptom: `check-stack.sh` flags missing `.gitkeep` in dirs that DO have one per the refined rule, and/or demands `yaml_merger = "rust"` in stackbuilder.toml, contradicting what existing verified stacks (tome exemplar) actually contain
- cause: check-stack.sh predates the refined `.gitkeep` rule (`.gitkeep` ONLY in exactly-one-subdir dirs) and the yaml_merger default change; it was not updated
- fix: treat `check-gitkeep.sh` + the tome exemplar as canon for gitkeep placement and yaml_merger; ignore stale check-stack.sh findings on those two topics (no fix to the script yet — needs user decision)

## P-068: images without baked-in volume dirs leave fresh named-volume mountpoints root-owned — add an init-chown service
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: omnibus stack gate (any image whose entrypoint chowns only some volumes, e.g. linuxserver.io-style PUID/PGID images)
- symptom: app runs fine but writes to a volume fail with permission errors (omnibus: upload → 400 "ebook library is not writable"); `ls -ld` inside the container shows the mountpoint owned by `root:root` while sibling volumes are correctly owned
- cause: Docker creates a named-volume mountpoint with the image's directory if it exists, else as root. The omnibus image has no `/books`//`/audiobooks` dirs and its entrypoint deliberately chowns only `/config` + `/cache` — library roots are left root-owned
- fix: one-shot init service in base compose: same image, `user: "0:0"`, `entrypoint: sh -c "chown ${PUID:-1000}:${PGID:-1000} <volumes>"`, `restart: "no"`; main service gets `depends_on: <init>: condition: service_completed_successfully`. Verify with `docker exec <svc> ls -ld <volumes>` after `up`

## P-069: debian-slim /bin/sh (dash) has no /dev/tcp — compose healthchecks must use curl
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp stack (any CMD-SHELL healthcheck on debian-slim images)
- symptom: healthcheck `exec 3<>/dev/tcp/127.0.0.1/7331` never succeeds; container stuck unhealthy while the app is fine
- cause: /dev/tcp is a bashism; debian-slim ships dash as /bin/sh, which does not support it
- fix: use curl in the healthcheck (`curl -s -o /dev/null -m 4 http://127.0.0.1:7331/healthz`); keep image HEALTHCHECK and compose healthcheck identical

## P-070: credential stores that join dir + `<key>.json` — token file lives flat in the data dir, not a credentials/ subdir
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp stack entrypoint seeding (upstream `credentials.zig pathOf` joins store dir + `<key>.json`; store dir = `<base>/userdata` per `state.zig`)
- symptom: token seeded into `userdata/credentials/inbound-token.json` (0600, correct content) but gateway still answers 401 with a valid bearer
- cause: the credential store's directory IS the userdata dir; `pathOf` produces `<userdata>/inbound-token.json` — the `credentials/` subdir guess was wrong
- fix: seed at the flat path `<userdata>/inbound-token.json` (0600); when a 401-with-bearer persists, read the upstream's pathOf/state code to find the real store dir before guessing paths

## P-071: compose `${VAR:-default}` treats an EMPTY shell override as unset — empty-value gate runs need an override file
- hits: 1 | status: fixed | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp Stage A gate (a) (any scenario that must run with a var explicitly EMPTY while the merged compose gives it a non-empty default)
- symptom: `NANOMCP_SEED_STUB_URL= docker compose up` still seeded the stub — the container got the `.env`/default URL and healthz showed `tools: 1` instead of the required `tools: 0`
- cause: `:-` (and `-`) substitution treats empty as unset, so an empty shell var loses to the compose default AND to `.env`; compose has no way to express "empty wins" inline
- fix: a compose override file that sets the key to an empty string in `environment:` (`docker compose -f docker-compose.yml -f override.yml up -d`, override: `NANOMCP_SEED_STUB_URL: ""`), plus `compose stop` for services the scenario excludes; verify with `docker exec <svc> env`

## P-072: `compose up` after `down -v` can fail with a stale container_name conflict — benign, verify with `docker ps`
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: nanomcp gate runs (any stack re-running `up` right after `down -v` with fixed `container_name`s)
- symptom: `up -d` reports "container name ... already in use" even though `down -v` reported removal
- cause: removal/creation race in the compose project with fixed `container_name` (same root as P-013's conflict noise)
- fix: retry `up -d` after a few seconds and confirm with `docker ps --filter name=<stack>`; the second attempt succeeds — no host-level cleanup needed
