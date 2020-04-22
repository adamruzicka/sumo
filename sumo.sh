#!/bin/bash

: ${CHECKSUM_COMMAND:=b2sum}
: ${CHECKSUM_FILE:=."$CHECKSUM_COMMAND"}
: ${CONCURRENCY:=4}

function checksum() {
    parallel -j $CONCURRENCY "$CHECKSUM_COMMAND" --tag '{}'
}

function newer_files() {
    find * -type f -newer "$1"
}

function check_updated() {
    grep -x -F -f "$1" "$2" | select_filenames
}

function check_new() {
    grep -x -v -F -f <(cat "$2" | select_filenames) "$1"
}

function check_deleted() {
    grep -v -F -f <(find * -type f) "$1" | select_filenames
}

function select_filenames() {
    grep -P -o --line-buffered '\(.*\)' | sed --unbuffered 's/^(\(.*\))$/\1/'
}

function prefix() {
    sed --unbuffered "s/^/$1 /"
}

case "$1" in
    "full")
        find * -type f | checksum | tee >(sort -k 2 > "$CHECKSUM_FILE") | select_filenames | prefix A
        ;;
    "update")
        NEW_FILE_LIST="$(mktemp)"
        newer_files "$CHECKSUM_FILE" > "$NEW_FILE_LIST"

        TMP="$(mktemp -d)"
        WORK="$TMP/work"

        check_new "$NEW_FILE_LIST" "$CHECKSUM_FILE" > "$TMP/new"
        check_updated "$NEW_FILE_LIST" "$CHECKSUM_FILE" > "$TMP/updated"
        check_deleted "$CHECKSUM_FILE" > "$TMP/deleted"

        cp "$CHECKSUM_FILE" "$TMP/work.new"

        checksum < "$TMP/new" | tee -a "$WORK.new" | select_filenames | prefix A
        grep -x -v -F -f "$TMP/updated" "$WORK.new" > "$WORK.updated"
        checksum < "$TMP/updated" | tee -a "$WORK.updated" | select_filenames | prefix U
        grep -F -f "$TMP/deleted" "$WORK.updated" | select_filenames | prefix D
        grep -v -F -f "$TMP/deleted" "$WORK.updated" | sort -k 2 > "$CHECKSUM_FILE"

        rm -r "$TMP"
        rm "$NEW_FILE_LIST"
        ;;
    "update-new")
        TMPDIR="$(mktemp -d)"
        find * -type f > "$TMPDIR/new"
        grep -x -v -F -f <(cat "$CHECKSUM_FILE" | select_filenames) "$TMPDIR/new" | checksum | tee "$TMPDIR/added" | select_filenames | prefix A
        cp "$CHECKSUM_FILE" "$TMPDIR/old"
        cat "$TMPDIR/old" "$TMPDIR/added" | sort -k 2 > "$CHECKSUM_FILE"
        rm -r "$TMPDIR"
        ;;
    "check")
        NEW_FILE_LIST="$(mktemp)"
        newer_files "$CHECKSUM_FILE" > "$NEW_FILE_LIST"

        check_new "$NEW_FILE_LIST" "$CHECKSUM_FILE" | prefix A
        check_updated "$NEW_FILE_LIST" "$CHECKSUM_FILE" | prefix U
        check_deleted "$CHECKSUM_FILE" | prefix D

        rm "$NEW_FILE_LIST"
        ;;
    "known-files")
        select_filenames < "$CHECKSUM_FILE"
        ;;
    "unknown-files")
        find * -type f | grep -x -v -F -f <(cat "$CHECKSUM_FILE" | select_filenames)
        ;;
    "select-filenames")
        select_filenames
        ;;
    "verify")
        "$CHECKSUM_COMMAND" -c "$CHECKSUM_FILE"
        ;;
esac
