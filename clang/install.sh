#!/usr/bin/env sh
# clang/install.sh — fetch tanh-lab clang configs into the current repo.
#   sh install.sh           write .clang-format / .clang-tidy / .clangd
#   sh install.sh --check   CI: exit non-zero if local files differ
# Override the pinned version with TANH_TOOLING_REF.
set -eu

REF="${TANH_TOOLING_REF:-v0.1.4}"
BASE="https://raw.githubusercontent.com/tanh-lab/tanh-tooling/${REF}/clang"
FILES="clang-format clang-tidy clangd"

dl() {  # dl <remote-name> <out-path>
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$BASE/$1" -o "$2"
  else wget -qO "$2" "$BASE/$1"; fi
}

if [ "${1:-}" = "--check" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  drift=0
  for f in $FILES; do
    dl "$f" "$tmp/$f" || { echo "fetch failed: $f" >&2; exit 1; }
    if [ ! -f ".$f" ] || ! cmp -s "$tmp/$f" ".$f"; then echo "out of date: .$f"; drift=1; fi
  done
  [ "$drift" -eq 0 ] || { echo "run install.sh and commit the result" >&2; exit 1; }
  echo "clang configs up to date ($REF)"
else
  for f in $FILES; do
    dl "$f" ".$f" || { echo "fetch failed: $f" >&2; exit 1; }
    echo "wrote .$f ($REF)"
  done
fi
