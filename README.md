# `tanh-tooling`

tanh-lab's single source of truth for shared developer configuration — Python
linters, clang configs, JS/TS linters, and Claude Code agents/skills/hooks.
Starting a new repo means **reusing** these options instead of copy-pasting them;
updating the house style means changing it in **one place**.

Each config family is distributed through its own ecosystem's native channel:

| Family | Lives in | Channel | Consumer gets it via |
|---|---|---|---|
| Python (ruff, pyright) | [`python/`](python/) | PyPI package `tanh-tooling` | `uv add` + `tanh-tooling sync` |
| clang (`.clang-format`/`.clang-tidy`/`.clangd`) | [`clang/`](clang/) | raw `install.sh` (verbatim copy, pinned tag) | `curl … \| sh -s -- clang` |
| CMake modules (platform, symbol policy, export check, git version, sanitizers, test deps, Apple, CPack, RPATH, binary data, compile-database link) | [`cmake/`](cmake/) | raw `install.sh` (verbatim copy into `cmake/tanh/`, pinned tag) | `curl … \| sh -s -- cmake` |
| JS/TS (eslint, prettier, tsconfig) | [`js/`](js/) | npm package `@tanh-lab/tanh-tooling` | `npm i -D` + flat-config spread / `extends` |
| `.claude` (agents/skills/hooks/LSP) | [`plugins/`](plugins/) | Claude Code plugin marketplace (this repo) | committed `.claude/settings.json` |

Releases are **mono-versioned**: one `vX.Y.Z` git tag ships the Python wheel and
the npm package and is the pin used by the `install.sh` URLs (clang and cmake families).

## Consumer adoption (quick reference)

**Python repo**
```sh
uv add tanh-tooling
uv run tanh-tooling sync          # writes ruff_base.toml + pyright_base.json
```
```toml
# pyproject.toml
[tool.ruff]
extend = "ruff_base.toml"
```
```json
// pyrightconfig.json
{ "extends": "pyright_base.json", "include": ["src"] }
```
CI drift check: `uv run tanh-tooling sync --check`.

**C++ repo** — install the families you use with the one-liner (leaves no script
behind; `clang` writes `.clang-format`/`.clang-tidy`/`.clangd`, `cmake` writes
`cmake/tanh/*.cmake`), commit the files, and pin the same tag in CI:
```sh
curl -fsSL https://raw.githubusercontent.com/tanh-lab/tanh-tooling/vX.Y.Z/install.sh | sh -s -- clang cmake
```
CI drift check — one job in the consumer's existing workflow:
```yaml
jobs:
  tooling-config:
    uses: tanh-lab/tanh-tooling/.github/workflows/config-check.yml@vX.Y.Z
    with:
      ref: vX.Y.Z
      family: "clang cmake"
```
`--check` fails when a committed file differs from the tag or `cmake/tanh/` holds a
file that is not from tanh-tooling. The modules and their API are documented in
[`cmake/README.md`](cmake/README.md). `TANH_TOOLING_SRC=<local checkout>` installs
from disk while developing. (The older `clang/install.sh` + `clang-check.yml` pair
keeps working for existing pins.)

`.clangd` reads `build/compile_commands.json`. A plain `cmake -B build` tree writes it
there; a project whose presets configure several trees under `build/` calls
`tanh_link_compile_commands()` (`cmake/tanh/compile-commands.cmake`) in the trees
clangd should follow, and each configure links the database there, so clangd reads
the tree configured last. Emscripten trees need clangd started with
`--query-driver=**/em++`: em++ adds the wasm target and the emsdk sysroot itself, and
the flag lets clangd ask it for them (it is a command-line flag only, since it runs
the compiler; `.clangd` cannot set it).

**TS repo**
```sh
npm i -D @tanh-lab/tanh-tooling eslint prettier
```
```js
// eslint.config.js
import tanh from "@tanh-lab/tanh-tooling";
export default [...tanh, { /* per-repo overrides */ }];
```
```js
// prettier.config.js
import base from "@tanh-lab/tanh-tooling/prettier";
export default { ...base };
```
```jsonc
// tsconfig.json — layer the house strictness base AFTER your framework base (TS 5+)
{
  "extends": ["expo/tsconfig.base", "@tanh-lab/tanh-tooling/tsconfig"],
  "compilerOptions": { "paths": { "@/*": ["./*"] } },
  "include": ["**/*.ts", "**/*.tsx"]
}
```
The `typecheck.sh` hook type-checks against a **`tsconfig.check.json`** (so it can
narrow `include` to your hand-written source and skip generated decls). It stays
per-repo — the hook runs `tsc` only when both `tsconfig.check.json` and a local
`tsc` exist, otherwise it skips:
```jsonc
// tsconfig.check.json (per-repo)
{ "extends": "./tsconfig.json", "include": ["src/**/*.ts", "src/**/*.tsx"] }
```

**Any repo (Claude Code plugin)** — commit `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "tanh-tooling": { "source": { "source": "github", "repo": "tanh-lab/tanh-tooling" } }
  },
  "enabledPlugins": { "tanh-tools@tanh-tooling": true }
}
```
Trust the repo once; you then get the `dsp-reviewer` agent, the `crossplatform-audio`
skill, the auto-firing format/lint/typecheck hooks, and the clangd LSP (pulled in as a
plugin dependency).

### GitHub MCP

The plugin ships no GitHub MCP server: GitHub's remote server
(`api.githubcopilot.com/mcp/`) is set up per person, in your own Claude Code
configuration, with a personal access token. A fine-grained token reaches the
repositories of one owner only (your account or one organisation), so the token and
with it the server depend on whose repositories you work on. Its OAuth endpoint does
not support dynamic client registration, so the tokenless **Authenticate** in the
`/mcp` menu fails with *"Incompatible auth server"*; send the token in an
`Authorization: Bearer ${…}` header from a variable your shell exports (e.g. from a
git-ignored `~/.dotfiles/.secrets`), and start `claude` from a terminal so it
inherits it. CI status on a private repository is read through the server's
`actions` toolset (`X-MCP-Toolsets: context,repos,issues,pull_requests,users,actions`,
token with *Actions: read*): fine-grained tokens cannot call the Checks API there.

> Headless/CI (`claude -p`) skips the trust dialog, so committed marketplaces are
> not auto-processed there — CI must `claude plugin marketplace add tanh-lab/tanh-tooling`
> explicitly.

## The Claude Code hooks

A single PostToolUse(Write|Edit) dispatcher, `check.sh`, runs three steps on the
edited file **in order, in one process** — `lint.sh` → `format.sh` → `typecheck.sh`
(under [`plugins/tanh-tools/hooks/`](plugins/tanh-tools/hooks/)). It is one hook
rather than three because Claude Code runs the hooks under a matcher concurrently:
`lint.sh` and `format.sh` both rewrite the file, so registering them separately
races them and a file needing both a lint `--fix` and a reformat gets a
non-deterministic result. Linting runs first so the formatter has the last word on
whitespace (per Astral's ruff guidance). Each step picks the right tool by file
extension and, if that tool is missing, prints install instructions and fails
(exit 2) rather than skipping silently:

- `format.sh` — clang-format (C/C++/ObjC++) · ruff format (Python) · prettier (TS/JS)
- `lint.sh` — clang-tidy · ruff check (--fix then verify) · eslint (--fix then verify)
- `typecheck.sh` — pyright (Python) · tsc against `tsconfig.check.json` (TS)

Each step also accepts the file path as its first argument, so `check.sh` can invoke
them directly; run standalone (no arg) they still parse the hook JSON from stdin.

## Repository layout

```
tanh-tooling/
├── .claude-plugin/marketplace.json   # this repo IS the marketplace
├── plugins/tanh-tools/               # the plugin (agents, skills, hooks)
├── python/                           # pip package → PyPI
├── js/                               # npm package
├── clang/                            # dotless canonical configs (+ shim install.sh)
├── cmake/                            # shared CMake modules + their test projects
├── install.sh                        # installer for the clang and cmake families
└── .github/workflows/                # release-python, release-js, config-check, cmake-test
```

## Releasing

Bump the default `REF` in `install.sh` and `clang/install.sh`, the `default:` of
`config-check.yml`/`clang-check.yml` and `TANH_CMAKE_MODULES_VERSION` in
`cmake/modules-version.cmake` to the new tag in the release commit (`cmake-test.yml`
must be green). Then tag and push `vX.Y.Z`: `release-python.yml` builds + publishes the wheel and
`release-js.yml` publishes the npm package. Both use **trusted publishing (OIDC) —
no tokens stored in the repo**. The same tag is the clang pin.

One-time setup before the first tag:

- **PyPI** — create a *pending publisher* at <https://pypi.org/manage/account/publishing/>
  (project `tanh-tooling`, owner `tanh-lab`, repo `tanh-tooling`, workflow
  `release-python.yml`, environment `pypi`). Pending publishers work before the
  project exists, so the first publish is already tokenless.
- **npm** — create the `tanh-lab` org first (free, public). npm has no
  pending-publisher mechanism, so **bootstrap the first publish with a token**, then
  switch to OIDC:
  1. `cd js && npm publish` once, authenticated with a granular token (or `npm login`).
     The package is scoped to the org and `publishConfig.access` is `public`, so it
     publishes publicly without extra flags.
  2. On npmjs.com → the `@tanh-lab/tanh-tooling` package → Settings → Trusted Publisher
     → add GitHub Actions: owner `tanh-lab`, repo `tanh-tooling`, workflow
     `release-js.yml`, environment `npm`.
  3. From then on the tagged workflow publishes tokenless; delete the bootstrap token.

Bump `version` in `plugins/tanh-tools/.claude-plugin/plugin.json` on every plugin
change, or pushing commits ships nothing (Claude Code keeps the cached copy).
