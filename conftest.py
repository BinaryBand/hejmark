"""Project-root conftest: make the Lean toolchain visible to test_lean.py."""

from __future__ import annotations

import os
from pathlib import Path

# elan (the Lean toolchain manager) installs `lake`/`lean` here, but this
# directory isn't reliably on PATH for every invocation of `uv run pytest`.
# Prepend it so the Lean build gate in test_lean.py can find the toolchain
# instead of silently skipping.
_ELAN_BIN = Path.home() / ".elan" / "bin"
if _ELAN_BIN.is_dir():
    os.environ["PATH"] = f"{_ELAN_BIN}{os.pathsep}{os.environ.get('PATH', '')}"
