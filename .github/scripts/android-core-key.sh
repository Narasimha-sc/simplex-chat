#!/bin/sh
# The android-core key of a tree: the hash of everything its Android core libs are built from.
# Usage: android-core-key.sh <tree-ish> <arch>   (in a git repository, or with GIT_DIR set)
# One definition, two byte-identical copies: ~/build/lib/android-core-key.sh and
# .github/scripts/android-core-key.sh on the fork branch ci/android-core (its workflow runs it).
# `bash ~/build/lib/ci-core.sh selftest` checks that they agree.
set -eu
[ $# -eq 2 ] || { echo "usage: $0 <tree-ish> <arch>" >&2; exit 2; }
case $2 in aarch64|armv7a) ;; *) echo "unknown arch: $2" >&2; exit 2 ;; esac
git rev-parse --verify -q "$1^{tree}" >/dev/null || { echo "not a tree: $1" >&2; exit 2; }
{
  for p in src cabal.project simplex-chat.cabal PRIVACY.md flake.nix flake.lock scripts/nix; do
    git rev-parse --verify -q "$1:$p" || echo "missing:$p"
  done
  echo "android-core v1 $2"
} | sha256sum | cut -c1-24
