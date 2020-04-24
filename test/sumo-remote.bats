load assertions
load test_helper

init_repo() {
    # Do not do anything
    mkdir .remotes
    REMOTES="a b c"
    mkdir $REMOTES
    for remote in $REMOTES; do
        mkdir -p $remote/{files,repo}
        ln -s "../../.remotes" $remote/repo/remotes
    done
}

@test "adds a remote" {
    run bash $SUMO new a a/repo a/files
    cd a/files
    run bash $SUMO_REMOTE add b "$(readlink -f "${TEST_DIR}/b/files")"
    assert_success
    [ -d .sumo/remotes/b ]
    [ -f .sumo/remotes/b/checksums ]
    [ -f .sumo/remotes/b/url ]
    assert_file_empty .sumo/remotes/b/checksums
    assert_file_contains "$(readlink -f "${TEST_DIR}/b/files")" .sumo/remotes/b/url
}

@test "removes a remote" {
    run bash $SUMO new a a/repo a/files
    cd a/files
    run bash $SUMO_REMOTE add b "$(readlink -f "${TEST_DIR}/b/files")"
    assert_success
    run bash $SUMO_REMOTE del b
    assert_success
    [ ! -d .sumo/remotes/b ]
}

@test "refuses to remove itself" {
    run bash $SUMO new a a/repo a/files
    cd a/files
    run bash $SUMO_REMOTE del a
    [ "$status" -eq 5 ]
    [ "$output" = "Local repository cannot be removed as a remote" ]
}

@test "pushes files to remote repository" {
    run bash $SUMO new a a/repo a/files
    bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" add b "$(readlink -f "${TEST_DIR}/b/files")"
    echo foo > a/files/foo
    bash $SUMO -r "${TEST_DIR}/a/repo" full
    run bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" push b
    assert_success
    
    [ "${lines[0]}" = "sending incremental file list" ]
    [ "${lines[1]}" = "foo" ]

    assert_file_contains "foo" "${TEST_DIR}/b/files/foo"
    assert_files_equal .remotes/{a,b}/checksums
}

@test "pulls files from remote repository" {
    bash $SUMO new a a/repo a/files
    bash $SUMO new b b/repo b/files
    echo foo > b/files/foo
    bash $SUMO -r ${TEST_DIR}/b/repo full
    
    bash $SUMO_REMOTE -r ${TEST_DIR}/a/repo add b "$(readlink -f "${TEST_DIR}/b/files")/"
    run bash $SUMO_REMOTE -r ${TEST_DIR}/a/repo pull b
    [ "${lines[0]}" = "sending incremental file list" ]
    [ "${lines[1]}" = "foo" ]

    assert_file_contains foo b/files/foo
    assert_files_equal .remotes/{a,b}/checksums
}

@test "lists local-only files" {
    bash $SUMO new a a/repo a/files
    bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" add b "$(readlink -f "${TEST_DIR}/b/files")"
    echo foo > a/files/foo
    bash $SUMO -r "${TEST_DIR}/a/repo" full
    run $SUMO_REMOTE -r "${TEST_DIR}/a/repo" local-only b
    assert_success
    [ "$output" = "foo" ]
}

@test "lists remote-only files" {
    bash $SUMO new a a/repo a/files
    bash $SUMO new b b/repo b/files
    bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" add b "$(readlink -f "${TEST_DIR}/b/files")"
    
    echo foo > b/files/foo
    bash $SUMO -r "${TEST_DIR}/b/repo" full
    run $SUMO_REMOTE -r "${TEST_DIR}/a/repo" remote-only b
    assert_success
    [ "$output" = "foo" ]
}

@test "lists common files" {
    bash $SUMO new a a/repo a/files
    bash $SUMO new b b/repo b/files
    bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" add b "$(readlink -f "${TEST_DIR}/b/files")"
    echo foo > b/files/foo
    bash $SUMO -r "${TEST_DIR}/b/repo" full
    run $SUMO_REMOTE -r "${TEST_DIR}/a/repo" common b
    assert_success
    [ "$output" = "" ]

    bash $SUMO_REMOTE -r "${TEST_DIR}/a/repo" pull b
    run $SUMO_REMOTE -r "${TEST_DIR}/a/repo" common b
    [ "$output" = "foo" ]
}
