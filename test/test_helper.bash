prepare() {
    OLD_DIR="$PWD"
    SUMO="${BATS_TEST_DIRNAME}/../sumo.sh"
    SUMO_REMOTE="${BATS_TEST_DIRNAME}/../sumo-remote.sh"
    TEST_DIR="${BATS_TMPDIR}/test-${BATS_TEST_NUMBER}"
    FILES="foo baz bar"
    rm -rf "$TEST_DIR"
    mkdir "$TEST_DIR"
    cd "$TEST_DIR"
}

init_repo() {
    mkdir source
    REPO="${TEST_DIR}/repo"
    SRC="${TEST_DIR}/source"
    mkdir -p "$SRC"
    cd "$SRC"
    for each in $FILES; do
        echo $each > $each
    done
    run bash $SUMO new batrepo "$REPO" "$SRC"
    assert_success
    CHECKSUMS="${REPO}/remotes/batrepo/checksums"
    cd "$SRC"
}

setup() {
    prepare
    init_repo
}

teardown() {
    cd "$OLD_DIR"
}

rehash() {
    b2sum --tag $* | sort -t= -k 1
}
