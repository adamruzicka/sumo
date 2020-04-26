#!/usr/bin/env bash

source "$(dirname "$0")/shared.sh"

usage() {
    echo "Usage: sumo.sh [OPTION]... COMMAND"
    echo
    cat <<EOF | column -s '&' --table
COMMAND:
add REMOTE URL & Add a remote REMOTE available at URL
del REMOTE & Remove a remote REMOTE
list REMOTE & List avilable REMOTES
push REMOTE & Push files which are available locally but missing on REMOTE to REMOTE
pull REMOTE & Pull files which are available on REMOTE but missing locally from REMOTE
common REMOTE & List files which are present locally and in REMOTE
local-only REMOTE & List files which are present locally but not in REMOTE
remote-only REMOTE & List files which are present in REMOTE but not locally
&
OPTION:
-r | --repository REPOSITORY & Use REPOSITORY for storing checksums
-n | --dry-run & Perform a dry run
-h | --help & Prints help
EOF
    exit 2
}

PARSED_ARGUMENTS=$(getopt -a -n sumo.sh -o nhr: --long dry-run,help,root: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
    usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
    case "$1" in
        -h | --help)   usage;;
        -r | --root)   ROOT="$2"; shift 2 ;;
        -n | --dry-run) DRY_RUN="-n"; shift ;;
        # -- means the end of the arguments; drop this, and break out of the while loop
        --) shift; break ;;
        # If invalid options were passed, then getopt should have reported an error,
        # which we checked as VALID_ARGUMENTS when getopt was called...
        *) echo "Unexpected option: $1 - this should not happen."
           usage ;;
    esac
done

set_defaults
init_tmpdir

function rsync_transfer() {
    local src_remote="$1"
    local src_path
    src_path="$(safe_load_path "$2")"
    local dst_remote="$3"
    local dst_path
    dst_path="$(safe_load_path "$4")"

    comm -2 -3 "${ROOT}/remotes/${src_remote}/checksums" "${ROOT}/remotes/${dst_remote}/checksums" > "$TEST_TEMP_DIR/transferred"
    rsync -Prhv $DRY_RUN --files-from <(select_filenames < "$TEST_TEMP_DIR/transferred") "$src_path" "$dst_path"

    if [ -n "$DRY_RUN" ]; then
        cat "${ROOT}/remotes/${dst_remote}/checksums" "$TEST_TEMP_DIR/transferred" > "$TEST_TEMP_DIR/wip"
        commit "${ROOT}/remotes/${dst_remote}/checksums"
    fi
}

case "$1" in
    "add")
        mkdir "${ROOT}/remotes/$2"
        touch "${ROOT}/remotes/$2/checksums"
        echo "$3" > "${ROOT}/remotes/$2/url"
        ;;
    "del")
        [ "$ID" = "$2" ] && die 5 "Local repository cannot be removed as a remote"
        rm -rf "${ROOT}/remotes/$2"
        ;;
    "common")
        comm -1 -2 "${ROOT}/remotes/${ID}/checksums" "${ROOT}/remotes/${2}/checksums" | select_filenames
        ;;
    "local-only")
        comm -2 -3 "${ROOT}/remotes/${ID}/checksums" "${ROOT}/remotes/${2}/checksums" | select_filenames
        ;;
    "remote-only")
        comm -2 -3 "${ROOT}/remotes/${2}/checksums" "${ROOT}/remotes/${ID}/checksums" | select_filenames
        ;;
    "push")
        rsync_transfer "$ID" "${ROOT}/root" \
                       "$2" "${ROOT}/remotes/${2}/url"
    ;;
    "pull")
        rsync_transfer "$2" "${ROOT}/remotes/${2}/url" \
                       "$ID" "${ROOT}/root"
    ;;
    *)
        echo "sumo.sh: unrecognized command '$1'" >&2
        usage
        ;;
esac

cleanup
