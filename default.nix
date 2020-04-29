{ pkgs ? import <nixpkgs> {} }:

with pkgs;
mkShell {
  # this will make all the build inputs from hello and gnutar
  # available to the shell environment
  buildInputs = [
    b2sum
    bash
    bats
    parallel
    getopt
    rsync
    shellcheck
    unixtools.column
  ];
}
