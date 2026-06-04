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
