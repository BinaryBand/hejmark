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
value order being iteration order, and refuse past a budget rather than hang.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.core.engine.scan.match import Factor, Match, Query, universe_at
from hejmark.core.floor.universe import Universe
from hejmark.core.ir.errors import HimarkScopeError

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


def _splits(
    factors: tuple[Factor, ...], text: str, pos: int, depth: int, bound: tuple[str, ...]
) -> Iterator[tuple[str, ...]]:
    """Yield every exact tiling of ``text[pos:]`` by ``factors[depth:]``.

    One face per factor, faces never empty -- the matcher accepts no zero-width
    part, and the re-split honors the same rule. A late factor resolves under
    the faces this tiling has already chosen, so each candidate split carries
    its own bindings.
    """
    if depth == len(factors):
        if pos == len(text):
            yield ()
        return
    universe = universe_at(factors[depth], bound)
    for end in range(pos + 1, len(text) + 1):
        face = text[pos:end]
        if not universe.contains(face):
            continue
        for tail in _splits(factors, text, end, depth + 1, (*bound, face)):
            yield (face, *tail)


def _address(universe: Universe, face: str) -> tuple[int, int]:
    """The ``<value, face>`` address of the entry wearing *face*.

    Value survives only as iteration order, so the value half is the wearer's
    stream position and the face half its index among the wearer's faces.

    Raises:
        HimarkScopeError: the wearer was not reached within :data:`BUDGET`.
    """
    for position, entry in enumerate(universe.entries()):
        if face in entry.faces:
            return position, entry.faces.index(face)
        if position >= BUDGET:
            break
    msg = (
        f"cannot address {face!r}: no entry wearing it appears within the "
        f"first {BUDGET} of an unbounded universe"
    )
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

    Raises:
        HimarkScopeError: the splits, or an address, outran :data:`BUDGET`.
    """
    text = "".join(part.face for part in found.parts)
    splits: list[tuple[str, ...]] = []
    for split in _splits(query.universes, text, 0, 0, ()):
        splits.append(split)
        if len(splits) > BUDGET:
            msg = f"cannot bind the factors of {text!r}: more than {BUDGET} splits"
            raise HimarkScopeError(msg)
    if len(splits) == 1:
        return splits[0]
    return min(splits, key=lambda split: _claim(query.universes, split))


def canonical_face(query: Query, found: Match) -> str:
    """The whole match re-spelled canonically: each part's face 0, concatenated.

    Adjacency is the product, so a compound query is one entry and one binding;
    reading each factor's canonical face and joining them is the reading that
    stays total. Where a part's wearer cannot be found, the part stands as it
    hit.
    """
    pieces = []
    bound: tuple[str, ...] = ()
    for factor, part in zip(query.universes, found.parts, strict=False):
        universe = universe_at(factor, bound)
        pieces.append(canonical(universe, part.face) or part.face)
        bound = (*bound, part.face)
    return "".join(pieces)
