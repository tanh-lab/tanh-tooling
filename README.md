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
| JS/TS (eslint, prettier, tsconfig) | [`js/`](js/) | npm package `@tanh-lab/tanh-tooling` | `npm i -D` + flat-config spread / `extends` |
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
curl -fsSL https://raw.githubusercontent.com/tanh-lab/tanh-tooling/vX.Y.Z/clang/install.sh | sh
```
CI drift check — one line in the consumer's existing workflow:
```yaml
jobs:
  clang-config:
    uses: tanh-lab/tanh-tooling/.github/workflows/clang-check.yml@vX.Y.Z
```

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
skill, the auto-firing format/lint/typecheck hooks, the GitHub MCP, and the clangd
LSP (pulled in as a plugin dependency).

### GitHub MCP token

The GitHub MCP server (`api.githubcopilot.com/mcp/`) needs a **personal access
token** — its OAuth endpoint does not support dynamic client registration, so Claude
Code's tokenless `/mcp` OAuth flow fails with *"Incompatible auth server"*. Don't pick
**Authenticate** in the `/mcp` menu; instead the committed `.mcp.json` reads the token
from a `GITHUB_TOKEN` env var (`Authorization: Bearer ${GITHUB_TOKEN}`) — the config
travels, the token never does.

Keep the token out of any repo. The convention here is a git-ignored `.secrets` file
in your dotfiles that your shell sources on startup, exporting `GITHUB_TOKEN` into the
environment Claude Code inherits. For example, in `~/.dotfiles/.secrets`:

```sh
# ~/.dotfiles/.secrets  (git-ignored; sourced from ~/.zshrc)
export GITHUB_TOKEN="github_pat_…"     # or: export GITHUB_TOKEN="$(gh auth token)"
```
```sh
# ~/.zshrc
[ -f "$HOME/.dotfiles/.secrets" ] && source "$HOME/.dotfiles/.secrets"
```

Then restart Claude Code (or `/reload-plugins`) so the server reconnects with the
header. Launching the desktop app from a GUI may not inherit shell exports — start
`claude` from a terminal, or set `GITHUB_TOKEN` where the app can see it. A
`gh`-issued token covers most tools; mint a fine-grained PAT if a specific call 403s.

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
├── plugins/tanh-tools/               # the plugin (agents, skills, hooks, MCP)
├── python/                           # pip package → PyPI
├── js/                               # npm package
├── clang/                            # dotless canonical configs + install.sh
└── .github/workflows/                # release-python, release-js, clang-check
```

## Releasing

Tag and push `vX.Y.Z`: `release-python.yml` builds + publishes the wheel and
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
