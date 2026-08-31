# Changelog

All notable changes to the shared tooling are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Consumers (tanh-lib, anira) pin a release tag in their config-check workflows
and install with `install.sh <family>...`; the internal
`TANH_CMAKE_MODULES_VERSION` tracks the **cmake family** and only moves when a
cmake module changes.

**Tagging checklist (mono-version)**: a `vX.Y.Z` tag also publishes the npm and
PyPI packages, so every tag bumps `install.sh`'s default `REF`,
`js/package.json` and `python/pyproject.toml` to X.Y.Z in the release commit.

## [Unreleased]

### Added

- `github/merge-queue-ruleset.json` + `github/apply-merge-queue.sh`: the shared
  merge-queue configuration (queue on the default branch, required status
  checks passed as arguments). Applied per repo once via
  `sh github/apply-merge-queue.sh <owner/repo> <required-context>...`; anira
  and tanh-lib use the same style. Required contexts must report on every PR
  head — queue entry is refused while a required check has not reported.

## [0.2.2] - 2026-08-31

### Fixed

- Mono-version alignment: `js/package.json` and `python/pyproject.toml` still
  said 0.1.5, so the v0.2.0/v0.2.1 tags' npm publish failed ("cannot publish
  over previously published versions") — those tags shipped no packages. This
  release aligns all three version sources and records the tagging checklist
  above.

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
