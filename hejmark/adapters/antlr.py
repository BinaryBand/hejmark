"""adapters.antlr: shells out to the external `antlr4` code generator.

The `antlr4-python3-runtime` dependency is only the runtime library the
generated parser imports at parse time; the generator itself is a separate
Java-backed CLI tool (see `tests/infrastructure/test_antlr.py`, which uses the
same `shutil.which("antlr4")` + subprocess shape as a CI gate). This adapter
is the one non-test place that invocation lives.
"""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Sequence
from pathlib import Path


class AntlrToolNotFoundError(RuntimeError):
    """Raised when the `antlr4` generator is not on PATH."""


class AntlrGenerationError(RuntimeError):
    """Raised when `antlr4` exits non-zero or reports diagnostics."""


class AntlrGenerator:
    """Concrete `core.ports.ParserGenerator` backed by the `antlr4` CLI tool."""

    def generate(self, grammars: Sequence[Path], output_dir: Path, *, language: str) -> None:
        """Generate *language* parser sources for *grammars* into *output_dir*.

        All grammars go through one `antlr4` invocation so a split
        lexer/parser pair resolves its `tokenVocab`; they must share a
        directory, which becomes the tool's working directory.

        Raises:
            AntlrToolNotFoundError: `antlr4` is not on PATH.
            AntlrGenerationError: no grammars, grammars in different
                directories, or `antlr4` exits non-zero.
        """
        tool = shutil.which("antlr4")
        if tool is None:
            msg = "antlr4 not found on PATH; install the ANTLR generator to use gen-parser"
            raise AntlrToolNotFoundError(msg)
        parents = {grammar.parent for grammar in grammars}
        if len(parents) != 1:
            msg = "gen-parser needs one or more grammars sharing a single directory"
            raise AntlrGenerationError(msg)
        output_dir.mkdir(parents=True, exist_ok=True)
        names = [grammar.name for grammar in grammars]
        result = subprocess.run(  # noqa: S603
            [tool, "-Dlanguage=" + language, "-o", str(output_dir.resolve()), *names],
            capture_output=True,
            text=True,
            cwd=parents.pop(),
            check=False,
        )
        if result.returncode != 0:
            msg = (
                f"antlr4 generation failed (exit {result.returncode}):\n"
                f"{result.stdout}{result.stderr}"
            )
            raise AntlrGenerationError(msg)
