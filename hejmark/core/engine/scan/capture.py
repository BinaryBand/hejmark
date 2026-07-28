"""The capture reads: what ``$``, ``$0`` and ``$1..$n`` see on a hit.

The floor already carries the pair, so a capture is a binding and never a
store. ``$`` is the hit as it hit -- the text over the branch's span, which the
branch already knows -- and ``$0`` is its canonical face, the zero of the face
axis as ``@0`` is the zero of the value axis. ``$k`` is factor ``k`` of the
hit as it hit: the hit binds one entry, an entry of a product is a tuple, and
the read is component ``k`` of the bound tuple.

Only ``$`` reads for free. Membership says *whether* a spelling is worn; it
does not say which entry wears it -- yet the canonical face is that entry's
face 0, and the bound tuple is the least ``<value, face>`` claimant where a
spelling splits more than one way. Both reads therefore stream the entries,
value order being iteration order, and refuse past a budget rather than hang:
L2's bounded-read rule, of which the value cut's radix budget is the other half.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.core.engine.denote.universe import Universe
from hejmark.core.engine.scan.match import (
    Factor,
    Match,
    Query,
    factor_reach,
    suffix_reach,
    universe_at,
)
from hejmark.core.ir.errors import HimarkScopeError

# How many entries a capture read will stream before giving up. Reaching a
# wearer costs its position, and a position is not bounded by anything the
# matcher knows: `{@char}` wears `￿` perfectly well, but only after every
# shorter spelling and every code point below it -- some sixty-five thousand
# entries for that one, and the whole plane space for a two-character face. The
# budget sits far above any hand-written fold (the case `$0` exists for) and far
# below the point where a wait stops being a wait.
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


def _splits(factors: tuple[Factor, ...], text: str) -> Iterator[tuple[str, ...]]:
    """Yield every exact tiling of ``text`` by ``factors``, one face per factor.

    One face per factor, faces never empty -- the matcher accepts no zero-width
    part, and the re-split honors the same rule. A late factor resolves under
    the faces this tiling has already chosen, so each candidate split carries
    its own bindings.

    Cut against the same reach the matcher probes against, so the tilings found
    are the tilings that exist -- the re-split is asking the same question of
    the same expression, and must not offer a factor a piece the matcher never
    would have.
    """
    tails = suffix_reach(factors)

    def rest(pos: int, depth: int, bound: tuple[str, ...]) -> Iterator[tuple[str, ...]]:
        """Every tiling of ``text[pos:]`` by ``factors[depth:]``, given the bindings so far."""
        if depth == len(factors):
            if pos == len(text):
                yield ()
            return
        universe = universe_at(factors[depth], bound)
        for end in _ends(factors[depth], tails[depth + 1], pos, len(text)):
            face = text[pos:end]
            if not universe.contains(face):
                continue
            for tail in rest(end, depth + 1, (*bound, face)):
                yield (face, *tail)

    yield from rest(0, 0, ())


def _ends(factor: Factor, tail: int | None, pos: int, length: int) -> range:
    """Where this factor may end its piece: reach at the top, its tail at the bottom.

    The matcher's :func:`~hejmark.core.engine.scan.match._lengths` in end-position
    form. One is added to the floor for the same reason it is there: a re-split
    honors the no-zero-width rule the matcher accepted the hit under.
    """
    far = factor_reach(factor)
    stop = length if far is None else min(pos + far, length)
    start = pos if tail is None else max(pos, length - tail)
    return range(max(start, pos + 1), stop + 1)


def _address(universe: Universe, face: str) -> tuple[int, int]:
    """The ``<value, face>`` address of the entry wearing *face*.

    Value survives only as iteration order, so the value half is the wearer's
    stream position and the face half its index among the wearer's faces.

    Bounded by :data:`BUDGET` exactly as :func:`canonical` is, and for the same
    reason: pricing an address walks the stream to the wearer, and nothing the
    matcher knows says how far that is.

    Raises:
        HimarkScopeError: no entry of a finite universe wears *face*, or none
            wearing it was reached within :data:`BUDGET`.
    """
    for position, entry in enumerate(universe.entries()):
        if face in entry.faces:
            return position, entry.faces.index(face)
        if position >= BUDGET:
            msg = (
                f"cannot address {face!r}: no entry wearing it appears within "
                f"the first {BUDGET} of an unbounded universe"
            )
            raise HimarkScopeError(msg)
    msg = f"cannot address {face!r}: no entry wears it"
    raise HimarkScopeError(msg)


def _claim(
    factors: tuple[Factor, ...], split: tuple[str, ...]
) -> tuple[tuple[int, ...], tuple[int, ...]]:
    """A split's sort key under the collision rule: values first, faces to break ties."""
    addresses = [
        _address(universe_at(factor, split[:depth]), face)
        for depth, (factor, face) in enumerate(zip(factors, split, strict=True))
    ]
    return tuple(a[0] for a in addresses), tuple(a[1] for a in addresses)


def factor_faces(query: Query, found: Match) -> tuple[str, ...]:
    """The hit split as the floor binds it: one face per factor, the least claimant.

    The matcher's parts are a membership witness -- any split proves the hit --
    but the floor gives a contested spelling to its least ``<value, face>``
    address, so a factor read consults the collision rule wherever the hit
    splits more than one way. A split the text pins uniquely -- the common
    case, anchor-pinned -- streams nothing; an ambiguous one prices each
    face's address exactly as :func:`canonical` prices the wearer.
    """
    text = "".join(part.face for part in found.parts)
    splits = list(_splits(query.universes, text))
    if len(splits) == 1:
        return splits[0]
    return min(splits, key=lambda split: _claim(query.universes, split))


def canonical_face(query: Query, found: Match) -> str:
    """The bound entry re-spelled canonically: each factor's face 0, concatenated.

    The bound entry is the least ``<value, face>`` claimant of the hit -- the same
    split :func:`factor_faces` reads -- so ``$0`` canonicalizes *that* split, not
    the matcher's greedy membership witness. Reading the raw parts would let
    ``$0`` disagree with ``$1..$n`` wherever the hit splits more than one way.
    Adjacency is the product, so a compound query is one entry and one binding;
    where a factor's wearer cannot be found, the part stands as it hit.
    """
    split = factor_faces(query, found)
    pieces = []
    bound: tuple[str, ...] = ()
    for factor, face in zip(query.universes, split, strict=True):
        universe = universe_at(factor, bound)
        pieces.append(canonical(universe, face) or face)
        bound = (*bound, face)
    return "".join(pieces)
