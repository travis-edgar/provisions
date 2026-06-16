#!/usr/bin/env bash
#
# install-gh.sh — Non-interactive GitHub CLI (gh) installer for Claude Code and
# OpenAI Codex hosted/dev environments. Mirrors install-hindsight.sh.
#
# SAFE TO HOST PUBLICLY: contains no secrets and no org-specific values.
# Authentication is read from environment variables at runtime.
#
# Optional env:
#   GH_TOKEN / GITHUB_TOKEN  GitHub Personal Access Token (secret). When set, the
#                            script wires git to use gh credentials and verifies
#                            auth. gh also reads this token directly at runtime.
#   GH_VERSION               Pin gh version, e.g. 2.63.0 (default: resolve latest)
#   GH_INSTALL_DIR           CLI binary install dir       (default: ~/.local/bin)
#
# Usage (in a hosted setup script):
#   export GH_TOKEN="$YOUR_SECRET_ENV_VAR"
#   curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/<ref>/install-gh.sh | bash
#
set -euo pipefail

log()  { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

GH_INSTALL_DIR="${GH_INSTALL_DIR:-$HOME/.local/bin}"

# ---- 1) Resolve OS/arch in gh's release-asset naming -----------------------
_os="$(uname -s)"; _arch="$(uname -m)"
case "$_os" in
  Linux)  gh_os="linux"; gh_ext="tar.gz" ;;
  Darwin) gh_os="macOS"; gh_ext="zip" ;;
  *) warn "unsupported OS: $_os"; exit 1 ;;
esac
case "$_arch" in
  x86_64|amd64)  gh_arch="amd64" ;;
  aarch64|arm64) gh_arch="arm64" ;;
  *) warn "unsupported arch: $_arch"; exit 1 ;;
esac

# ---- 2) Resolve the latest version via the GitHub *web* redirect rather than
#         the unauthenticated REST API (60/hr per IP, shared across runners).
#         Pinning GH_VERSION skips this entirely. -----------------------------
if [ -z "${GH_VERSION:-}" ]; then
  _loc="$(curl -sI https://github.com/cli/cli/releases/latest 2>/dev/null \
            | tr -d '\r' | awk -F': ' 'tolower($1)=="location"{print $2}' || true)"
  GH_VERSION="$(printf '%s' "$_loc" | sed -E 's#.*/tag/v?##')"
fi
[ -n "${GH_VERSION:-}" ] || { warn "could not resolve gh version; set GH_VERSION"; exit 1; }
log "Installing GitHub CLI v${GH_VERSION} (${gh_os}/${gh_arch}) -> ${GH_INSTALL_DIR}"

# ---- 3) Download + extract just the gh binary ------------------------------
_tmp="$(mktemp -d)"; trap 'rm -rf "$_tmp"' EXIT
_pkg="gh_${GH_VERSION}_${gh_os}_${gh_arch}.${gh_ext}"
_url="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${_pkg}"
log "Downloading ${_url}"
curl -fsSL "$_url" -o "$_tmp/${_pkg}"
if [ "$gh_ext" = "tar.gz" ]; then
  tar -xzf "$_tmp/${_pkg}" -C "$_tmp"
else
  unzip -q "$_tmp/${_pkg}" -d "$_tmp"
fi
_bin="$(find "$_tmp" -type f -name gh -path '*/bin/gh' | head -1)"
[ -n "$_bin" ] || { warn "gh binary not found inside ${_pkg}"; exit 1; }
mkdir -p "$GH_INSTALL_DIR"
install -m 0755 "$_bin" "$GH_INSTALL_DIR/gh"
export PATH="$GH_INSTALL_DIR:$PATH"
log "Installed: $("$GH_INSTALL_DIR/gh" --version | head -1)"

# ---- 4) Configure auth from the env token (optional) -----------------------
_tok="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -n "$_tok" ]; then
  # gh reads GH_TOKEN/GITHUB_TOKEN from the env for API calls automatically;
  # setup-git makes plain `git` push/clone over HTTPS use those credentials too.
  if GH_TOKEN="$_tok" gh auth setup-git 2>/dev/null; then
    log "git configured to use gh credentials (gh auth setup-git)"
  else
    warn "gh auth setup-git failed (non-fatal); gh API calls still use the env token"
  fi
  if GH_TOKEN="$_tok" gh auth status 2>&1 | grep -qi "Logged in"; then
    log "gh authenticated"
  else
    warn "gh not authenticated — check the token value and scopes (repo, workflow)"
  fi
else
  warn "GH_TOKEN/GITHUB_TOKEN not set — gh installed but unauthenticated."
  warn "Set GH_TOKEN as a secret env var (scopes: repo, workflow) to authenticate."
fi

log "Done. Ensure ${GH_INSTALL_DIR} is on PATH:  export PATH=\"${GH_INSTALL_DIR}:\$PATH\""
