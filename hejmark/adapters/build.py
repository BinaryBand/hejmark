r"""Walks an ANTLR parse tree into a faithful :mod:`hejmark.core.compiler.ast` AST.

The grammar carries the classification, so this module only transcribes: every
labelled alternative (``# UniDecl``, ``# RangeMember``, ``# QueryStep``, ...)
generates its own context class, and each one maps to exactly one AST node.
Nothing is resolved, folded, or flattened here.

Two syntactic normalizations happen, both of them readings the grammar already
states: an escape resolves to its character (``\n``/``\t``/``\r`` to the
whitespace they name, any other ``\x`` to ``x``), and a braced exponent
``^{w'}`` unwraps to the parameter name it spells.
"""

from __future__ import annotations

from typing import Any

from hejmark.core.compiler.ast import (
    DefDecl,  # def name params = body
    Exponent,  # A^lo..hi count span
    Expr,  # product of units (a query)
    Interp,  # {{$k}} capture interpolation
    IterStatement,  # query <=> template, iterated to a fixpoint
    Operand,  # the `_` pipeline-stage token
    Param,  # a def parameter: name, or lo..hi pair
    PipeItem,  # one flat pipeline-bracket item
    Read,  # $k back-reference
    Ref,  # @name reference
    RefInterp,  # {{@name}} sentinel interpolation
    ScriptNode,  # a whole script: lines in source order
    Segments,  # a member built from adjacent segments
    SentinelDecl,  # sentinel name declaration
    Statement,  # steps joined by =>
    Subtract,  # !{...} member
    Template,  # quoted template: text + interpolation sites
    Text,  # literal template text
    UniDecl,  # uni name = expr declaration
    Unit,  # one factor: base + exponent + pipelines
    UniverseNode,  # a surface brace group {...}
    ValueCut,  # @lo..hi value-line cut
)
from hejmark.core.floor.syntax import Closure, Face, HimarkSyntaxError, Range

# The three mnemonic escapes. Every other escape the lexer admits is a
# structural character standing for itself; unknown escapes never reach here,
# since the grammar refuses to lex them (the spec's "no reading"). Whitespace is
# a literal face character inside braces, so these mnemonics are the only way the
# foundation's own scripts spell it on one line (`{\n}`).
_MNEMONIC = {"n": "\n", "t": "\t", "r": "\r"}


def _unescape(text: str) -> str:
    r"""Resolve one token: ``\..`` to two dots, the mnemonics to whitespace, ``\x`` to ``x``."""
    if not text.startswith("\\"):
        return text
    if text == "\\..":
        return ".."
    return _MNEMONIC.get(text[1], text[1])


def _face(ctx: Any) -> Face:
    """Assemble a face from its ordered ``(CHAR | DOT | ESC)+`` tokens."""
    return Face("".join(_unescape(child.getText()) for child in ctx.children or ()))


def _exponent_atom(ctx: Any) -> str:
    """Read one count atom as raw text: a numeral, a parameter name, or a braced one."""
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


def _exponent(ctx: Any) -> Exponent:
    """Read an exponent as a closed count span; a lone atom is the degenerate ``n..n``."""
    atoms = ctx.exponentAtom()
    hi = _exponent_atom(atoms[1]) if len(atoms) > 1 else None
    return Exponent(_exponent_atom(atoms[0]), hi)


def _pipeline(ctx: Any) -> tuple[PipeItem, ...]:
    """Read one pipeline bracket as its flat item list; binding splits it later."""
    items = []
    for item in ctx.pipeItem():
        args = item.pipeArg()
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
    """Read a unit: a base, an optional exponent, and its chain of pipelines."""
    exponent = ctx.exponent()
    return Unit(
        _base(ctx.base()),
        _exponent(exponent) if exponent is not None else None,
        tuple(_pipeline(bracket) for bracket in ctx.pipeline()),
    )


def _segment(ctx: Any) -> Unit | Closure | Face | Read:
    """Dispatch a segment: a factor, the closure token, a back-reference, or a face."""
    if ctx.base() is not None:
        return _unit(ctx)
    capture = ctx.CAPTURE()
    if capture is not None:
        return Read(int(capture.getText()[1:]))
    face = ctx.face()
    return _face(face) if face is not None else Closure()


def _member(ctx: Any) -> Range | ValueCut | Subtract | Segments:
    """Dispatch one member context to its faithful AST node."""
    match type(ctx).__name__:
        case "RangeMemberContext":
            faces = ctx.face()
            return Range(_face(faces[0]).text, _face(faces[1]).text)
        case "ValueMemberContext":
            bound = ctx.valueBound()
            capture = bound.CAPTURE()
            hi: str | Read = (
                Read(int(capture.getText()[1:]))
                if capture is not None
                else _face(bound.face()).text
            )
            return ValueCut(ctx.REF().getText()[1:], hi)
        case "SubtractMemberContext":
            return Subtract(_universe(ctx.universe()))
        case "SegmentsMemberContext":
            return Segments(tuple(_segment(segment) for segment in ctx.segment()))
        case name:
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
        match type(part).__name__:
            case "InterpPartContext":
                capture = part.interp().CAPTURE()
                if capture is not None:
                    parts.append(Interp(capture.getText()))
                else:
                    parts.append(RefInterp(part.interp().REF().getText()[1:]))
            case "EscPartContext":
                parts.append(Text(_unescape(part.getText())))
            case _:
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


def _declaration(ctx: Any) -> UniDecl | DefDecl | SentinelDecl:
    """Dispatch a declaration: a ``uni`` name, a sentinel, or a ``def`` definition."""
    match type(ctx).__name__:
        case "UniDeclContext":
            return UniDecl(ctx.IDENT().getText(), _expr(ctx.expr()))
        case "SentinelDeclContext":
            return SentinelDecl(ctx.IDENT().getText())
        case _:
            params = tuple(_param(param) for param in ctx.param())
            return DefDecl(ctx.IDENT().getText(), params, _expr(ctx.expr()))


def _line(ctx: Any) -> UniDecl | DefDecl | SentinelDecl | IterStatement | Statement:
    """Dispatch a line: a declaration, a contracting statement, or a statement."""
    declaration = ctx.declaration()
    if declaration is not None:
        return _declaration(declaration)
    contract = ctx.contract()
    if contract is not None:
        return IterStatement(_expr(contract.expr()), _template(contract.template()))
    statement = ctx.statement()
    return Statement(tuple(_step(step) for step in statement.step()))


def build(ctx: Any) -> ScriptNode:
    """Assemble a whole script from its lines, in source order."""
    return ScriptNode(tuple(_line(line) for line in ctx.line()))
