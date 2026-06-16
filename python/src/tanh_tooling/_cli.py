import argparse
import importlib.resources as res
import shutil
import sys
from pathlib import Path

from . import __version__

# package-relative source -> filename written into the consuming repo
FILES = {"ruff_base.toml": "ruff_base.toml", "pyright_base.json": "pyright_base.json"}


def _bundled(name: str) -> Path:
    # wheels unpack into site-packages, so this resolves to a real path
    return Path(str(res.files("tanh_tooling").joinpath("data", name)))


def main() -> int:
    p = argparse.ArgumentParser(prog="tanh-tooling")
    p.add_argument("--version", action="version", version=__version__)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sync", help="materialise Python base configs into this repo")
    s.add_argument(
        "--check",
        action="store_true",
        help="fail if a base config is missing or differs (CI)",
    )
    args = p.parse_args()

    dest, drift = Path.cwd(), False
    for src_name, out_name in FILES.items():
        src, tgt = _bundled(src_name), dest / out_name
        if args.check:
            if not tgt.exists() or tgt.read_bytes() != src.read_bytes():
                print(f"out of date: {out_name}")
                drift = True
        else:
            shutil.copy(src, tgt)
            print(f"wrote {out_name}")
    if args.check and drift:
        print("run `tanh-tooling sync` and commit the result", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
