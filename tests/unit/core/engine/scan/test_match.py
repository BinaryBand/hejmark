"""Tests for core.match: leftmost-greedy membership matching.

These drive `match`/`finditer` on hand-built queries (AST nodes through
`denote`), so the parser is not in the loop. The matcher knows only spellings,
so every assertion is about spans and faces.
"""

from __future__ import annotations

import pytest

from hejmark import parse
from hejmark.core.engine.denote.universe import denote
from hejmark.core.engine.scan.match import Eager, Query, Slot, _plain, finditer, match
from hejmark.core.floor.syntax import Face, Fold, UniverseNode
from hejmark.core.ir.errors import HimarkScopeError


def _of(node: UniverseNode) -> Eager:
    """Wrap a hand-built floor node as a factor."""
    return Eager(denote(node))


def _factor(*faces: str) -> Eager:
    """Build a factor over single-faced entries."""
    return _of(UniverseNode(tuple(Face(f) for f in faces)))


def _query(*factors: Eager) -> Query:
    return Query("<hand-built>", factors)


def test_leftmost_match_skips_unmatched_prefix() -> None:
    found = match(_query(_factor("a")), "xxa")

    assert found is not None
    assert found.span == (2, 3)
    assert found.parts[0].face == "a"


def test_no_match_returns_none() -> None:
    assert match(_query(_factor("a")), "zzz") is None


def test_start_offset_is_honoured() -> None:
    found = match(_query(_factor("a")), "aXa", start=1)

    assert found is not None
    assert found.span == (2, 3)


def test_longest_face_wins() -> None:
    """Candidates are tried longest-first regardless of declaration order."""
    found = match(_query(_factor("a", "ab")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert found.parts[0].face == "ab"


def test_backtracks_when_the_greedy_choice_strands_the_rest() -> None:
    """`ab` is longest at position 0, but then `b` cannot match -- so back off to `a`."""
    found = match(_query(_factor("a", "ab"), _factor("b")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert [part.face for part in found.parts] == ["a", "b"]


def test_empty_universe_in_a_product_matches_nothing() -> None:
    assert match(_query(_factor("a"), _factor()), "a") is None


def test_zero_width_is_never_accepted() -> None:
    """The unit universe wears only the empty spelling, so no match exists."""
    unit = _of(UniverseNode((Fold(UniverseNode(())),)))

    assert match(_query(unit), "anything") is None


def test_matching_is_membership_by_any_face() -> None:
    """A fold's alternate spelling hits like any other."""
    folded = _of(UniverseNode((Fold(UniverseNode((Face("cat"), Face("feline")))),)))
    found = match(_query(folded), "a feline")

    assert found is not None
    assert found.parts[0].face == "feline"


def test_finditer_yields_non_overlapping_matches() -> None:
    found = list(finditer(_query(_factor("aa")), "aaaa"))

    assert [m.span for m in found] == [(0, 2), (2, 4)]


def test_finditer_is_empty_when_nothing_matches() -> None:
    assert list(finditer(_query(_factor("a")), "zzz")) == []


def _echo(_slot: int, reads: tuple[str, ...]) -> UniverseNode:
    """A hand-built resolver: the slot's universe is the face its read bound."""
    return UniverseNode((Face(reads[0]),))


def _late_echo() -> Slot:
    """A hand-built back-reference: a factor that re-spells factor 1."""
    return Slot(0, (1,), _echo)


def test_a_late_factor_expands_under_the_faces_bound_to_its_left() -> None:
    """Each attempt substitutes the bound face, so `{a,b}{$1}` matches only echoes."""
    query = Query("<hand-built>", (_factor("a", "b"), _late_echo()))
    found = match(query, "bb")

    assert found is not None
    assert [part.face for part in found.parts] == ["b", "b"]
    assert match(query, "ab") is None


def test_the_chart_covers_a_query_with_no_back_reference() -> None:
    """Nothing back-references, so every depth's answer stands across positions."""
    assert _plain((_factor("a"), _factor("b"), _factor("c"))) == 0


def test_the_chart_starts_past_the_last_back_reference() -> None:
    """A late factor's answer depends on its bindings, so only its tail is chartable."""
    factors = (_factor("a"), _late_echo(), _factor("b"))

    assert _plain(factors) == 2


def test_a_late_factor_last_leaves_nothing_chartable() -> None:
    assert _plain((_factor("a"), _late_echo())) == 2


def test_a_slot_resolves_once_per_read_combination() -> None:
    """The memo keys on the projected read faces, so agreeing bindings share one call."""
    calls: list[tuple[str, ...]] = []

    def counting(_slot: int, reads: tuple[str, ...]) -> UniverseNode:
        calls.append(reads)
        return UniverseNode((Face(reads[0]),))

    slot = Slot(0, (1,), counting)
    assert slot.at(("a", "x")) is slot.at(("a", "y"))
    assert calls == [("a",)]


def test_a_scan_past_a_late_factor_still_reads_each_binding() -> None:
    """The chart covers the plain tail, so the echo must still answer per attempt."""
    query = Query("<hand-built>", (_factor("a", "b"), _late_echo(), _factor("!")))
    found = list(finditer(query, "ab! bb! aa!"))

    assert [m.span for m in found] == [(4, 7), (8, 11)]
    assert [m.parts[1].face for m in found] == ["b", "a"]


def test_universe_refuses_a_late_factor() -> None:
    """A back-referencing factor denotes only under a binding, and says so."""
    query = Query("<hand-built>", (_factor("a"), _late_echo()))

    assert query.universe(0).contains("a")
    with pytest.raises(HimarkScopeError, match="under a binding"):
        query.universe(1)


def test_reach_bounds_the_probe_without_moving_the_match() -> None:
    """L2's reach rewrite: a bounded factor is offered no piece it could not wear.

    `{cat}` reaches 3, so at each start position three lengths are on offer
    instead of one per remaining character. The rewrite is on the *probing*, so
    the assertion that matters is that the hit is where it always was.
    """
    hit = match(parse("{cat}{0..9}"), "xx cat5 yy")
    assert hit is not None
    assert hit.span == (3, 7)
    assert [part.face for part in hit.parts] == ["cat", "5"]


def test_maximal_munch_survives_the_bound() -> None:
    """Longest-first inside a narrowed range is still longest-first overall.

    A bound that changed which face won would be a semantic change wearing an
    optimization's clothes, so this pins the greedy choice specifically: `{a,ab}`
    reaches 2 and must still take `ab` over `a`.
    """
    hit = match(parse("{a,ab}"), "abc")
    assert hit is not None
    assert hit.parts[0].face == "ab"


def test_an_unbounded_factor_still_probes_the_whole_text() -> None:
    """`&` reaches nowhere, so the text is the only bound -- the honest fallback.

    The closure here has to take five characters before the tail can take one,
    which only happens if an unbounded factor is offered every length.
    """
    hit = match(parse("{{a..z,&{a..z}}}{\\!}"), "hello!")
    assert hit is not None
    assert hit.span == (0, 6)
    assert [part.face for part in hit.parts] == ["hello", "!"]
