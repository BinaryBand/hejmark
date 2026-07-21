"""The wrap ceiling: how many entries a universe carries, as a modulus.

Groundwork the render layer will read, not yet consumed here. A positional
value drawn from a universe wraps against the count of entries it carries --
``{0..9}`` is base ten, and a width-``w`` field of it ceils at ``ten ** w`` --
so an arithmetic that overflows a field folds back modulo that ceiling. This
module computes the ceiling structurally, without streaming a single entry, so
an astronomically wide field costs nothing to price.

The count is exact only where it can be: a universe built from disjoint faces
and ranges, and products of such, has a ceiling this returns exactly. Anywhere
the collision rule might drop an entry (overlapping members, a subtraction) or
a member is unbounded (a final segment, a closure), it returns ``None`` -- "no
known ceiling", never a wrong one. A later refinement may price more shapes;
none may return a count that streaming the entries would contradict.
"""

from __future__ import annotations

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


def cardinality(node: UniverseNode) -> int | None:
    """The count of entries the universe carries, or ``None`` when unknown.

    Exact where the members are collision-free and finite; ``None`` where a
    subtraction or an overlap could drop an entry, or an unbounded member (a
    final segment or a closure) makes the count infinite. ``None`` is "no known
    ceiling", never a wrong count.
    """
    members = node.members
    if len(members) == 1:
        return _member(members[0])
    if not all(isinstance(member, Face | Range) for member in members) or not _disjoint(members):
        return None
    total = 0
    for member in members:
        total += _span(member.lo, member.hi) if isinstance(member, Range) else 1
    return total


def _span(low: str, high: str) -> int:
    """A range's entry count: its span of code points, empty when reversed."""
    return max(0, ord(high) - ord(low) + 1)


def _member(member: Member) -> int | None:
    """The entry count one member contributes, or ``None`` when unbounded.

    A face is one entry; a range is its span of code points; a fold collapses
    to a single entry however many faces it wears. A final segment and a
    closure are unbounded, and a subtraction adds no entry of its own.
    """
    match member:
        case Face():
            return 1
        case Range(lo, hi):
            return _span(lo, hi)
        case Fold():
            return 1
        case Product(factors):
            return _product(factors)
        case Final() | Closure() | Subtract():
            return None


def _product(factors: tuple[UniverseNode | Closure, ...]) -> int | None:
    """A product ceils at the product of its factors' ceilings; a closure voids it."""
    total = 1
    for factor in factors:
        if isinstance(factor, Closure):
            return None
        size = cardinality(factor)
        if size is None:
            return None
        total *= size
    return total


def _disjoint(members: tuple[Member, ...]) -> bool:
    """Whether the members -- all faces and ranges -- share no spelling.

    Two members that could spell the same face collide under the union rule, so
    their sizes would overcount; only a provably disjoint spread counts exactly.
    A multi-character face cannot fall inside a single-code-point range, so only
    a length-one face is checked against the ranges.
    """
    faces: set[str] = set()
    spans: list[tuple[int, int]] = []
    for member in members:
        if isinstance(member, Face):
            if member.text in faces:
                return False
            faces.add(member.text)
        elif isinstance(member, Range):
            lo, hi = ord(member.lo), ord(member.hi)
            if hi < lo:
                continue
            if any(lo <= high and low <= hi for low, high in spans):
                return False
            spans.append((lo, hi))
    return not any(
        len(face) == 1 and any(low <= ord(face) <= high for low, high in spans) for face in faces
    )
