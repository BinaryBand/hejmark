"""The capture reads: what ``$`` and ``$0`` see on a hit.

The floor already carries the pair, so a capture is a binding and never a
store. ``$`` is the hit as it hit -- the text over the branch's span, which the
branch already knows -- and ``$0`` is its canonical face, the zero of the face
axis as ``@0`` is the zero of the value axis.

Only ``$0`` needs anything the floor does not already hand back. Membership
says *whether* a spelling is worn; it does not say which entry wears it, and
the canonical face is that entry's face 0. So this module streams the entries
until it finds the wearer.
"""

from __future__ import annotations

from hejmark.core.match import Match
from hejmark.core.surface import HimarkScopeError
from hejmark.core.universe import Query, Universe

# How many entries a canonical-face read will stream before giving up. Reaching
# a wearer costs its position, and a position is not bounded by anything the
# matcher knows: `{a..}` wears `zz`, but only after every shorter spelling and
# every two-character one below it over the whole code space -- some 137
# million entries. The budget is far above any hand-written fold (the case
# `$0` exists for) and far below that.
BUDGET = 100_000


def canonical(universe: Universe, spelling: str) -> str | None:
    """The canonical face of the entry wearing *spelling*, or ``None`` if none does.

    Streams the entries until it finds the wearer, because membership says
    *whether* a spelling is worn and not by which entry.

    The stream is bounded. A worn spelling always sits at a finite position, so
    the search terminates in principle, but the position can be astronomically
    large over an infinite universe -- and the matcher, which only ever asked
    ``contains``, cannot tell the caller which case it is in. Rather than hang
    or guess, the read refuses past :data:`BUDGET`.

    Raises:
        HimarkScopeError: the wearer was not reached within :data:`BUDGET`.
    """
    for position, entry in enumerate(universe.entries()):
        if spelling in entry.faces:
            return entry.faces[0]
        if position >= BUDGET:
            msg = (
                f"cannot read the canonical face of {spelling!r}: no entry wearing it "
                f"appears within the first {BUDGET} of an unbounded universe"
            )
            raise HimarkScopeError(msg)
    return None


def canonical_face(query: Query, found: Match) -> str:
    """The whole match re-spelled canonically: each part's face 0, concatenated.

    Adjacency is the product, so a compound query is one entry and one binding;
    reading each factor's canonical face and joining them is the reading that
    stays total. Where a part's wearer cannot be found, the part stands as it
    hit.
    """
    pieces = []
    for universe, part in zip(query.universes, found.parts, strict=False):
        pieces.append(canonical(universe, part.face) or part.face)
    return "".join(pieces)
