---
name: Readme Gen
description: >-
  Generate or regenerate stack READMEs in the collection's two canonical
  styles: stack-root hub README and component README (~100-250 lines),
  documenting the product's base parts and extension statuses from its
  DEPLOYMENT.md. Use when creating a stack or modernizing one.
---

# Readme Gen

Load the `stack-conventions` skill first. Full templates with placeholders:
read `references/templates.md`.

## Canonical templates

`references/templates.md` (fully embedded) is the canon for both styles —
component and hub README. Module READMEs
(`modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`)
are REUSED verbatim — never rewrite them.

## Rules

1. 100% English.
2. An emoji on EVERY heading.
3. Every command fenced with a language tag (```bash, ```sh, ...).
4. Document letsencrypt / step-ca / OIDC variants when present.
5. NEVER present `build/` as editable — it is auto-generated; say so in Notes.
6. Hub README links each component (`app/README.md`,
   `modules/ssl-automation/*`) with a one-two sentence blurb.
7. Component README is ~100-250 lines and follows the template section order
   exactly (Quick Start → Product Parts → Project Structure →
   Available Configurations → Environment Variables → Networks →
   Security → Troubleshooting → Notes).
8. Environment variables grouped Base / Let's Encrypt / Step CA / OIDC /
   Step CA Trust, formatted `- `NAME`: description (default: X)`.
9. Document the product's base parts and every extension's status
   (`available` / `implemented` / `refused`) from the stack's
   `DEPLOYMENT.md` (stack-conventions §20) — in the Product Parts and
   Extensions sections. A stack without DEPLOYMENT.md → run the
   `stack-analysis` skill gap mode first.

## Workflow

1. Read the stack's `DEPLOYMENT.md` (base parts, extension catalog,
   statuses — §20) FIRST, then `stackbuilder.toml`, `components/**`, and
   existing READMEs to learn environments, extensions, ports, and
   variables.
2. Generate the component README(s) from the template.
3. Generate the hub README from the template.
4. Cross-check: every env var in `.env.example` files is documented; every
   documented variant exists in `stackbuilder.toml`; every DEPLOYMENT.md
   base part and catalog extension appears in the README with the correct
   status.
