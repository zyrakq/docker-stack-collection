# Docker Stack Collection

A curated collection of Docker Compose stacks for self-hosted applications and
services. The catalog repository tracks only a **manifest** (`stacks.csv`) and
sync tooling — every stack lives in `stacks/` as an **independent git
repository** with its own `origin` (GitHub, `zyrakq/*`).

## 🚀 Setup (mandatory after clone)

```bash
git clone https://github.com/zyrakq/docker-stack-collection.git
cd docker-stack-collection
git config core.hooksPath .githooks   # REQUIRED — enables auto-clone hooks
scripts/stack-sync.sh                 # clone all stacks listed in stacks.csv
```

After activation, any `git pull` that brings manifest changes automatically
clones newly added stacks (`post-merge` hook); `post-checkout` does the same
after branch switches. Re-run `scripts/stack-sync.sh` anytime — it is idempotent.

## 📋 Manifest (`stacks.csv`)

The full catalog lives in [`stacks.csv`](stacks.csv) — one stack per row,
comma-separated (GitHub renders it as a table):

| column  | meaning                                                                    |
|---------|----------------------------------------------------------------------------|
| `path`  | stack location under `stacks/`                                             |
| `url`   | git remote to clone from (`-` = no remote yet; such rows are skipped)      |
| `status`| `unverified` (likely finished, not yet confirmed) / `incomplete` / `completed` |

Notes:

- `.gitattributes` sets `stacks.csv merge=union`, so rows added independently on
  different machines merge without conflicts. **Remove rows manually** — union
  merge cannot delete lines.
- The block between `# BEGIN stack-sync` / `# END stack-sync` markers in
  `.gitignore` is **generated** by `scripts/stack-sync.sh` — do not edit it by hand.
- Each stack repo may contain its own nested submodules — they are part of the
  stack repo and are not managed by the catalog.

## 🔧 Working on a stack

```bash
cd stacks/<category>/<...>/<stack>   # it is a normal independent git repo
git pull && git push                 # sync with its own origin
```

The catalog never pulls/pushes inside stack repos — `scripts/stack-sync.sh` only
**clones what is missing**. Updating stacks is manual, per repo.

Each stack includes `docker-compose.yml`, `.env.example`, and its own `README.md`:

```bash
cp .env.example .env   # edit, then:
docker compose up -d
```

## 📝 License

Dual-licensed under your choice of:

- **Apache License 2.0** ([LICENSE-APACHE](LICENSE-APACHE))
- **MIT License** ([LICENSE-MIT](LICENSE-MIT))

Individual services may have their own licenses.

## ⚠️ Disclaimer

These stacks are provided as-is for educational and self-hosting purposes.
Always review configurations and security settings before deploying in
production environments.
