# Docker Stack Collection

A curated collection of Docker Compose stacks for self-hosted applications and
services. The catalog repository tracks only a **manifest** (`stacks.txt`) and
sync tooling — every stack lives in `stacks/` as an **independent git
repository** with its own `origin` (GitHub, `zyrakq/*`).

## 🚀 Setup (mandatory after clone)

```bash
git clone https://github.com/zyrakq/docker-stack-collection.git
cd docker-stack-collection
git config core.hooksPath tools/hooks   # REQUIRED — enables auto-clone hooks
tools/stack-sync.sh                     # clone all stacks listed in stacks.txt
```

After activation, any `git pull` that brings manifest changes automatically
clones newly added stacks (`post-merge` hook); `post-checkout` does the same
after branch switches. Re-run `tools/stack-sync.sh` anytime — it is idempotent.

## 📋 Manifest (`stacks.txt`)

Tab-separated, one stack per line:

```
path	url	status
stacks/devops/monitoring/kibana	https://github.com/zyrakq/kibana-stack.git	done
```

- `path` — stack location under `stacks/`
- `url` — git remote to clone from (`-` = no remote yet; such rows are skipped by sync)
- `status` — `done` (finished stack) or `wip` (work in progress)

Notes:

- `.gitattributes` sets `stacks.txt merge=union`, so rows added independently on
  different machines merge without conflicts. **Remove rows manually** — union
  merge cannot delete lines.
- The block between `# BEGIN stack-sync` / `# END stack-sync` markers in
  `.gitignore` is **generated** by `tools/stack-sync.sh` — do not edit it by hand.
- Each stack repo may contain its own nested submodules — they are part of the
  stack repo and are not managed by the catalog.

## 📁 Categories

Stacks live under five categories. **Done** stacks are listed below; the full
catalog (including 69 WIP stacks) is in [`stacks.txt`](stacks.txt).

### 🛠️ Development Tools (`stacks/development-tools/`)

- **Webtop Desktop** — browser-based desktop environments (`remote-access/webtop-desktop`) ✅
- **BaGetter** — NuGet server for .NET (`registries/package-registries/bagetter`) ✅
- **Distribution** — Docker registry with SSL automation (`registries/container-registries/distribution`) ✅
- **Registry Admin** — distribution admin UI (`registries/container-registries/registry-admin`)

### ⚙️ DevOps (`stacks/devops/`)

- **Keycloak** / **Kanidm** — identity management (`identity-management/`) ✅
- **Elasticsearch** / **Kibana** / **OpenObserve** — monitoring (`monitoring/`) ✅
- **SyncStorage** — Firefox Sync server (`secret-control/syncstorage`) ✅
- **LetsEncrypt Manager** / **Step-CA Manager** — SSL automation (`ssl-automation/`) ✅
- **Gitea** — version control (`version-control/gitea`) ✅

### 🔒 Network Privacy (`stacks/network-privacy/`)

- **Unbound** / **Pi-hole** / **DNSMasq** — DNS (`dns/`) ✅
- **Nginx Proxy Manager** — reverse proxy (`reverse-proxy/nginx-proxy-manager`) ✅
- **Network Client** / **VPN Server** — VPN (`vpn/`) ✅
- **COTURN** — TURN/STUN for WebRTC (`turn/coturn`) ✅

### 🏠 Self-Hosting (`stacks/self-hosting/`)

- **LiteLLM** / **Ollama** — AI model serving (`ai-services/model-serving/`) ✅
- **Open WebUI** / **Libre WebUI** — AI chats (`ai-services/chats/`) ✅
- **N8N** — AI automation (`ai-services/automation/n8n`) ✅
- **Synapse** / **Conduit** — Matrix servers (`communication/matrix/backend/`) ✅
- **Maubot** / **Mautrix-Telegram** — Matrix bridges (`communication/matrix/bridges/`) ✅
- **Element** / **FluffyChat** / **Cinny** / **Commet** — Matrix clients (`communication/matrix/frontend/`) ✅
- **HLedger Web** — personal finance (`finance/hledger-web`) ✅
- **RSSHub** — RSS aggregation (`integration-services/rsshub`) ✅
- **Invidious** — YouTube frontend (`media-streaming/youtube/invidious`) ✅

### ⛓️ Blockchain Nodes (`stacks/blockchain-nodes/`)

- **Bitcoin Core** — Bitcoin node with Lightning (LND) support ✅

## 🔧 Working on a stack

```bash
cd stacks/<category>/<...>/<stack>   # it is a normal independent git repo
git pull && git push                 # sync with its own origin
```

The catalog never pulls/pushes inside stack repos — `tools/stack-sync.sh` only
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
