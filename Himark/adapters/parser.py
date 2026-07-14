r"""ANTLR binding: turn Himark source into a faithful :mod:`Himark.core.syntax` AST.

This adapter owns the generated lexer/parser (under ``_gen``) and the ANTLR
runtime. It installs an error listener that raises :class:`HimarkSyntaxError`
instead of printing to stderr, then walks the parse tree into frozen AST nodes.
Escapes are resolved here (``\x`` -> ``x``); no other normalization happens.
"""

from __future__ import annotations

from typing import Any

from antlr4 import CommonTokenStream, InputStream
from antlr4.error.ErrorListener import ErrorListener

from Himark.core.syntax import (
    Face,
    Final,
    Fold,
    HimarkSyntaxError,
    QueryNode,
    Range,
    Subtract,
    UniverseNode,
)

# Deferred (assigned at runtime by the first to_ast() call -- see _gen bootstrap in .FIX.md)
HimarkLexer: Any
HimarkParser: Any


class _RaisingErrorListener(ErrorListener):
    """Error listener that raises instead of printing to stderr."""

    def syntaxError(  # noqa: N802, PLR0913
        self,
        recognizer: object,
        offendingSymbol: object,  # noqa: N803
        line: int,
        column: int,
        msg: str,
        e: object,
    ) -> None:
        """Raise :class:`HimarkSyntaxError` describing the offending position."""
        del recognizer, offendingSymbol, e
        detail = f"line {line}:{column} {msg}"
        raise HimarkSyntaxError(detail)


_RAISING_LISTENER = _RaisingErrorListener()


def _token_char(token_text: str) -> str:
    r"""Resolve one face token to its character (``\x`` -> ``x``; else itself)."""
    return token_text[1] if token_text.startswith("\\") else token_text


def _build_face(ctx: HimarkParser.FaceContext) -> Face:
    """Assemble a face from its ordered ``(CHAR | DOT | ESC)+`` tokens."""
    return Face("".join(_token_char(child.getText()) for child in ctx.children or ()))


def _build_member(ctx: HimarkParser.MemberContext) -> Face | Range | Final | Fold | Subtract:
    """Dispatch one member context to its faithful AST node."""
    if isinstance(ctx, HimarkParser.RangeMemberContext):
        return Range(ctx.CHAR(0).getText(), ctx.CHAR(1).getText())
    if isinstance(ctx, HimarkParser.FinalMemberContext):
        return Final(_build_face(ctx.face()).text)
    if isinstance(ctx, HimarkParser.SubtractMemberContext):
        return Subtract(_build_universe(ctx.universe()))
    if isinstance(ctx, HimarkParser.FoldMemberContext):
        return Fold(_build_universe(ctx.universe()))
    if isinstance(ctx, HimarkParser.FaceMemberContext):
        return _build_face(ctx.face())
    unreachable = "unknown member alternative"
    raise HimarkSyntaxError(unreachable)


def _build_universe(ctx: HimarkParser.UniverseContext) -> UniverseNode:
    """Assemble a universe from its members in declaration order."""
    return UniverseNode(tuple(_build_member(member) for member in ctx.member()))


def _build_query(ctx: HimarkParser.QueryContext) -> QueryNode:
    """Assemble the whole query from its juxtaposed universes."""
    return QueryNode(tuple(_build_universe(universe) for universe in ctx.universe()))


def to_ast(source: str) -> QueryNode:
    """Parse Himark source into a faithful AST, raising on any syntax error."""
    global HimarkLexer, HimarkParser  # noqa: PLW0603 -- deferred from module scope to break _gen bootstrap cycle
    from Himark.adapters._gen.HimarkLexer import (  # noqa: PLC0415 -- deferred; see global above
        HimarkLexer,
    )
    from Himark.adapters._gen.HimarkParser import (  # noqa: PLC0415 -- deferred; see global above
        HimarkParser,
    )

    lexer = HimarkLexer(InputStream(source))
    lexer.removeErrorListeners()
    lexer.addErrorListener(_RAISING_LISTENER)
    parser = HimarkParser(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(_RAISING_LISTENER)
    return _build_query(parser.query())
