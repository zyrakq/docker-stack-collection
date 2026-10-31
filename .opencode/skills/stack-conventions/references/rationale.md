# Stack Conventions — Rationale

Reasons behind each convention in `SKILL.md`. When an assumption breaks
(new sb version, changed layout), update the skill AND note it in
`STASKBUILDER.md` — the skills are the single source of truth.

1. **Skills, not MCP.** Kanidm/rustfs tooling is command-cookbook shaped;
   skills carry it without server infrastructure. MCP only if limits are hit.
2. **Location `.opencode/skills/` at collection root.** OpenCode discovers
   project skills from the project root toward the current directory, so
   skills work even when a session starts inside `stacks/<category>/<stack>/`.
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
