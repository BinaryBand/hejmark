"""The work budget: opened by a run, charged at the membership question.

The behaviour that matters is not the number but the shape: exactly one meter is
open however deeply runs nest, a charge outside any run is free, and an
exhausted meter stays exhausted rather than handing a caller a second allowance
for asking twice.
"""

from __future__ import annotations

import pytest

from hejmark.core.engine.budget import BUDGET, Meter, budgeted, charge
from hejmark.core.ir.errors import HimarkBudgetError


def test_charging_outside_a_run_is_free() -> None:
    """Denotation is asked at compile time too, and no run owns those questions."""
    charge(10**9)


def test_a_run_spends_what_it_charges() -> None:
    """The meter counts questions, so a caller can see what a run cost."""
    with budgeted("a scan", 100) as meter:
        assert meter is not None
        charge()
        charge(4)
        assert meter.spent == 5


def test_spending_past_the_budget_refuses() -> None:
    """Past the bound the run is over: a diagnostic, never a longer wait."""
    with pytest.raises(HimarkBudgetError, match="work budget"), budgeted("a scan", 3):
        charge(4)


def test_an_exhausted_meter_stays_exhausted_within_its_run() -> None:
    """Swallowing the refusal and asking again is told the same thing.

    A fresh allowance per attempt would make the budget unbounded for any caller
    willing to loop, which is exactly the hang it exists to prevent.
    """
    with budgeted("a scan", 2) as meter:
        assert meter is not None
        with pytest.raises(HimarkBudgetError):
            charge(3)
        with pytest.raises(HimarkBudgetError):
            charge()


def test_the_outermost_run_is_the_one_that_holds() -> None:
    """Runs nest -- a contracting pass is made of matches -- and the outer one meters.

    An inner run that opened its own meter would price a pass per match, so a
    thousand affordable matches would never add up to an unaffordable pass.
    """
    with budgeted("the pass", 10) as outer:
        assert outer is not None
        with budgeted("a match inside it") as inner:
            assert inner is None
            charge(6)
        assert outer.spent == 6


def test_a_run_closes_its_meter_even_when_it_refuses() -> None:
    """The next run starts fresh; a refusal is this run's, not the process's."""
    with pytest.raises(HimarkBudgetError), budgeted("a scan", 1):
        charge(2)
    with budgeted("the next scan", 1) as meter:
        assert meter is not None
        assert meter.spent == 0


def test_the_default_budget_is_read_when_a_run_opens() -> None:
    """The size is the host's choice, so setting the constant has to be enough."""
    with budgeted("a scan") as meter:
        assert meter == Meter("a scan", BUDGET, 0)
