# Security Policy

## Reporting a vulnerability

Found a security issue — a way these scripts could leak credentials, or a
supply-chain concern with how they're fetched and executed? Please report it
privately:

- Preferred: open a private advisory →
  https://github.com/travis-edgar/provisions/security/advisories/new
- Or email: security@travesty.ca  <!-- replace with your address -->

Please do **not** open a public issue for security reports.

## Why this repo is safe to be public

- **Secret-free.** Scripts read all configuration (API keys, bank ids, URLs) from
  environment variables at runtime — nothing sensitive is committed.
- **Pin to a commit SHA**, never a branch, when fetching a script to execute.
- A **gitleaks** scan runs on every push and pull request.
