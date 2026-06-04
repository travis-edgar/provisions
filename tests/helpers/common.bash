#!/usr/bin/env bash
# Common bats helpers for install-hindsight.sh tests.
# Strategy: run the installer end-to-end against a throwaway $HOME with curl
# mocked so nothing downloads and no network/API call is ever made.

INSTALL_SCRIPT="${BATS_TEST_DIRNAME}/../install-hindsight.sh"
MOCK_DIRS=()

# make_temp_home - fresh HOME/CLAUDE_CONFIG_DIR/install dir per test
make_temp_home() {
    export TEST_HOME="${BATS_TMPDIR}/home_$$_${RANDOM}"
    rm -rf "$TEST_HOME"
    mkdir -p "$TEST_HOME/.local/bin"
    export HOME="$TEST_HOME"
    export HINDSIGHT_INSTALL_DIR="$TEST_HOME/.local/bin"
    # default: a Claude agent dir exists so 'auto' selects claude
    mkdir -p "$TEST_HOME/.claude"
    export CLAUDE_CONFIG_DIR="$TEST_HOME/.claude"
}

teardown_temp_home() {
    [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
}

# mock_curl - shadow curl so the version-probe returns a fake tag and the
# get-cli download pipes a harmless no-op into bash. No real egress.
mock_curl() {
    local dir="${BATS_TMPDIR}/mock_$$_${RANDOM}"
    mkdir -p "$dir"
    MOCK_DIRS+=("$dir")
    cat > "$dir/curl" <<'CURL_EOF'
#!/usr/bin/env bash
# Fake curl: enough surface for install-hindsight.sh.
for arg in "$@"; do
  case "$arg" in
    *releases/latest) printf 'location: https://github.com/vectorize-io/hindsight/releases/tag/v9.9.9\r\n'; exit 0 ;;
    *get-cli)         printf ':\n'; exit 0 ;;  # no-op piped into bash
  esac
done
exit 0
CURL_EOF
    chmod +x "$dir/curl"
    export PATH="$dir:$PATH"
}

teardown_mocks() {
    local d
    for d in "${MOCK_DIRS[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done
    MOCK_DIRS=()
}

# skill_path - where the claude skill is rendered for the current TEST_HOME
skill_path() { printf '%s/.claude/skills/hindsight/SKILL.md' "$TEST_HOME"; }
