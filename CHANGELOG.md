# Changelog

All notable changes to the shared tooling are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Consumers (tanh-lib, anira) pin a release tag in their config-check workflows
and install with `install.sh <family>...`; the internal
`TANH_CMAKE_MODULES_VERSION` tracks the **cmake family** and only moves when a
cmake module changes.

## [0.2.1] - 2026-08-31

### Fixed

- `install.sh`'s default `REF` now matches the release it ships in — the v0.2.0
  copy still defaulted to v0.1.5, so a plain `curl ... | sh` fetched the old
  family set and could not find `hooks/`. (Release rule going forward: bumping
  the default REF is part of tagging.)

## [0.2.0] - 2026-08-31

### Added

- New `hooks` family: `hooks/tanh/pre-push`, a diff-based clang-tidy gate — it
  tidies the `.cpp` files a push changes against the newest
  `compile_commands.json` under `build/`, ignores TUs the compile DB does not
  know (out-of-scope sources), and degrades to a skip when clang-tidy or a
  compile DB is missing (`TANH_SKIP_TIDY=1` skips explicitly). Activation is
  per developer — git does not version hooks: symlink it as
  `.git/hooks/pre-push`, or chain from a `core.hooksPath` pre-push (pass stdin
  through). Manifests gain an optional `MODE` for executable installs.
- This changelog.

The `clang` and `cmake` families are byte-identical to v0.1.5 —
`TANH_CMAKE_MODULES_VERSION` stays `0.1.5`, so bumping the pin causes no cmake
churn and no cross-check warning against a tanh-lib fetched at 0.1.5.

## [0.1.5] and earlier

Untracked here — see the git history.
