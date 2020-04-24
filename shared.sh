#!/usr/bin/env bash

function die() {
    echo "$2" >&2
    cleanup
    exit "$1"
}

function init_tmpdir() {
    TEST_TEMP_DIR="$(mktemp -d)"
}


function cleanup() {
    [ -d "$TEST_TEMP_DIR" ] && rm -rf "$TEST_TEMP_DIR"
}

function find_repository_root() {
    if [ "$PWD" = "/" ]; then
        exit 1
    elif [ -e .sumo ]; then
        ROOT="${PWD}/.sumo"
    else
        cd ..
        find_repository_root
    fi
}

function set_defaults() {
    if [ -z "$ROOT" ]; then
        find_repository_root
    fi
    root_file="${ROOT}/root"
    [ -f "$root_file" ] || die 3 "This repository does not seem to have local files"
    cd "$(cat "$root_file")" || die 3 "Could not change to root directory"
    id_file="${ROOT}/id"
    [ -f "$id_file" ] || die 3 "This repository does not seem to have an identity"
    ID="$(cat "$id_file")"
    CHECKSUM_FILE="${ROOT}/remotes/${ID}/checksums"
}

function safe_load_path() {
    local file="$1"

    [ -f "$file" ] || die 4 "Required file '$file' does not exist"
    cat "$file"
}

function select_filenames() {
    grep -P -o --line-buffered '\(.*\)' | sed --unbuffered 's/^(\(.*\))$/\1/'
}

function strip_dot_slash() {
    sed 's|^\./||'
}

function prefix() {
    sed --unbuffered "s/^/$1 /"
}

function commit() {
    if [ -z "$1" ]; then
        local target="$CHECKSUM_FILE"
    else
        local target="$1"
    fi
    sort -k 2 < "$TEST_TEMP_DIR/wip" > "$target"
}
