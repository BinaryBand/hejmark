"""Universe algebra: denote a faithful AST to lazy, computational universes.

A denoted :class:`Universe` answers two questions, both computed structurally
from the AST rather than from a stored table. ``contains(spelling)`` is pure
set algebra over the five constructors, because collision never changes it (a
claimed spelling merely moves owner). ``entries()`` streams the entries in
declaration order with the collision rule applied -- a spelling is claimed by
the least ``<value, face>`` address, every later claimant drops it, and an
entry that loses every face drops with them; claims against the members to the
left are decided by membership queries, never by materializing.

The closure ``&`` binds to the innermost enclosing brace expression other than
a subtraction operand, which then denotes the closure at omega of its body:
inflationary stages, first-appearance order. Membership is decided at stage
``len(spelling) + 1`` -- exact on guarded bodies by the fixpoint theorem. On an
unguarded body presence is still reported when a stage shows it, but absence is
only semi-decided: a spelling no stage up to that bound shows reads as absent,
which a later stage of an unsettled body could contradict. ``entries()`` streams
any closure stage by stage (denotation stays total).

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

from hejmark.core.engine.denote.window import carve, window_of
from hejmark.core.floor.binder import binds
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

# A liveness test: whether a face is still unclaimed at its point of use.
Live = Callable[[str], bool]
# A member that adds faces (every member except a subtraction).
Adding = Face | Range | Fold | Product | Closure


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
        if binds(self.node):
            return _closure_entries(self.node, self.amp, self.stages)
        return _stream(self.node.members, self.amp, None)


def denote(node: UniverseNode) -> Universe:
    """Denote a universe AST node to a lazy :class:`Universe`."""
    return Universe(node)


def canonical_faces(node: UniverseNode) -> Iterator[str]:
    """Stream the canonical face of each entry of *node*, in declaration order.

    The engine's side of :data:`~hejmark.core.ir.program.ToFaces`, and the whole
    of what expansion asks of denotation. Lazy like :meth:`Universe.entries`, so
    a caller wanting only the zero entry pays for one entry, and an unbounded
    head streams without returning rather than being refused a reading.
    """
    return (entry.faces[0] for entry in denote(node).entries())


@lru_cache(maxsize=65536)
def _contains(universe: Universe, spelling: str) -> bool:
    """Decide membership, memoized -- a closure re-asks each stage the same pieces."""
    node, amp, stages = universe.node, universe.amp, universe.stages
    if not binds(node):
        return walk(node.members, amp, spelling)
    if stages is None:
        _shorter_first(universe, spelling)
    bound = len(spelling) + 1 if stages is None else stages
    # A guarded body settles by ``len + 1``, so this is exact; an unguarded one
    # only semi-decides, and a spelling no stage up to the bound shows reads as
    # absent -- which a later stage of an unsettled body could contradict.
    return any(walk(node.members, Universe(node, amp, stage), spelling) for stage in range(bound))


def _shorter_first(universe: Universe, spelling: str) -> None:
    """Answer the shorter prefixes before the whole, so the descent stays shallow.

    A closure decides a length-``L`` spelling by asking its body about strictly
    shorter ones, so the recursion is naturally as deep as the spelling is long
    -- and a document long enough exhausts the interpreter's stack.
    Walking the prefixes upward first puts each answer the descent will want in
    the memo, so the descent finds it there rather than a frame deeper; each
    step recurses one level, its own prefixes being answered already. Only the
    closure at omega warms, because only it is asked from outside -- answering
    it at each prefix has already filled its stages' member walks.

    Pure warming: no answer changes, only where it is computed. Tactic, not
    rule: a host whose stack is its memory conforms without it.
    """
    for end in range(1, len(spelling)):
        _contains(universe, spelling[:end])


def walk(members: Sequence[Member], amp: Universe | None, spelling: str) -> bool:
    """The union/subtraction walk: presence after the member list, left to right.

    Public because it is the member-level membership oracle: a caller asking
    about a *slice* of a binder's members cannot re-brace the slice without
    rebinding its free ``&``, so it asks here with the binder's ``amp`` intact.
    """
    present = False
    for member in members:
        if isinstance(member, Subtract):
            present = present and not walk(member.universe.members, amp, spelling)
        elif not present:
            present = _spells(member, amp, spelling)
    return present


@lru_cache(maxsize=65536)
def _spells(member: Adding, amp: Universe | None, spelling: str) -> bool:
    """Whether the member's face set holds ``spelling`` (claims never shrink it).

    Memoized beside :func:`_contains`, and for the same reason one level down: a
    closure re-walks its whole member list once per stage, so the same member is
    asked about the same spelling under the same stage from every path that
    reaches it. The answer is a pure function of the three arguments, so the memo
    changes no denotation -- it collapses the repeated product splits below,
    which rebuild their own local memo on every call.
    """
    match member:
        case Face(text):
            return text == spelling
        case Range():
            return window_of(member).contains(spelling)
        case Fold(universe):
            return _braced_spells(universe, spelling)
        case Closure():
            return _amp(amp).contains(spelling)
        case Product(factors):
            return _splits(factors, amp, spelling)
        case _ as unreachable:
            assert_never(unreachable)


def _braced_spells(inner: UniverseNode, spelling: str) -> bool:
    """A braced member's face set: its universe's faces, plus the fold-to-unit boundary.

    A fold of the empty alphabet is the unit, so it wears the empty spelling; a
    binder splices its closure instead, and an empty closure contributes nothing.
    A brace that is not a subtraction operand seals its own ``&``, so no outer
    stage reaches in and the inner universe carries no ``amp``.
    """
    universe = Universe(inner)
    if spelling == "" and not binds(inner):
        return universe.contains("") or next(iter(universe.entries()), None) is None
    return universe.contains(spelling)


def _splits(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, spelling: str
) -> bool:
    """Whether ``spelling`` splits into consecutive pieces, one per factor's faces."""
    memo: dict[tuple[int, int], bool] = {}
    length = len(spelling)

    def rest(index: int, pos: int) -> bool:
        """Whether ``spelling[pos:]`` splits across the factors from ``index`` on."""
        if index == len(factors):
            return pos == length
        key = (index, pos)
        if key not in memo:
            memo[key] = any(
                _factor_contains(factors[index], amp, spelling[pos:end]) and rest(index + 1, end)
                for end in range(pos, length + 1)
            )
        return memo[key]

    return rest(0, 0)


def _factor_contains(factor: UniverseNode | Closure, amp: Universe | None, piece: str) -> bool:
    """Whether a product factor's face set holds ``piece``; a braced factor seals ``&``."""
    if isinstance(factor, Closure):
        return _amp(amp).contains(piece)
    return Universe(factor).contains(piece)


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
                f for f in entry.faces if not any(walk(op.members, amp, f) for op in strips)
            )
            if faces:
                yield Entry(faces)


def _live(prefix: Sequence[Member], amp: Universe | None, outer: Live | None) -> Live:
    """A claim test: live means neither the members to the left nor ``outer`` claim it."""

    def live(face: str) -> bool:
        """Whether ``face`` is still unclaimed at this member's position."""
        if outer is not None and not outer(face):
            return False
        return not walk(prefix, amp, face)

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
        case Range():
            for window in carve(window_of(member), strips):
                yield from (Entry((s,)) for s in window if live(s))
        case Fold(universe):
            yield from _braced_entries(universe, live)
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


def _braced_entries(inner: UniverseNode, live: Live) -> Iterator[Entry]:
    """A braced member: a binder splices its closure, anything else folds to one entry.

    As at membership, the brace seals its own ``&``: no ``amp`` reaches in.
    """
    universe = Universe(inner)
    if binds(inner):
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
    """A product factor's entries in declaration order; a braced factor seals ``&``."""
    source = _amp(amp) if isinstance(factor, Closure) else Universe(factor)
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
