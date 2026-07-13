"""gen-parser: regenerate the ANTLR lexer/parser/visitor."""

from __future__ import annotations

import subprocess
from pathlib import Path

from Himark.cli.registry import command

_ROOT = Path(__file__).resolve().parents[3]
_ANTLR_VERSION = "4.13.2"
# Relative to _ROOT (the antlr4 subprocess is run with cwd=_ROOT below) so the
# "Generated from ..." header embedded in the output stays machine-independent.
_GRAMMAR = Path("static/grammar/Himark.g4")
_OUT_DIR = Path("Himark/adapters/_gen")


@command("gen-parser")
def gen_parser() -> None:
    """Regenerate the ANTLR lexer/parser/visitor from static/grammar/Himark.g4."""
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
