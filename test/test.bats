load assertions
load test_helper

@test "errors when unknown command is provided" {
    run bash $SUMO crash-hard
    [ "$status" -eq 2 ]
    [ "${lines[0]}" = "sumo.sh: unrecognized command 'crash-hard'" ]
}

@test "errors when unknown flag is provided" {
    run bash $SUMO --unknown
    [ "$status" -eq 2 ]
    [ "${lines[0]}" = "sumo.sh: unrecognized option '--unknown'" ]
}

@test "exits if it cannot find repository root" {
    cd "$REPO"
    run bash $SUMO full
    [ "$status" -eq 1 ]
}

@test "creates a new repository" {
    # Repository gets created and asserted in setup
    [ -h "${REPO}/checksums" ]
    [ -d "${REPO}/remotes" ]
    [ -d "${REPO}/remotes/batrepo" ]
    assert_file_empty ../repo/remotes/batrepo/checksums
    assert_file_contains batrepo ../repo/id
    assert_file_contains "${SRC}/" ../repo/root
}

@test "finds repository root" {
    dirs=asd/foo/bar/baz/this/is/a/deep/path
    mkdir -p "${dirs}"
    cd "${dirs}"
    run bash $SUMO full
    assert_success
    run bash $SUMO --root "$REPO" full
    assert_success
}

@test "generates full digest" {
    run bash $SUMO full
    assert_success
    assert_output_equals <<EOF
A bar
A baz
A foo
EOF
    [ -h "${REPO}/checksums" ]

    run wc -l < "$REPO/checksums"
    [ "$output" -eq 3 ]

    b2sum --tag bar baz foo > reference
    assert_files_equal reference "${REPO}/checksums"
}

@test "detects removed files" {
    run bash $SUMO full
    rm bar
    run bash $SUMO check
    assert_success
    [ "$output" = "D bar" ]
}

@test "lists known files" {
    run bash $SUMO full
    assert_success
    run bash $SUMO known-files
    assert_success
    assert_output_equals <<EOF
bar
baz
foo
EOF
}

@test "lists updated files" {
    run bash $SUMO full
    assert_success
    echo something > foo
    run bash $SUMO check
    assert_success
    [ "$output" = "U foo" ]
}

@test "selects filenames from checksum file" {
    bash $SUMO full
    run bash $SUMO select-filenames < "${REPO}/checksums"
    assert_output_equals <<EOF
bar
baz
foo
EOF
}

@test "lists unknown files" {
    bash $SUMO full
    echo asd > asd
    run bash $SUMO unknown-files
    assert_success
    [ "$output" = "asd" ]
}

@test "verifies known files" {
    bash $SUMO full
    run bash $SUMO verify
    assert_success
    assert_output_equals <<EOF
bar: OK
baz: OK
foo: OK
EOF
}

@test "updates added files" {
    bash $SUMO full
    echo new > new
    run bash $SUMO update
    [ "$status" -eq 0 ]
    [ "$output" = "A new" ]
    rehash foo bar baz new > reference
    assert_files_equal "${REPO}/checksums" reference
}

@test "updates updated files" {
    bash $SUMO full
    rm foo
    echo new > foo
    run bash $SUMO update
    assert_success
    [ "$output" = "U foo" ]
    [ "${lines[0]}" = "U foo" ]
    rehash $FILES > reference
    assert_files_equal "${REPO}/checksums" reference
}

@test "updates deleted files" {
    bash $SUMO full
    rm foo
    run bash $SUMO check
    assert_success
    [ "$output" = "D foo" ]
    run bash $SUMO update
    assert_success
    [ "$output" = "D foo" ]
    rehash bar baz > reference
    assert_files_equal "${REPO}/checksums" reference
}
