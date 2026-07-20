"""The contracting measure's read: which of two spellings sits earlier.

A ``<=>`` statement settles because every pass strictly descends its declared
measure's entry order -- iteration order, value order as ever, a well-order
with no infinite descent. This module decides the descent: :func:`precedes`
says whether one spelling's entry sits strictly before another's.

Nothing here streams entries. The stream's order is structural -- member-major
across a union, spelling order inside a window, leftmost-slowest across a
product, stage-major up a closure -- so the comparison recurses down the same
structure the stream walks, and an infinite stretch of entries between the two
spellings costs nothing to step over. The one search is a product's tilings:
where a spelling splits more than one way its entry is the least claimant, so
the split search is budgeted exactly as a factor read is, on the ``$0`` shelf.
Two spellings of one entry compare equal, which ``precedes`` reports as not
earlier: re-dressing an entry is no descent.
"""

from __future__ import annotations

from typing import assert_never

from hejmark.core.floor.binder import binds
from hejmark.core.floor.order import spelling_key
from hejmark.core.floor.syntax import (
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
from hejmark.core.floor.universe import Adding, Universe, walk
from hejmark.core.scan.capture import BUDGET
from hejmark.core.surface.ast import HimarkScopeError


def precedes(universe: Universe, left: str, right: str) -> bool:
    """Whether *left*'s entry sits strictly earlier than *right*'s.

    Both spellings must be spelled by *universe*; the caller has membership as
    the exact oracle for that. Faces of one entry are nowhere earlier than
    each other, so they compare not-earlier in both directions.

    Raises:
        HimarkScopeError: a spelling the universe does not spell, or a split
            search past :data:`~hejmark.core.scan.capture.BUDGET`.
    """
    return _compare(universe, left, right) < 0


def _refuse(spelling: str) -> HimarkScopeError:
    """The not-spelled refusal: order is asked only of members."""
    msg = f"the measure does not spell {spelling!r}"
    return HimarkScopeError(msg)


def _compare(universe: Universe, left: str, right: str) -> int:
    """Three-way entry order: negative, zero, positive as *left* sits to *right*."""
    if left == right:
        return 0
    node, amp = universe.node, universe.amp
    if not binds(node):
        return _within(node.members, amp, left, right)
    lo, hi = _stage(universe, left), _stage(universe, right)
    if lo != hi:
        return -1 if lo < hi else 1
    return _within(node.members, Universe(node, amp, lo - 1), left, right)


def _stage(universe: Universe, spelling: str) -> int:
    """The stage a closure first spells *spelling* at; settled bodies bound it."""
    bound = len(spelling) + 1
    if universe.stages is not None:
        bound = min(bound, universe.stages)
    for stage in range(1, bound + 1):
        if Universe(universe.node, universe.amp, stage).contains(spelling):
            return stage
    raise _refuse(spelling)


def _within(members: tuple[Member, ...], amp: Universe | None, left: str, right: str) -> int:
    """Compare inside one member list: owner-major, then within the owner."""
    lo, owner = _owner(members, amp, left)
    hi, _other = _owner(members, amp, right)
    if lo != hi:
        return -1 if lo < hi else 1
    return _same(owner, amp, left, right)


def _owner(members: tuple[Member, ...], amp: Universe | None, face: str) -> tuple[int, Adding]:
    """The member whose stream carries *face*, with its index.

    Mirrors the stream's conditions: the member wears the face, no member to
    the left already claims it, and no subtraction to the right strips it.
    Dropped faces shift positions but never reorder, so the owner index alone
    carries the member-major half of the order.
    """
    for index, member in enumerate(members):
        if isinstance(member, Subtract):
            continue
        if not walk((member,), amp, face):
            continue
        if walk(members[:index], amp, face):
            continue
        strips = (m for m in members[index + 1 :] if isinstance(m, Subtract))
        if any(walk(strip.universe.members, amp, face) for strip in strips):
            continue
        return index, member
    raise _refuse(face)


def _same(member: Adding, amp: Universe | None, left: str, right: str) -> int:
    """Compare two faces the same member carries, by that member's own order."""
    match member:
        case Face():
            return 0
        case Fold(inner):
            # A binder's brace splices its closure; anything else folds to one
            # entry. Either way the brace seals its own `&`, so no amp reaches in.
            return _compare(Universe(inner), left, right) if binds(inner) else 0
        case Range() | Final():
            return -1 if spelling_key(left) < spelling_key(right) else 1
        case Closure():
            return _compare(_amp(amp), left, right)
        case Product(factors):
            return _product(factors, amp, left, right)
        case _ as unreachable:
            assert_never(unreachable)


def _product(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, left: str, right: str
) -> int:
    """Compare inside a product: leftmost factor moves slowest, so lex by factor."""
    first = _least(factors, amp, left)
    second = _least(factors, amp, right)
    for factor, one, other in zip(factors, first, second, strict=True):
        ordering = _compare(_factor(factor, amp), one, other)
        if ordering:
            return ordering
    return 0


def _least(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, face: str
) -> tuple[str, ...]:
    """The split the floor binds: the least claimant among every tiling of *face*."""
    splits = _tilings(factors, amp, face)
    best = splits[0]
    for split in splits[1:]:
        if _lex(factors, amp, split, best) < 0:
            best = split
    return best


def _lex(
    factors: tuple[UniverseNode | Closure, ...],
    amp: Universe | None,
    split: tuple[str, ...],
    other: tuple[str, ...],
) -> int:
    """Compare two tilings of one spelling, factor entry by factor entry."""
    for factor, one, two in zip(factors, split, other, strict=True):
        ordering = _compare(_factor(factor, amp), one, two)
        if ordering:
            return ordering
    return 0


def _tilings(
    factors: tuple[UniverseNode | Closure, ...], amp: Universe | None, spelling: str
) -> list[tuple[str, ...]]:
    """Every split of *spelling* into consecutive factor faces, empty pieces included."""
    found: list[tuple[str, ...]] = []

    def rest(depth: int, pos: int, acc: tuple[str, ...]) -> None:
        """Extend *acc* with every tiling of ``spelling[pos:]`` from ``depth`` on."""
        if depth == len(factors):
            if pos == len(spelling):
                found.append(acc)
                if len(found) > BUDGET:
                    msg = f"cannot seat {spelling!r} in the measure: more than {BUDGET} splits"
                    raise HimarkScopeError(msg)
            return
        universe = _factor(factors[depth], amp)
        for end in range(pos, len(spelling) + 1):
            if universe.contains(spelling[pos:end]):
                rest(depth + 1, end, (*acc, spelling[pos:end]))

    rest(0, 0, ())
    if not found:
        raise _refuse(spelling)
    return found


def _factor(factor: UniverseNode | Closure, amp: Universe | None) -> Universe:
    """A product factor as a universe; the closure token reads the binder's stage."""
    return _amp(amp) if isinstance(factor, Closure) else Universe(factor)


def _amp(amp: Universe | None) -> Universe:
    """The universe a free ``&`` reads; the grammar guarantees a binder exists."""
    if amp is None:
        msg = "free `&` outside any binder"
        raise ValueError(msg)
    return amp
