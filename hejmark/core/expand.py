"""Expansion: rewrite the L1.5 surface into the floor's six constructors.

This is L1.5's admission rule made executable. A surface construct adds no
denotation -- every application expands into union, subtraction, fold, final
segment, product and closure -- or it does not enter. So nothing here is
interpreted: names splice, definitions substitute, exponents repeat, and what
comes out is a plain :mod:`hejmark.core.syntax` tree that
:func:`hejmark.core.universe.denote` reads without knowing L1.5 exists.

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

from hejmark.core import syntax
from hejmark.core.resolve import Binding, Env, bind, canonicalize
from hejmark.core.surface import (
    DefDecl,
    Expr,
    HimarkScopeError,
    Member,
    Operand,
    Param,
    Ref,
    Segment,
    Subtract,
    Unit,
    UniverseNode,
)

# The floor's own binder test: whether a brace expression's members hold a free
# `&`. Expansion must know, because a binder may never be inlined.
from hejmark.core.universe import _binds as binds
from hejmark.core.universe import denote

# The empty universe, and the unit: a fold over the empty alphabet, the one
# entry wearing the empty spelling. The unit is the product identity.
EMPTY = syntax.UniverseNode(())
UNIT = syntax.UniverseNode((syntax.Fold(syntax.UniverseNode(())),))


@dataclass(frozen=True)
class Ctx:
    """What an expansion reads: the namespace, the head, the operand, the bindings.

    ``head`` is the pipeline head every register reads; ``operand`` is the
    stage operand ``_`` binds to; ``bindings`` maps a definition's parameters
    to the literal spellings an application gave them. All three are ``None``
    or empty outside the scope that supplies them, which is what turns a
    stray register or operand into a diagnostic.
    """

    env: Env
    head: syntax.UniverseNode | None = None
    operand: syntax.UniverseNode | None = None
    bindings: dict[str, str] | None = None

    def spell(self, text: str) -> str:
        """Substitute a parameter name for the spelling bound to it, if any."""
        bindings = self.bindings or {}
        return bindings.get(text, text)


def _zero(node: syntax.UniverseNode) -> str | None:
    """The canonical face of a universe's zero entry, or ``None`` if it has none.

    Reads the first entry of the lazy stream, so an infinite head costs one
    entry rather than a materialization.
    """
    for entry in denote(node).entries():
        return entry.faces[0]
    return None


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
    zero = _zero(ctx.head)
    return UNIT if zero is None else syntax.UniverseNode((syntax.Face(zero),))


def _bind_params(
    params: tuple[Param, ...], arguments: tuple[Binding, ...], zero: str | None
) -> dict[str, str]:
    """Bind a definition's parameters to an application's literal arguments.

    A pair parameter takes one argument, which may be written ``lo..hi`` or --
    the degenerate case -- a lone numeral standing for ``n..n``. Arguments
    canonicalize in the head radix, so ``aa`` binds as ``a``.

    Raises:
        HimarkScopeError: a pair argument is given to a single parameter.
    """
    bindings: dict[str, str] = {}
    for param, argument in zip(params, arguments, strict=True):
        lo = canonicalize(argument.lo, zero) if zero else argument.lo
        hi = argument.hi if argument.hi is not None else argument.lo
        if param.hi is None:
            if argument.hi is not None:
                msg = f"{param.lo} is a single parameter, got the pair {argument.lo}..{argument.hi}"
                raise HimarkScopeError(msg)
            bindings[param.lo] = lo
        else:
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
    bindings = _bind_params(definition.params, arguments, _zero(head) if head else None)
    inner = Ctx(ctx.env, head, operand, bindings)
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


def _unit(unit: Unit, ctx: Ctx) -> syntax.UniverseNode:
    """Expand a unit: its base, then its exponent, then its pipeline stages.

    Every stage reads the same head -- the base as written -- so one radix
    rides the whole chain, whatever a previous stage left in the pipe.
    """
    node = _base(unit.base, ctx)
    if unit.exponent is not None:
        node = _power(node, _count(unit.exponent, ctx))
    head = node
    for stage in bind(unit.pipeline, ctx.env):
        node = _apply(stage.definition, stage.arguments, Ctx(ctx.env, head, node, None), node)
    return node


def _application(segments: tuple[Segment, ...], ctx: Ctx) -> syntax.UniverseNode | None:
    """Read adjacent segments as an application, or ``None`` if they are not one.

    ``@shorter w`` is an application and ``{a}{b}`` a product; only the
    definition's arity tells them apart.
    """
    first = segments[0]
    if not isinstance(first, Unit) or not isinstance(first.base, Ref):
        return None
    definition = ctx.env.defs.get(first.base.name)
    if definition is None or not definition.params:
        return None
    arity = len(definition.params)
    given = segments[1 : 1 + arity]
    if len(given) < arity or not all(isinstance(s, syntax.Face) for s in given):
        msg = f"{first.base.name} takes {arity} argument(s) here"
        raise HimarkScopeError(msg)
    arguments = tuple(Binding(ctx.spell(s.text)) for s in given if isinstance(s, syntax.Face))
    node = _apply(definition, arguments, ctx, ctx.operand)
    rest = segments[1 + arity :]
    if not rest:
        return node
    return _product((node, *(_factor(segment, ctx) for segment in rest)))


def _factor(segment: Segment, ctx: Ctx) -> syntax.UniverseNode:
    """Expand one segment standing as a product factor."""
    match segment:
        case syntax.Face(text):
            return syntax.UniverseNode((syntax.Face(ctx.spell(text)),))
        case Unit():
            return _unit(segment, ctx)
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
    if isinstance(only.base, UniverseNode) and only.exponent is None and not only.pipeline:
        return (syntax.Fold(_universe(only.base, ctx)),)
    return _members_of(_unit(only, ctx))


def _segments(segments: tuple[Segment, ...], ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand a segment member: an application, a lone segment, or a product."""
    applied = _application(segments, ctx)
    if applied is not None:
        return _members_of(applied)
    if len(segments) == 1:
        return _lone(segments[0], ctx)
    factors = tuple(
        syntax.Closure() if isinstance(s, syntax.Closure) else _factor(s, ctx) for s in segments
    )
    return (syntax.Product(factors),)


def _member(member: Member, ctx: Ctx) -> tuple[syntax.Member, ...]:
    """Expand one member; a splice may contribute several."""
    match member:
        case syntax.Range(lo, hi):
            return (syntax.Range(ctx.spell(lo), ctx.spell(hi)),)
        case syntax.Final(lo):
            return (syntax.Final(ctx.spell(lo)),)
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
    """Expand an expression into its product factors, over the six constructors."""
    return tuple(_unit(unit, ctx) for unit in expr.units)
