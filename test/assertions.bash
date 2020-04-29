assert_file_contains() {
    diff <(echo "$1") "$2"
}

assert_file_empty() {
    [ "$(wc -c < "$1")" -eq 0 ]
}

assert_files_equal() {
    run diff "$1" "$2"
    assert_success
}

assert_output_equals() {
    [ "$output" = "$(cat)" ]
}

assert_success() {
    [ "$status" -eq 0 ]
}
