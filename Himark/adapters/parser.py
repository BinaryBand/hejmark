"""adapters.antlr_parser: parses Himark source using the generated ANTLR parser.

Imports `Himark.adapters._gen`, the build artifact `adapters.antlr.AntlrGenerator`
writes (and `Himark gen-parser` triggers). It's gitignored and not present until
generated, so the import is deferred to `parse()` and translated into a clear
domain error rather than a bare `ModuleNotFoundError` reaching the CLI.
"""

from __future__ import annotations

import importlib

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

    def parse(self, source: str) -> list[str]:
        """Return syntax error messages for *source*; empty means it parsed cleanly.

        Raises:
            GeneratedParserMissingError: `Himark.adapters._gen` doesn't exist.
        """
        try:
            lexer_module = importlib.import_module("Himark.adapters._gen.HimarkLexer")
            parser_module = importlib.import_module("Himark.adapters._gen.HimarkParser")
        except ModuleNotFoundError as exc:
            msg = "generated parser not found; run `Himark gen-parser` first"
            raise GeneratedParserMissingError(msg) from exc

        listener = _CollectingErrorListener()
        lexer = lexer_module.HimarkLexer(InputStream(source))
        lexer.removeErrorListeners()
        lexer.addErrorListener(listener)
        parser = parser_module.HimarkParser(CommonTokenStream(lexer))
        parser.removeErrorListeners()
        parser.addErrorListener(listener)
        parser.query()
        return listener.errors
