#!/usr/bin/env bats

setup() {
    load test_helper
    setup_test_env
    export DOTFILES_BACKUP_PASSPHRASE="test-passphrase"
}

teardown() {
    teardown_test_env
}

@test "backup and restore roundtrip preserves local files" {
    "$TEST_DOTFILES/scripts/local.sh" init

    mkdir -p "$TEST_DOTFILES/local/git"
    printf '[user]\n    name = Backed Up\n    email = backup@test.com\n' \
        >"$TEST_DOTFILES/local/git/.gitconfig-github"

    local backup_file="$TEST_HOME/local-test.enc"
    "$TEST_DOTFILES/scripts/local.sh" backup "$backup_file"
    [ -f "$backup_file" ]

    rm -rf "$TEST_DOTFILES/local"

    run "$TEST_DOTFILES/scripts/local.sh" restore "$backup_file"

    [ "$status" -eq 0 ]
    [ -f "$TEST_DOTFILES/local/git/.gitconfig" ]
    [ -f "$TEST_DOTFILES/local/git/.gitconfig-github" ]
    [ -f "$TEST_DOTFILES/local/npm/.npmrc" ]
    [ -f "$TEST_DOTFILES/local/secrets/secrets-map.json" ]

    grep -q 'Backed Up' "$TEST_DOTFILES/local/git/.gitconfig-github"
}

@test "restore fails on conflict without --overwrite" {
    "$TEST_DOTFILES/scripts/local.sh" init

    local backup_file="$TEST_HOME/local-test.enc"
    "$TEST_DOTFILES/scripts/local.sh" backup "$backup_file"

    run "$TEST_DOTFILES/scripts/local.sh" restore "$backup_file"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Restore aborted"* ]]
}

@test "restore succeeds with --overwrite flag" {
    "$TEST_DOTFILES/scripts/local.sh" init

    local backup_file="$TEST_HOME/local-test.enc"
    "$TEST_DOTFILES/scripts/local.sh" backup "$backup_file"

    echo "modified" >"$TEST_DOTFILES/local/git/.gitconfig"

    run "$TEST_DOTFILES/scripts/local.sh" restore --overwrite "$backup_file"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Restore complete"* ]]

    grep -q 'autocrlf' "$TEST_DOTFILES/local/git/.gitconfig"
    ! grep -q 'modified' "$TEST_DOTFILES/local/git/.gitconfig"
}

@test "init after restore fills gaps" {
    "$TEST_DOTFILES/scripts/local.sh" init

    local backup_file="$TEST_HOME/local-test.enc"
    "$TEST_DOTFILES/scripts/local.sh" backup "$backup_file"

    rm -rf "$TEST_DOTFILES/local"

    "$TEST_DOTFILES/scripts/local.sh" restore "$backup_file"

    rm "$TEST_DOTFILES/local/npm/.npmrc"

    run "$TEST_DOTFILES/scripts/local.sh" init

    [ "$status" -eq 0 ]
    [[ "$output" == *"seeded: npm/.npmrc"* ]]
    [[ "$output" == *"exists: git/.gitconfig"* ]]
    [ -f "$TEST_DOTFILES/local/npm/.npmrc" ]
}
