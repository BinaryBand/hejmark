"""The face reach bounds every face a universe wears, or admits it cannot.

The strongest check is the cross-check: where ``reach`` returns a number, no
face the universe streams may be longer than it. An over-estimate is safe (it
costs a probe), an under-estimate would drop a match, so the tests pin the
direction as well as the value.
"""

from __future__ import annotations

from itertools import islice

from hejmark.core.floor.reach import cuts, factor_reach, reach, suffixes
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
from hejmark.core.floor.universe import denote


def _u(*members: Member) -> UniverseNode:
    """A universe node from its members, spelled positionally for brevity."""
    return UniverseNode(members)


def _longest_streamed(node: UniverseNode, limit: int = 200) -> int:
    """The longest face in the first *limit* entries -- the bound must not be under it."""
    faces = (face for entry in islice(denote(node).entries(), limit) for face in entry.faces)
    return max((len(face) for face in faces), default=0)


def test_empty_universe_reaches_nothing() -> None:
    """A brace with no member wears no face at all."""
    assert reach(_u()) == 0


def test_face_is_its_own_length() -> None:
    node = _u(Face("cat"))
    assert reach(node) == 3 == _longest_streamed(node)


def test_union_takes_the_longest_member() -> None:
    node = _u(Face("a"), Face("feline"), Face("cat"))
    assert reach(node) == 6 == _longest_streamed(node)


def test_range_spells_single_code_points() -> None:
    node = _u(Range("a", "z"))
    assert reach(node) == 1 == _longest_streamed(node)


def test_reversed_range_spells_nothing() -> None:
    """A range whose high sits below its low wears no face, so it reaches zero."""
    assert reach(_u(Range("z", "a"))) == 0


def test_final_segment_is_unbounded() -> None:
    """Every spelling from `lo` onward: no length bounds it."""
    assert reach(_u(Final("a"))) is None


def test_product_sums_its_factors() -> None:
    node = _u(Product((_u(Face("ab")), _u(Range("0", "9")))))
    assert reach(node) == 3 == _longest_streamed(node)


def test_product_with_an_unbounded_factor_is_unbounded() -> None:
    assert reach(_u(Product((_u(Face("a")), _u(Final("b")))))) is None


def test_closure_factor_is_unbounded() -> None:
    """The `&` reads the binder's stage, which no length bounds."""
    assert reach(_u(Face("a"), Product((Closure(), _u(Face("b")))))) is None


def test_bare_closure_member_is_unbounded() -> None:
    assert reach(_u(Face("a"), Closure())) is None


def test_fold_reaches_its_inner_universe() -> None:
    """A fold is one entry, but it wears every face its inner universe spells."""
    node = _u(Fold(_u(Face("cat"), Face("feline"))))
    assert reach(node) == 6 == _longest_streamed(node)


def test_fold_of_a_binder_is_unbounded() -> None:
    """A braced binder splices its whole closure, so no length bounds the fold."""
    inner = _u(Face("a"), Product((Closure(), _u(Face("b")))))
    assert reach(_u(Fold(inner))) is None


def test_subtraction_never_lengthens() -> None:
    """Stripping faces can only shrink the set, so a subtraction adds no reach."""
    node = _u(Face("cat"), Subtract(_u(Final("a"))))
    assert reach(node) == 3


def test_a_binder_stripping_through_its_closure_stays_bounded() -> None:
    """The one binder with a bound: its `&` occurs only where no face is added."""
    node = _u(Range("a", "z"), Subtract(_u(Closure())))
    assert reach(node) == 1


def test_the_admission_witness_is_unbounded() -> None:
    """`{ab, {a}&{b}}` spells a^n b^n: the shape closure exists to admit."""
    node = _u(Face("ab"), Product((_u(Face("a")), Closure(), _u(Face("b")))))
    assert reach(node) is None


def test_a_closure_factor_reaches_nowhere() -> None:
    """The `&` token reads the binder's stage, which carries no bound."""
    assert factor_reach(Closure()) is None
    assert factor_reach(_u(Face("ab"))) == 2


def test_suffixes_run_from_the_whole_product_down_to_nothing() -> None:
    """One entry longer than the factors: no factor left spells nothing."""
    factors = (_u(Face("ab")), _u(Range("0", "9")), _u(Face("xyz")))

    assert suffixes(factors) == (6, 4, 3, 0)


def test_suffixes_go_unbounded_leftward_from_the_first_unbounded_factor() -> None:
    """Nothing to the left of a closure has a bounded tail either."""
    factors = (_u(Face("a")), Closure(), _u(Range("0", "9")))

    assert suffixes(factors) == (None, None, 1, 0)


def test_cuts_stop_where_the_factor_stops_reaching() -> None:
    """A two-character factor is never offered a third character."""
    assert list(cuts(_u(Face("ab")), None, 0, 9)) == [0, 1, 2]


def test_cuts_are_empty_where_the_two_bounds_cross() -> None:
    """Nothing after it and only two characters of its own: it cannot cover nine."""
    assert list(cuts(_u(Face("ab")), 0, 0, 9)) == []


def test_cuts_start_where_the_tail_can_still_finish() -> None:
    """A cut leaving the tail more than it can spell can never be completed."""
    assert list(cuts(Closure(), 1, 0, 9)) == [8, 9]


def test_an_unbounded_factor_beside_an_unbounded_tail_tries_everything() -> None:
    """No bound on either side, so the text itself is the only cap -- honestly."""
    assert list(cuts(Closure(), None, 3, 6)) == [3, 4, 5, 6]


def test_the_idiomatic_closure_pins_its_cut() -> None:
    """`{@x, &@x}`: the single-character factor beside `&` leaves one cut to look at."""
    factors = (Closure(), _u(Range("a", "z")))
    tails = suffixes(factors)

    assert list(cuts(factors[0], tails[1], 0, 40)) == [39, 40]
