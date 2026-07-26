"""Expansion: rewrite the L1.5 surface into the floor's five constructors.

This is L1.5's admission rule made executable. A surface construct adds no
denotation -- every application expands into union, subtraction, fold, product
and closure -- or it does not enter. So nothing here is
interpreted: names splice, definitions substitute, exponents repeat, and what
comes out is a plain :mod:`hejmark.core.floor.syntax` tree that
:func:`hejmark.core.engine.denote.universe.denote` reads without knowing L1.5
exists.

The registers are the expander's metafunctions, given tokens. The precedent is
the floor's own bounded range -- ``{a..z}`` is ``{a.., !{s..}}``, which
computes the successor at expansion time -- so ``@0`` reading the head's zero
entry is the same move, not a new kind of thing. Both registers are total:
on an empty head ``@`` is the empty universe and ``@0`` is the unit, so a fill
built on it no-ops.

Splice versus fold is the one decision that needs the floor's own answer. A
name splices -- its entries spread into the enclosing universe -- which is
inlining its members, except when it binds a closure: inlining a binder's
members would rebind ``&`` to the enclosing brace. A binder is therefore
passed through as a braced member, which denotation already splices.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import NoReturn

from hejmark.core.compiler import valueline
from hejmark.core.compiler.ast import (
    DefDecl,
    Exponent,
    Expr,
    Member,
    Operand,
    Param,
    Read,
    Ref,
    Segment,
    Subtract,
    Unit,
    UniverseNode,
    ValueCut,
    read_index,
)
from hejmark.core.compiler.resolve import Binding, Env, bind, canonicalize
from hejmark.core.floor import syntax

# The floor's own binder test: whether a brace expression's members hold a free
# `&`. Expansion must know, because a binder may never be inlined. A question
# about the written tree, so it is answered here rather than by denotation.
from hejmark.core.floor.binder import binds
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import ToFaces

# The empty universe, and the unit: a fold over the empty alphabet, the one
# entry wearing the empty spelling. The unit is the product identity.
EMPTY = syntax.UniverseNode(())
UNIT = syntax.UniverseNode((syntax.Fold(syntax.UniverseNode(())),))


@dataclass(frozen=True)
class Ctx:
    """What an expansion reads: the namespace, denotation, the head, the operand, the bindings.

    ``faces`` is the engine's :data:`~hejmark.core.ir.program.ToFaces`, the one
    thing expansion cannot answer for itself -- carried here rather than
    imported, so the compiler names denotation without depending on it.
    ``head`` is the pipeline head every register reads; ``operand`` is the
    stage operand ``_`` binds to; ``bindings`` maps a definition's parameters
    to the literal spellings an application gave them. The last three are
    ``None`` or empty outside the scope that supplies them, which is what turns
    a stray register or operand into a diagnostic.
    """

    env: Env
    faces: ToFaces
    head: syntax.UniverseNode | None = None
    operand: syntax.UniverseNode | None = None
    bindings: dict[str, str] | None = None

    def spell(self, text: str) -> str:
        """Substitute a parameter name for the spelling bound to it, if any."""
        bindings = self.bindings or {}
        return bindings.get(text, text)


def _refuse_read(spelling: str) -> NoReturn:
    """Refuse a back-reference that reached expansion: it crossed a declaration.

    A query's own reads are substituted before its units expand, so a read
    still standing here sits inside a ``uni`` or ``def`` body -- where there is
    no query to bind it.

    Raises:
        HimarkScopeError: always.
    """
    msg = f"{spelling} reads through a declaration: a factor read stands in the query itself"
    raise HimarkScopeError(msg)


def _zero(node: syntax.UniverseNode, faces: ToFaces) -> str | None:
    """The canonical face of a universe's zero entry, or ``None`` if it has none.

    Reads the first face of the lazy stream, so an infinite head costs one
    entry rather than a materialization.
    """
    return next(iter(faces(node)), None)


def _product(factors: tuple[syntax.UniverseNode, ...]) -> syntax.UniverseNode:
    """Fold a factor list into one universe; adjacency is the product."""
    if len(factors) == 1:
        return factors[0]
    return syntax.UniverseNode((syntax.Product(factors),))


def _power(node: syntax.UniverseNode, count: int) -> syntax.UniverseNode:
    """Repeat a factor ``count`` times; ``A^0`` is the unit, the product identity."""
    if count == 0:
        return UNIT
    return _product((node,) * count)


def _power_span(exponent: Exponent, node: syntax.UniverseNode, ctx: Ctx) -> syntax.UniverseNode:
    """Expand ``A^lo..hi``: union ``A`` across the powers ``lo`` through ``hi``.

    A lone count (``hi`` absent) is the degenerate ``A^n``, the one power. A
    high count below the low one spans nothing and reads as the empty universe,
    total in the floor's manner. Each power splices its entries in, so a power
    that binds a closure passes through folded rather than rebinding ``&``.
    """
    low = _count(exponent.lo, ctx)
    high = _count(exponent.hi, ctx) if exponent.hi is not None else low
    members: list[syntax.Member] = []
    for count in range(low, high + 1):
        members.extend(_members_of(_power(node, count)))
    return syntax.UniverseNode(tuple(members))


def _count(text: str, ctx: Ctx) -> int:
    """Read an exponent as a repetition count.

    The spelling is read as a decimal numeral. L1.5 binds numeral parameters in
    the head radix, but every exponent the surface writes is a plain count, so
    a non-decimal exponent is refused rather than guessed at.

    Raises:
        HimarkScopeError: the exponent does not spell a decimal numeral.
    """
    spelling = ctx.spell(text)
    if not spelling.isdigit():
        msg = f"exponent must be a decimal numeral, got {spelling!r}"
        raise HimarkScopeError(msg)
    return int(spelling)


def _register(name: str, ctx: Ctx) -> syntax.UniverseNode:
    """Read a register: bare ``@`` is the head, ``@0`` its zero entry.

    Both are total. An empty head reads as the empty universe, and a head with
    no zero entry reads as the unit.
    """
    if ctx.head is None:
        msg = f"register @{name} outside a definition body"
        raise HimarkScopeError(msg)
    if name == "":
        return ctx.head
    zero = _zero(ctx.head, ctx.faces)
    return UNIT if zero is None else syntax.UniverseNode((syntax.Face(zero),))


def _value_cut(lo: str, hi: str | Read, ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand the value family ``@lo..hi``: the head's value line cut by value.

    Both bounds are spellings in the head radix -- a written numeral, or a
    parameter naming one -- so each rides ``spell`` the way a range endpoint
    does, and both are always present: there is no open cut. A read still
    standing here crossed a declaration and is refused, as one in any other
    position is. The cut rides a one-factor product so that a sibling member
    never falls inside its subtraction.

    Raises:
        HimarkScopeError: the family stands outside a definition body, or a
            read reached expansion.
    """
    if isinstance(hi, Read):
        _refuse_read(f"${hi.index}")
    if ctx.head is None:
        msg = f"register @{lo}..{hi} outside a definition body"
        raise HimarkScopeError(msg)
    node = valueline.cut(ctx.faces, ctx.head, ctx.spell(lo), ctx.spell(hi))
    return (syntax.Product((node,)),)


def _bind_params(
    params: tuple[Param, ...], arguments: tuple[Binding, ...], zero: str | None
) -> dict[str, str]:
    """Bind a definition's parameters to an application's literal arguments.

    A pair parameter takes one argument, which may be written ``lo..hi`` or --
    the degenerate case -- a lone numeral standing for ``n..n`` (there is no
    open pair). Arguments canonicalize in the head radix, so ``aa`` binds as ``a``.

    Raises:
        HimarkScopeError: a pair argument is given to a single parameter.
    """
    bindings: dict[str, str] = {}
    for param, argument in zip(params, arguments, strict=True):
        for spelling in (argument.lo, argument.hi):
            if isinstance(spelling, str) and read_index(spelling) is not None:
                _refuse_read(spelling)
        lo = canonicalize(argument.lo, zero) if zero else argument.lo
        if param.hi is None:
            if argument.hi is not None:
                msg = f"{param.lo} is a single parameter, got the pair {argument.lo}..{argument.hi}"
                raise HimarkScopeError(msg)
            bindings[param.lo] = lo
        else:
            hi = argument.hi if argument.hi is not None else argument.lo
            bindings[param.lo] = lo
            bindings[param.hi] = canonicalize(hi, zero) if zero else hi
    return bindings


def _apply(
    definition: DefDecl,
    arguments: tuple[Binding, ...],
    ctx: Ctx,
    operand: syntax.UniverseNode | None,
) -> syntax.UniverseNode:
    """Apply a definition: substitute its parameters and the operand, then expand."""
    head = ctx.head
    bindings = _bind_params(definition.params, arguments, _zero(head, ctx.faces) if head else None)
    inner = Ctx(ctx.env, ctx.faces, head, operand, bindings)
    return _product(expand(definition.expr, inner))


def _reference(name: str, ctx: Ctx, operand: syntax.UniverseNode | None) -> syntax.UniverseNode:
    """Expand a reference: a register, a spliced declaration, or a bare application."""
    if name in {"", "0"}:
        return _register(name, ctx)
    declared = ctx.env.lookup(name)
    if isinstance(declared, DefDecl):
        return _apply(declared, (), ctx, operand)
    return _product(expand(declared, ctx))


def _base(base: UniverseNode | Ref | Operand, ctx: Ctx) -> syntax.UniverseNode:
    """Expand a base: a brace group, a reference, or the operand token."""
    match base:
        case UniverseNode():
            return _universe(base, ctx)
        case Operand():
            if ctx.operand is None:
                msg = "operand token `_` outside an application"
                raise HimarkScopeError(msg)
            return ctx.operand
        case Ref(name):
            return _reference(name, ctx, ctx.operand)


def _spell_arg(binding: Binding, ctx: Ctx) -> Binding:
    """Substitute a pipeline argument through the caller's parameter bindings.

    A stage argument may name the enclosing definition's parameter -- ``[shorter
    w]`` in ``upto``'s body reads ``upto``'s ``w`` -- so it is resolved here,
    before ``_apply`` binds it to the stage's own parameter. A literal argument
    passes through unchanged.
    """
    lo = ctx.spell(binding.lo)
    if binding.hi is None:
        return Binding(lo, None)
    return Binding(lo, ctx.spell(binding.hi))


def _unit(unit: Unit, ctx: Ctx) -> syntax.UniverseNode:
    """Expand a unit: its base, then its exponent, then its chain of brackets.

    Within one bracket every stage reads the same head, so one radix rides the
    fused chain whatever a previous stage left in the pipe. Across brackets the
    head re-points to each bracket's left operand, so ``A[f][g]`` lets ``g``
    read ``f``'s output where ``A[f g]`` pins both stages to ``A``.
    """
    node = _base(unit.base, ctx)
    if unit.exponent is not None:
        node = _power_span(unit.exponent, node, ctx)
    for bracket in unit.pipelines:
        head = node
        for stage in bind(bracket, ctx.env):
            arguments = tuple(_spell_arg(a, ctx) for a in stage.arguments)
            node = _apply(
                stage.definition, arguments, Ctx(ctx.env, ctx.faces, head, node, None), node
            )
    return node


def _factor(segment: Segment, ctx: Ctx) -> syntax.UniverseNode:
    """Expand one segment standing as a product factor."""
    match segment:
        case syntax.Face(text):
            return syntax.UniverseNode((syntax.Face(ctx.spell(text)),))
        case Unit():
            return _unit(segment, ctx)
        case Read(index):
            _refuse_read(f"${index}")
        case _:
            msg = "the closure token `&` is not a universe"
            raise HimarkScopeError(msg)


def _members_of(node: syntax.UniverseNode) -> tuple[syntax.Member, ...]:
    """The members a spliced name contributes: its own, unless it binds a closure."""
    if binds(node):
        return (syntax.Fold(node),)
    return node.members


def _lone(only: Segment, ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand a member built from one segment: a face, the closure token, or a brace group.

    A plain brace group is the fold; anything a name or a pipeline produced
    splices instead, since a name spreads where a braced member quotients.
    """
    if isinstance(only, syntax.Face):
        return (syntax.Face(ctx.spell(only.text)),)
    if isinstance(only, syntax.Closure):
        return (syntax.Closure(),)
    if isinstance(only, Read):
        _refuse_read(f"${only.index}")
    if isinstance(only.base, UniverseNode) and only.exponent is None and not only.pipelines:
        return (syntax.Fold(_universe(only.base, ctx)),)
    return _members_of(_unit(only, ctx))


def _segments(segments: tuple[Segment, ...], ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand a segment member: a lone segment, or a product.

    Adjacency is always a product now -- a definition is applied only through
    the pipeline `A[f x]`, never by juxtaposition -- so no arity-based
    application/product disambiguation happens here.
    """
    if len(segments) == 1:
        return _lone(segments[0], ctx)
    factors = tuple(
        syntax.Closure() if isinstance(s, syntax.Closure) else _factor(s, ctx) for s in segments
    )
    return (syntax.Product(factors),)


def _member(member: Member, ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand one member; a splice may contribute several."""
    match member:
        case ValueCut(lo, hi):
            return _value_cut(lo, hi, ctx)
        case syntax.Range(lo, hi):
            return (syntax.Range(ctx.spell(lo), ctx.spell(hi)),)
        case Subtract(universe):
            return (syntax.Subtract(_universe(universe, ctx)),)
        case _:
            return _segments(member.segments, ctx)


def _universe(node: UniverseNode, ctx: Ctx) -> syntax.UniverseNode:
    """Expand a brace group, splicing every member that contributes several."""
    members: list[syntax.Member] = []
    for member in node.members:
        members.extend(_member(member, ctx))
    return syntax.UniverseNode(tuple(members))


def expand(expr: Expr, ctx: Ctx) -> tuple[syntax.UniverseNode, ...]:
    """Expand an expression into its product factors, over the five constructors."""
    return tuple(_unit(unit, ctx) for unit in expr.units)
