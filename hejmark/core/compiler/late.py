"""Late-bound expansion: the compiler's side of the boundary's one back edge.

A back-reference ``$k`` stands in a pattern -- ``{$1}`` wherever a universe
stands, ``where 0..$2`` as a pipeline argument -- and reads factor ``k`` of
the same query, strictly to its left. The matcher binds factors left to
right, so by the time the reading factor is tried its read is bound;
substituting the face turns every attempt into a plain floor query.
Expansion parameterized by a binding, never new denotation.

The unit itself never crosses to the engine: compilation deposits it in a
:class:`SlotTable` and hands the query a
:class:`~hejmark.core.ir.program.LateSlot` naming it. The table's
:meth:`~SlotTable.resolve` is the
:data:`~hejmark.core.ir.program.LateResolver` the engine calls back -- faces
in, a floor node out, pure data both ways.

The substitution is the whole mechanism. In a pattern position the bound face
stands as the literal spelling it is (a :class:`~hejmark.core.floor.syntax.Face`);
in an argument position it substitutes as a written argument, so the numeral
binding rules -- canonicalization, the degenerate pair -- apply unchanged.
"""

from __future__ import annotations

from collections.abc import Callable

from hejmark.core.compiler.ast import (
    Expr,
    Member,
    PipeItem,
    Read,
    Segment,
    Segments,
    Subtract,
    Unit,
    UniverseNode,
    ValueCut,
    read_index,
)
from hejmark.core.compiler.expand import Ctx, expand
from hejmark.core.compiler.resolve import Env
from hejmark.core.floor import syntax
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import LateSlot


def reads(unit: Unit) -> tuple[int, ...]:
    """Every factor index *unit* reads, in written order, without duplicates.

    Walks the unit's own brace tree and its pipeline arguments only: a read
    never crosses a declaration, so a spliced name contributes nothing here
    (a ``$k`` inside one is refused at expansion instead).
    """
    return tuple(dict.fromkeys(_unit_reads(unit)))


def _unit_reads(unit: Unit) -> list[int]:
    """The unit's read indices with duplicates, base first, then the pipeline."""
    found = []
    if isinstance(unit.base, UniverseNode):
        for member in unit.base.members:
            found.extend(_member_reads(member))
    for item in unit.pipeline:
        for text in (item.lo, item.hi):
            index = read_index(text) if isinstance(text, str) else None
            if index is not None:
                found.append(index)
    return found


def _member_reads(member: Member) -> list[int]:
    """A member's read indices, at any depth."""
    if isinstance(member, Subtract):
        found = []
        for inner in member.universe.members:
            found.extend(_member_reads(inner))
        return found
    if isinstance(member, ValueCut):
        return [member.hi.index] if isinstance(member.hi, Read) else []
    if not isinstance(member, Segments):
        return []
    found = []
    for segment in member.segments:
        if isinstance(segment, Read):
            found.append(segment.index)
        elif isinstance(segment, Unit):
            found.extend(_unit_reads(segment))
    return found


# A read's own reach, keyed by the 1-based factor index it names -- already
# known by the time a slot needs it, since a read is strictly left of the
# factor reading it.
FactorReach = Callable[[int], int | None]


def unit_reach(unit: Unit, factor_reach: FactorReach) -> int | None:
    """A sound upper bound on the length of any face *unit* could wear once its reads substitute.

    Valid for *every* binding, not just one. Conservative exactly the way
    `floor.reach.reach` is: `None` ("no known
    bound") wherever the shape is not confidently priced, rather than risk a
    bound a real substitution could exceed. A read contributes at most the
    reach already known for the factor it names -- `_sub_segment` turns it
    into a literal :class:`~hejmark.core.floor.syntax.Face` no longer than
    that factor could ever spell. Anything the pipeline or an exponent could
    stretch, a value cut's own bound, or a name needing the environment
    chased, is priced `None` rather than guessed: this only has to be sound,
    not exhaustive, since a slot with no known bound simply falls back to the
    unbounded split search that ran before this existed.
    """
    if unit.exponent is not None or unit.pipeline:
        return None
    if not isinstance(unit.base, UniverseNode):
        return None
    return _group_reach(unit.base, factor_reach)


def _group_reach(node: UniverseNode, factor_reach: FactorReach) -> int | None:
    """The unexpanded analogue of `floor.reach.reach`: longest member, subtraction skipped."""
    longest = 0
    for member in node.members:
        if isinstance(member, Subtract):
            continue  # stripping faces can only shorten the set, never lengthen it
        far = _member_reach(member, factor_reach)
        if far is None:
            return None
        longest = max(longest, far)
    return longest


def _member_reach(
    member: syntax.Range | syntax.Final | Segments | ValueCut, factor_reach: FactorReach
) -> int | None:
    """One member's reach; only ``Segments`` can hold a read, so only it recurses."""
    if isinstance(member, syntax.Range):
        return 1 if member.lo <= member.hi else 0
    if isinstance(member, syntax.Final):
        return None
    if isinstance(member, ValueCut):
        return None  # value-driven -- not priced here, even where `hi` carries no read
    return _segments_reach(member.segments, factor_reach)


def _segments_reach(segments: tuple[Segment, ...], factor_reach: FactorReach) -> int | None:
    """Adjacent segments concatenate, so their reach sums -- the product's own rule."""
    total = 0
    for segment in segments:
        far = _segment_reach(segment, factor_reach)
        if far is None:
            return None
        total += far
    return total


def _segment_reach(segment: Segment, factor_reach: FactorReach) -> int | None:
    """One segment's reach: a read stands for the face its factor will bind."""
    if isinstance(segment, syntax.Face):
        return len(segment.text)
    if isinstance(segment, syntax.Closure):
        return None
    if isinstance(segment, Read):
        return factor_reach(segment.index)
    return unit_reach(segment, factor_reach)


def _sub_unit(unit: Unit, bound: tuple[str, ...]) -> Unit:
    """Rebuild *unit* with every read replaced by the face it binds."""
    base = _sub_universe(unit.base, bound) if isinstance(unit.base, UniverseNode) else unit.base
    pipeline = tuple(
        PipeItem(
            _sub_text(item.lo, bound),
            _sub_text(item.hi, bound) if isinstance(item.hi, str) else item.hi,
        )
        for item in unit.pipeline
    )
    return Unit(base, unit.exponent, pipeline)


def _sub_universe(node: UniverseNode, bound: tuple[str, ...]) -> UniverseNode:
    """Rebuild a brace group with its reads substituted."""
    return UniverseNode(tuple(_sub_member(member, bound) for member in node.members))


def _sub_member(member: Member, bound: tuple[str, ...]) -> Member:
    """Rebuild one member with its reads substituted."""
    if isinstance(member, Subtract):
        return Subtract(_sub_universe(member.universe, bound))
    if isinstance(member, ValueCut):
        hi = bound[member.hi.index - 1] if isinstance(member.hi, Read) else member.hi
        return ValueCut(member.lo, hi)
    if not isinstance(member, Segments):
        return member
    return Segments(tuple(_sub_segment(segment, bound) for segment in member.segments))


def _sub_segment(segment: Segment, bound: tuple[str, ...]) -> Segment:
    """Rebuild one segment: a read becomes the literal face it bound."""
    if isinstance(segment, Read):
        return syntax.Face(bound[segment.index - 1])
    if isinstance(segment, Unit):
        return _sub_unit(segment, bound)
    return segment


def _sub_text(text: str, bound: tuple[str, ...]) -> str:
    """Substitute an argument spelling: a read becomes the face it bound."""
    index = read_index(text)
    return bound[index - 1] if index is not None else text


class SlotTable:
    """The deferred units of one compilation, behind their slot ids.

    :meth:`add` deposits a back-referencing unit and mints the
    :class:`~hejmark.core.ir.program.LateSlot` that rides the query in its
    place; :meth:`resolve` is the resolver the engine calls back. The surface
    unit and its environment never leave this table.
    """

    def __init__(self) -> None:
        """An empty table; compilation deposits as it walks the query's units."""
        self._entries: dict[int, tuple[Unit, Env, tuple[int, ...]]] = {}

    def add(
        self, unit: Unit, env: Env, needs: tuple[int, ...], factor_reach: FactorReach
    ) -> LateSlot:
        """Deposit one deferred unit, returning the slot that stands for it.

        ``factor_reach`` answers the reach already known for each factor
        *needs* names, which is what :func:`unit_reach` prices the slot's own
        bound from.
        """
        slot = len(self._entries)
        self._entries[slot] = (unit, env, needs)
        return LateSlot(slot, needs, unit_reach(unit, factor_reach))

    def resolve(self, slot: int, reads: tuple[str, ...]) -> syntax.UniverseNode:
        """Expand the slot's unit under its bound reads, one face per need.

        Raises:
            HimarkScopeError: the slot id names no deferred unit, or the reads
                do not line up with its needs.
        """
        entry = self._entries.get(slot)
        if entry is None:
            msg = f"unknown late slot: {slot}"
            raise HimarkScopeError(msg)
        unit, env, needs = entry
        if len(reads) != len(needs):
            msg = f"slot {slot} reads {len(needs)} factor(s), got {len(reads)}"
            raise HimarkScopeError(msg)
        # Substitution addresses positions; positions outside `needs` are
        # provably never read, because `reads()` computed `needs` from the
        # same walk the substitution performs.
        bound = [""] * max(needs)
        for index, face in zip(needs, reads, strict=True):
            bound[index - 1] = face
        return expand(Expr((_sub_unit(unit, tuple(bound)),)), Ctx(env))[0]
