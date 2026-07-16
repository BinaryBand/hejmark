"""adapters.parser: parses Himark source using the generated ANTLR parser.

Imports `Himark.adapters._gen`, the build artifact `adapters.antlr.AntlrGenerator`
writes (and `Himark gen-parser` triggers). It's gitignored and not present until
generated, so the import is deferred to `parse()` and translated into a clear
domain error rather than a bare `ModuleNotFoundError` reaching the CLI.
"""

from __future__ import annotations

import importlib
from typing import Any

from antlr4 import CommonTokenStream, InputStream
from antlr4.error.ErrorListener import ErrorListener


class GeneratedParserMissingError(RuntimeError):
    """Raised when `Himark.adapters._gen` hasn't been generated yet."""


class _CollectingErrorListener(ErrorListener):
    """Records syntax errors as strings instead of printing them to stderr."""

    def __init__(self) -> None:
        self.errors: list[str] = []

    def syntaxError(self, *args: object) -> None:  # noqa: N802  # ty: ignore[invalid-method-override]
        # ANTLR calls this positionally: recognizer, offendingSymbol, line,
        # column, msg, e. Only the location and message are recorded.
        _recognizer, _offending, line, column, msg, _exc = args
        self.errors.append(f"{line}:{column} {msg}")


class AntlrParser:
    """Concrete `core.ports.SurfaceParser` backed by the generated ANTLR parser."""

    def _run(self, source: str) -> tuple[Any, list[str], Any]:
        """Parse *source* and return `(tree, errors, parser)`.

        Raises:
            GeneratedParserMissingError: `Himark.adapters._gen` doesn't exist.
        """
        listener = _CollectingErrorListener()
        lexer = HimarkLexer(InputStream(source))
        lexer.removeErrorListeners()
        lexer.addErrorListener(listener)
        parser = HimarkParser(CommonTokenStream(lexer))
        parser.removeErrorListeners()
        parser.addErrorListener(listener)
        tree = parser.query()
        return tree, listener.errors, parser

    def parse(self, source: str) -> list[str]:
        """Return syntax error messages for *source*; empty means it parsed cleanly.

        Raises:
            GeneratedParserMissingError: `Himark.adapters._gen` doesn't exist.
        """
        _tree, errors, _parser = self._run(source)
        return errors

    def parse_tree(self, source: str) -> str:
        """Return a LISP-style s-expression dump of *source*'s parse tree.

        Testing/inspection helper, not part of `core.ports.SurfaceParser` -- core
        has no evaluator yet to consume a real AST, so this only formats ANTLR's
        own tree for a human to read.

        Raises:
            GeneratedParserMissingError: `Himark.adapters._gen` doesn't exist.
        """
        tree, _errors, parser = self._run(source)
        return tree.toStringTree(recog=parser)
