---
name: Source Image
description: >-
  Create self-contained source-built Docker images for stacks in
  docker-stack-collection: app/images/<image>/Dockerfile that downloads
  release binaries/archives or clones the upstream repo at a pinned
  tag/commit, builds the app from source, and wires the image into the
  app/ compose via the IMAGE variable. Use whenever an upstream app has no
  published Docker image and must be built from source. NEVER vendor
  upstream source into the stack repo (no submodules, no source trees).
---

# Source Image

Load the `stack-conventions` skill first — §19 defines the hard rules this
skill implements.

## Iron rules

1. **No vendoring.** The stack repo never contains upstream source — no
   submodule, no copied tree. The clone-in-tmp clone (§17) is
   reference-only.
2. **Self-contained Dockerfile.** `app/images/<image>/Dockerfile` must
   build from an empty build context: it fetches the source itself
   (release archive or git clone at a pinned tag/commit).
3. **No `build:` in compose.** Images are built standalone; compose only
   references the prebuilt image.

## Workflow

1. **Research upstream build requirements** in the clone-in-tmp clone
   (`/tmp/opencode/upstreams/<stack>-<project>`): existing Dockerfile(s),
   build docs, required toolchain (Rust/Node/pnpm versions), runtime
   deps, ports, healthcheck endpoints, data dirs, non-root feasibility.
   Pick the variant to build deliberately (e.g. desktop vs cloud server).
2. **Choose the fetch strategy:**
   - **Release archive** (preferred when a tag exists): download
     `https://github.com/<owner>/<repo>/archive/refs/tags/v<VERSION>.tar.gz`
     via ARG `GITHUB_REPO` / `VERSION`. Deterministic, no git history.
   - **Git clone**: `git clone --depth 1 --branch <tag>` via ARG
     `GIT_REPO` / `GIT_TAG` (or `GIT_BRANCH` for main). Use
     `--filter=blob:none --sparse` when only a subdirectory is needed.
   - **Release binaries** (preferred when upstream publishes them): fetch
     the artifact for the target arch via ARG `VERSION`.
3. **Write the Dockerfile** at `app/images/<image>/Dockerfile`:
   - Multi-stage: builder stage(s) install toolchain + build; runtime
     stage copies only artifacts. Pin base image tags.
   - All version/repo inputs as ARGs with pinned defaults.
   - Use BuildKit cache mounts for heavy package managers (cargo, pnpm).
   - Runtime: non-root user when feasible, `EXPOSE`, `HEALTHCHECK` on a
     real endpoint, `tini`/init if the app doesn't reap signals.
   - No `COPY` from the build context except trivial, stack-owned files
     (e.g. a small config) — and if any exist, prefer a second
     `<image>-conf` image layered on the first (litellm-amd64-conf
     idiom) or a compose `configs.content` volume.
4. **Build standalone** from the app dir:
   `docker build -t localhost/<image>:<tag> images/<image>` — verify it
   builds with no context files (run it from a clean checkout if unsure).
5. **Wire into compose:** in `components/base/docker-compose.yml` set
   `image: ${IMAGE:-localhost/<image>:<tag>}` on the service. Add
   `IMAGE=localhost/<image>:<tag>` to `.env.example` in the standard key
   order (§6). Never add a `build:` section.
6. **Record provenance:** append the UPSTREAM.md row (§17) — upstream
   commit the image is built from (the pinned tag/commit) in the commit
   column, `localhost/<image>:<tag>` in the image column, note
   `source-built via app/images/<image>`.
7. **Test** per the `stack-test` skill, then remove the tmp clone.

## Exemplars

Canonical skeletons (release-tarball, pinned git-clone, conf-layer) are
embedded in `references/dockerfiles.md` — imitate those, not live stacks.
