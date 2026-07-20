r"""Walks an ANTLR parse tree into a faithful :mod:`hejmark.core.surface` AST.

The grammar carries the classification, so this module only transcribes: every
labelled alternative (``# UniDecl``, ``# RangeMember``, ``# QueryStep``, ...)
generates its own context class, and each one maps to exactly one AST node.
Nothing is resolved, folded, or flattened here.

Two syntactic normalizations happen, both of them readings the grammar already
states: an escape ``\\x`` resolves to ``x``, and a braced exponent ``^{w'}``
unwraps to the parameter name it spells.
"""

from __future__ import annotations

from typing import Any

from hejmark.core.surface import (
    DefDecl,
    Expr,
    Interp,
    Operand,
    Param,
    PipeItem,
    Ref,
    ScriptNode,
    Segments,
    Statement,
    Subtract,
    Template,
    Text,
    UniDecl,
    Unit,
    UniverseNode,
)
from hejmark.core.syntax import Closure, Face, Final, HimarkSyntaxError, Range


def _unescape(text: str) -> str:
    r"""Resolve one token's text: ``\x`` yields ``x``, anything else itself."""
    return text[1] if text.startswith("\\") else text


def _face(ctx: Any) -> Face:
    """Assemble a face from its ordered ``(CHAR | DOT | ESC)+`` tokens."""
    return Face("".join(_unescape(child.getText()) for child in ctx.children or ()))


def _exponent(ctx: Any) -> str:
    """Read an exponent as raw text: a numeral, a parameter name, or a braced one."""
    universe = ctx.universe()
    if universe is not None:
        inner = _universe(universe)
        member = inner.members[0] if inner.members else None
        if isinstance(member, Segments) and len(member.segments) == 1:
            only = member.segments[0]
            if isinstance(only, Face):
                return only.text
        msg = "a braced exponent must spell a single parameter name"
        raise HimarkSyntaxError(msg)
    face = ctx.face()
    return _face(face).text if face is not None else ctx.getText()


def _pipeline(ctx: Any) -> tuple[PipeItem, ...]:
    """Read a pipeline bracket as its flat item list; binding splits it later."""
    if ctx is None:
        return ()
    items = []
    for item in ctx.pipeItem():
        args = item.ARG()
        hi = _unescape(args[1].getText()) if len(args) > 1 else None
        items.append(PipeItem(_unescape(args[0].getText()), hi))
    return tuple(items)


def _base(ctx: Any) -> UniverseNode | Ref | Operand:
    """Dispatch a base: a brace group, a reference, or the operand token."""
    universe = ctx.universe() if hasattr(ctx, "universe") else None
    if universe is not None:
        return _universe(universe)
    text = ctx.getText()
    return Operand() if text == "_" else Ref(text[1:])


def _unit(ctx: Any) -> Unit:
    """Read a unit: a base with an optional exponent and an optional pipeline."""
    exponent = ctx.exponent()
    return Unit(
        _base(ctx.base()),
        _exponent(exponent) if exponent is not None else None,
        _pipeline(ctx.pipeline()),
    )


def _segment(ctx: Any) -> Unit | Closure | Face:
    """Dispatch a segment: a factor, the closure token, or a bare face."""
    if ctx.base() is not None:
        return _unit(ctx)
    face = ctx.face()
    return _face(face) if face is not None else Closure()


def _member(ctx: Any) -> Any:
    """Dispatch one member context to its faithful AST node."""
    name = type(ctx).__name__
    if name == "RangeMemberContext":
        faces = ctx.face()
        return Range(_face(faces[0]).text, _face(faces[1]).text)
    if name == "FinalMemberContext":
        return Final(_face(ctx.face()).text)
    if name == "SubtractMemberContext":
        return Subtract(_universe(ctx.universe()))
    if name == "SegmentsMemberContext":
        return Segments(tuple(_segment(segment) for segment in ctx.segment()))
    msg = f"unknown member alternative: {name}"
    raise HimarkSyntaxError(msg)


def _universe(ctx: Any) -> UniverseNode:
    """Assemble a brace group from its members in declaration order."""
    return UniverseNode(tuple(_member(member) for member in ctx.member()))


def _expr(ctx: Any) -> Expr:
    """Assemble an expression: adjacent units are the product."""
    return Expr(tuple(_unit(unit) for unit in ctx.unit()))


def _template(ctx: Any) -> Template:
    """Assemble a template from its parts; adjacent literal text is kept as written."""
    parts = []
    for part in ctx.part():
        name = type(part).__name__
        if name == "InterpPartContext":
            parts.append(Interp(part.interp().CAPTURE().getText()))
        elif name == "EscPartContext":
            parts.append(Text(_unescape(part.getText())))
        else:
            parts.append(Text(part.getText()))
    return Template(tuple(parts))


def _step(ctx: Any) -> Expr | Template:
    """Dispatch a step: a query expression or a template."""
    template = ctx.template() if type(ctx).__name__ == "TemplateStepContext" else None
    return _template(template) if template is not None else _expr(ctx.expr())


def _param(ctx: Any) -> Param:
    """Read a parameter: an identifier, or an identifier pair ``lo..hi``."""
    names = ctx.IDENT()
    return Param(names[0].getText(), names[1].getText() if len(names) > 1 else None)


def _declaration(ctx: Any) -> UniDecl | DefDecl:
    """Dispatch a declaration: a ``uni`` name or a ``:=`` definition."""
    if type(ctx).__name__ == "UniDeclContext":
        return UniDecl(ctx.IDENT().getText(), _expr(ctx.expr()))
    params = tuple(_param(param) for param in ctx.param())
    return DefDecl(ctx.IDENT().getText(), params, _expr(ctx.expr()))


def _line(ctx: Any) -> Any:
    """Dispatch a line: a declaration or a statement."""
    declaration = ctx.declaration()
    if declaration is not None:
        return _declaration(declaration)
    statement = ctx.statement()
    return Statement(tuple(_step(step) for step in statement.step()))


def build(ctx: Any) -> ScriptNode:
    """Assemble a whole script from its lines, in source order."""
    return ScriptNode(tuple(_line(line) for line in ctx.line()))
