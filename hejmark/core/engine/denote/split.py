"""The split search over a product, cut by reach.

A product's faces are the concatenations of its factors' faces, so deciding
whether one spelling is among them is a search for a tiling: consecutive pieces,
one per factor, covering the spelling exactly. The search is a dynamic program
over ``(factor, position)`` -- the same question from two paths has the same
answer -- and this module is that program and nothing else.

It is also where L2's reach rewrite is *spent*. :mod:`hejmark.core.floor.reach`
reads the two bounds off the expression; here they narrow which cuts are tried,
at both ends: no factor is offered a piece longer than the longest face it could
wear, and none is offered a cut leaving the factors after it more text than they
could ever cover between them. The tilings found are exactly the tilings that
exist, so the rewrite changes cost and never meaning.

Whether a factor's face set holds a piece is the caller's to answer, and it
arrives as :data:`Holds` rather than being computed here. That is what keeps
this a leaf: deciding a factor means denoting it, and a factor's free ``&`` reads
a stage only the caller knows about. The same threading
:data:`~hejmark.core.floor.binder.SpellsEmpty` uses, for the same reason.
"""

from __future__ import annotations

from collections.abc import Callable

from hejmark.core.floor.reach import cuts, suffixes
from hejmark.core.floor.syntax import Closure, UniverseNode

# Whether a product factor's face set holds a piece. A factor may be the closure
# token, which reads whichever stage the caller is asking under, so the caller
# closes over that rather than passing it.
Holds = Callable[[UniverseNode | Closure, str], bool]


def splits(factors: tuple[UniverseNode | Closure, ...], spelling: str, holds: Holds) -> bool:
    """Whether *spelling* tiles across *factors*, one consecutive piece each.

    A piece may be empty: a factor whose universe folds to the unit wears the
    empty spelling, so a cut that advances nothing is a legal tiling step. That
    is the one place this differs from the matcher, which accepts no zero-width
    part.
    """
    memo: dict[tuple[int, int], bool] = {}
    length = len(spelling)
    tails = suffixes(factors)

    def rest(index: int, pos: int) -> bool:
        """Whether ``spelling[pos:]`` tiles across the factors from ``index`` on."""
        if index == len(factors):
            return pos == length
        key = (index, pos)
        if key not in memo:
            memo[key] = any(
                holds(factors[index], spelling[pos:end]) and rest(index + 1, end)
                for end in cuts(factors[index], tails[index + 1], pos, length)
            )
        return memo[key]

    return rest(0, 0)
