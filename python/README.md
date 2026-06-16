# tanh-tooling (Python)

Shared tanh-lab Python developer configuration: a `ruff` base and a `pyright`
base, plus a `tanh-tooling sync` CLI that materialises them into a consuming repo.

## Use it

```sh
uv add tanh-tooling
uv run tanh-tooling sync        # writes ruff_base.toml + pyright_base.json
```

Then keep thin, hand-owned configs that extend the bases:

```toml
# ruff.toml
extend = "ruff_base.toml"
```

```json
// pyrightconfig.json
{ "extends": "pyright_base.json", "include": ["src"] }
```

The synced `ruff_base.toml` / `pyright_base.json` are committed but **generated** —
treat them like a lockfile, never hand-edit. CI drift check:

```sh
uv run tanh-tooling sync --check
```
