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
- hits: 1 | status: mitigated | first: 2026-11-04 | last: 2026-11-04
- where: sb build / host tooling (opencode-stack)
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
- hits: 1 | status: open | first: 2026-11-05 | last: 2026-11-05
- where: openwork stack — TLS (step-ca) gate via live step-ca-manager companion
- symptom: with `*.example.com` vhosts the companion never issues certificates; cert-wait hangs
- cause: `*.example.com` does not resolve in this environment; the live step-ca-companion only issues certs for names it can see via the unbound redirect
- fix: use `*.af` vhosts (e.g. `openwork.af`, `openwork-api.af`) — they resolve via the live unbound redirect and get certs in seconds; `*.example.com` placeholders stay only in `.env.example` docs
