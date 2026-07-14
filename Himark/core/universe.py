"""Universe algebra: denote a faithful AST to symbolic universes of entries.

Denotation applies the four constructors (union, subtraction, fold, final
segment) plus the range compression in a single left-to-right pass. The result
is a tuple of **segments**: an :class:`Entry` is one entry wearing a sequence of
face *pieces*, each an :class:`~Himark.core.order.IntervalSet` (a literal
spelling is the one-point interval set), while a :class:`Run` contributes one
single-face entry per spelling in an interval set. A final segment is an
unbounded run, so a universe may hold infinitely many entries without ever
materializing them.

The claim invariant is unchanged, only its carrier: ``claimed`` is an
``IntervalSet`` holding exactly the faces of the live entries. Values are
positions, read in ordinal arithmetic (:mod:`Himark.core.ordinal`) so that an
entry after an unbounded run lands at ``omega`` and beyond; finite universes keep
plain ``int`` values end to end.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, assert_never

from Himark.core.order import IntervalSet, successor
from Himark.core.ordinal import OMEGA, Ordinal
from Himark.core.syntax import Face, Final, Fold, Range, Subtract, UniverseNode

if TYPE_CHECKING:
    from collections.abc import Iterator


class HimarkInfiniteError(ValueError):
    """Raised when an infinite universe is asked to materialize its entries."""


@dataclass(frozen=True)
class Entry:
    """One member of a universe: its face pieces (ordered, unique) and its value."""

    faces: tuple[IntervalSet, ...]
    value: int | Ordinal

    @property
    def face_count(self) -> int | Ordinal:
        """How many spellings name this entry, summed across its pieces."""
        total: int | Ordinal = 0
        for piece in self.faces:
            total = total + _order_type(piece)
        return total

    def face_index(self, spelling: str) -> int | Ordinal | None:
        """The position of ``spelling`` among this entry's faces, or ``None`` if absent."""
        offset: int | Ordinal = 0
        for piece in self.faces:
            if piece.contains(spelling):
                return offset + piece.rank(spelling)
            offset = offset + _order_type(piece)
        return None


@dataclass(frozen=True)
class Run:
    """A run of single-face entries, one per spelling in ``faces``, from ``base`` on."""

    faces: IntervalSet
    base: int | Ordinal


Segment = Entry | Run


@dataclass(frozen=True)
class Universe:
    """A denoted universe: an ordered tuple of entry and run segments."""

    segments: tuple[Segment, ...]

    @property
    def entry_count(self) -> int | Ordinal:
        """The order type of the universe: 1 per entry, the run's cardinality per run."""
        total: int | Ordinal = 0
        for segment in self.segments:
            total = total + (_order_type(segment.faces) if isinstance(segment, Run) else 1)
        return total

    @property
    def is_finite(self) -> bool:
        """Whether every entry can be materialized (no unbounded run or face piece)."""
        for segment in self.segments:
            if isinstance(segment, Run):
                if segment.faces.cardinality() is None:
                    return False
            elif any(p.cardinality() is None for p in segment.faces):
                return False
        return True

    def iter_entries(self) -> Iterator[Entry]:
        """Yield the entries in order, lazily -- safe over an infinite universe."""
        for segment in self.segments:
            if isinstance(segment, Run):
                for i, spelling in enumerate(segment.faces):
                    yield Entry((IntervalSet.point(spelling),), segment.base + i)
            else:
                yield Entry(_materialize(segment.faces), segment.value)

    @property
    def entries(self) -> tuple[Entry, ...]:
        """Materialize every entry as a flat tuple; infinite universes are an error.

        Huge-but-finite universes (an astronomical bounded range) are slow here
        by design -- use :meth:`lookup` to probe them without materializing.
        """
        if not self.is_finite:
            msg = "cannot materialize the entries of an infinite universe; use lookup()"
            raise HimarkInfiniteError(msg)
        return tuple(self.iter_entries())

    def lookup(self, spelling: str) -> tuple[int | Ordinal, int | Ordinal, int | Ordinal] | None:
        """Find ``spelling``: its entry value, face index, and entry face count.

        Claims are unique, so a spelling belongs to at most one entry -- the
        first segment that owns it answers. ``None`` means no entry is spelled
        this way (the matcher then probes a different length).
        """
        for segment in self.segments:
            if isinstance(segment, Run):
                if segment.faces.contains(spelling):
                    return (segment.base + segment.faces.rank(spelling), 0, 1)
            else:
                index = segment.face_index(spelling)
                if index is not None:
                    return (segment.value, index, segment.face_count)
        return None


@dataclass(frozen=True)
class Query:
    """A denoted query: its source plus its universes, most-significant-first."""

    source: str
    universes: tuple[Universe, ...]


def _order_type(faces: IntervalSet) -> int | Ordinal:
    """The order type of an interval set: its cardinality, or ``omega`` when unbounded."""
    cardinality = faces.cardinality()
    return OMEGA if cardinality is None else cardinality


def _materialize(pieces: tuple[IntervalSet, ...]) -> tuple[IntervalSet, ...]:
    """Expand face pieces to a flat tuple of single-spelling pieces (finite pieces only)."""
    out: list[IntervalSet] = []
    for piece in pieces:
        out.extend(IntervalSet.point(s) for s in piece)
    return tuple(out)


def _fold_pieces(node: UniverseNode) -> list[IntervalSet]:
    """The face pieces of a nested universe in entry order (its own scope)."""
    pieces: list[IntervalSet] = []
    for segment in denote(node).segments:
        if isinstance(segment, Run):
            pieces.append(segment.faces)
        else:
            pieces.extend(segment.faces)
    return pieces


def _doomed(node: UniverseNode) -> IntervalSet:
    """The total face set of a subtracted universe -- every spelling it removes."""
    doomed = IntervalSet.empty()
    for piece in _fold_pieces(node):
        doomed = doomed.union(piece)
    return doomed


# Denotation builds segments with placeholder positions; `_finalize` bases them.
# Carrying real `Segment` objects (not opaque payloads) keeps the pass typed.


def _add_face(text: str, segments: list[Segment], claimed: IntervalSet) -> IntervalSet:
    """Union a single spelling: claim it as a new entry, or no-op if taken."""
    if not claimed.contains(text):
        point = IntervalSet.point(text)
        segments.append(Entry((point,), 0))
        return claimed.union(point)
    return claimed


def _add_run(faces: IntervalSet, segments: list[Segment], claimed: IntervalSet) -> IntervalSet:
    """Add a run (range or final segment) over the spellings not already claimed."""
    available = faces.difference(claimed)
    if not available.is_empty():
        segments.append(Run(available, 0))
        return claimed.union(available)
    return claimed


def _add_fold(node: Fold, segments: list[Segment], claimed: IntervalSet) -> IntervalSet:
    """Fold a nested universe into one entry, dropping already-claimed faces."""
    kept: list[IntervalSet] = []
    for piece in _fold_pieces(node.universe):
        available = piece.difference(claimed)
        if not available.is_empty():
            kept.append(available)
            claimed = claimed.union(available)
    if kept:
        segments.append(Entry(tuple(kept), 0))
    return claimed


def _survives(segment: Segment, doomed: IntervalSet) -> Segment | None:
    """The segment after subtracting ``doomed``: a shrunken run, a kept entry, or gone."""
    if isinstance(segment, Run):
        shrunk = segment.faces.difference(doomed)
        return None if shrunk.is_empty() else Run(shrunk, 0)
    if any(piece.intersects(doomed) for piece in segment.faces):
        return None
    return segment


def _subtract(node: Subtract, segments: list[Segment]) -> tuple[list[Segment], IntervalSet]:
    """Remove every live entry sharing a face with the subtracted universe."""
    doomed = _doomed(node.universe)
    kept = [
        survivor for segment in segments if (survivor := _survives(segment, doomed)) is not None
    ]
    return kept, _claimed_of(kept)


def _claimed_of(segments: list[Segment]) -> IntervalSet:
    """Rebuild the claim set as the union of every live segment's faces."""
    claimed = IntervalSet.empty()
    for segment in segments:
        if isinstance(segment, Run):
            claimed = claimed.union(segment.faces)
        else:
            for piece in segment.faces:
                claimed = claimed.union(piece)
    return claimed


def _finalize(segments: list[Segment]) -> Universe:
    """Assign each segment its derived position: values are indices, nothing stored."""
    based: list[Segment] = []
    base: int | Ordinal = 0
    for segment in segments:
        if isinstance(segment, Run):
            based.append(Run(segment.faces, base))
            base = base + _order_type(segment.faces)
        else:
            based.append(Entry(segment.faces, base))
            base = base + 1
    return Universe(tuple(based))


def denote(node: UniverseNode) -> Universe:
    """Normalize a universe AST node to a symbolic, valued :class:`Universe`."""
    segments: list[Segment] = []
    claimed = IntervalSet.empty()
    for member in node.members:
        if isinstance(member, Face):
            claimed = _add_face(member.text, segments, claimed)
        elif isinstance(member, Range):
            faces = IntervalSet.from_range(member.lo, successor(member.hi))
            claimed = _add_run(faces, segments, claimed)
        elif isinstance(member, Final):
            claimed = _add_run(IntervalSet.from_range(member.lo, None), segments, claimed)
        elif isinstance(member, Fold):
            claimed = _add_fold(member, segments, claimed)
        elif isinstance(member, Subtract):
            segments, claimed = _subtract(member, segments)
        else:
            assert_never(member)
    return _finalize(segments)
