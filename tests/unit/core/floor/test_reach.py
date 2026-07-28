"""The face reach: an upper bound on face length, read off the AST.

Every assertion here is about a *bound*, never about what a universe denotes --
nothing in this module streams an entry, which is the whole point of it. The
cases that matter are the ones where the honest answer is ``None``: pricing a
shape too tightly would drop a match, so anything not priced exactly must be
priced as unbounded.
"""

from __future__ import annotations

from hejmark.core.floor.reach import cuts, factor_reach, reach, suffixes
from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def test_a_face_reaches_its_own_length() -> None:
    """The base case, and the only one that is a measurement rather than a rule."""
    assert reach(UniverseNode((Face("cat"),))) == 3


def test_an_empty_universe_reaches_nothing() -> None:
    """No member wears no face, and the empty spelling is length zero either way."""
    assert reach(UniverseNode(())) == 0


def test_a_range_reaches_one_code_point() -> None:
    """A range is single code points by definition, however wide the span."""
    assert reach(UniverseNode((Range("a", "z"),))) == 1
    assert reach(UniverseNode((Range("z", "a"),))) == 0


def test_a_union_reaches_its_longest_member() -> None:
    """Union adds faces, so the bound is the greatest of them, not the sum."""
    assert reach(UniverseNode((Face("a"), Face("feline"), Range("0", "9")))) == 6


def test_a_product_sums_its_factors() -> None:
    """Concatenation is what a product spells, so the lengths add."""
    left = UniverseNode((Face("ab"),))
    right = UniverseNode((Face("cde"),))
    assert reach(UniverseNode((Product((left, right)),))) == 5


def test_a_fold_reaches_what_it_folds() -> None:
    """Folding changes how many entries there are, never how long a face is."""
    assert reach(UniverseNode((Fold(UniverseNode((Face("longest"),))),))) == 7


def test_a_closure_is_unbounded() -> None:
    """`&` reads a stage that grows, so no length read off the expression bounds it."""
    assert reach(UniverseNode((Face("a"), Closure()))) is None
    assert reach(UniverseNode((Product((Closure(), UniverseNode((Face("b"),)))),))) is None


def test_a_subtraction_never_raises_the_bound() -> None:
    """Stripping faces can only shorten the set, so the strip is not priced at all.

    It is not merely ignored for convenience: pricing it would be *wrong* in the
    dangerous direction. `{a,!{feline}}` reaches 1, and an implementation that
    took the maximum over every member would say 6 and probe five times too far.
    """
    node = UniverseNode((Face("a"), Subtract(UniverseNode((Face("feline"),)))))
    assert reach(node) == 1


def test_a_binder_whose_amp_is_only_subtracted_stays_bounded() -> None:
    """`{a,!{&}}` binds, yet adds faces only through `{a}` -- so it reaches 1.

    The asymmetry `binder.free_amp` encodes, priced: a subtraction's `&` reads
    the enclosing binder but contributes no face through it, so the adding
    members bound the node exactly.
    """
    node = UniverseNode((Face("a"), Subtract(UniverseNode((Closure(),)))))
    assert reach(node) == 1


def test_suffixes_price_each_tail_and_end_at_zero() -> None:
    """`suffixes(f)[i]` bounds `f[i:]`; the empty tail spells nothing."""
    factors = (UniverseNode((Face("ab"),)), UniverseNode((Range("0", "9"),)))
    assert suffixes(factors) == (3, 1, 0)


def test_an_unbounded_factor_unbounds_every_tail_to_its_left() -> None:
    """Nothing left of an unbounded factor has a bounded tail either."""
    factors = (UniverseNode((Face("a"),)), Closure(), UniverseNode((Face("b"),)))
    assert suffixes(factors) == (None, None, 1, 0)


def test_the_closure_token_carries_no_reach_as_a_factor() -> None:
    """A factor may be the bare token, which reads a stage rather than an expression."""
    assert factor_reach(Closure()) is None
    assert factor_reach(UniverseNode((Face("ab"),))) == 2


def test_cuts_stop_where_the_factor_reaches() -> None:
    """A two-character factor is offered no piece of three, whatever the text holds.

    The tail is unbounded here so that only the upper bound is in play; with a
    bounded tail the two ends can contradict, which is the case below.
    """
    assert list(cuts(UniverseNode((Face("ab"),)), None, 0, 9)) == [0, 1, 2]


def test_cuts_are_empty_where_the_two_ends_cannot_both_be_met() -> None:
    """No cut satisfies both bounds, so none is tried -- an early "cannot match".

    A two-character head with a tail that spells nothing cannot cover nine
    characters between them. The empty range is the correct answer and not a
    degenerate one: the caller tries nothing and fails fast.
    """
    assert list(cuts(UniverseNode((Face("ab"),)), 0, 0, 9)) == []


def test_cuts_start_where_the_tail_can_still_cover() -> None:
    """A cut leaving the factors after it more than they can spell cannot complete.

    This is the bound read from the other end, and it is what collapses the
    language's idiomatic closure: an unbounded head beside a one-character tail
    has exactly one legal cut, not one per position.
    """
    assert list(cuts(Closure(), 1, 0, 6)) == [5, 6]


def test_cuts_fall_back_to_the_text_when_both_ends_are_unbounded() -> None:
    """No bound is the honest answer, not a missing one: every cut stays on offer."""
    assert list(cuts(Closure(), None, 2, 5)) == [2, 3, 4, 5]
