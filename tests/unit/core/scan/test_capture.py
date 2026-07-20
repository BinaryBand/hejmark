"""The capture reads: finding the entry that wears a hit, and its face 0."""

from __future__ import annotations

import pytest

from hejmark import parse
from hejmark.core.scan.capture import canonical, canonical_face
from hejmark.core.scan.match import match
from hejmark.core.surface.ast import HimarkScopeError


def test_canonical_finds_the_wearer_of_a_later_face() -> None:
    """A fold's entry is worn by every face; face 0 is the canonical one."""
    universe = parse("{{cat,feline}}").universes[0]
    assert canonical(universe, "feline") == "cat"
    assert canonical(universe, "cat") == "cat"


def test_canonical_is_none_when_no_entry_wears_the_spelling() -> None:
    """Over a finite universe an absent spelling simply runs the stream out."""
    assert canonical(parse("{a,b}").universes[0], "z") is None


def test_canonical_reaches_a_wearer_near_the_front_of_an_infinite_stream() -> None:
    """An infinite universe is fine as long as the wearer is actually reachable."""
    universe = parse("{a..}").universes[0]
    assert canonical(universe, "b") == "b"


def test_canonical_refuses_a_wearer_it_cannot_reach() -> None:
    """`{a..}` wears `zz`, but only past millions of shorter spellings.

    A worn spelling always sits at a finite position, so the search terminates
    in principle; the position is what is unbounded. The read refuses rather
    than hanging, since the matcher that accepted the hit cannot say which case
    it handed over.
    """
    universe = parse("{a..}").universes[0]
    with pytest.raises(HimarkScopeError, match="canonical face"):
        canonical(universe, "zz")


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
