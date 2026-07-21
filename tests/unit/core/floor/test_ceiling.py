"""The wrap ceiling counts entries exactly where it can, and refuses otherwise.

The strongest check is the cross-check: where ``cardinality`` returns a number,
streaming the universe's entries must yield exactly that many. Where it returns
``None`` the shape is unbounded or collision-ambiguous, and no count is claimed.
"""

from __future__ import annotations

from hejmark.core.floor.ceiling import cardinality
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


def _streamed(node: UniverseNode) -> int:
    """The true entry count by streaming -- only call on finite universes."""
    return sum(1 for _ in denote(node).entries())


def test_empty_universe_carries_no_entry() -> None:
    """A brace with no members ceils at zero."""
    assert cardinality(_u()) == 0


def test_single_face_is_one() -> None:
    """A lone face is one entry."""
    node = _u(Face("x"))
    assert cardinality(node) == 1 == _streamed(node)


def test_multi_character_face_is_still_one() -> None:
    """A face is one entry however long its spelling."""
    node = _u(Face("cat"))
    assert cardinality(node) == 1 == _streamed(node)


def test_range_is_its_code_point_span() -> None:
    """A digit range ceils at its base."""
    node = _u(Range("0", "9"))
    assert cardinality(node) == 10 == _streamed(node)


def test_reversed_range_is_empty() -> None:
    """A range whose high sits below its low carries nothing."""
    assert cardinality(_u(Range("9", "0"))) == 0


def test_disjoint_union_sums() -> None:
    """Hex is ten digits and six letters, disjoint, so sixteen."""
    node = _u(Range("0", "9"), Range("a", "f"))
    assert cardinality(node) == 16 == _streamed(node)


def test_disjoint_faces_sum() -> None:
    """Distinct faces each count once."""
    node = _u(Face("cat"), Face("dog"))
    assert cardinality(node) == 2 == _streamed(node)


def test_multi_character_face_never_collides_with_a_range() -> None:
    """A two-character face cannot sit inside a single-code-point range."""
    node = _u(Face("ab"), Range("0", "9"))
    assert cardinality(node) == 11 == _streamed(node)


def test_overlapping_ranges_refuse() -> None:
    """Overlapping ranges could double-count a shared code point, so no count."""
    assert cardinality(_u(Range("0", "5"), Range("3", "9"))) is None


def test_face_inside_a_range_refuses() -> None:
    """A face the range already spells is a collision, so no count."""
    assert cardinality(_u(Face("5"), Range("0", "9"))) is None


def test_final_segment_is_unbounded() -> None:
    """A final segment has no ceiling."""
    assert cardinality(_u(Final("a"))) is None


def test_subtraction_refuses() -> None:
    """A subtraction can drop entries, so the count is not cheaply exact."""
    assert cardinality(_u(Range("a", "z"), Subtract(_u(Face("a"))))) is None


def test_product_multiplies() -> None:
    """A two-letter field ceils at the square of its alphabet."""
    letters = _u(Range("a", "z"))
    node = _u(Product((letters, letters)))
    assert cardinality(node) == 676 == _streamed(node)


def test_product_width_three_is_the_cube() -> None:
    """A width-three decimal field ceils at ten cubed, without streaming."""
    digits = _u(Range("0", "9"))
    node = _u(Product((digits, digits, digits)))
    assert cardinality(node) == 1000


def test_closure_factor_voids_the_product() -> None:
    """A closure factor is unbounded, so the product has no ceiling."""
    node = _u(Product((_u(Face("a")), Closure())))
    assert cardinality(node) is None


def test_closure_member_is_unbounded() -> None:
    """A brace binding a closure carries no ceiling."""
    node = _u(Face("a"), Product((Closure(), _u(Face("b")))))
    assert cardinality(node) is None


def test_fold_collapses_to_one_entry() -> None:
    """A fold is a single entry however many faces it wears."""
    node = _u(Fold(_u(Face("cat"), Face("feline"))))
    assert cardinality(node) == 1 == _streamed(node)
