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
- hits: 1 | status: mitigated | first: 2026-10-31 | last: 2026-10-31
- where: sb build
- symptom: `sb build` падает "yq is required but not available" на хостах без
  системного yq
- workaround: `yaml_merger = "rust"` в `[build]` секции stackbuilder.toml
  (встроенный Rust-мерджер); также зафиксировано в STASKBUILDER.md (L10)
- fix: —

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
- hits: 1 | status: fixed | first: 2026-11-01 | last: 2026-11-01
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
  дерево становится ровно `build/<env>/<combo>/` по списку combos

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
- hits: 1 | status: open | first: 2026-11-02 | last: 2026-11-02
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
