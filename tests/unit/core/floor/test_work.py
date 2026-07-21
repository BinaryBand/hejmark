"""The work budget refuses a run rather than letting it hang.

The budget is deterministic -- it counts membership questions, not seconds -- so
a test can pin exactly where the refusal falls. The tests use tiny budgets: the
shipped :data:`BUDGET` is sized for a wall clock, and pinning that number would
be pinning a machine.
"""

from __future__ import annotations

import pytest

from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.floor.universe import Universe, denote
from hejmark.core.floor.work import _OPEN, HimarkBudgetError, budgeted, charge


def _fixture() -> Universe:
    """A universe whose membership questions are cheap and countable."""
    return denote(UniverseNode((Face("a"), Face("b"))))


def test_no_open_budget_charges_nothing() -> None:
    """The budget belongs to the caller that asked for a run, not to the algebra."""
    for _ in range(10_000):
        charge()

    assert not _OPEN


def test_a_run_inside_its_budget_completes() -> None:
    universe = _fixture()
    with budgeted("a test run", 10) as meter:
        assert universe.contains("a")
        assert meter is not None
        assert meter.spent == 1


def _ask(universe: Universe, faces: tuple[str, ...]) -> None:
    """Ask one membership question per face -- one charge each."""
    for face in faces:
        universe.contains(face)


def test_a_run_past_its_budget_is_refused() -> None:
    universe = _fixture()
    faces = ("a", "b", "ab", "ba", "aa", "bb", "aba", "bab")
    with pytest.raises(HimarkBudgetError, match="work budget"), budgeted("a test run", 3):
        _ask(universe, faces)


def test_the_diagnostic_names_the_run_and_the_budget() -> None:
    refused = pytest.raises(HimarkBudgetError, match=r"a contracting pass .* budget of 2 ")
    with refused, budgeted("a contracting pass", 2):
        charge(5)


def test_an_over_budget_meter_keeps_refusing() -> None:
    """Swallowing the diagnostic buys no fresh allowance; the run is over."""
    with budgeted("a test run", 1) as meter:
        with pytest.raises(HimarkBudgetError):
            charge(5)
        with pytest.raises(HimarkBudgetError):
            charge()
        assert meter is not None


def test_the_budget_closes_when_the_run_unwinds() -> None:
    with pytest.raises(HimarkBudgetError), budgeted("a test run", 1):
        charge(5)

    assert not _OPEN


def test_a_nested_run_rides_the_outer_budget() -> None:
    """A pass is made of matches, so the pass is priced whole."""
    with budgeted("a contracting pass", 100) as outer:
        with budgeted("a match", 1) as inner:
            assert inner is None
            charge(50)
        assert outer is not None
        assert outer.spent == 50


def test_a_nested_run_cannot_outlive_the_outer_budget() -> None:
    """A generous inner allowance buys nothing: the outermost budget is the one that holds."""
    refused = pytest.raises(HimarkBudgetError, match="a contracting pass")
    with refused, budgeted("a contracting pass", 3), budgeted("a match", 1_000_000):
        charge(9)
