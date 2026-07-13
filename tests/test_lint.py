"""CI/CD gate: fail the test suite when any linter, type checker, or dead-code scanner
reports issues.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)


def test_ruff_check() -> None:
    """ruff check must produce zero diagnostics after auto-fix."""
    result = _run(["ruff", "check", str(ROOT)])
    assert result.returncode == 0, (
        f"ruff check failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_ruff_format() -> None:
    """ruff format --check must report no reformats needed."""
    result = _run(["ruff", "format", "--check", str(ROOT)])
    assert result.returncode == 0, (
        "ruff format --check found unformatted files "
        f"(exit {result.returncode}):\n\n{result.stdout}"
    )


def test_ty_check() -> None:
    """ty check must produce zero diagnostics."""
    result = _run(["ty", "check", str(ROOT)])
    assert result.returncode == 0, (
        f"ty check failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_import_linter() -> None:
    """import-linter contracts must all pass."""
    result = _run(["lint-imports", "--config", str(ROOT / "pyproject.toml")])
    assert result.returncode == 0, (
        f"import-linter failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_vulture() -> None:
    """vulture must report no dead code above the confidence threshold."""
    result = _run(["vulture"])
    assert result.returncode == 0, (
        f"vulture found dead code (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_astgrep() -> None:
    """ast-grep architectural rules must all pass.

    Installed via the `ast-grep-cli` dev dependency (declared in
    pyproject.toml), which provides both the `ast-grep` and `sg` binaries.
    """
    result = _run(["ast-grep", "scan", "--config", str(ROOT / "sgconfig.yml"), str(ROOT)])
    assert result.returncode == 0, (
        f"ast-grep found violations (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )
