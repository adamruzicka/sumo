#!/bin/env bash

source "$(dirname "$0")/shared.sh"

: "${CHECKSUM_COMMAND:=b2sum}"
: "${JOBS:=4}"

function checksum() {
    parallel -j $JOBS "$CHECKSUM_COMMAND" --tag '{}'
}

function newer_files() {
    find ./* -type f -newer "$1" | strip_dot_slash
}

function check_updated() {
    grep -F -f "$1" "$2" | select_filenames
}

function check_new() {
    grep -x -v -F -f <(select_filenames < "$2") "$1"
}

function check_deleted() {
    grep -v -F -f <(find ./* -type f | strip_dot_slash) "$1" | select_filenames
}

function select_filenames() {
    grep -P -o --line-buffered '\(.*\)' | sed --unbuffered 's/^(\(.*\))$/\1/'
}

usage() {
    echo "Usage: sumo.sh [OPTION]... COMMAND"
    echo
    cat <<EOF | column -s '&' --table
COMMAND:
new NAME REPOSITORY-PATH FILE-PATH & Initializes a new repository for remote NAME with files at FILE-PATH under REPOSITORY-PATH
full & Generates a new checksum file from scratch
update & Updates CHECKSUM-FILE with checksums of files which changed since CHECKSUM-FILE was generated
update-new & Updates CHECKSUM-FILE with checksums of files which are not there
check & Checks for changes in files against CHECKSUM-FILE
known-files & Lists files which are checksummed in CHECKSUM-FILE
unknown-files & Lists files which are not checksummed in CHECKSUM-FILE
select-filenames & Reads checksums in tagged format from STDIN and output filenames
verify & Verifies files against a checksum file
&
OPTION:
-c | --checksum-command COMMAND & Use COMMAND to generate checksums, defaults to $CHECKSUM_COMMAND
-j | --jobs JOBS & Use JOBS number of concurrent jobs, defaults to $JOBS
-r | --repository REPOSITORY & Use REPOSITORY for storing checksums
-h | --help & Prints help
EOF
    exit 2
}

PARSED_ARGUMENTS=$(getopt -a -n sumo.sh -o c:j:hr: --long checksum-command:,jobs:,help,root: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
    usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
    case "$1" in
        -h | --help)   usage;;
        -c | --checksum-command) CHECKSUM_COMMAND="$2" ; shift 2 ;;
        -j | --jobs)   JOBS="$2"   ; shift 2 ;;
        -r | --root)   ROOT="$2"; shift 2 ;;
        # -- means the end of the arguments; drop this, and break out of the while loop
        --) shift; break ;;
        # If invalid options were passed, then getopt should have reported an error,
        # which we checked as VALID_ARGUMENTS when getopt was called...
        *) echo "Unexpected option: $1 - this should not happen."
           usage ;;
    esac
done

# Set defaults
if [ "$1" != "new" ]; then
    set_defaults
fi

case "$1" in
    "new")
        # new NAME REPOSITORY-PATH FILE-PATH & Initializes a new repository for remote NAME with files at FILE-PATH under REPOSITORY-PATH
        FILE_PATH="$(readlink -f "${4%/}")/"
        mkdir -p "$3/remotes/$2"
        touch "$3/remotes/$2/checksums"
        echo "$2" > "$3/id"
        echo "${FILE_PATH}" > "$3/root"
        ln -s "$(readlink -f "$3")" "${FILE_PATH}.sumo"
        ;;
    "full")
        find ./* -type f | strip_dot_slash | checksum | tee >(sort -k 2 > "$CHECKSUM_FILE") | select_filenames | prefix A
        ;;
    "update")
        NEW_FILE_LIST="$(mktemp)"
        newer_files "$CHECKSUM_FILE" > "$NEW_FILE_LIST"

        TMP="$(mktemp -d)"
        WORK="$TMP/work"

        grep -x -v -F -f <(select_filenames < "$CHECKSUM_FILE") <(find ./* -type f | strip_dot_slash) > "$TMP/new"
        check_updated "$NEW_FILE_LIST" "$CHECKSUM_FILE" > "$TMP/updated"
        check_deleted "$CHECKSUM_FILE" > "$TMP/deleted"

        cp "$CHECKSUM_FILE" "$TMP/work.new"

        checksum < "$TMP/new" | tee -a "$WORK.new" | select_filenames | prefix A
        grep -v -F -f "$TMP/updated" "$WORK.new" > "$WORK.updated"
        checksum < "$TMP/updated" | tee -a "$WORK.updated" | select_filenames | prefix U
        grep -F -f "$TMP/deleted" "$WORK.updated" | select_filenames | prefix D
        grep -v -F -f "$TMP/deleted" "$WORK.updated" | sort -k 2 > "$CHECKSUM_FILE"

        rm -r "$TMP"
        rm "$NEW_FILE_LIST"
        ;;
    "update-new")
        TMPDIR="$(mktemp -d)"
        find ./* -type f | strip_dot_slash > "$TMPDIR/new"
        grep -x -v -F -f <(select_filenames < "$CHECKSUM_FILE") "$TMPDIR/new" | checksum | tee "$TMPDIR/added" | select_filenames | prefix A
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
        find ./* -type f | strip_dot_slash | grep -x -v -F -f <(select_filenames < "$CHECKSUM_FILE")
        ;;
    "select-filenames")
        select_filenames
        ;;
    "verify")
        "$CHECKSUM_COMMAND" -c "$CHECKSUM_FILE"
        ;;
    *)
        echo "sumo.sh: unrecognized command '$1'" >&2
        usage
        ;;
esac
