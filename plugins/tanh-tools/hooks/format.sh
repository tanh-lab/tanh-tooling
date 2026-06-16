#!/bin/bash
# format.sh — format the edited file with the right formatter for its type.
#   C/C++/ObjC++ -> clang-format · Python -> ruff format · TS/JS -> prettier
# If the matching tool is missing, prints install instructions and fails (exit 2).
# Non-matching file types are skipped silently (exit 0).
set -uo pipefail

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

fail() { printf '%s\n' "$1" >&2; exit 2; }

# Resolve a Node CLI from the nearest node_modules/.bin (walking up from the
# edited file's dir), falling back to one on PATH. Echoes path, or nothing.
node_bin() {
  local name="$1" dir; dir=$(dirname "$FILE")
  while [ "$dir" != "/" ]; do
    if [ -x "$dir/node_modules/.bin/$name" ]; then printf '%s\n' "$dir/node_modules/.bin/$name"; return 0; fi
    dir=$(dirname "$dir")
  done
  command -v "$name" 2>/dev/null
}

case "$FILE" in
  *.cpp|*.cc|*.cxx|*.h|*.hpp|*.hh|*.mm)
    command -v clang-format >/dev/null 2>&1 || fail \
"format hook: clang-format not found.
Install it:
  Fedora/Asahi : sudo dnf install clang-tools-extra
  macOS        : brew install clang-format
  Debian/Ubuntu: sudo apt install clang-format"
    clang-format -i "$FILE"
    ;;
  *.py)
    RUFF="$CLAUDE_PROJECT_DIR/.venv/bin/ruff"
    [ -x "$RUFF" ] || RUFF=$(command -v ruff 2>/dev/null) || RUFF=""
    [ -n "$RUFF" ] || fail \
"format hook: ruff not found.
Install it:
  uv add --dev ruff   (or: uv tool install ruff)
  pip install ruff"
    "$RUFF" format "$FILE"
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    PRETTIER=$(node_bin prettier)
    [ -n "$PRETTIER" ] || fail \
"format hook: prettier not found.
Install it in the repo:
  npm i -D prettier   (or: pnpm add -D prettier)"
    "$PRETTIER" --write "$FILE"
    ;;
esac

exit 0
