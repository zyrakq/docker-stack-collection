# Source Image — Dockerfile Skeletons

Genericized canonical skeletons for `app/images/<image>/Dockerfile`. All
are self-contained: empty build context, the source fetched by the
Dockerfile itself, every input a pinned ARG. Distilled from the
collection's source-built image idioms (open-coreui sparse clone,
vibe-kanban release-assets / git-clone, litellm-amd64-conf conf layer).

## 1. Release-tarball download

Upstream publishes release archives — deterministic, no git history.

```dockerfile
ARG GITHUB_REPO=<owner>/<repo>
ARG VERSION=v1.2.3

FROM <builder-image>:<tag> AS builder
ARG GITHUB_REPO
ARG VERSION
RUN wget -qO /tmp/src.tar.gz \
      "https://github.com/${GITHUB_REPO}/archive/refs/tags/${VERSION}.tar.gz" \
 && echo "<sha256>  /tmp/src.tar.gz" | sha256sum -c - \
 && mkdir /tmp/src && tar -xzf /tmp/src.tar.gz -C /tmp/src --strip-components=1 \
 && cd /tmp/src \
 && <install toolchain + build; artifacts to /out>

FROM <runtime-image>:<tag>
COPY --from=builder /out/<artifact> /usr/local/bin/<artifact>
USER <non-root-user>
EXPOSE <port>
HEALTHCHECK CMD <health-probe>
ENTRYPOINT ["<artifact>"]
```

## 2. Pinned git-clone

No release archive, or the release tag does not compile (P-007) — clone
at a pinned commit.

```dockerfile
ARG GIT_REPO=https://github.com/<owner>/<repo>.git
ARG GIT_COMMIT=<pinned-short-sha>

FROM <builder-image>:<tag> AS builder
ARG GIT_REPO
ARG GIT_COMMIT
RUN git clone "$GIT_REPO" /src \
 && git -C /src checkout "$GIT_COMMIT" \
 && cd /src \
 && <install toolchain + build; artifacts to /out>
# Only a subdirectory needed? Clone sparse:
#   git clone --filter=blob:none --sparse "$GIT_REPO" /src \
#    && git -C /src sparse-checkout set <subdir> \
#    && git -C /src checkout "$GIT_COMMIT"

FROM <runtime-image>:<tag>
COPY --from=builder /out/<artifact> /usr/local/bin/<artifact>
USER <non-root-user>
EXPOSE <port>
HEALTHCHECK CMD <health-probe>
ENTRYPOINT ["<artifact>"]
```

## 3. Conf-layer image (`<image>-conf`)

A small stack-owned config must be baked in? Do NOT add `COPY . .` to the
app image — layer a second image on the prebuilt base instead.

```dockerfile
# app/images/<image>-conf/Dockerfile
ARG BASE=localhost/<image>:<tag>

FROM ${BASE}
COPY <config-file> /etc/<app>/<config-file>
```

Build standalone like any source image
(`docker build -t localhost/<image>-conf:<tag> images/<image>-conf`);
compose still references only `${IMAGE:-...}` — point `IMAGE` at the
conf tag in `.env`.
