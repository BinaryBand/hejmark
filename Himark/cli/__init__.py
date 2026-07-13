"""cli: command-line entry points and argument parsing.

The only layer that may import from app. Keep it thin -- parse arguments,
call into app, format results. May use print() for output.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import typer

app = typer.Typer(add_completion=False, no_args_is_help=True)

_ROOT = Path(__file__).resolve().parents[2]
_ANTLR_VERSION = "4.13.2"
# Relative to _ROOT (the antlr4 subprocess is run with cwd=_ROOT below) so the
# "Generated from ..." header embedded in the output stays machine-independent.
_GRAMMAR = Path("grammar/Himark.g4")
_OUT_DIR = Path("Himark/adapters/_gen")


# A no-op callback keeps this a named-subcommand CLI even while it has only one
# command -- Typer otherwise collapses a single-command app so its name is not
# required, which would make `gen-parser` uncallable by name.
@app.callback()
def _callback() -> None:
    """Himark: a query language over pointed alphabets."""


@app.command("gen-parser")
def gen_parser() -> None:
    """Regenerate the ANTLR lexer/parser/visitor from grammar/Himark.g4."""
    # S603/S607: fixed argv, no untrusted input; "antlr4" is resolved via PATH by design.
    subprocess.run(  # noqa: S603
        [  # noqa: S607
            "antlr4",
            "-v",
            _ANTLR_VERSION,
            "-Dlanguage=Python3",
            "-visitor",
            "-no-listener",
            "-Xexact-output-dir",
            "-o",
            str(_OUT_DIR),
            str(_GRAMMAR),
        ],
        cwd=_ROOT,
        check=True,
    )
    (_ROOT / _OUT_DIR / "__init__.py").touch()


def main() -> None:
    """Run the command-line interface."""
    app()
