"""Late-bound expansion: the factor a back-reference parameterizes.

A back-reference ``$k`` stands in a pattern -- ``{$1}`` wherever a universe
stands, ``where 0..$2`` as a pipeline argument -- and reads factor ``k`` of
the same query, strictly to its left. The matcher binds factors left to
right, so by the time the reading factor is tried its read is bound;
substituting the face turns every attempt into a plain floor query.
Expansion parameterized by a binding, never new denotation.

The substitution is the whole mechanism. In a pattern position the bound face
stands as the literal spelling it is (a :class:`~hejmark.core.floor.syntax.Face`);
in an argument position it substitutes as a written argument, so the numeral
binding rules -- canonicalization, the degenerate pair -- apply unchanged.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from hejmark.core.floor import syntax
from hejmark.core.floor.universe import Universe, denote
from hejmark.core.surface.ast import (
    Expr,
    Member,
    PipeItem,
    Read,
    Segment,
    Segments,
    Subtract,
    Unit,
    UniverseNode,
    read_index,
)
from hejmark.core.surface.expand import Ctx, expand
from hejmark.core.surface.resolve import Env


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
            index = read_index(text) if text is not None else None
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
    if not isinstance(member, Segments):
        return []
    found = []
    for segment in member.segments:
        if isinstance(segment, Read):
            found.append(segment.index)
        elif isinstance(segment, Unit):
            found.extend(_unit_reads(segment))
    return found


def _sub_unit(unit: Unit, bound: tuple[str, ...]) -> Unit:
    """Rebuild *unit* with every read replaced by the face it binds."""
    base = _sub_universe(unit.base, bound) if isinstance(unit.base, UniverseNode) else unit.base
    pipeline = tuple(
        PipeItem(_sub_text(item.lo, bound), _sub_text(item.hi, bound) if item.hi else item.hi)
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


@dataclass(frozen=True)
class Late:
    """A factor whose expansion awaits the faces bound to its left.

    ``needs`` is what :func:`reads` found in the unit; :meth:`at` keys its
    memo on those faces alone, since substitution touches nothing else.
    """

    unit: Unit
    env: Env
    needs: tuple[int, ...]
    _cache: dict[tuple[str, ...], Universe] = field(default_factory=dict, repr=False, compare=False)

    def at(self, bound: tuple[str, ...]) -> Universe:
        """Denote this factor under *bound*, the faces of the factors to its left."""
        key = tuple(bound[index - 1] for index in self.needs)
        if key not in self._cache:
            substituted = _sub_unit(self.unit, bound)
            self._cache[key] = denote(expand(Expr((substituted,)), Ctx(self.env))[0])
        return self._cache[key]
