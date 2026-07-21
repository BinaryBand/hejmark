"""Tests for core.match: leftmost-greedy membership matching.

These drive `match`/`finditer` on hand-built queries (AST nodes through
`denote`), so the parser is not in the loop. The matcher knows only spellings,
so every assertion is about spans and faces.
"""

from __future__ import annotations

import pytest

from hejmark.core.floor import work
from hejmark.core.floor.syntax import Face, Fold, UniverseNode
from hejmark.core.floor.universe import Universe, denote
from hejmark.core.floor.work import HimarkBudgetError
from hejmark.core.scan.match import Query, _plain, finditer, match
from hejmark.core.surface import ast
from hejmark.core.surface.ast import HimarkScopeError
from hejmark.core.surface.late import Late
from hejmark.core.surface.resolve import Env


def _universe(*faces: str) -> Universe:
    """Build a universe of single-faced entries in declaration order."""
    return denote(UniverseNode(tuple(Face(f) for f in faces)))


def _query(*universes: Universe) -> Query:
    return Query("<hand-built>", universes)


def test_leftmost_match_skips_unmatched_prefix() -> None:
    found = match(_query(_universe("a")), "xxa")

    assert found is not None
    assert found.span == (2, 3)
    assert found.parts[0].face == "a"


def test_no_match_returns_none() -> None:
    assert match(_query(_universe("a")), "zzz") is None


def test_start_offset_is_honoured() -> None:
    found = match(_query(_universe("a")), "aXa", start=1)

    assert found is not None
    assert found.span == (2, 3)


def test_longest_face_wins() -> None:
    """Candidates are tried longest-first regardless of declaration order."""
    found = match(_query(_universe("a", "ab")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert found.parts[0].face == "ab"


def test_backtracks_when_the_greedy_choice_strands_the_rest() -> None:
    """`ab` is longest at position 0, but then `b` cannot match -- so back off to `a`."""
    found = match(_query(_universe("a", "ab"), _universe("b")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert [part.face for part in found.parts] == ["a", "b"]


def test_empty_universe_in_a_product_matches_nothing() -> None:
    assert match(_query(_universe("a"), _universe()), "a") is None


def test_zero_width_is_never_accepted() -> None:
    """The unit universe wears only the empty spelling, so no match exists."""
    unit = denote(UniverseNode((Fold(UniverseNode(())),)))

    assert match(_query(unit), "anything") is None


def test_matching_is_membership_by_any_face() -> None:
    """A fold's alternate spelling hits like any other."""
    folded = denote(UniverseNode((Fold(UniverseNode((Face("cat"), Face("feline")))),)))
    found = match(_query(folded), "a feline")

    assert found is not None
    assert found.parts[0].face == "feline"


def test_finditer_yields_non_overlapping_matches() -> None:
    found = list(finditer(_query(_universe("aa")), "aaaa"))

    assert [m.span for m in found] == [(0, 2), (2, 4)]


def test_finditer_is_empty_when_nothing_matches() -> None:
    assert list(finditer(_query(_universe("a")), "zzz")) == []


def _late_echo() -> Late:
    """A hand-built back-reference: a factor that re-spells factor 1."""
    unit = ast.Unit(ast.UniverseNode((ast.Segments((ast.Read(1),)),)))
    return Late(unit, Env({}, {}), (1,))


def test_a_late_factor_expands_under_the_faces_bound_to_its_left() -> None:
    """Each attempt substitutes the bound face, so `{a,b}{$1}` matches only echoes."""
    query = Query("<hand-built>", (_universe("a", "b"), _late_echo()))
    found = match(query, "bb")

    assert found is not None
    assert [part.face for part in found.parts] == ["b", "b"]
    assert match(query, "ab") is None


def test_the_chart_covers_a_query_with_no_back_reference() -> None:
    """Nothing back-references, so every depth's answer stands across positions."""
    assert _plain((_universe("a"), _universe("b"), _universe("c"))) == 0


def test_the_chart_starts_past_the_last_back_reference() -> None:
    """A late factor's answer depends on its bindings, so only its tail is chartable."""
    factors = (_universe("a"), _late_echo(), _universe("b"))

    assert _plain(factors) == 2


def test_a_late_factor_last_leaves_nothing_chartable() -> None:
    assert _plain((_universe("a"), _late_echo())) == 2


def test_a_scan_past_a_late_factor_still_reads_each_binding() -> None:
    """The chart covers the plain tail, so the echo must still answer per attempt."""
    query = Query("<hand-built>", (_universe("a", "b"), _late_echo(), _universe("!")))
    found = list(finditer(query, "ab! bb! aa!"))

    assert [m.span for m in found] == [(4, 7), (8, 11)]
    assert [m.parts[1].face for m in found] == ["b", "a"]


def test_a_match_past_the_work_budget_is_refused(monkeypatch: pytest.MonkeyPatch) -> None:
    """Never a hang: a run the host cannot afford is a diagnostic, not a longer wait."""
    monkeypatch.setattr(work, "BUDGET", 3)
    query = _query(_universe("z"))

    with pytest.raises(HimarkBudgetError, match="a match ran past"):
        match(query, "aaaaaaaaaa")


def test_each_match_of_a_scan_carries_its_own_budget(monkeypatch: pytest.MonkeyPatch) -> None:
    """A scan is many runs, so a long document is not one run that outgrows the budget."""
    monkeypatch.setattr(work, "BUDGET", 4)
    found = list(finditer(_query(_universe("a")), "a" * 20))

    assert [m.span for m in found] == [(pos, pos + 1) for pos in range(20)]


def test_universe_refuses_a_late_factor() -> None:
    """A back-referencing factor denotes only under a binding, and says so."""
    query = Query("<hand-built>", (_universe("a"), _late_echo()))

    assert query.universe(0).contains("a")
    with pytest.raises(HimarkScopeError, match="under a binding"):
        query.universe(1)
