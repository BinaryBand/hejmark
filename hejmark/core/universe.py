"""Universe algebra: denote a faithful AST to lazy, computational universes.

A denoted :class:`Universe` answers two questions, both computed structurally
from the AST rather than from a stored table. ``contains(spelling)`` is pure
set algebra over the six constructors, because collision never changes it (a
claimed spelling merely moves owner). ``entries()`` streams the entries in
declaration order with the collision rule applied -- a spelling is claimed by
the least ``<value, face>`` address, every later claimant drops it, and an
entry that loses every face drops with them; claims against the members to the
left are decided by membership queries, never by materializing.

The closure ``&`` binds to the innermost enclosing brace expression other than
a subtraction operand, which then denotes the closure at omega of its body:
inflationary stages, first-appearance order. Membership is decided at stage
``len(spelling) + 1`` -- exact on settled (guarded) bodies by the fixpoint
theorem; on an unsettled body presence is still reported when a stage shows
it, but absence has no bound and raises :class:`HimarkUnsettledError`, while
``entries()`` streams any closure stage by stage (denotation stays total).

Laziness is the one discipline: nothing here materializes an infinite object,
so iterating an infinite universe simply never ends, and folding one into a
single entry is the caller's non-terminating loop to ask for.
"""

from __future__ import annotations

import itertools
from collections.abc import Callable, Iterator, Sequence
from dataclasses import dataclass
from functools import lru_cache
from typing import assert_never

from hejmark.core.order import Window, successor
from hejmark.core.syntax import (
    Closure,
    Face,
    Final,
    Fold,
    Member,
    Product,
    Range,
    Subtract,
    UniverseNode,
)

# A liveness test: whether a face is still unclaimed at its point of use.
Live = Callable[[str], bool]
# A member that adds faces (every member except a subtraction).
Adding = Face | Range | Final | Fold | Product | Closure


class HimarkUnsettledError(ValueError):
    """Raised when membership in an unsettled closure cannot be decided."""


@dataclass(frozen=True)
class Entry:
    """One member of a universe: the spellings that wear it, canonical face first."""

    faces: tuple[str, ...]


@dataclass(frozen=True)
class Universe:
    """A denoted universe: a brace expression plus what its free ``&`` reads.

    ``amp`` is the stage a free ``&`` in the members denotes (``None`` outside
    any binder). When the node is itself a binder, ``stages`` truncates the
    closure to its first ``stages`` passes -- the stage universe ``X_k`` --
    while ``None`` means the full closure at omega.
    """

    node: UniverseNode
    amp: Universe | None = None
    stages: int | None = None

    def contains(self, spelling: str) -> bool:
        """Whether some entry of this universe wears ``spelling``."""
        return _contains(self, spelling)

    def entries(self) -> Iterator[Entry]:
        """Yield the entries in declaration order, lazily -- safe over infinity."""
        if _binds(self.node):
            return _closure_entries(self.node, self.amp, self.stages)
        return _stream(self.node.members, self.amp, None)


@dataclass(frozen=True)
class Query:
    """A denoted query: its source plus its universes, most-significant-first."""

    source: str
    universes: tuple[Universe, ...]


def denote(node: UniverseNode) -> Universe:
    """Denote a universe AST node to a lazy :class:`Universe`."""
    return Universe(node)


@lru_cache(maxsize=65536)
def _contains(universe: Universe, spelling: str) -> bool:
    """Decide membership, memoized -- a closure re-asks each stage the same pieces."""
    node, amp, stages = universe.node, universe.amp, universe.stages
    if not _binds(node):
        return _walk(node.members, amp, spelling)
    bound = len(spelling) + 1 if stages is None else stages
    for stage in range(bound):
        if _walk(node.members, Universe(node, amp, stage), spelling):
            return True
    if stages is not None or _settled(node):
        return False
    msg = f"membership of {spelling!r} in an unsettled closure has no stage bound"
    raise HimarkUnsettledError(msg)


def _binds(node: UniverseNode) -> bool:
    """Whether this brace expression is a closure binder: a free ``&`` in its members."""
    return any(_free_amp(member) for member in node.members)


def _free_amp(member: Member) -> bool:
    """Whether a free ``&`` occurs in this member (subtraction braces never bind)."""
    if isinstance(member, Closure):
        return True
    if isinstance(member, Product):
        return any(isinstance(factor, Closure) for factor in member.factors)
    if isinstance(member, Subtract):
        return _binds(member.universe)
    return False


def _settled(node: UniverseNode) -> bool:
    """Whether every free ``&`` is guarded, so membership settles by stage len + 1."""
    return all(_settled_member(member) for member in node.members)


def _settled_member(member: Member) -> bool:
    """Whether this member's free ``&`` occurrences (if any) are guarded."""
    if isinstance(member, Closure):
        return False
    if isinstance(member, Product) and any(isinstance(f, Closure) for f in member.factors):
        return any(_guards(f) for f in member.factors if isinstance(f, UniverseNode))
    if isinstance(member, Subtract):
        return _settled(member.universe)
    return True


def _guards(factor: UniverseNode) -> bool:
    """Whether a factor guards its product: no empty face, so every pass lengthens."""
    return not Universe(factor).contains("")


def _walk(members: Sequence[Member], amp: Universe | None, spelling: str) -> bool:
    """The union/subtraction walk: presence after the member list, left to right."""
    present = False
    for member in members:
        if isinstance(member, Subtract):
            present = present and not _walk(member.universe.members, amp, spelling)
        elif not present:
            present = _spells(member, amp, spelling)
    return present


def _spells(member: Adding, amp: Universe | None, spelling: str) -> bool:
    """Whether the member's face set holds ``spelling`` (claims never shrink it)."""
    match member:
        case Face(text):
            return text == spelling
        case Range() | Final():
            return _window(member).contains(spelling)
        case Fold(universe):
            return _braced_spells(universe, amp, spelling)
        case Closure():
            return _amp(amp).contains(spelling)
        case Product(factors):
            return _splits(factors, amp, spelling)
        case _ as unreachable:
            assert_never(unreachable)


def _window(member: Range | Final) -> Window:
    """The shortlex window a range or final segment denotes."""
    if isinstance(member, Range):
        return Window(member.lo, successor(member.hi))
    return Window(member.lo, None)


def _carve(window: Window, strips: tuple[UniverseNode, ...]) -> list[Window]:
    """Cut the window-shaped strips out of a run's window, symbolically.

    Operands that are not plainly window-shaped carve nothing here; they are
    still applied face by face downstream.
    """
    pieces = [window]
    for operand in strips:
        for cut in _windows_of(operand) or []:
            pieces = [part for piece in pieces for part in piece.minus(cut)]
    return pieces


def _windows_of(node: UniverseNode) -> list[Window] | None:
    """The node's face set as windows when every member is one, else ``None``."""
    windows: list[Window] = []
    for member in node.members:
        if isinstance(member, Face):
            windows.append(Window(member.text, successor(member.text)))
        elif isinstance(member, Range | Final):
            windows.append(_window(member))
        else:
            return None
    return windows


def _braced_spells(inner: UniverseNode, amp: Universe | None, spelling: str) -> bool:
    """A braced member's face set: its universe's faces, plus the fold-to-unit boundary.

    A fold of the empty alphabet is the unit, so it wears the empty spelling; a
    binder splices its closure instead, and an empty closure contributes nothing.
    """
    universe = Universe(inner, amp)
    if spelling == "" and not _binds(inner):
        return universe.contains("") or next(iter(universe.entries()), None) is None
    return universe.contains(spelling)


def _splits(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, spelling: str
) -> bool:
    """Whether ``spelling`` splits into consecutive pieces, one per factor's faces."""
    memo: dict[tuple[int, int], bool] = {}

    def rest(index: int, pos: int) -> bool:
        """Whether ``spelling[pos:]`` splits across the factors from ``index`` on."""
        if index == len(factors):
            return pos == len(spelling)
        key = (index, pos)
        if key not in memo:
            memo[key] = any(
                _factor_contains(factors[index], amp, spelling[pos:end]) and rest(index + 1, end)
                for end in range(pos, len(spelling) + 1)
            )
        return memo[key]

    return rest(0, 0)


def _factor_contains(factor: UniverseNode | Closure, amp: Universe | None, piece: str) -> bool:
    """Whether a product factor's face set holds ``piece``."""
    if isinstance(factor, Closure):
        return _amp(amp).contains(piece)
    return Universe(factor, amp).contains(piece)


def _amp(amp: Universe | None) -> Universe:
    """The universe a free ``&`` reads; the grammar guarantees a binder exists."""
    if amp is None:
        msg = "free `&` outside any binder"
        raise ValueError(msg)
    return amp


def _stream(members: Sequence[Member], amp: Universe | None, outer: Live | None) -> Iterator[Entry]:
    """Yield the member list's entries: claims to the left, strips to the right."""
    for index, member in enumerate(members):
        if isinstance(member, Subtract):
            continue
        strips = tuple(m.universe for m in members[index + 1 :] if isinstance(m, Subtract))
        live = _live(members[:index], amp, outer)
        for entry in _member_entries(member, amp, live, strips):
            faces = tuple(
                f for f in entry.faces if not any(_walk(op.members, amp, f) for op in strips)
            )
            if faces:
                yield Entry(faces)


def _live(prefix: Sequence[Member], amp: Universe | None, outer: Live | None) -> Live:
    """A claim test: live means neither the members to the left nor ``outer`` claim it."""

    def live(face: str) -> bool:
        """Whether ``face`` is still unclaimed at this member's position."""
        if outer is not None and not outer(face):
            return False
        return not _walk(prefix, amp, face)

    return live


def _member_entries(
    member: Adding, amp: Universe | None, live: Live, strips: tuple[UniverseNode, ...] = ()
) -> Iterator[Entry]:
    """Yield one member's entries pre-subtraction, collisions already applied.

    ``strips`` is advisory: window-shaped operands are carved out of a run
    symbolically (so a fully subtracted infinite tail terminates); every strip
    is re-checked face by face at the stream level regardless.
    """
    match member:
        case Face(text):
            if live(text):
                yield Entry((text,))
        case Range() | Final():
            for window in _carve(_window(member), strips):
                yield from (Entry((s,)) for s in window if live(s))
        case Fold(universe):
            yield from _braced_entries(universe, amp, live)
        case Closure():
            yield from _filtered(_amp(amp).entries(), live)
        case Product(factors):
            yield from _product_entries(factors, amp, live)
        case _ as unreachable:
            assert_never(unreachable)


def _filtered(entries: Iterator[Entry], live: Live) -> Iterator[Entry]:
    """Drop claimed faces entry-wise; an entry that loses every face drops."""
    for entry in entries:
        faces = tuple(f for f in entry.faces if live(f))
        if faces:
            yield Entry(faces)


def _braced_entries(inner: UniverseNode, amp: Universe | None, live: Live) -> Iterator[Entry]:
    """A braced member: a binder splices its closure, anything else folds to one entry."""
    universe = Universe(inner, amp)
    if _binds(inner):
        yield from _filtered(universe.entries(), live)
        return
    declared = [face for entry in universe.entries() for face in entry.faces]
    faces = tuple(face for face in (declared or [""]) if live(face))
    if faces:
        yield Entry(faces)


def _product_entries(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, live: Live
) -> Iterator[Entry]:
    """Tuples in value order, spelled by concatenation; the least address claims."""
    seen: set[str] = set()
    for combo in _tuples(factors, amp):
        faces: list[str] = []
        for pieces in itertools.product(*combo):
            spelling = "".join(pieces)
            if spelling not in seen and spelling not in faces and live(spelling):
                faces.append(spelling)
        seen.update(faces)
        if faces:
            yield Entry(tuple(faces))


def _tuples(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None
) -> Iterator[tuple[tuple[str, ...], ...]]:
    """Factor face-tuples in value order: the most significant factor moves slowest."""
    if not factors:
        yield ()
        return
    for entry in _factor_entries(factors[0], amp):
        for tail in _tuples(factors[1:], amp):
            yield (entry.faces, *tail)


def _factor_entries(factor: UniverseNode | Closure, amp: Universe | None) -> Iterator[Entry]:
    """A product factor's entries in declaration order."""
    source = _amp(amp) if isinstance(factor, Closure) else Universe(factor, amp)
    return source.entries()


def _closure_entries(
    node: UniverseNode, amp: Universe | None, limit: int | None
) -> Iterator[Entry]:
    """Stage-major, first-appearance enumeration of a binder's closure.

    Each pass streams the body read at the previous stage, keeping only faces no
    earlier stage spells; a pass that completes without producing is the
    fixpoint, so the closure is finite and the stream ends.
    """
    stage = 0
    while limit is None or stage < limit:
        prev = Universe(node, amp, stage)
        produced = False
        for entry in _stream(node.members, prev, _fresh(prev)):
            produced = True
            yield entry
        if not produced:
            return
        stage += 1


def _fresh(prev: Universe) -> Live:
    """A face is fresh when no earlier stage of the same closure spells it."""

    def fresh(face: str) -> bool:
        """Whether ``face`` first appears at the current stage."""
        return not prev.contains(face)

    return fresh
