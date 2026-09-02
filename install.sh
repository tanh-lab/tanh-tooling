#!/usr/bin/env sh
# install.sh — copy tanh-lab shared config files into the current repo, verbatim.
#
#   sh install.sh <family>...            write the files of each family
#   sh install.sh --check <family>...    CI: exit non-zero if any local file differs
#
# Families are the top-level directories that carry a `manifest` (clang, cmake,
# hooks). A manifest is an sh fragment:
#   FILES="a b c"        files of the family, relative to its directory
#   DEST="cmake/tanh/%s" where each file lands in the consumer (%s = file name)
#   MODE="755"           optional chmod applied after install (scripts/hooks)
#
# Pinned to a tanh-tooling release; override with TANH_TOOLING_REF=vX.Y.Z, or set
# TANH_TOOLING_SRC=<local checkout> to install from disk (development, offline tests).
set -eu

REF="${TANH_TOOLING_REF:-v0.2.7}"
BASE="https://raw.githubusercontent.com/tanh-lab/tanh-tooling/${REF}"

fetch() {  # fetch <repo-relative path> <out-path>
  if [ -n "${TANH_TOOLING_SRC:-}" ]; then cp "$TANH_TOOLING_SRC/$1" "$2"
  elif command -v curl >/dev/null 2>&1; then curl -fsSL "$BASE/$1" -o "$2"
  else wget -qO "$2" "$BASE/$1"; fi
}

check=0
if [ "${1:-}" = "--check" ]; then check=1; shift; fi
[ $# -gt 0 ] || { echo "usage: install.sh [--check] <family>...   (clang, cmake, hooks)" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
drift=0
for family in "$@"; do
  fetch "$family/manifest" "$tmp/manifest" || { echo "fetch failed: $family/manifest ($REF)" >&2; exit 1; }
  FILES=""; DEST=""; MODE=""
  . "$tmp/manifest"
  [ -n "$FILES" ] && [ -n "$DEST" ] || { echo "bad manifest: $family/manifest" >&2; exit 1; }
  for f in $FILES; do
    dest="$(printf '%s' "$DEST" | sed "s|%s|$f|")"
    fetch "$family/$f" "$tmp/file" || { echo "fetch failed: $family/$f ($REF)" >&2; exit 1; }
    if [ "$check" -eq 1 ]; then
      if [ ! -f "$dest" ] || ! cmp -s "$tmp/file" "$dest"; then echo "out of date: $dest"; drift=1; fi
    else
      mkdir -p "$(dirname "$dest")"
      cp "$tmp/file" "$dest"
      [ -z "$MODE" ] || chmod "$MODE" "$dest"
      echo "wrote $dest ($REF)"
    fi
  done
  # A family that owns a directory (DEST has a path component) owns it entirely:
  # anything else in there is not covered by the pin and is flagged in --check.
  case "$DEST" in
    */*)
      dir="$(dirname "$DEST")"
      if [ "$check" -eq 1 ] && [ -d "$dir" ]; then
        for existing in "$dir"/*; do
          [ -f "$existing" ] || continue
          name="$(basename "$existing")"
          case " $FILES " in *" $name "*) ;; *) echo "not from tanh-tooling: $existing"; drift=1;; esac
        done
      fi;;
  esac
done

if [ "$check" -eq 1 ]; then
  [ "$drift" -eq 0 ] || { echo "run install.sh $* and commit the result" >&2; exit 1; }
  echo "tanh-tooling files up to date: $* ($REF)"
fi
