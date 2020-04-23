rehash() {
    b2sum --tag $* | sort -k 2
}

compare_with_reference() {
    run diff .b2sum .reference
    [ "$status" -eq 0 ]
}

setup() {
    OLD_DIR="$PWD"
    SUMO="${BATS_TEST_DIRNAME}/../sumo.sh"
    TEST_DIR="${BATS_TMPDIR}/test-${BATS_TEST_NUMBER}"
    FILES="foo baz bar"
    rm -rf "$TEST_DIR"
    mkdir "$TEST_DIR"
    cd "$TEST_DIR"
    for each in $FILES; do
        echo $each > $each
    done
    rehash $FILES > .reference
}

teardown() {
    cd "$OLD_DIR"
    rm -rf "$TEST_DIR"
}

@test "generates full digest" {
    run bash $SUMO full
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "A bar" ]
    [ "${lines[1]}" = "A baz" ]
    [ "${lines[2]}" = "A foo" ]
    run wc -l < .b2sum
    [ "$output" -eq 3 ]
    compare_with_reference
}

@test "detects removed files" {
    run bash $SUMO full
    rm bar
    run bash $SUMO check
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "D bar" ]
}

@test "lists known files" {
    run bash $SUMO full
    [ "$status" -eq 0 ]
    run bash $SUMO known-files
    [ "${lines[0]}" = "bar" ]
    [ "${lines[1]}" = "baz" ]
    [ "${lines[2]}" = "foo" ]
}

@test "lists updated files" {
    bash $SUMO full
    echo something > foo
    run bash $SUMO check
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "U foo" ]
}

@test "selects filenames from checksum file" {
    bash $SUMO full
    run bash $SUMO select-filenames < .reference
    select="$output"
    run bash $SUMO known-files
    [ "$select" = "$output" ]
}

@test "lists unknown files" {
    bash $SUMO full
    echo asd > asd
    run bash $SUMO unknown-files
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "asd" ]
}

@test "verifies known files" {
    bash $SUMO full
    run bash $SUMO verify
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "bar: OK" ]
    [ "${lines[1]}" = "baz: OK" ]
    [ "${lines[2]}" = "foo: OK" ]
}

@test "updates added files" {
    bash $SUMO full
    echo new > new
    run bash $SUMO update
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "A new" ]
    rehash $FILES new > .reference
    compare_with_reference
}

@test "updates updated files" {
    bash $SUMO full
    rm foo
    echo new > foo
    echo "===== b2sum" >&3
    cat .b2sum >&3
    rehash $FILES > .reference
    echo "===== reference" >&3
    cat .reference >&3
    run bash $SUMO update
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "U foo" ]
    rehash $FILES > .reference
    compare_with_reference
}

@test "updates deleted files" {
    bash $SUMO full
    rm foo
    run bash $SUMO update
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "D foo" ]
    rehash bar baz > .reference
    compare_with_reference
}
