"""Project-root conftest: auto-format and auto-fix before each test session."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def pytest_configure(config) -> None:
    subprocess.run(["ruff", "format", str(ROOT)], cwd=ROOT, check=False)
    subprocess.run(["ruff", "check", "--fix", str(ROOT)], cwd=ROOT, check=False)

    if not (ROOT / "Himark" / "adapters" / "_gen").is_dir():
        subprocess.run(
            [sys.executable, "-m", "Himark", "gen-parser"],
            cwd=ROOT,
            check=True,
        )
