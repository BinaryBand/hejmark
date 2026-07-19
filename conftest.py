"""Project-root conftest: make the Lean and ANTLR toolchains visible to the infrastructure tests."""

from __future__ import annotations

import os
from importlib.metadata import version
from pathlib import Path

# elan (the Lean toolchain manager) installs `lake`/`lean` here, but this
# directory isn't reliably on PATH for every invocation of `uv run pytest`.
# Prepend it so the Lean build gate in test_lean.py can find the toolchain
# instead of silently skipping.
_ELAN_BIN = Path.home() / ".elan" / "bin"
if _ELAN_BIN.is_dir():
    os.environ["PATH"] = f"{_ELAN_BIN}{os.pathsep}{os.environ.get('PATH', '')}"

# Unpinned, the `antlr4` launcher asks Maven for the latest tool version on
# every run, and falls over entirely when that request fails and no jar has
# been cached under ~/.m2. Pin it to the runtime version from pyproject.toml,
# which is also the only tool version whose generated parser is guaranteed to
# match the pinned `antlr4-python3-runtime`.
os.environ.setdefault("ANTLR4_TOOLS_ANTLR_VERSION", version("antlr4-python3-runtime"))
