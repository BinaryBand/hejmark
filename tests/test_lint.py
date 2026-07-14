"""CI/CD gate: fail the suite when any linter, type checker, or dead-code scan reports issues."""

from __future__ import annotations

import ast
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Himark"
TESTS = ROOT / "tests"
# The mirrored, per-layer unit tests live under tests/unit/, leaving the rest of
# tests/ (e.g. tests/infrastructure/, tests/integration/) free for test
# categories the mirror check does not police.
UNIT_TESTS = TESTS / "unit"

# No ruff rule caps file length; this is the single most effective knob for
# keeping modules navigable, so enforce it here.
MAX_MODULE_LINES = 400

# Source modules that never need a dedicated mirror test: the package/CLI entry
# shims, the pure Protocol interface module, and package ``__init__`` files
# (which serve as re-export / composition-root surfaces, not logic modules).
MIRROR_EXEMPT = {"__init__.py", "__main__.py", "ports.py"}

# The ANTLR-generated parser package: a build artifact, exempt from the source
# rules below just as it is from ruff, ty, vulture, and ast-grep.
GENERATED = "_gen"

# Kebab-case verb-noun: a lowercase letter, then lowercase digits/hyphens.
# The first segment is the verb, subsequent segments are nouns / modifiers.
COMMAND_NAME_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")


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
    result = _run(["ast-grep", "scan", "--config", str(ROOT / "sgconfig.yml"), str(ROOT)])
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
        # _gen holds generated ANTLR code: not authored source, unavoidably long.
        if GENERATED in parts:
            continue
        line_count = path.read_text().count("\n") + 1
        if line_count > MAX_MODULE_LINES:
            offenders.append(f"{path.relative_to(ROOT)}: {line_count} lines")
    listing = "\n".join(offenders)
    assert not offenders, f"modules exceed {MAX_MODULE_LINES} lines; split them:\n\n{listing}"


def _has_top_level_definition(path: Path) -> bool:
    """Return True if the module defines any top-level function or class."""
    tree = ast.parse(path.read_text())
    return any(
        isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef | ast.ClassDef)
        for node in tree.body
    )


def _expected_test(rel: Path) -> Path:
    """Map a source module (relative to PACKAGE) to its mirror test path."""
    if rel.name == "__init__.py":
        return UNIT_TESTS / rel.parent / f"test_{rel.parent.name}.py"
    return UNIT_TESTS / rel.parent / f"test_{rel.stem}.py"


def test_tests_mirror_package() -> None:
    """Every source module with logic must have a mirrored test under tests/unit/.

    tests/unit/ mirrors the package layout 1:1: a source module ``PKG/<path>.py``
    requires ``tests/unit/<path>/test_<name>.py`` (a package ``__init__.py`` maps
    to ``test_<dir>.py``). Pure namespace shells (no top-level def/class) and the
    entries in MIRROR_EXEMPT are skipped, so a test is required only once a
    module actually carries logic. Other tests/ subtrees (integration,
    infrastructure, ...) are free-form and not checked here.
    """
    offenders: list[str] = []
    for path in sorted(PACKAGE.rglob("*.py")):
        rel = path.relative_to(PACKAGE)
        if any(part.startswith(".") for part in rel.parts) or path.name in MIRROR_EXEMPT:
            continue
        if GENERATED in rel.parts:
            continue
        if not _has_top_level_definition(path):
            continue
        expected = _expected_test(rel)
        if not expected.exists():
            offenders.append(f"{path.relative_to(ROOT)} -> {expected.relative_to(ROOT)}")
    listing = "\n".join(offenders)
    assert not offenders, (
        f"source modules missing their mirror test (create each right-hand file):\n\n{listing}"
    )


def _extract_command_name(node: ast.Call) -> str | None:
    """Return the command name from a ``@command("name")`` call, or *None*."""
    func = node.func
    if not isinstance(func, ast.Name) or func.id != "command":
        return None
    if not node.args:
        return None
    arg = node.args[0]
    if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
        return arg.value
    return None


def _collect_command_names() -> list[tuple[str, str]]:
    """Scan all Python source for ``@command("name")`` calls.

    Returns a list of ``(relative_path, command_name)`` tuples.
    """
    found: list[tuple[str, str]] = []
    for path in sorted(PACKAGE.rglob("*.py")):
        rel = path.relative_to(PACKAGE)
        if any(part.startswith(".") for part in rel.parts):
            continue
        if GENERATED in rel.parts:
            continue
        found.extend(_scan_module(path))
    return found


def _scan_module(path: Path) -> list[tuple[str, str]]:
    """Parse *path* and return ``(relpath, name)`` for each ``@command``."""
    tree = ast.parse(path.read_text())
    results: list[tuple[str, str]] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = _extract_command_name(node)
            if name is not None:
                results.append((str(path.relative_to(ROOT)), name))
    return results


def test_command_naming() -> None:
    """All ``@command("...")`` names must follow kebab-case verb-noun convention.

    The pattern enforces a leading lowercase letter followed by lowercase
    alphanumeric characters and hyphens (e.g. ``gen-parser``, ``show-config``).
    """
    offenders = [
        f"{src}: @command({name!r})"
        for src, name in _collect_command_names()
        if not COMMAND_NAME_RE.match(name)
    ]
    listing = "\n".join(offenders)
    assert not offenders, (
        f"command names must be kebab-case verb-noun (e.g. 'gen-parser'):\n\n{listing}"
    )
