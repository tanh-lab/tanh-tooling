#!/usr/bin/env sh
# clang/install.sh — kept so the documented one-liner keeps working. The generic
# installer at the repository root handles every family:  sh install.sh [--check] clang
set -eu
REF="${TANH_TOOLING_REF:-v0.1.5}"
if [ -n "${TANH_TOOLING_SRC:-}" ]; then exec sh "$TANH_TOOLING_SRC/install.sh" "$@" clang; fi
URL="https://raw.githubusercontent.com/tanh-lab/tanh-tooling/${REF}/install.sh"
if command -v curl >/dev/null 2>&1; then script="$(curl -fsSL "$URL")"; else script="$(wget -qO- "$URL")"; fi
TANH_TOOLING_REF="$REF" sh -c "$script" install.sh "$@" clang
