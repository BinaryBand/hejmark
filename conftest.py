"""Project-root conftest: bootstrap the gitignored ANTLR parser before each test session."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def pytest_configure(config) -> None:
    # _gen is a gitignored build artifact, so a fresh clone has none. Generate it
    # via the CLI command that owns the antlr recipe rather than duplicating it.
    # check=True so a missing antlr4 binary fails loudly here instead of
    # cascading into confusing import errors inside the tests.
    if not (ROOT / "Himark" / "adapters" / "_gen").is_dir():
        subprocess.run(
            [sys.executable, "-m", "Himark", "gen-parser"],
            cwd=ROOT,
            check=True,
        )
