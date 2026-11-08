---
name: RustFS S3
description: >-
  Cookbook for administering RustFS (the collection's S3 provider): create
  buckets, users/keys, and policies; wire apps via s3-storage extension env
  fragments. Use for any RustFS or S3 storage wiring task.
---

# RustFS S3

Load the `stack-conventions` skill first.

Full command cookbook: read `references/cookbook.md`.

## What this covers

- Create buckets, users/keys, and policies on the rustfs instance.
- Wire apps via the `s3-storage` extension env fragments
  (app-specific `<APP>__storage__*` / `SPACES_*` var shapes).

- Apps without native S3 support mount a bucket as a volume via the
  `s3-rclone` skill (rclone docker volume plugin) — create the bucket and
  user here first.

## Instance facts

- API on port 9000, console on 9001 (step-ca variant: `S3_VIRTUAL_HOST` /
  `UI_VIRTUAL_HOST` via `VIRTUAL_HOST_MULTIPORTS`).
- Credentials: `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` from the stack's
  `.env` (never from `.env.example` defaults in production).

## Guardrails

- Destructive operations (deleting buckets/objects/users/policies) ALWAYS
  require explicit user confirmation.
- The live instance may back real apps — never delete data to "free space"
  without confirmation.
- For hands-off delegation use the `rustfs-admin` subagent.
