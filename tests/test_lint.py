"""CI/CD gate: fail the suite when any linter, type checker, or dead-code scan reports issues."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# No ruff rule caps file length; this is the single most effective knob for
# keeping modules navigable, so enforce it here.
MAX_MODULE_LINES = 400


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT, check=False)


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
        f"ruff format --check found unformatted files (exit {result.returncode}):\n\n"
        f"{result.stdout}"
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
    result = _run(
        ["ast-grep", "scan", "--config", str(ROOT / "sgconfig.yml"), str(ROOT)]
    )
    assert result.returncode == 0, (
        f"ast-grep found violations (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_module_length() -> None:
    """No source module may exceed MAX_MODULE_LINES lines."""
    offenders: list[str] = []
    for path in sorted(ROOT.rglob("*.py")):
        parts = path.relative_to(ROOT).parts
        if any(part.startswith(".") for part in parts) or "tests" in parts:
            continue
        # _gen contains generated ANTLR code that is unavoidably long
        if "_gen" in parts:
            continue
        line_count = path.read_text().count("\n") + 1
        if line_count > MAX_MODULE_LINES:
            offenders.append(f"{path.relative_to(ROOT)}: {line_count} lines")
    listing = "\n".join(offenders)
    assert not offenders, f"modules exceed {MAX_MODULE_LINES} lines; split them:\n\n{listing}"
