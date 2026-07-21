"""adapters.parser: parses hejmark source using the generated ANTLR parser.

Imports `hejmark.adapters._gen`, the build artifact `adapters.antlr.AntlrGenerator`
writes (and `hejmark gen-parser` triggers). It's gitignored and not present until
generated, so the import is deferred to `parse()` and translated into a clear
domain error rather than a bare `ModuleNotFoundError` reaching the CLI.
"""

from __future__ import annotations

import importlib
from typing import Any

from antlr4 import CommonTokenStream, InputStream
from antlr4.error.ErrorListener import ErrorListener

from hejmark.adapters.build import build
from hejmark.core.compiler.ast import ScriptNode
from hejmark.core.floor.syntax import HimarkSyntaxError


class GeneratedParserMissingError(RuntimeError):
    """Raised when `hejmark.adapters._gen` hasn't been generated yet."""


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
    """Parses hejmark source with the generated ANTLR parser.

    `to_ast` is the `core.ports.ToAst` port the engine consumes; `parse` and
    `parse_tree` are the error-listing and tree-dumping helpers the CLI uses.
    """

    def _run(self, source: str) -> tuple[Any, list[str], Any]:
        """Parse *source* and return `(tree, errors, parser)`.

        Raises:
            GeneratedParserMissingError: `hejmark.adapters._gen` doesn't exist.
        """
        try:
            lexer_module = importlib.import_module("hejmark.adapters._gen.HimarkLexer")
            parser_module = importlib.import_module("hejmark.adapters._gen.HimarkParser")
        except ModuleNotFoundError as exc:
            msg = "hejmark.adapters._gen not found; run `hejmark gen-parser` first"
            raise GeneratedParserMissingError(msg) from exc
        listener = _CollectingErrorListener()
        lexer = lexer_module.HimarkLexer(InputStream(source))
        lexer.removeErrorListeners()
        lexer.addErrorListener(listener)
        parser = parser_module.HimarkParser(CommonTokenStream(lexer))
        parser.removeErrorListeners()
        parser.addErrorListener(listener)
        tree = parser.script()
        return tree, listener.errors, parser

    def parse(self, source: str) -> list[str]:
        """Return syntax error messages for *source*; empty means it parsed cleanly.

        Raises:
            GeneratedParserMissingError: `hejmark.adapters._gen` doesn't exist.
        """
        _tree, errors, _parser = self._run(source)
        return errors

    def to_ast(self, source: str) -> ScriptNode:
        """Parse *source* into a faithful `core.compiler` AST.

        Raises:
            GeneratedParserMissingError: `hejmark.adapters._gen` doesn't exist.
            HimarkSyntaxError: *source* failed to lex or parse.
        """
        tree, errors, _parser = self._run(source)
        if errors:
            raise HimarkSyntaxError(errors[0])
        return build(tree)

    def parse_tree(self, source: str) -> str:
        """Return a LISP-style s-expression dump of *source*'s parse tree.

        Testing/inspection helper, not part of `core.ports.SurfaceParser` -- core
        has no evaluator yet to consume a real AST, so this only formats ANTLR's
        own tree for a human to read.

        Raises:
            GeneratedParserMissingError: `hejmark.adapters._gen` doesn't exist.
        """
        tree, _errors, parser = self._run(source)
        return tree.toStringTree(recog=parser)
