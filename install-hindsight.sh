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
#   HINDSIGHT_BANK_ID      Memory bank / namespace id         (e.g. team-myproject)
#
# Optional env:
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
: "${HINDSIGHT_BANK_ID:?HINDSIGHT_BANK_ID is required (your Hindsight memory bank id)}"

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

# ---- 4) Render the SKILL.md (BANK_ID substituted) and install per app ------
# Embedded with a quoted heredoc so backticks / $ stay literal; BANK_ID is a
# placeholder substituted via bash parameter expansion (delimiter-safe).
SKILL_RAW="$(cat <<'SKILL_EOF'
---
name: hindsight
description: Store team knowledge, project conventions, and learnings from tasks. Use to remember what works and recall context before new tasks. This is a shared team memory bank.
---

# Hindsight Memory Skill (Cloud)

You have persistent memory via **Hindsight Cloud**. This memory bank is **shared with the team**, so knowledge stored here benefits everyone working on this codebase.

**Proactively store team knowledge and recall context** to provide better assistance.

## Commands

### Store a memory

Use `memory retain` to store what you learn:

```bash
hindsight memory retain BANK_ID "Project uses ESLint with Airbnb config and Prettier for formatting"
hindsight memory retain BANK_ID "Running tests requires NODE_ENV=test" --context procedures
hindsight memory retain BANK_ID "Build failed when using Node 18, works with Node 20" --context learnings
hindsight memory retain BANK_ID "Alice prefers verbose commit messages with context" --context preferences
```

### Recall memories

Use `memory recall` BEFORE starting tasks to get relevant context:

```bash
hindsight memory recall BANK_ID "project conventions and coding standards"
hindsight memory recall BANK_ID "Alice preferences for this project"
hindsight memory recall BANK_ID "what issues have we encountered before"
hindsight memory recall BANK_ID "how does the auth module work"
```

### Reflect on memories

Use `memory reflect` to synthesize context:

```bash
hindsight memory reflect BANK_ID "How should I approach this task based on past experience?"
```

## IMPORTANT: When to Store Memories

This is a **shared team bank**. Store knowledge that benefits the team. For individual preferences, include the persons name.

### Project/Team Conventions (shared)
- Coding standards ("Project uses 2-space indentation")
- Required tools and versions ("Project requires Node 20+, PostgreSQL 15+")
- Linting and formatting rules ("ESLint with Airbnb config")
- Testing conventions ("Integration tests require Docker running")
- Branch naming and PR conventions

### Individual Preferences (attribute to person)
- Personal coding style ("Alice prefers explicit type annotations")
- Communication preferences ("Bob prefers detailed PR descriptions")
- Tool preferences ("Carol uses vim keybindings")

### Procedure Outcomes
- Steps that successfully completed a task
- Commands that worked (or failed) and why
- Workarounds discovered
- Configuration that resolved issues

### Learnings from Tasks
- Bugs encountered and their solutions
- Performance optimizations that worked
- Architecture decisions and rationale
- Dependencies or version requirements

### Team Knowledge
- Onboarding information for new team members
- Common pitfalls and how to avoid them
- Architecture decisions and their rationale
- Integration points with external systems
- Domain knowledge and business logic explanations

## IMPORTANT: When to Recall Memories

**Always recall** before:
- Starting any non-trivial task
- Making decisions about implementation
- Suggesting tools, libraries, or approaches
- Writing code in a new area of the project
- When answering questions about the codebase
- When a team member asks how something works

## Best Practices

1. **Store immediately**: When you discover something, store it right away
2. **Be specific**: Store "npm test requires --experimental-vm-modules flag" not "tests need a flag"
3. **Include outcomes**: Store what worked AND what did not work
4. **Recall first**: Always check for relevant context before starting work
5. **Think team-first**: Store knowledge that would help other team members
6. **Attribute individual preferences**: Store "Alice prefers X" not just "User prefers X"
7. **Distinguish project vs personal**: Project conventions apply to everyone; personal preferences are per-person
SKILL_EOF
)"
SKILL_MD="${SKILL_RAW//BANK_ID/$HINDSIGHT_BANK_ID}"

for app in "${APPS[@]}"; do
  dir="$(skills_dir_for "$app")" || { warn "unknown app '$app' (use claude|codex|opencode) — skipping"; continue; }
  mkdir -p "$dir/hindsight"
  printf '%s\n' "$SKILL_MD" > "$dir/hindsight/SKILL.md"
  log "Installed skill -> $dir/hindsight/SKILL.md  (app=$app)"
done

# ---- Done -------------------------------------------------------------------
log "Done."
printf '    CLI:    %s\n' "$(command -v hindsight || echo 'NOT FOUND on PATH — set HINDSIGHT_INSTALL_DIR to a dir on PATH')"
printf '    Config: %s (api_url=%s, bank=%s)\n' "$HOME/.hindsight/config" "$HINDSIGHT_API_URL" "$HINDSIGHT_BANK_ID"
printf '    Apps:   %s\n' "${APPS[*]}"
