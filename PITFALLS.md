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
- fix: правило зафиксировано в stack-conventions §12 — всегда указывать
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
- fix: правило зафиксировано в stack-conventions §15, скилл `source-image`,
  шаги в stack-init/stack-modernize, секция в AGENTS.md
