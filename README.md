# `tanh-tooling`

tanh-lab's single source of truth for shared developer configuration — Python
linters, clang configs, JS/TS linters, and Claude Code agents/skills/hooks/MCP.
Starting a new repo means **reusing** these options instead of copy-pasting them;
updating the house style means changing it in **one place**.

Each config family is distributed through its own ecosystem's native channel:

| Family | Lives in | Channel | Consumer gets it via |
|---|---|---|---|
| Python (ruff, pyright) | [`python/`](python/) | PyPI package `tanh-tooling` | `uv add` + `tanh-tooling sync` |
| clang (`.clang-format`/`.clang-tidy`/`.clangd`) | [`clang/`](clang/) | GitHub template repo + raw `install.sh` | born-with-it, or `curl … \| sh` |
| JS/TS (eslint, prettier) | [`js/`](js/) | npm package `tanh-tooling` | `npm i -D` + flat-config spread |
| `.claude` (agents/skills/hooks/MCP/LSP) | [`plugins/`](plugins/) | Claude Code plugin marketplace (this repo) | committed `.claude/settings.json` |

Releases are **mono-versioned**: one `vX.Y.Z` git tag ships the Python wheel and
the npm package and is the pin used by the clang `install.sh` URLs.

## Consumer adoption (quick reference)

**Python repo**
```sh
uv add tanh-tooling
uv run tanh-tooling sync          # writes ruff_base.toml + pyright_base.json
```
```toml
# ruff.toml
extend = "ruff_base.toml"
```
```json
// pyrightconfig.json
{ "extends": "pyright_base.json", "include": ["src"] }
```
CI drift check: `uv run tanh-tooling sync --check`.

**C++ repo** — create from the `tanh-cpp-template` GitHub template (born with the
configs), or refresh an existing repo with the one-liner (leaves no script behind):
```sh
curl -fsSL https://raw.githubusercontent.com/tanh-lab/tanh-tooling/v0.1.0/clang/install.sh | sh
```
CI drift check — one line in the consumer's existing workflow:
```yaml
jobs:
  clang-config:
    uses: tanh-lab/tanh-tooling/.github/workflows/clang-check.yml@v0.1.0
```

**TS repo**
```sh
npm i -D tanh-tooling eslint prettier
```
```js
// eslint.config.js
import tanh from "tanh-tooling";
export default [...tanh, { /* per-repo overrides */ }];
```
```js
// prettier.config.js
import base from "tanh-tooling/prettier";
export default { ...base };
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
skill, the auto-firing format/lint/typecheck hooks, the GitHub MCP, and the clangd
LSP (pulled in as a plugin dependency). The GitHub MCP authenticates per-user via a
one-time `/mcp` OAuth flow — **no token to create**. (To use a PAT instead, give the
server an `Authorization: Bearer ${GITHUB_TOKEN}` header and export the var.)

> Headless/CI (`claude -p`) skips the trust dialog, so committed marketplaces are
> not auto-processed there — CI must `claude plugin marketplace add tanh-lab/tanh-tooling`
> explicitly.

## The Claude Code hooks

The plugin contributes three PostToolUse(Write|Edit) dispatchers under
[`plugins/tanh-tools/hooks/`](plugins/tanh-tools/hooks/). Each picks the right tool
by file extension and, if that tool is missing, prints install instructions and
fails (exit 2) rather than skipping silently:

- `format.sh` — clang-format (C/C++/ObjC++) · ruff format (Python) · prettier (TS/JS)
- `lint.sh` — clang-tidy · ruff check (--fix then verify) · eslint (--fix then verify)
- `typecheck.sh` — pyright (Python) · tsc against `tsconfig.check.json` (TS)

## Repository layout

```
tanh-tooling/
├── .claude-plugin/marketplace.json   # this repo IS the marketplace
├── plugins/tanh-tools/               # the plugin (agents, skills, hooks, MCP)
├── python/                           # pip package → PyPI
├── js/                               # npm package
├── clang/                            # dotless canonical configs + install.sh
└── .github/workflows/                # release-python, release-js, clang-check
```

## Releasing

Tag and push `vX.Y.Z`: `release-python.yml` builds + publishes the wheel (PyPI
trusted publishing, OIDC) and `release-js.yml` runs `npm publish` (needs the
`NPM_TOKEN` repo secret). The same tag is the clang pin. Bump `version` in
`plugins/tanh-tools/.claude-plugin/plugin.json` on every plugin change, or pushing
commits ships nothing (Claude Code keeps the cached copy).
