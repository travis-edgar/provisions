#!/usr/bin/env bats

load helpers/common

setup() {
    unset HINDSIGHT_BANK_ID HINDSIGHT_BANK_PREFIX HINDSIGHT_APP
    make_temp_home
    mock_curl
    export HINDSIGHT_API_KEY="hsk_test_fake_key_not_real"
    export HINDSIGHT_API_URL="https://api.hindsight.vectorize.io"
}

teardown() {
    teardown_mocks
    teardown_temp_home
}

@test "team mode: BANK_ID set renders a single-bank skill" {
    export HINDSIGHT_BANK_ID="team-myproject"

    run bash "$INSTALL_SCRIPT"

    [ "$status" -eq 0 ]
    [ -f "$(skill_path)" ]
    grep -q "team-myproject" "$(skill_path)"
}

@test "personal mode: BANK_ID unset renders dual-bank skill with prefix" {
    unset HINDSIGHT_BANK_ID
    export HINDSIGHT_BANK_PREFIX="travis"

    run bash "$INSTALL_SCRIPT"

    [ "$status" -eq 0 ]
    [ -f "$(skill_path)" ]
    grep -q "travis-core" "$(skill_path)"
    grep -qi "repo-slug" "$(skill_path)"
    grep -qi "Routing" "$(skill_path)"
}

@test "skill documents real recall flags, not deprecated tags" {
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    grep -q -- "--budget" "$(skill_path)"
    grep -q -- "--fact-type" "$(skill_path)"
    ! grep -q -- "--document-tags" "$(skill_path)"
}

@test "skill documents the reconciled context vocabulary" {
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    for label in decision gotcha pattern procedures learnings preferences; do
        grep -q "$label" "$(skill_path)"
    done
}

@test "team mode does not leak personal dual-bank markers" {
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    ! grep -q "repo-slug" "$(skill_path)"
}

@test "personal mode does not leak team-bank framing" {
    export HINDSIGHT_BANK_PREFIX="travis"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    ! grep -qi "shared with the team" "$(skill_path)"
}

@test "auto app-selection installs only for detected agents" {
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/skills/hindsight/SKILL.md" ]
    [ ! -f "$TEST_HOME/.codex/skills/hindsight/SKILL.md" ]
}

@test "explicit app list installs for each named agent" {
    export HINDSIGHT_BANK_ID="team-x"
    export HINDSIGHT_APP="claude,codex"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/skills/hindsight/SKILL.md" ]
    [ -f "$TEST_HOME/.codex/skills/hindsight/SKILL.md" ]
}

@test "writes ~/.hindsight/config with api values and mode 0600" {
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.hindsight/config" ]
    grep -q 'api_url = ' "$TEST_HOME/.hindsight/config"
    grep -q 'api_key = ' "$TEST_HOME/.hindsight/config"
    [ "$(file_mode "$TEST_HOME/.hindsight/config")" = "600" ]
}

@test "fails loudly when HINDSIGHT_API_KEY is unset" {
    unset HINDSIGHT_API_KEY
    export HINDSIGHT_BANK_ID="team-x"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -ne 0 ]
}

@test "whitespace-only BANK_ID is treated as personal mode" {
    export HINDSIGHT_BANK_ID="   "
    export HINDSIGHT_BANK_PREFIX="travis"
    run bash "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "travis-core" "$(skill_path)"
}
