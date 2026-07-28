"""The face reach: how long a face a universe can wear.

L2's first permitted rewrite (``docs/foundation/L2.md``), and the reason it is a
*rewrite* rather than a refusal: it changes how an expression is computed and
never what it denotes. A split search probing a product position has no reason
to offer a factor a piece longer than the longest face that factor could ever
wear, nor to leave the factors after it more text than they could ever cover
between them. Both bounds are read off the expression -- structurally, without
streaming a single entry -- so an infinite universe is priced as cheaply as a
finite one, and the matches are identical: only the cuts tried are fewer.

The bound is an upper one, and only ever that. A face is its own length, a range
spells single code points, a product sums its factors; anything unbounded -- a
closure, or a factor beside one -- is ``None``, "no known bound", which is the
correct answer rather than a failure to find one. A subtraction adds no face, so
it never raises the bound. Over-approximating is safe (a probe too many costs
time); under-approximating would drop a match, so a shape not priced exactly is
priced ``None``.

Floor, not engine: this reads the AST the way :mod:`hejmark.core.floor.binder`
does and denotes nothing, which is what lets both split searches -- the
matcher's over a query and membership's inside a product -- share one answer
rather than each carrying its own.
"""

from __future__ import annotations

from functools import lru_cache

from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Product,
    Range,
    Subtract,
    UniverseNode,
)

# A member that adds faces (every member except a subtraction). Spelled out
# rather than imported: ``denote.universe.Adding`` names the same union, and this
# module sits below it -- denotation reads reach, never the other way round.
Adding = Face | Range | Fold | Product | Closure


@lru_cache(maxsize=65536)
def reach(node: UniverseNode) -> int | None:
    """The length of the longest face the universe wears, or ``None`` when unbounded.

    A universe with no member wears nothing and reaches ``0`` -- which is also
    the fold-to-unit boundary's answer, the empty spelling being length zero.

    A closure binder is priced through its members like any other node: the free
    ``&`` it binds is itself a member (or a product factor), and that is what
    returns ``None``. A binder whose ``&`` occurs only inside subtractions adds
    no face through it, so its adding members bound it exactly.
    """
    longest = 0
    for member in node.members:
        if isinstance(member, Subtract):
            continue  # stripping faces can only shorten the set, never lengthen it
        far = _member(member)
        if far is None:
            return None
        longest = max(longest, far)
    return longest


def _member(member: Adding) -> int | None:
    """The longest face one adding member contributes, or ``None`` when unbounded."""
    match member:
        case Face(text):
            return len(text)
        case Range(lo, hi):
            return 1 if lo <= hi else 0
        case Fold(universe):
            return reach(universe)
        case Product(factors):
            return suffixes(factors)[0]
        case Closure():
            return None


def factor_reach(factor: UniverseNode | Closure) -> int | None:
    """A product factor's reach; the closure token reads a stage and carries none."""
    return None if isinstance(factor, Closure) else reach(factor)


@lru_cache(maxsize=65536)
def suffixes(factors: tuple[UniverseNode | Closure, ...]) -> tuple[int | None, ...]:
    """How far each suffix of a product reaches: ``suffixes(f)[i]`` bounds ``f[i:]``.

    One entry longer than *factors*, ending at ``0``: no factor left spells
    nothing. This is the bound read from the *other* end of a split search -- a
    cut that leaves the factors after it more text than they can ever spell
    cannot be completed, so it need not be tried. ``None`` propagates leftward
    from the first unbounded factor, since nothing to its left has a bounded
    tail either.
    """
    tails: list[int | None] = [0]
    for factor in reversed(factors):
        far = factor_reach(factor)
        tail = tails[-1]
        tails.append(None if far is None or tail is None else far + tail)
    return tuple(reversed(tails))


def cuts(factor: UniverseNode | Closure, tail: int | None, pos: int, length: int) -> range:
    """Where a split search may cut for this factor, as end positions into the text.

    Both ends are reach read off the expression. The factor cannot take a piece
    longer than *it* reaches, so the cut stops there; the factors after it cannot
    cover more than *tail*, so a cut leaving more than that behind can never be
    completed and the cut starts there. Where either side is unbounded the text
    itself is the only bound, which is the honest answer rather than a missing
    one.

    This is what collapses the language's idiomatic closure, ``{@x, &@x}``: the
    ``&`` reaches nowhere, but the single-code-point factor beside it pins the
    cut to the last position, turning a scan of every cut into a look at one.
    """
    far = factor_reach(factor)
    stop = length if far is None else min(pos + far, length)
    start = pos if tail is None else max(pos, length - tail)
    return range(start, stop + 1)
