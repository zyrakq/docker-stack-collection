# rclone docker volume plugin: driver_opts findings (2026-11-08)

Source: https://rclone.org/docker/ (fetched 2026-11-08; Docker Hub not needed, GitHub not used).

## Remote definition
- `remote` (alias `fs`): remote name with trailing colon, or on-the-fly `:backend:dir`.
- `type` + `path` is equivalent to `remote=:type:path`.
- Backend/mount/VFS opts are named like CLI flags without `--`; dashes or underscores both OK.
- Backend params MUST carry the backend prefix in `-o`/driver_opts form: `s3-provider`, `s3-endpoint`, `s3-access-key-id`, `s3-secret-access-key`, `s3-env-auth` (underscores: `s3_endpoint`). Without prefix (as in connection strings) they are NOT valid in driver_opts. (Plan draft used unprefixed `provider`/`endpoint`/`access_key_id`: corrected.)
- Only the backend directly referenced by `type` can be configured.

## Mount opts
- `allow_other: 'true'`, `vfs_cache_mode: full`, also `poll_interval`, `uid`/`gid`/`umask`/`dir_cache_time` (serve-docker/mount flags; not shown on the page, taken from rclone mount flag naming).
- `mount-type`, `persist` are special options.

## Quoting
- Booleans MUST be quoted strings (`'true'`).
- A `remote` ending with colon MUST be quoted.
- Integers may be unquoted.
- Options not valid for the backend/mount make volume creation fail.

## Minimal compose snippet (verbatim from docs)
```yaml
volumes:
  volume_name_1:
    driver: rclone
    driver_opts:
      remote: 'gdrive:'
      allow_other: 'true'
      vfs_cache_mode: full
      poll_interval: 0
```

## Install / requirements (USER only; agents never run)
```
sudo mkdir -p /var/lib/docker-plugins/rclone/config /var/lib/docker-plugins/rclone/cache
docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions
```
- FUSE (fuse3) on the host; Docker Engine >= 19.03.15.
- config dir must exist even if empty; cache dir holds state and VFS cache.
- Plugin runs on the host: endpoint must be host-reachable.
- Changing opts: `docker volume rm` then recreate (create on existing volume is a silent no-op).
- Secrets in driver_opts are visible in `docker volume inspect`.

## Final driver_opts for omnibus
```
type: ${S3_VOLUMES_TYPE}                          (s3)
path: ${S3_VOLUMES_BOOKS_BUCKET}                  (AUDIOBOOKS_BUCKET for audiobooks)
s3-provider: ${S3_VOLUMES_PROVIDER}
s3-endpoint: ${S3_VOLUMES_ENDPOINT}
s3-access-key-id: ${S3_VOLUMES_ACCESS_KEY}
s3-secret-access-key: ${S3_VOLUMES_SECRET_KEY}
allow_other: ${S3_VOLUMES_ALLOW_OTHER}            (value 'true'; env value is a string, compose keeps it quoted-safe)
vfs_cache_mode: ${S3_VOLUMES_VFS_CACHE_MODE}
```
Unverified: `s3-env-auth` default (false) is fine; `uid`/`gid` not confirmed by the page.
