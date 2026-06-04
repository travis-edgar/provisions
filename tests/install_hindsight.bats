#!/usr/bin/env bats

load helpers/common

setup() {
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
