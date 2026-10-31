# Docker Stack Collection

A curated collection of Docker Compose stacks. The catalog tracks only a
manifest ([`stacks.csv`](stacks.csv) → rendered as [`stacks.md`](stacks.md)) —
every stack lives in `stacks/` as an independent git repo with its own `origin`.

## 🚀 Setup (mandatory after clone)

```bash
git clone https://github.com/zyrakq/docker-stack-collection.git
cd docker-stack-collection
git config core.hooksPath .githooks   # REQUIRED — enables auto-clone hooks
.githooks/stack-sync.sh               # clone all stacks listed in stacks.csv
```

After that, any `git pull` / branch switch automatically clones newly added
stacks. The script is idempotent — re-run it anytime.

## 📋 Manifest

One stack per row, semicolon-separated: `path;url;status`.

- `url` — git remote to clone from (`-` = no remote yet, row is skipped)
- `status` — `unverified` (likely finished, not confirmed) / `incomplete` / `completed`
- `merge=union` in `.gitattributes` merges row additions without conflicts —
  remove rows manually
- generated files (do not edit by hand): the `# BEGIN stack-sync` block in
  `.gitignore` and [`stacks.md`](stacks.md) — both regenerate from the CSV on
  sync runs and via the `pre-commit` hook

## 🔧 Working on a stack

Each stack is a normal independent git repo with `docker-compose.yml`,
`.env.example`, and its own `README.md`. The catalog only clones what is
missing — updates are manual, per repo:

```bash
cd stacks/<category>/<...>/<stack>
git pull && git push
cp .env.example .env && docker compose up -d
```

To push committed work in **all** stacks at once, run the manual mass-push
script (never fires automatically; never stashes or commits anything):

```bash
.githooks/stack-push.sh
```

It fetches every repo and pushes only the ones strictly ahead of their
upstream. Diverged repos, repos without an upstream, and missing repos are
reported and left for manual follow-up.

## 📝 License

Dual-licensed under [Apache 2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), your
choice. Individual services may have their own licenses. Provided as-is —
review configurations and security settings before production use.
