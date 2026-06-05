#!/usr/bin/env bash
#
# install-hindsight.sh — Non-interactive Hindsight (cloud mode) installer
# for Claude Code and OpenAI Codex hosted/dev environments.
#
# SAFE TO HOST PUBLICLY: contains no secrets and no org-specific values.
# Every piece of configuration is read from environment variables at runtime.
#
# Required env:
#   HINDSIGHT_API_KEY      Hindsight Cloud API key            (secret)
#
# Optional env:
#   HINDSIGHT_BANK_ID      Team bank id. If set -> team mode (one shared bank).
#                          If unset -> personal mode (dual banks derived at runtime).
#   HINDSIGHT_BANK_PREFIX  Personal-mode bank prefix          (default: me)
#   HINDSIGHT_API_URL      Cloud API base URL        (default: https://api.hindsight.vectorize.io)
#   HINDSIGHT_APP          Target agent(s): auto | all | claude | codex | opencode,
#                          or a comma-separated list           (default: auto)
#   HINDSIGHT_CLI_VERSION  Pin CLI version, e.g. v0.7.1  (default: auto-resolve latest)
#   HINDSIGHT_INSTALL_DIR  CLI binary install dir               (default: ~/.local/bin)
#   CLAUDE_CONFIG_DIR      Override Claude config dir            (default: ~/.claude)
#   CODEX_HOME             Override Codex config dir             (default: ~/.codex)
#
# Usage (in a hosted setup script):
#   export HINDSIGHT_API_KEY="$YOUR_SECRET_ENV_VAR"
#   export HINDSIGHT_BANK_ID="team-myproject"
#   curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/<ref>/install-hindsight.sh | bash
#
set -euo pipefail

log()  { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

# ---- Required configuration (no defaults; fail loud) ------------------------
: "${HINDSIGHT_API_KEY:?HINDSIGHT_API_KEY is required (set it as a secret env var)}"

# ---- Bank configuration -----------------------------------------------------
# Team mode: HINDSIGHT_BANK_ID set -> one shared bank baked into the skill.
# Personal mode: HINDSIGHT_BANK_ID unset -> dual banks derived at runtime
# (<prefix>-core + <prefix>-<repo-slug>); HINDSIGHT_BANK_PREFIX defaults to "me".
HINDSIGHT_BANK_ID="${HINDSIGHT_BANK_ID:-}"
# Trim surrounding whitespace so a blank-ish HINDSIGHT_BANK_ID -> personal mode
HINDSIGHT_BANK_ID="$(printf '%s' "$HINDSIGHT_BANK_ID" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
HINDSIGHT_BANK_PREFIX="${HINDSIGHT_BANK_PREFIX:-me}"

# ---- Optional configuration -------------------------------------------------
HINDSIGHT_API_URL="${HINDSIGHT_API_URL:-https://api.hindsight.vectorize.io}"
HINDSIGHT_APP="${HINDSIGHT_APP:-auto}"

# ---- 1) Install the Hindsight CLI ------------------------------------------
# Resolve the version via the GitHub *web* redirect rather than the unauthenticated
# REST API, which is rate-limited to 60/hr per IP and shared across hosted runners.
# Pinning HINDSIGHT_CLI_VERSION makes get-cli skip the API call entirely.
if [ -z "${HINDSIGHT_CLI_VERSION:-}" ]; then
  _loc="$(curl -sI https://github.com/vectorize-io/hindsight/releases/latest 2>/dev/null \
            | tr -d '\r' | awk -F': ' 'tolower($1)=="location"{print $2}' || true)"
  _ver="$(printf '%s' "$_loc" | sed -E 's#.*/tag/##')"
  if [ -n "$_ver" ]; then export HINDSIGHT_CLI_VERSION="$_ver"; fi
fi
log "Installing Hindsight CLI (version: ${HINDSIGHT_CLI_VERSION:-latest-via-API-fallback})"
curl -fsSL https://hindsight.vectorize.io/get-cli | bash
export PATH="${HINDSIGHT_INSTALL_DIR:-$HOME/.local/bin}:$PATH"

# ---- 2) Write the cloud config (api_url + api_key) -------------------------
log "Writing ~/.hindsight/config"
mkdir -p "$HOME/.hindsight"
umask 077
cat > "$HOME/.hindsight/config" <<EOF
api_url = "$HINDSIGHT_API_URL"
api_key = "$HINDSIGHT_API_KEY"
EOF
chmod 600 "$HOME/.hindsight/config"

# ---- 3) Decide which agent skills directories to populate ------------------
skills_dir_for() {
  case "$1" in
    claude)   printf '%s/skills' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
    codex)    printf '%s/skills' "${CODEX_HOME:-$HOME/.codex}" ;;
    opencode) printf '%s/skills' "$HOME/.opencode" ;;
    *)        return 1 ;;
  esac
}

declare -a APPS=()
case "$HINDSIGHT_APP" in
  auto)
    if [ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]; then APPS+=(claude); fi
    if [ -d "${CODEX_HOME:-$HOME/.codex}" ];         then APPS+=(codex); fi
    if [ -d "$HOME/.opencode" ];                     then APPS+=(opencode); fi
    if [ "${#APPS[@]}" -eq 0 ]; then APPS=(claude); fi   # nothing detected -> safe default
    ;;
  all) APPS=(claude codex opencode) ;;
  *)   IFS=',' read -r -a APPS <<< "$HINDSIGHT_APP" ;;
esac

# ---- 4) Render the SKILL.md and install per app ----------------------------
# Two render functions, each using a quoted heredoc so backticks / $ stay
# literal inside. Mode is selected by whether HINDSIGHT_BANK_ID is set.

render_team_skill() {
cat <<'SKILL_EOF'
---
name: hindsight
description: Store team knowledge, project conventions, and learnings from tasks. Use to remember what works and recall context before new tasks. This is a shared team memory bank.
---

# Hindsight Memory Skill (Cloud, team bank)

You have persistent memory via the **Hindsight CLI** (`hindsight`). This bank is **shared with the team**, so knowledge stored here benefits everyone on this codebase.

## Commands

Store (`retain`):

```bash
hindsight memory retain BANK_ID "Project uses ESLint (Airbnb) + Prettier" --context procedures
hindsight memory retain BANK_ID "Build fails on Node 18, works on Node 20" --context learnings
hindsight memory retain BANK_ID "Chose Postgres over Mongo for strong consistency" --context decision
```

Recall (`recall`) BEFORE starting tasks:

```bash
hindsight memory recall BANK_ID "project conventions and coding standards" --budget mid
hindsight memory recall BANK_ID "issues we have hit before" --fact-type experience
```

Reflect (`reflect`) to synthesize:

```bash
hindsight memory reflect BANK_ID "How should I approach this based on past work?" --budget high
```

`recall` accepts `--budget low|mid|high` and `--fact-type world|experience|opinion`. `retain` accepts `--context <label>` and `-d/--doc-id <id>` for idempotent updates.

## Context labels

Use one of: `decision`, `gotcha`, `pattern`, `procedures`, `learnings`, `preferences`.

## When to store (do not wait to be asked)

- A decision was made → `--context decision`
- A bug/gotcha was solved → `--context gotcha`
- A reusable pattern emerged → `--context pattern`
- A command/config that worked or failed → `--context procedures`/`learnings`
- Individual preference → `--context preferences`, and name the person ("Alice prefers …")

## When to recall

Always recall before: starting a non-trivial task, choosing tools/libraries/approaches, writing code in a new area, or answering "how does X work?"
SKILL_EOF
}

render_personal_skill() {
cat <<'SKILL_EOF'
---
name: hindsight
description: Persistent personal memory via the Hindsight CLI. Capture decisions, gotchas, and patterns; recall context before non-trivial work. Routes knowledge between a cross-project core bank and a per-project bank.
---

# Hindsight Memory Skill (CLI, personal dual-bank)

You have persistent memory via the **Hindsight CLI** (`hindsight`), split across two banks:

- **Core bank — `PREFIX-core`** — knowledge that survives project/role changes: preferences, reusable patterns, people, career decisions, cross-project gotchas.
- **Project bank — `PREFIX-<repo-slug>`** — codebase-specific: architecture decisions, project gotchas, session notes. Derive `<repo-slug>` from the current git repo's directory name, lowercased, with runs of non-alphanumerics collapsed to single hyphens (e.g. `One-Cloud_Costs` → `PREFIX-one-cloud-costs`).

## Routing — which bank?

Ask: "Would this help me on a completely different project?"

| Answer | Bank |
|--------|------|
| Yes — preference, reusable pattern, person, cross-project gotcha | `PREFIX-core` |
| No — references files/modules/services in this repo | `PREFIX-<repo-slug>` |
| Maybe / cross-cutting | retain to both |

## Commands

Store (`retain`):

```bash
hindsight memory retain PREFIX-core "I prefer squash-merge for feature branches" --context preferences
hindsight memory retain PREFIX-<repo-slug> "Auth tokens refresh via /oauth/refresh; 401 retries once" --context gotcha
```

Recall (`recall`) BEFORE non-trivial work:

```bash
hindsight memory recall PREFIX-<repo-slug> "auth architecture and known issues" --budget mid
hindsight memory recall PREFIX-core "my testing conventions" --fact-type experience
```

Reflect (`reflect`) to synthesize:

```bash
hindsight memory reflect PREFIX-core "What patterns recur across my projects?" --budget high
```

`recall` accepts `--budget low|mid|high` and `--fact-type world|experience|opinion`. `retain` accepts `--context <label>` and `-d/--doc-id <id>` for idempotent updates.

## Context labels

Use one of: `decision`, `gotcha`, `pattern`, `procedures`, `learnings`, `preferences`.

## When to capture (do not wait to be asked)

- A decision was made → `--context decision` (route per the table above)
- A bug/gotcha was solved → `--context gotcha`
- A reusable pattern emerged → `--context pattern` (usually `PREFIX-core`)
- Work completed → retain a short session note

## When to recall

Always recall before: starting non-trivial work, choosing tools/approaches, working in a new area, or answering "how does X work?"
SKILL_EOF
}

if [ -n "$HINDSIGHT_BANK_ID" ]; then
  SKILL_MD="$(render_team_skill)"
  SKILL_MD="${SKILL_MD//BANK_ID/$HINDSIGHT_BANK_ID}"
else
  SKILL_MD="$(render_personal_skill)"
  SKILL_MD="${SKILL_MD//PREFIX/$HINDSIGHT_BANK_PREFIX}"
fi

for app in "${APPS[@]}"; do
  dir="$(skills_dir_for "$app")" || { warn "unknown app '$app' (use claude|codex|opencode) — skipping"; continue; }
  mkdir -p "$dir/hindsight"
  printf '%s\n' "$SKILL_MD" > "$dir/hindsight/SKILL.md"
  log "Installed skill -> $dir/hindsight/SKILL.md  (app=$app)"
done

# ---- Done -------------------------------------------------------------------
log "Done."
printf '    CLI:    %s\n' "$(command -v hindsight || echo 'NOT FOUND on PATH — set HINDSIGHT_INSTALL_DIR to a dir on PATH')"
if [ -n "$HINDSIGHT_BANK_ID" ]; then
  printf '    Config: %s (api_url=%s, bank=%s)\n' "$HOME/.hindsight/config" "$HINDSIGHT_API_URL" "$HINDSIGHT_BANK_ID"
else
  printf '    Config: %s (api_url=%s, banks=%s-core + %s-<repo-slug>)\n' "$HOME/.hindsight/config" "$HINDSIGHT_API_URL" "$HINDSIGHT_BANK_PREFIX" "$HINDSIGHT_BANK_PREFIX"
fi
printf '    Apps:   %s\n' "${APPS[*]}"
