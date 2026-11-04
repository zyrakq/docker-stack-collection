# Stack Conventions — Rationale

Reasons behind each convention in `SKILL.md`. When an assumption breaks
(new sb version, changed layout), update the skill AND note it in
`STASKBUILDER.md` — the skills are the single source of truth.

1. **Skills, not MCP.** Kanidm/rustfs tooling is command-cookbook shaped;
   skills carry it without server infrastructure. MCP only if limits are hit.
2. **Location `.opencode/skills/` at collection root.** OpenCode discovers
   project skills from the project root toward the current directory, so
   skills work even when a session starts inside a stack directory.
   Specs and rationale live as supporting files inside each skill directory —
   they travel with the skill.
3. **No host bind mounts.** Bind mounts break multi-host docker contexts and
   couple a stack to one machine's filesystem. Named volumes are portable and
   survive `docker compose down`.
4. **`dockerfile_inline` COPY preferred over `configs.content`.** Baked-in
   config is immutable at runtime and needs no host path; `configs.content`
   is reserved for tiny files because it inlines content into the compose
   file itself.
5. **Environments are variants, not dev/prod.** The same service code is
   deployed against different integration surfaces (plain ports, Let's
   Encrypt, step-ca). Naming them dev/prod would misrepresent the model.
6. **Variant selection by directory, not compose profiles.** `sb build`
   renders each variant into `build/<env>/<combo>/`; selecting by `cd` keeps
   generated files self-contained and diffable.
7. **OIDC in the default build + no-oidc variant kept.** OIDC is the tested
   end state for apps that support it; the no-oidc variant proves the
   pre-OIDC step still builds and runs.
8. **step-ca tested first.** The live step-ca-manager setup exists and is
   running; the letsencrypt variant is untested and assumed analogous minus
   `STEP_CA_TRUST`.
9. **`STEP_CA_TRUST_RESTART=true`.** Trust is often not picked up on first
   boot; the restart after bundle install makes it deterministic.
10. **gosu cert-wait.** TLS-terminating non-root services cannot read
    root-owned certs. Root is used only to wait + chmod, then the process
    drops to the upstream user via `exec gosu` (no lingering root process).
11. **No init containers.** Considered tech debt; the sleep-entrypoint and
    gosu patterns solve the same problems inside one container.
12. **`src/<name>/` is legacy, `app/` is target.** `app/` matches the
    stackbuilder-native layout and the multi-project sibling convention.
13. **Old stacks are NOT migrated unless explicitly requested.** Migration
    churn without a driver creates diff noise; `stack-modernize` exists for
    when it IS requested.
14. **Skills + `STASKBUILDER.md` as single source of truth.** When reality
    drifts from a skill, both are updated together so the next session never
    re-derives conventions.

15. **Naming `<stack>-<role>`.** A DB of this class is assumed to be
    per-project with its own container name — user: «для таких решений
    как бд обычно предполагается, что она под каждый проект своя и со
    своим именем контейнера». Generic names (`app`, `db`, `server`)
    collide across stacks, break external references, and hide the stack
    identity in `docker ps`.
16. **Env overridability (`${VAR:-}` everywhere).** Compose files are
    generated/managed artifacts; `.env` is the user surface. A value the
    user cannot override from `.env` without editing compose is a defect.
17. **No dead vars in `.env.example`.** A declared-but-unreferenced var
    (the `PROJECT_NAME` failure) misleads every reader and agent into
    using it. `.env.example` documents exactly what compose consumes.
18. **Postgres as the `database/{postgresql,pgrust}` extension pair.** An
    alternative implementation exists (pgrust) → the DB is swappable per
    project → it is an extension, not base infrastructure. A plain base
    service hard-couples the stack to one engine.
19. **`postgres:alpine` (latest), not the upstream-pinned version.**
    Upstream project instructions pin conservative versions; the latest
    postgres fits almost every app. `/var/lib/postgresql` (wide mount) is
    the current image layout; `/var/lib/postgresql/data` is legacy.
20. **Staged protocol (base first, test gates).** Extensions compound the
    failure surface; the base must be proven working before each
    extension is added, or a failure cannot be attributed. One extension
    at a time, each followed by its test.
21. **Environment layering (base is environment-agnostic).** A var whose
    correct value depends on the deployment environment (public URLs, TLS
    defaults) has no single right default — declaring it in base
    guarantees a wrong default somewhere. Each overlay owns its default.
22. **Self-contained skills (no path pointers into stacks).** Stacks are
    independent repos that move and change; skills that point into them
    rot silently. Patterns are embedded verbatim; no attribution to specific stacks.
