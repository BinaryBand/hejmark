"""Tests for core.universe: denoting a faithful AST to lazy universes.

These drive `denote` on hand-built AST nodes, so the parser is not in the loop.
Entries are asserted as tuples of face tuples; infinite universes are sampled
through the lazy iterator.
"""

from __future__ import annotations

from itertools import islice

from hejmark.core.engine.denote.universe import canonical_faces, denote
from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def _faces(node: UniverseNode, limit: int | None = None) -> list[tuple[str, ...]]:
    """Materialize the denoted entries as face tuples (the first `limit` if given)."""
    entries = denote(node).entries()
    if limit is not None:
        entries = islice(entries, limit)
    return [entry.faces for entry in entries]


def test_union_is_ordered_and_deduplicates() -> None:
    node = UniverseNode((Face("a"), Face("b"), Face("a")))

    assert _faces(node) == [("a",), ("b",)]


def test_range_expands_inclusively() -> None:
    assert _faces(UniverseNode((Range("a", "e"),))) == [(c,) for c in "abcde"]


def test_reversed_range_is_empty() -> None:
    assert _faces(UniverseNode((Range("e", "a"),))) == []


def test_fold_collapses_a_nested_universe_into_one_entry() -> None:
    inner = UniverseNode((Face("x"), Face("y")))
    node = UniverseNode((Face("a"), Fold(inner)))

    assert _faces(node) == [("a",), ("x", "y")]


def test_fold_of_the_empty_universe_is_the_unit() -> None:
    """Zero declared faces is one empty face: `{{}}` wears the empty spelling."""
    node = UniverseNode((Fold(UniverseNode(())),))

    assert _faces(node) == [("",)]
    assert denote(node).contains("")


def test_fold_drops_faces_already_claimed() -> None:
    """A fold only keeps faces no live entry has claimed -- union no-ops win."""
    inner = UniverseNode((Face("a"), Face("x")))
    node = UniverseNode((Face("a"), Fold(inner)))

    assert _faces(node) == [("a",), ("x",)]


def test_subtraction_strips_the_named_spelling_and_renumbers() -> None:
    node = UniverseNode((Face("a"), Face("b"), Face("c"), Subtract(UniverseNode((Face("b"),)))))

    assert _faces(node) == [("a",), ("c",)]


def test_subtraction_of_one_face_leaves_the_entry_on_its_others() -> None:
    """`{{cat,feline},!{feline}}` is one entry spelled only `cat` -- a face cut."""
    folded = Fold(UniverseNode((Face("cat"), Face("feline"))))
    node = UniverseNode((folded, Subtract(UniverseNode((Face("feline"),)))))

    assert _faces(node) == [("cat",)]


def test_entry_that_loses_every_face_drops() -> None:
    folded = Fold(UniverseNode((Face("x"), Face("y"))))
    node = UniverseNode((Face("a"), folded, Subtract(UniverseNode((Face("x"), Face("y"))))))

    assert _faces(node) == [("a",)]


def test_face_can_be_reclaimed_after_subtraction() -> None:
    """Subtraction releases the claim, so a later union may re-add the spelling."""
    node = UniverseNode((Face("a"), Subtract(UniverseNode((Face("a"),))), Face("a")))

    assert _faces(node) == [("a",)]


def test_product_member_collides_on_the_least_value() -> None:
    """`{a,ab}{c,bc}` spells `abc` twice; the lower value keeps it, the other drops."""
    left = UniverseNode((Face("a"), Face("ab")))
    right = UniverseNode((Face("c"), Face("bc")))
    node = UniverseNode((Product((left, right)),))

    assert _faces(node) == [("ac",), ("abc",), ("abbc",)]


def test_cross_axis_collision_can_cost_a_canonical_face() -> None:
    """`{{{},0}}{0,00}`: the value-1 entry loses `00` to value 0 and renumbers."""
    fill = UniverseNode((Fold(UniverseNode((Fold(UniverseNode(())), Face("0")))),))
    right = UniverseNode((Face("0"), Face("00")))
    node = UniverseNode((Product((fill, right)),))

    assert _faces(node) == [("0", "00"), ("000",)]


def test_closure_unfolds_stage_major() -> None:
    """`{a,&{b}}` denotes a, ab, abb, ... in first-appearance order."""
    node = UniverseNode((Face("a"), Product((Closure(), UniverseNode((Face("b"),))))))

    assert _faces(node, 4) == [("a",), ("ab",), ("abb",), ("abbb",)]
    assert denote(node).contains("abbbb")
    assert not denote(node).contains("ba")


def test_binder_braces_splice_rather_than_fold() -> None:
    """A braced member that binds `&` contributes its entries -- the union rule."""
    body = UniverseNode((Face("a"), Product((Closure(), UniverseNode((Face("b"),))))))
    node = UniverseNode((Face("z"), Fold(body)))

    assert _faces(node, 3) == [("z",), ("a",), ("ab",)]


def test_bare_self_reference_is_the_union_no_op() -> None:
    assert _faces(UniverseNode((Face("a"), Closure()))) == [("a",)]


def test_closure_of_nothing_is_empty() -> None:
    assert _faces(UniverseNode((Closure(),))) == []


def test_unguarded_closure_enumerates_and_membership_semi_decides() -> None:
    """Totality is denotation's; an unguarded absence is only semi-decided.

    Presence is still reported when a stage shows it; a spelling no stage up to
    ``len + 1`` shows reads as absent -- which a later stage could contradict,
    but nothing here refuses it.
    """
    fill = UniverseNode((Fold(UniverseNode((Fold(UniverseNode(())), Face("0")))),))
    node = UniverseNode((Face("a"), Product((fill, Closure()))))
    universe = denote(node)

    assert _faces(node, 3) == [("a",), ("0a",), ("00a",)]
    assert universe.contains("00a")
    assert not universe.contains("xyz")


def test_subtracted_self_reference_settles_at_stage_one() -> None:
    """`{{a,b,&{a,b}},!{&}}` places everything at stage 1; every later body is empty."""
    ab = UniverseNode((Face("a"), Face("b")))
    witness = UniverseNode((Face("a"), Face("b"), Product((Closure(), ab))))
    node = UniverseNode((Fold(witness), Subtract(UniverseNode((Closure(),)))))

    assert _faces(node, 3) == [("a",), ("b",), ("aa",)]


def test_canonical_faces_streams_one_face_per_entry() -> None:
    """The `ToFaces` port: each entry's face 0, in declaration order."""
    node = UniverseNode((Face("a"), Face("b"), Product((UniverseNode((Face("c"),)),))))

    assert list(canonical_faces(node)) == ["a", "b", "c"]


def test_canonical_faces_is_lazy_over_an_unbounded_universe() -> None:
    """Expansion reads the zero entry of a head it must never materialize."""
    zero = UniverseNode((Face("0"),))
    node = UniverseNode((Fold(UniverseNode((Face("0"), Product((Closure(), zero))))),))

    assert next(iter(canonical_faces(node))) == "0"
    assert list(islice(canonical_faces(node), 3)) == ["0", "00", "000"]
