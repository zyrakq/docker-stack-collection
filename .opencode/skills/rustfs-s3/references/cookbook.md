# RustFS S3 — Cookbook

RustFS is S3-compatible: use the MinIO client (`mc`) or `aws` CLI against
endpoint `http://<s3-endpoint>:9000` (or the S3 virtual host on the step-ca
variant). Alias setup:

```bash
mc alias set rustfs http://<s3-endpoint>:9000 "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
```

## Buckets

```bash
mc mb rustfs/<bucket>
mc ls rustfs
mc ls --recursive rustfs/<bucket>
```

## Users / keys / policies

```bash
# Create a user with its own keypair
mc admin user add rustfs <username>
# Policy: write JSON, then create + attach
mc admin policy create rustfs <policy-name> <policy.json>
mc admin policy attach rustfs <policy-name> --user <username>
# List
mc admin user list rustfs
mc admin policy list rustfs
```

Minimal read-write bucket policy JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::<bucket>", "arn:aws:s3:::<bucket>/*"]
    }
  ]
}
```

## Wiring an app (s3-storage extension)

1. Create the bucket + a dedicated user/policy (least privilege).
2. Copy the extension fragment shape from the embedded s3-storage
   fragments in the `stack-conventions` skill
   (`references/patterns.md` §8) — env-only fragments
   (`<APP>__storage__*` or `SPACES_*` var shapes).
3. Fill the app's `.env` with endpoint, key id, secret, bucket.
4. Verify with a round-trip per the `stack-test` skill (put/get/delete).

## Bucket for an S3 volume (s3-volumes)

For apps without native S3 (rclone docker volume plugin, `s3-volumes`
skill): create one bucket per volume plus a dedicated user/policy, then put
bucket, endpoint (reachable from the HOST), key id and secret into the
extension's `.env`. Verify with `mc ls rustfs/<bucket>` after writing a
file in the mount.

## Round-trip smoke test

```bash
echo test | mc pipe rustfs/<bucket>/smoke-test.txt
mc cat rustfs/<bucket>/smoke-test.txt
mc rm rustfs/<bucket>/smoke-test.txt
```
