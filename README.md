# provisions

Secret-free bootstrap & installer scripts for AI coding agents (Claude Code & Codex).

**Everything in this repo is safe to be public.** No secrets, no API keys, no private-repo
references — ever. All configuration is supplied at runtime via environment variables.
A gitleaks scan runs on every push/PR to keep it that way.

---

## `install-hindsight.sh`

Non-interactively installs the [Hindsight](https://hindsight.vectorize.io) cloud memory
integration into Claude Code and/or Codex. It:

1. installs the `hindsight` CLI (version-pinned to avoid GitHub API rate limits),
2. writes `~/.hindsight/config` (`api_url` + `api_key`, `chmod 600`),
3. drops the `hindsight` skill into each agent's skills dir (`~/.claude/skills`, `~/.codex/skills`).

### Configuration (environment variables)

| Variable | Required | Default | Notes |
|---|:---:|---|---|
| `HINDSIGHT_API_KEY` | ✅ | — | Hindsight Cloud API key (**secret**) |
| `HINDSIGHT_BANK_ID` | | — | Set → **team mode** (one shared bank). Unset → **personal mode** (dual banks derived at runtime). |
| `HINDSIGHT_BANK_PREFIX` | | `me` | Personal-mode bank prefix → `<prefix>-core` + `<prefix>-<repo-slug>` |
| `HINDSIGHT_API_URL` | | `https://api.hindsight.vectorize.io` | Override for self-hosted |
| `HINDSIGHT_APP` | | `auto` | `auto` \| `all` \| `claude` \| `codex` \| `opencode`, or a comma list |
| `HINDSIGHT_CLI_VERSION` | | latest (auto-resolved) | Pin for reproducible installs, e.g. `v0.7.1` |
| `HINDSIGHT_INSTALL_DIR` | | `~/.local/bin` | CLI install location (must be on `PATH`) |

### Usage (in a hosted environment's setup script)

Set `HINDSIGHT_API_KEY` and `HINDSIGHT_BANK_ID` as **secret environment variables** in the
environment's settings, then fetch the script **pinned to a commit SHA** (not a branch — so the
executed code can't change underneath you):

```bash
curl -fsSL https://raw.githubusercontent.com/travis-edgar/provisions/<COMMIT_SHA>/install-hindsight.sh | bash
```

### Network egress required

`hindsight.vectorize.io`, `github.com` + `objects.githubusercontent.com` (release CDN),
and `raw.githubusercontent.com` (to fetch the script itself).

---

## `install-gh.sh`

Non-interactively installs the GitHub CLI (`gh`) into Claude Code and/or Codex environments.
Useful for automated workflows that need direct GitHub API access or repository operations
via `gh run`, `gh pr`, `gh issue`, etc.

### Configuration (environment variables)

| Variable | Required | Default | Notes |
|---|:---:|---|---|
| `GH_TOKEN` or `GITHUB_TOKEN` | | — | GitHub Personal Access Token (**secret**). Scopes: `repo`, `workflow`. If set, wires git to use gh credentials. |
| `GH_VERSION` | | latest (auto-resolved) | Pin gh version for reproducible installs, e.g. `2.63.0` |
| `GH_INSTALL_DIR` | | `~/.local/bin` | CLI install location (must be on `PATH`) |

### Usage (in a hosted environment's setup script)

If you need GitHub API access, set `GH_TOKEN` as a **secret environment variable** in your
cloud setup, then fetch the script **pinned to a commit SHA**:

```bash
export GH_TOKEN="$YOUR_SECRET_GITHUB_TOKEN"
curl -fsSL https://raw.githubusercontent.com/travis-edgar/provisions/<COMMIT_SHA>/install-gh.sh | bash
```

If no `GH_TOKEN` is set, `gh` installs but runs unauthenticated (subject to GitHub's 60
req/hr per-IP rate limit).

### Network egress required

`github.com` + `objects.githubusercontent.com` (release CDN), and `raw.githubusercontent.com`
(to fetch the script itself).

---

## Conventions

- **No secrets, no private-repo references.** If a value is environment-specific, it's an env var.
- **Consumers pin to a commit SHA**, never a moving branch.
- Protect `main` (require PR review) so a single account can't silently change what runs everywhere.
