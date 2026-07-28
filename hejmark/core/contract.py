"""The L2 seam: the finite-execution contract, as a ``Program -> Program`` pass.

L1's denotation is total and L1.5's surface adds none, yet a run must be finite.
L2 (``docs/foundation/L2.md``) is where that is enforced: meaning-preserving
rewrites that narrow what a program computes (reach, the value-cut collapse) and
the refusals that decline a program that would not settle. All of it acts on the
compiler's pure-data output, :class:`~hejmark.core.ir.program.Program`, before
the engine runs it -- the one seam between the two.

This module is that seam. It imports only the payload (:mod:`hejmark.core.ir`),
never the compiler that produced a program nor the engine that consumes one, so
it stays an *optional* stage: a program crosses it whether or not it rewrites
anything. Two halves of the contract live here -- :func:`apply`, the
``Program -> Program`` rewrite, and :func:`check_ingest`, the boundary refusal
that guards what may enter the engine.

Not every L2 obligation is expressible here, and the ones that are not land
where they are enforceable rather than being dragged in: reach narrows a split
search, so it is read off the floor
(:mod:`hejmark.core.floor.reach`) where both searches can share one answer; the
budgets meter a run, so they sit with the run. What belongs *here* is what is
genuinely a rewrite of the pure data on its way past -- and what belongs here is
identified by the L2 error classes it raises, not by the module it lives in.
"""

from __future__ import annotations

from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Member,
    Product,
    Range,
    Subtract,
    UniverseNode,
)
from hejmark.core.ir.errors import HimarkSentinelError
from hejmark.core.ir.program import (
    CompiledIter,
    CompiledLine,
    CompiledQuery,
    CompiledStatement,
    CompiledStep,
    EagerFactor,
    Program,
    QueryFactor,
    is_noncharacter,
)

# A top-exclusive cut lowers to exactly two members: the range it keeps, and the
# subtraction that takes its top endpoint off. That count is the shape
# `_fold_subtraction` recognizes, and recognizing nothing wider is deliberate.
_CUT_SHAPE = 2


def apply(program: Program) -> Program:
    """Rewrite a compiled program into one the engine computes more cheaply.

    Meaning-preserving by construction: every step below is a floor identity, so
    what comes back denotes exactly what went in and the engine's answers are
    unchanged. Total, and partial in the same sense
    :func:`~hejmark.core.engine.denote.window.carve` is -- a shape it does not
    recognize passes through untouched, so a missed rewrite costs computation
    and never correctness.

    The one rewrite it performs today is the value-cut collapse's second half.
    The compiler already emits a single-digit cut as one range
    (:func:`~hejmark.core.compiler.valueline._collapsed`); what it cannot do is
    see the *pair*, because L3 spells a top-exclusive cut as one cut less
    another (``below`` is ``{@lo..hi,!{@hi..hi}}``) and each half is lowered on
    its own. Here the whole program is in hand, so ``{3..7,!{7..7}}`` folds to
    ``{3..6}`` -- one range and no subtraction to re-check face by face.
    """
    statements = tuple(_line(line) for line in program.statements)
    if statements == program.statements:
        return program
    return Program(statements, program.sentinels)


def _line(line: CompiledLine) -> CompiledLine:
    """Rewrite one statement's queries; templates carry no universe to rewrite."""
    if isinstance(line, CompiledIter):
        return CompiledIter(_query(line.query), line.template)
    return CompiledStatement(tuple(_step(step) for step in line.steps))


def _step(step: CompiledStep) -> CompiledStep:
    """Rewrite one step, which is a query or a template."""
    return _query(step) if isinstance(step, CompiledQuery) else step


def _query(query: CompiledQuery) -> CompiledQuery:
    """Rewrite each eager factor; a late slot holds no universe until it binds."""
    return CompiledQuery(query.source, tuple(_factor(factor) for factor in query.factors))


def _factor(factor: QueryFactor) -> QueryFactor:
    """Rewrite one factor, leaving a slot alone.

    A slot's universe does not exist yet -- it is minted per binding by the
    compiler's resolver -- so there is nothing here to rewrite. What the
    resolver mints is already collapsed, the compiler having emitted it.
    """
    return EagerFactor(_node(factor.node)) if isinstance(factor, EagerFactor) else factor


def _node(node: UniverseNode) -> UniverseNode:
    """Rewrite a universe bottom-up: its members first, then the node itself."""
    return _collapse(UniverseNode(tuple(_member(member) for member in node.members)))


def _member(member: Member) -> Member:
    """Rewrite whatever universes a member carries; leaves pass straight through."""
    match member:
        case Fold(universe):
            return Fold(_node(universe))
        case Subtract(universe):
            return Subtract(_node(universe))
        case Product(factors):
            return Product(tuple(_node(f) if isinstance(f, UniverseNode) else f for f in factors))
        case Face() | Range() | Closure():
            return member
    return member


def _as_range(member: Member) -> Range | None:
    """The range a member denotes, seeing through the expander's product wrapper.

    Adjacency is the product, so the expander gives every pipeline stage a
    one-factor product to sit in and a value cut builds its terms the same way.
    That wrapper carries no faces of its own -- a product of one factor wears
    exactly that factor's faces, in that factor's order -- so looking through it
    is reading the same universe, not approximating it. Anything wider than one
    factor, or one member, is not a range and says so.
    """
    if isinstance(member, Range):
        return member
    if not isinstance(member, Product) or len(member.factors) != 1:
        return None
    inner = member.factors[0]
    if not isinstance(inner, UniverseNode) or len(inner.members) != 1:
        return None
    return _as_range(inner.members[0])


def _collapse(node: UniverseNode) -> UniverseNode:
    """Rewrite a node that denotes one interval of the code space into one range.

    Pure endpoint arithmetic over code points, which is why it can live on this
    side of the seam at all: a :class:`~hejmark.core.floor.syntax.Range` is
    single code points by definition, so subtracting one from another is integer
    comparison and needs none of the shortlex successor the engine's window
    algebra is built on. The two are not the same problem, and this is not that
    problem solved twice.

    Two shapes, which are the two halves of L2's value-cut collapse. A lone
    wrapped range sheds its wrapper, so ``{a..z}[where c..g]`` arrives at the
    engine as ``{c..g}`` and not as a product around it. A range followed by a
    subtraction of a range folds into what is left, which is the shape L3's
    top-exclusive cut leaves: ``{3..7,!{7..7}}`` becomes ``{3..6}``. Anything
    else -- a strip biting out of the middle, which leaves two intervals and so
    no single range -- passes through for the engine to carve.
    """
    if len(node.members) == 1:
        kept = _as_range(node.members[0])
        return node if kept is None else UniverseNode((kept,))
    if len(node.members) != _CUT_SHAPE:
        return node
    kept, strip = _as_range(node.members[0]), node.members[1]
    if kept is None or not isinstance(strip, Subtract) or len(strip.universe.members) != 1:
        return node
    cut = _as_range(strip.universe.members[0])
    if cut is None:
        return node
    remains = _minus(kept, cut)
    return node if remains is None else UniverseNode(remains)


def _minus(kept: Range, cut: Range) -> tuple[Member, ...] | None:
    """What is left of a range after another is removed, when that is one range.

    ``None`` where the answer is not a single range: a cut that misses entirely
    (leave the node alone rather than rebuild it) or one that splits the range
    in two. An empty result is a real answer -- the cut swallowed the range --
    and comes back as no members at all.
    """
    low, high = ord(kept.lo), ord(kept.hi)
    start, end = ord(cut.lo), ord(cut.hi)
    if high < low or end < start or end < low or start > high:
        return None
    if start <= low and end >= high:
        return ()
    if start <= low:
        return (Range(chr(end + 1), kept.hi),)
    if end >= high:
        return (Range(kept.lo, chr(start - 1)),)
    return None


def check_ingest(document: str) -> None:
    """Refuse a document that arrives spelling a noncharacter.

    The way *in* to the sentinel boundary, complementing the engine's exit
    strip: the way out clears every declared sentinel, and the way in refuses a
    document already carrying one, so nothing engine-private is forged from
    outside and the masking idiom stays sound. A clean document passes silently.

    Raises:
        HimarkSentinelError: the document spells a noncharacter.
    """
    for position, character in enumerate(document):
        if is_noncharacter(ord(character)):
            msg = (
                f"document spells the noncharacter U+{ord(character):04X} at "
                f"position {position}: the sentinel space is engine-private"
            )
            raise HimarkSentinelError(msg)
