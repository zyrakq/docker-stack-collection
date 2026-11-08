---
name: S3 Volumes
description: >-
  Mount an S3 bucket as a docker named volume via the rclone docker volume
  plugin (`s3-volumes` extension, `driver: rclone` overrides). Use when an
  app without native S3 support needs a bucket as a filesystem. Never for
  database volumes.
---

# S3 Volumes (rclone docker volume plugin)

Load the `stack-conventions` skill first. Buckets/users: `rustfs-s3` skill.

## When to use

- The app has NO native S3 support but should keep files (books, media,
  uploads) in a bucket. Native S3 → `s3-storage` extension instead.
- NEVER on database volumes. Only after the base passes its gate (§9).
- Not allowed: bind mounts, s3fs baked into the app image, s3fs sidecars.

## Host plugin (installed ONCE by the USER)

Agents must NOT run these (sudo/host change) — ask the user and STOP:

```bash
sudo mkdir -p /var/lib/docker-plugins/rclone/{config,cache}
docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions
```

Check (read-only): `docker plugin ls` shows `rclone:latest` enabled;
`/dev/fuse` exists on the host.

## Extension layout

`components/extensions/s3-volumes/docker-compose.yml` overrides the base
named volumes with the rclone driver, plus a `services:` stub:

```yaml
services:
  <stack>:
    volumes:
      - <stack>-books:/books
volumes:
  <stack>-books:
    name: <stack>-books
    driver: rclone
    driver_opts:
      type: s3
      path: ${S3_BOOKS_BUCKET}
      s3-provider: ${S3_PROVIDER}
      s3-endpoint: ${S3_ENDPOINT}
      s3-access-key-id: ${S3_ACCESS_KEY_ID}
      s3-secret-access-key: ${S3_SECRET_ACCESS_KEY}
      allow_other: "true"
      vfs_cache_mode: ${S3_VFS_CACHE_MODE}
```

- `.env.example` of the extension holds the `S3_*` vars (secret with a
  generator comment, §6).
- `sb` silently SKIPS fragments without `services:` (PITFALLS P-098) — the
  stub re-declaring the mounts is mandatory.
- The extension must be listed in the `stackbuilder.toml` combos
  (`entire`/`entire-trust`), otherwise it never reaches `build/`.

## driver_opts (verified)

- Keys: `type` (=`s3`), `path` (the bucket name), `s3-provider`,
  `s3-endpoint`, `s3-access-key-id`, `s3-secret-access-key`, `allow_other`,
  `vfs_cache_mode` (`vfs-cache-mode` also accepted). Invalid values are
  rejected with an explicit error.
- Booleans MUST be quoted strings (`"true"`).

## Gotchas

- The plugin mounts on the HOST side: the endpoint must be reachable from
  the host. The compose service name (`rustfs`) does NOT resolve. The e2e
  test used the RustFS container IP on `step-ca-network`
  (`http://172.20.0.x:9000`); for real use a host-reachable URL.
- Secrets in `driver_opts` are visible in `docker volume inspect`.
- `chown` inside the container is a no-op on the S3 mount: files stay
  `0:0`, writes still work — don't try to "fix" it.
- Create bucket + dedicated user/policy first (`rustfs-s3` skill).

## Verification (e2e)

1. Build, deploy from `build/<env>/<combo>/`; container healthy.
2. Write a file into the mount path inside the container
   (`docker exec <stack> sh -c 'echo t > /books/t.txt'`).
3. The object appears in the bucket (`mc ls rustfs/<bucket>`).
4. Mount type: `docker exec <stack> mount | grep <path>` shows
   `fuse.rclone ... allow_other`.
5. Teardown: `docker compose down -v --remove-orphans` — `-v` removes the
   rclone volumes (bucket data stays in S3).
