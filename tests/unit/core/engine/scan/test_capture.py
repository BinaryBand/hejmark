"""The capture reads: the wearer of a hit, its face 0, and the bound split."""

from __future__ import annotations

from hejmark import parse
from hejmark.core.engine.scan.capture import canonical, canonical_face, factor_faces
from hejmark.core.engine.scan.match import match


def test_canonical_finds_the_wearer_of_a_later_face() -> None:
    """A fold's entry is worn by every face; face 0 is the canonical one."""
    universe = parse("{{cat,feline}}").universe()
    assert canonical(universe, "feline") == "cat"
    assert canonical(universe, "cat") == "cat"


def test_canonical_is_none_when_no_entry_wears_the_spelling() -> None:
    """Over a finite universe an absent spelling simply runs the stream out."""
    assert canonical(parse("{a,b}").universe(), "z") is None


def test_canonical_reaches_a_wearer_near_the_front_of_an_infinite_stream() -> None:
    """An infinite universe is fine as long as the wearer is actually reachable."""
    universe = parse("{a..}").universe()
    assert canonical(universe, "b") == "b"


def test_canonical_face_rejoins_a_product() -> None:
    """Adjacency is the product, so each factor's face 0 is read and joined."""
    query = parse("{{cat,feline}}{{dog,canine}}")
    found = match(query, "felinecanine")
    assert found is not None
    assert canonical_face(query, found) == "catdog"


def test_canonical_face_leaves_a_part_as_it_hit_when_unfound() -> None:
    """The read stays total: a part with no wearer stands as it was spelled."""
    query = parse("{a..}")
    found = match(query, "q")
    assert found is not None
    assert canonical_face(query, found) == "q"


def test_factor_faces_reads_a_pinned_split_without_streaming() -> None:
    """A split the text pins uniquely stands as matched: no entry is streamed."""
    query = parse("{ab}{c}")
    found = match(query, "abc")
    assert found is not None
    assert factor_faces(query, found) == ("ab", "c")


def test_factor_faces_binds_the_least_claimant_of_an_ambiguous_split() -> None:
    """`{a,ab}{c,bc}` spells `abc` twice; collision gave it to `(a, bc)`.

    The matcher's greedy witness is `(ab, c)` -- value 2 -- but the floor binds
    the value-1 claimant, and the factor reads follow the floor, not the
    witness.
    """
    query = parse("{a,ab}{c,bc}")
    found = match(query, "abc")
    assert found is not None
    assert found.parts[0].face == "ab"
    assert factor_faces(query, found) == ("a", "bc")


def test_factor_faces_breaks_a_value_tie_by_face_index() -> None:
    """Two splits over the same entries part on the face axis; lower index wins."""
    query = parse("{{a,ab}}{{bc,c}}")
    found = match(query, "abc")
    assert found is not None
    assert factor_faces(query, found) == ("a", "bc")


def test_factor_faces_prices_a_late_factor_under_each_splits_own_binding() -> None:
    """`{a,ab}{c,bc}{a,$1}` on `abca`: both splits tile, and value order decides.

    The greedy witness is `(ab, c, a)`, but the `(a, bc, a)` split -- whose
    third factor offers `{a, a}` under its own binding -- wins on the value
    vector, so the reads follow it.
    """
    query = parse("{a,ab}{c,bc}{a,$1}")
    found = match(query, "abca")
    assert found is not None
    assert [part.face for part in found.parts] == ["ab", "c", "a"]
    assert factor_faces(query, found) == ("a", "bc", "a")
