# Submodules → Manifest (stacks.txt) + Hook Sync — Implementation Plan

**Goal:** Replace all 37 catalog git-submodules with a `stacks.txt` manifest (path TAB url TAB status), migrate 101 repos from untracked `docker/` into `stacks/` (new category structure, `-stack` suffix stripped), clone 5 missing done-projects, and add idempotent `tools/stack-sync.sh` + git hooks so `git pull` auto-clones missing stacks.

**Architecture:** The catalog repo tracks only `stacks.txt`, `.gitattributes`, `.gitignore` (generated), `tools/stack-sync.sh`, `tools/hooks/*`, and `README.md`. Each stack is an independent git repo under `stacks/`, ignored by the catalog via a generated `.gitignore` block. `tools/stack-sync.sh` clones missing repos from the manifest and regenerates `.gitignore`; `post-merge`/`post-checkout` hooks (activated per-machine via `git config core.hooksPath tools/hooks`) invoke it.

**Design:** `thoughts/shared/designs/2026-10-26-submodules-to-manifest-design.md`

---

## Verified facts (research done — implementer needs no re-checking)

- `.gitmodules`: exactly **37** submodules, all `https://github.com/zyrakq/<name>-stack.git`.
- `docker/` contains exactly **101 top-level git repos** (each with its own `.git`), organized as `docker/{development-tools,devops,network-privacy,self-hosting}/...`. All 101 top-level repo dir names end in `-stack`.
- **170 nested repos/submodules** live INSIDE those 101 repos (e.g. `*/modules/ssl-automation/letsencrypt-manager`, `unbound-stack/vendor`, `step-ca-manager-stack/modules/*`). **NEVER touch, rename, move, or manifest them.** None of their dir names end in `-stack`, so the rename rule "strip `-stack` from dirs named `*-stack`" is safe.
- Special case RESOLVED by research: `docker/development-tools/registries/container-registries/distribution/` is a container folder (no `.git` itself) holding **two** repos:
  - `distribution/servers/distribution-stack` → remote `git@github.com:zyrakq/distribution-stack.git` (**done**, former submodule — no fresh clone needed)
  - `distribution/clients/registry-admin-stack` → remote `git@github.com:zyrakq/registry-admin-stack.git` (**wip**, extra repo)
- Done projects present in `docker/`: **32** (31 `-stack` repos + distribution-stack). WIP: **69**. 32 + 69 = 101 ✓
- **5 done projects missing** from `docker/` (old `stacks/` dirs are empty): sunshine, pi-hole, dnsmasq, vpn-server, bitcoin-core → clone fresh.
- **3 wip repos have NO origin remote**: `sftp-stack`, `komodo-stack`, `metube-stack` → manifest url `-`.
- All existing remotes use SSH form `git@github.com:zyrakq/<name>.git`; HTTPS also works (verified: `git ls-remote https://github.com/zyrakq/kibana-stack.git` succeeds anonymously).
- Old `stacks/` contains only empty submodule dirs + tracked `.gitkeep` files. No `.gitignore` exists yet. Tracked top-level entries: `.gitmessage`, `.gitmodules`, `.kilocode/`, `.vscode/`, `LICENSE-*`, `README.md`, `stacks/` (gitlinks + .gitkeep).
- No `.mindmodel/` in this project — plain bash conventions apply.

## Decisions (gap-filling — implementer follows these)

1. **Manifest URL protocol: normalize everything to `https://github.com/zyrakq/<name>.git`.** Design example uses https; HTTPS cloning verified to work anonymously; makes manifest portable to machines without SSH keys. (If any clone fails with auth error, fall back to that repo's SSH URL.)
2. **Distribution split:** `servers/distribution-stack` → `stacks/development-tools/registries/container-registries/distribution`; `clients/registry-admin-stack` → `stacks/development-tools/registries/container-registries/registry-admin` (sibling, suffix stripped). Container folder is dissolved.
3. **Manifest has NO header row** (matches design example). Comments start with `#`, blank lines allowed; sync script skips both.
4. **`.gitignore` is marker-delimited**: script regenerates only the block between `# BEGIN stack-sync (generated - do not edit)` and `# END stack-sync`; anything outside markers is preserved.
5. **Migration is sequential** (single shared working tree — cannot be parallelized). Batch 1 files are parallel.
6. **Nested submodules inside stack repos survive `mv`**: modern git uses relative `gitdir:` paths; moving the parent repo is safe. Plain `mv` is used everywhere.
7. **Testing**: plain bash test script `tools/tests/stack-sync.test.sh` (no test framework in repo). Hooks verified via `bash -n` + executable bit + wiring smoke test.

---

## Dependency Graph

```
Batch 1 (parallel):  1.1, 1.2, 1.3, 1.4, 1.5        [infra files - no deps]
Batch 2 (sequential): 2.1 → 2.2 → 2.3 → 2.4 → 2.5   [migration - shared tree]
Batch 3 (sequential): 3.1                            [final verification]
```

---

## Batch 1: Infrastructure files (parallel - 5 implementers)

All tasks independent. NOTE: Batch 1 files are created BEFORE migration; `tools/stack-sync.sh` will error "manifest not found" if run before Batch 2 — that is expected and fine.

### Task 1.1: Sync script + test
**File:** `tools/stack-sync.sh`
**Test:** `tools/tests/stack-sync.test.sh`
**Depends:** none

```bash
#!/usr/bin/env bash
# tools/tests/stack-sync.test.sh — tests for tools/stack-sync.sh
# Run: bash tools/tests/stack-sync.test.sh
set -euo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stack-sync.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# fixtures: two local "remote" repos
mkdir -p "$T/remotes/a" "$T/remotes/b"
for r in a b; do
  git -C "$T/remotes/$r" init -q
  git -C "$T/remotes/$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
done

# fixture: manifest (tab-separated) with normal rows, no-url row, comment
mkdir -p "$T/work"
printf 'stacks/x/alpha\t%s\tdone\n' "$T/remotes/a" > "$T/work/stacks.txt"
printf 'stacks/y/beta\t%s\twip\n' "$T/remotes/b" >> "$T/work/stacks.txt"
printf 'stacks/z/gamma\t-\tdone\n' >> "$T/work/stacks.txt"
printf '# comment line\n\n' >> "$T/work/stacks.txt"

# run 1: clones happen, .gitignore generated
STACKS_ROOT="$T/work" bash "$SCRIPT"
[[ -d "$T/work/stacks/x/alpha/.git" ]] || fail "alpha not cloned"
[[ -d "$T/work/stacks/y/beta/.git" ]] || fail "beta not cloned"
[[ ! -e "$T/work/stacks/z/gamma" ]] || fail "no-url row must not be cloned"
grep -qF '# BEGIN stack-sync' "$T/work/.gitignore" || fail "gitignore missing BEGIN marker"
grep -qF '# END stack-sync' "$T/work/.gitignore" || fail "gitignore missing END marker"
grep -qx 'stacks/x/alpha/' "$T/work/.gitignore" || fail "gitignore missing alpha/"
grep -qx 'stacks/y/beta/' "$T/work/.gitignore" || fail "gitignore missing beta/"

# run 2: idempotent — no re-clone, .gitignore unchanged
echo marker > "$T/work/stacks/x/alpha/MARKER"
cp "$T/work/.gitignore" "$T/work/.gitignore.before"
STACKS_ROOT="$T/work" bash "$SCRIPT"
diff -q "$T/work/.gitignore" "$T/work/.gitignore.before" >/dev/null || fail ".gitignore changed on second run"
[[ -f "$T/work/stacks/x/alpha/MARKER" ]] || fail "second run touched existing clone"

# run 3: collision — manifest path exists as a non-directory file → warning, no crash
printf 'stacks/w/delta\t%s\twip\n' "$T/remotes/a" >> "$T/work/stacks.txt"
mkdir -p "$T/work/stacks/w"
echo notadir > "$T/work/stacks/w/delta"
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)"
echo "$out" | grep -q "not a directory" || fail "expected collision warning for delta"

echo "OK: stack-sync tests passed"
```

```bash
#!/usr/bin/env bash
# tools/stack-sync.sh — clone missing stack repos from stacks.txt and regenerate
# the managed section of .gitignore. Idempotent: safe to run any number of times.
# NEVER pulls/pushes/merges inside stack repos and never deletes anything.
#
# Env overrides (used by tests): STACKS_ROOT, STACKS_MANIFEST, STACKS_GITIGNORE
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.txt}"
GITIGNORE="${STACKS_GITIGNORE:-$ROOT/.gitignore}"
BEGIN_MARK="# BEGIN stack-sync (generated - do not edit)"
END_MARK="# END stack-sync"

cd "$ROOT"

if [[ ! -f "$MANIFEST" ]]; then
  echo "stack-sync: manifest not found: $MANIFEST" >&2
  exit 1
fi

# --- 1. clone missing repos ------------------------------------------------
while IFS=$'\t' read -r path url status; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  if [[ -z "$url" || "$url" == "-" ]]; then
    echo "stack-sync: WARN no url for '$path', skipping" >&2
    continue
  fi
  if [[ -d "$path" ]]; then
    continue  # already present — nothing to do
  fi
  if [[ -e "$path" ]]; then
    echo "stack-sync: WARN '$path' exists and is not a directory, skipping" >&2
    continue
  fi
  mkdir -p "$(dirname "$path")"
  if ! git clone --quiet "$url" "$path" < /dev/null; then
    echo "stack-sync: WARN clone failed for '$path' ($url)" >&2
  fi
done < "$MANIFEST"

# --- 2. regenerate managed .gitignore section ------------------------------
block_file="$(mktemp)"
new_file="$(mktemp)"
trap 'rm -f "$block_file" "$new_file"' EXIT
{
  printf '%s\n' "$BEGIN_MARK"
  awk -F'\t' '$1 != "" && $1 !~ /^#/ { print $1 "/" }' "$MANIFEST" | sort -u
  printf '%s\n' "$END_MARK"
} > "$block_file"

if [[ -f "$GITIGNORE" ]] && grep -qF "$BEGIN_MARK" "$GITIGNORE"; then
  awk -v block="$block_file" '
    BEGIN { n = 0; while ((getline l < block) > 0) B[n++] = l; close(block) }
    $0 == B[0] { for (i = 0; i < n; i++) print B[i]; inblk = 1; next }
    inblk && $0 == B[n-1] { inblk = 0; next }
    !inblk { print }
  ' "$GITIGNORE" > "$new_file"
elif [[ -f "$GITIGNORE" ]]; then
  { cat "$GITIGNORE"; echo ""; cat "$block_file"; } > "$new_file"
else
  cp "$block_file" "$new_file"
fi
mv "$new_file" "$GITIGNORE"
```

**Verify:**
```bash
chmod +x tools/stack-sync.sh tools/tests/stack-sync.test.sh
bash -n tools/stack-sync.sh && bash -n tools/tests/stack-sync.test.sh
bash tools/tests/stack-sync.test.sh   # must print: OK: stack-sync tests passed
```
**Commit:** `feat(sync): add idempotent stack-sync script with tests`

### Task 1.2: post-merge hook
**File:** `tools/hooks/post-merge`
**Test:** none (config file — verified via `bash -n` + executable bit)
**Depends:** none

```bash
#!/usr/bin/env bash
# Auto-clone missing stack repos after a merge (e.g. git pull that changed stacks.txt).
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
script="$root/tools/stack-sync.sh"
[[ -x "$script" ]] || exit 0
exec "$script"
```

**Verify:** `chmod +x tools/hooks/post-merge && bash -n tools/hooks/post-merge && test -x tools/hooks/post-merge`
**Commit:** `feat(hooks): add post-merge hook calling stack-sync`

### Task 1.3: post-checkout hook
**File:** `tools/hooks/post-checkout`
**Test:** none (config file)
**Depends:** none

```bash
#!/usr/bin/env bash
# Auto-clone missing stack repos after checkout (covers branch switches and
# fresh checkouts once core.hooksPath is configured on the machine).
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
script="$root/tools/stack-sync.sh"
[[ -x "$script" ]] || exit 0
exec "$script"
```

**Verify:** `chmod +x tools/hooks/post-checkout && bash -n tools/hooks/post-checkout && test -x tools/hooks/post-checkout`
**Commit:** `feat(hooks): add post-checkout hook calling stack-sync`

### Task 1.4: .gitattributes
**File:** `.gitattributes`
**Test:** none
**Depends:** none

```
stacks.txt merge=union
```

**Verify:** `git check-attr merge -- stacks.txt` → `stacks.txt: merge: union`
**Commit:** `chore: union-merge stacks.txt manifest`

### Task 1.5: README rewrite
**File:** `README.md`
**Test:** none (doc — verified by grep)
**Depends:** none

Replace the ENTIRE file with:

````markdown
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
````

**Verify:** `grep -c 'core.hooksPath tools/hooks' README.md` → `1`; `grep -c 'stack-sync.sh' README.md` → ≥ 2
**Commit:** `docs: rewrite README for manifest-based structure and hook setup`

---

## Batch 2: Migration (sequential - single implementer, shared working tree)

These tasks mutate the same working tree and MUST run in order. Tasks 2.2–2.3 produce **no tracked changes** (they move untracked repos); only 2.1, 2.4, 2.5 create commits.

### Task 2.1: Remove catalog submodules, old stacks/, .gitmodules
**File:** none (git operation)
**Depends:** none (but MUST precede 2.2)

```bash
cd /home/archuser/projects/docker-stack-collection
git submodule deinit --all || true        # dirs are empty; likely a no-op
git rm -r --quiet stacks                  # removes 37 gitlinks + tracked .gitkeep files
git rm --quiet .gitmodules
rm -rf stacks                             # leftover empty dirs
rm -rf .git/modules                       # stale submodule gitdirs, if any
```

If `git rm -r stacks` refuses (submodule dirty warnings), retry with `git rm -rf stacks` — verified safe: all submodule worktrees are empty.

**Verify:**
```bash
test ! -e .gitmodules && test ! -e stacks
git ls-files | grep -c '^stacks/'         # → 0
git status --short | head -5              # shows only D entries for old stacks + .gitmodules
```
**Commit:** `chore: remove catalog submodules, old stacks/ tree and .gitmodules`

### Task 2.2: Move docker/ → stacks/, split distribution, strip -stack suffix
**File:** none (filesystem operation on untracked repos)
**Depends:** 2.1

```bash
cd /home/archuser/projects/docker-stack-collection
mv docker stacks

# split the distribution container folder into two sibling repos
D=stacks/development-tools/registries/container-registries
mv "$D/distribution/servers/distribution-stack" "$D/.distribution-tmp"
mv "$D/distribution/clients/registry-admin-stack" "$D/registry-admin-stack"
rm -rf "$D/distribution"
mv "$D/.distribution-tmp" "$D/distribution"

# strip -stack suffix from every top-level repo dir (safe: no nested dir ends in -stack)
find stacks -depth -type d -name '*-stack' -print0 |
while IFS= read -r -d '' d; do
  p="${d%/*}"; b="${d##*/}"
  mv "$d" "$p/${b%-stack}"
done
```

**Verify:**
```bash
find stacks -type d -name '*-stack' | wc -l          # → 0
find stacks -name .git | wc -l                        # → 271 (101 top-level + 170 nested)
test -d stacks/development-tools/registries/container-registries/distribution/.git
test -d stacks/development-tools/registries/container-registries/registry-admin/.git
test -d stacks/devops/monitoring/kibana/.git          # renamed from kibana-stack
git -C stacks/development-tools/registries/container-registries/distribution remote get-url origin
#   → git@github.com:zyrakq/distribution-stack.git (mv preserved the repo)
git status --short                                    # unchanged vs after 2.1 (moves are untracked)
```
**Commit:** none (no tracked changes)

### Task 2.3: Clone 5 missing done projects
**File:** none (git clone)
**Depends:** 2.2

```bash
cd /home/archuser/projects/docker-stack-collection
git clone https://github.com/zyrakq/sunshine-stack.git    stacks/self-hosting/media-streaming/sunshine
git clone https://github.com/zyrakq/pi-hole-stack.git     stacks/network-privacy/dns/pi-hole
git clone https://github.com/zyrakq/dnsmasq-stack.git     stacks/network-privacy/dns/dnsmasq
git clone https://github.com/zyrakq/vpn-server-stack.git  stacks/network-privacy/vpn/vpn-server
git clone https://github.com/zyrakq/bitcoin-core-stack.git stacks/blockchain-nodes/bitcoin-core
```

**Verify:**
```bash
for p in stacks/self-hosting/media-streaming/sunshine stacks/network-privacy/dns/pi-hole \
         stacks/network-privacy/dns/dnsmasq stacks/network-privacy/vpn/vpn-server \
         stacks/blockchain-nodes/bitcoin-core; do
  test -d "$p/.git" || echo "MISSING: $p"
done   # → no output
find stacks -name .git -maxdepth 9 | sed 's|/.git$||' > /tmp/opencode/repos-final.txt
python3 -c "
lines=[l.strip() for l in open('/tmp/opencode/repos-final.txt') if l.strip()]
top=[r for r in lines if not any(r!=o and r.startswith(o+'/') for o in lines)]
print(len(top))"   # → 106
```
**Commit:** none (untracked clones)

### Task 2.4: Generate stacks.txt
**File:** `stacks.txt`
**Depends:** 2.3

```bash
cd /home/archuser/projects/docker-stack-collection
python3 - <<'EOF'
import os, subprocess

DONE = set("""litellm ollama open-webui libre-webui n8n synapse conduit maubot
mautrix-telegram element fluffychat cinny commet hledger-web rsshub invidious
sunshine keycloak kanidm elasticsearch kibana openobserve syncstorage
letsencrypt-manager step-ca-manager gitea unbound pi-hole dnsmasq
nginx-proxy-manager network-client vpn-server coturn webtop-desktop bagetter
distribution bitcoin-core""".split())
assert len(DONE) == 37, f"DONE set must have 37 names, got {len(DONE)}"

repos = []
for root, dirs, files in os.walk('stacks'):
    if '.git' in dirs or '.git' in files:
        repos.append(root)
        dirs[:] = []  # do not descend — nested submodules are excluded
assert len(repos) == 106, f"expected 106 top-level repos, got {len(repos)}"

rows = []
for r in sorted(repos):
    name = r.rsplit('/', 1)[1]
    status = 'done' if name in DONE else 'wip'
    try:
        url = subprocess.run(['git', '-C', r, 'remote', 'get-url', 'origin'],
                             capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        url = '-'
    rows.append(f"{r}\t{url}\t{status}")

with open('stacks.txt', 'w') as f:
    f.write('\n'.join(rows) + '\n')
print(f"rows={len(rows)} done={sum(r.endswith('done') for r in rows)} "
      f"wip={sum(r.endswith('wip') for r in rows)} nouserl={sum(chr(9)+'-'+chr(9) in r for r in rows)}")
EOF
```

Note: cloned repos keep their real remote URLs (fresh clones → https; migrated repos → their existing SSH remotes). The sync script clones whatever URL a row carries — both protocols work.

**Verify:**
```bash
wc -l stacks.txt                                        # → 106
awk -F'\t' '$3=="done"' stacks.txt | wc -l              # → 37
awk -F'\t' '$3=="wip"'  stacks.txt | wc -l              # → 69
awk -F'\t' '$2=="-"'    stacks.txt | wc -l              # → 3 (sftp, komodo, metube)
awk -F'\t' 'NF!=3{print "BAD:" $0}' stacks.txt          # → no output
grep -c 'stacks/devops/monitoring/kibana' stacks.txt    # → 1
grep -c 'stacks/blockchain-nodes/bitcoin-core' stacks.txt # → 1
```
**Commit:** `feat: add stacks.txt manifest (37 done, 69 wip)`

### Task 2.5: Generate .gitignore + activate hooks on this machine
**File:** `.gitignore`
**Depends:** 2.4, 1.1

```bash
cd /home/archuser/projects/docker-stack-collection
git config core.hooksPath tools/hooks
tools/stack-sync.sh
cp .gitignore /tmp/opencode/gitignore-run1
tools/stack-sync.sh                      # second run — must be a no-op
diff /tmp/opencode/gitignore-run1 .gitignore   # → no output
```

**Verify:**
```bash
grep -c '^stacks/' .gitignore            # → 106
head -1 .gitignore                       # → # BEGIN stack-sync (generated - do not edit)
git config core.hooksPath                # → tools/hooks
git status --short                       # → only `?? .gitignore` (all repos ignored)
```
**Commit:** `chore: add generated .gitignore ignoring stack repo paths`

---

## Batch 3: Final verification (sequential)

### Task 3.1: End-to-end verification
**Depends:** all of Batch 1 + Batch 2

```bash
cd /home/archuser/projects/docker-stack-collection

# 1. catalog tree is clean — everything committed, stack repos ignored
rtk git status                            # → working tree clean
git ls-files | grep -c '^stacks/'         # → 0 (no stack content tracked)
test -z "$(git ls-files -o --exclude-standard | grep -v '^thoughts/')" && echo "no stray untracked"

# 2. manifest integrity
wc -l stacks.txt                          # 106
awk -F'\t' '$3=="done"' stacks.txt | wc -l   # 37
awk -F'\t' '$3=="wip"'  stacks.txt | wc -l   # 69

# 3. hooks wired and executable
test -x tools/hooks/post-merge && test -x tools/hooks/post-checkout && echo hooks-ok
git config core.hooksPath                 # tools/hooks

# 4. sync idempotency on the real tree
cp stacks.txt /tmp/opencode/manifest.bak
cp .gitignore /tmp/opencode/gitignore.bak
tools/stack-sync.sh
diff /tmp/opencode/manifest.bak stacks.txt       # → no output (script never edits manifest)
diff /tmp/opencode/gitignore.bak .gitignore      # → no output (no-op)

# 5. hook wiring smoke test (simulates "another machine pulled a new row")
git init -q /tmp/opencode/tiny-stack && git -C /tmp/opencode/tiny-stack \
  -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git clone -q . /tmp/opencode/machine-b
cd /tmp/opencode/machine-b && git config core.hooksPath tools/hooks
printf 'stacks/tiny\t/tmp/opencode/tiny-stack\twip\n' >> stacks.txt
tools/hooks/post-merge                    # what post-merge would execute after a pull
test -d stacks/tiny/.git && echo "hook auto-clone OK"
cd /home/archuser/projects/docker-stack-collection
rm -rf /tmp/opencode/machine-b /tmp/opencode/tiny-stack
```

**Verify (acceptance criteria):**
- `git status` clean; manifest row counts 37 done / 69 wip; 106 rows total
- second `tools/stack-sync.sh` run is a no-op (diff empty)
- hook smoke test clones `stacks/tiny` without any manual clone command
- `find stacks -type d -name '*-stack' | wc -l` → 0
- nested submodules untouched: `find stacks -path '*/modules/*' -name .git | wc -l` matches pre-migration count (170 total nested `.git` entries)

**Commit:** none (verification only)

---

## Rollback notes

- Batch 2 tasks 2.2–2.3 are pure `mv`/`clone` — reversible by moving dirs back.
- Task 2.1 is committed separately; `git revert` restores gitlinks + `.gitmodules`.
- The 5 fresh clones can be re-created anytime by `tools/stack-sync.sh` from the manifest.
