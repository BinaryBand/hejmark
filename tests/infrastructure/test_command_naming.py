"""Gate: enforce kebab-case verb-noun naming on CLI ``@command`` calls.

This is a hejmark-specific convention not shipped by the scaffold, so it
lives outside the uniform ``test_lint.py`` gate in the free-form
``tests/infrastructure/`` category.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "hejmark"

# The ANTLR-generated parser package: a build artifact, exempt from source rules.
GENERATED = "_gen"

# Kebab-case verb-noun: a lowercase letter, then lowercase digits/hyphens.
COMMAND_NAME_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")


def _extract_command_name(decorator: ast.expr, func_name: str) -> str | None:
    """Return the CLI name a ``command`` decorator gives *func_name*, or *None*.

    Matches both the bare ``@command(...)`` and the ``@app.command(...)`` form
    Typer actually uses -- an ``ast.Attribute``, which an earlier version of
    this gate skipped, making it vacuous. When the decorator carries no explicit
    name, Typer derives one from the function name by replacing underscores with
    hyphens, so that derived name is what gets checked.
    """
    if not isinstance(decorator, ast.Call):
        return None
    func = decorator.func
    is_command = (isinstance(func, ast.Name) and func.id == "command") or (
        isinstance(func, ast.Attribute) and func.attr == "command"
    )
    if not is_command:
        return None
    if decorator.args:
        arg = decorator.args[0]
        if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
            return arg.value
        return None
    return func_name.replace("_", "-")


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
        if not isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef):
            continue
        for decorator in node.decorator_list:
            name = _extract_command_name(decorator, node.name)
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
