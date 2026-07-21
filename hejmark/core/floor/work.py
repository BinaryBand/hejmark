"""The work budget: what a run may spend before it is refused rather than waited on.

`L2.md` generalizes a rule the tree already states twice --
:data:`~hejmark.core.scan.capture.BUDGET` over a factor read,
``valueline.RADIX_BUDGET`` over a value cut -- to the runs themselves: the host
holds a work budget over a match and over a contracting pass exactly as it holds
one over a read. Its *existence* is the contract; its size is a choice.
Polynomial is not the same as affordable, and at the boundary a hang is
indistinguishable from a wrong answer, so a run past the budget is a diagnostic
and never a longer wait.

This sits on the floor, low enough to see the work, because that is where the
work is. A matcher probe is one line of Python around one membership question;
the question is what can cost seconds, so a budget counting probes counts
nothing. The unit charged is therefore one **membership question** -- one call
to :meth:`~hejmark.core.floor.universe.Universe.contains`, the recursion's own
chokepoint, memo hits included, since a run that re-asks a million answered
questions has spent a million questions' worth of clock.

Nothing here makes the floor partial. Denotation stays total and membership
still has an answer; a budget only decides whether *this host* keeps computing
it, which is L2's whole remit -- whether a well-formed program can be run within
a bound, never whether it means something. Where no budget is open,
:func:`charge` is free: the budget belongs to the caller that asked for a run,
not to the algebra.

A budget is opened by the entry point that owns a run: one per match, one per
contracting pass. Runs nest -- a pass is made of matches -- and the outermost
open budget is the one that holds, so a pass is priced whole rather than per
match inside it.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass


class HimarkBudgetError(ValueError):
    """Raised when a run spends past the host's work budget.

    Its own class rather than the reads' ``HimarkScopeError``: a read that
    outruns its budget cannot name an entry, where this run could name every one
    of them and simply could not afford to. L2 separates them too -- bounded
    reads and cost are different sections of the contract.
    """


# How many membership questions a single run may spend. Around a hundred
# thousand of them go by per second, so this is roughly a minute of work: far
# above any hand-written script the engine is meant to run (the north-star sort
# settles in five thousand) and far below the point where a wait stops being a
# wait. A host with different patience is meant to change this number; nothing
# else here depends on its value.
BUDGET = 5_000_000


@dataclass
class Meter:
    """One open budget: what is being run, what it may spend, what it has spent."""

    what: str
    budget: int
    spent: int = 0


# The open budget, in a list rather than a rebound module global so that opening
# and closing one is a mutation and the outermost run stays the one that holds.
_OPEN: list[Meter] = []


@contextmanager
def budgeted(what: str, budget: int | None = None) -> Iterator[Meter | None]:
    """Open a work budget over this run, unless an outer run already holds one.

    ``budget`` defaults to :data:`BUDGET` read at the moment the run opens, not
    at import: the size is the host's choice, so setting the constant has to be
    enough to change it.

    Yields the meter that will be charged, or ``None`` when an outer budget is
    already open and this run rides it.
    """
    if _OPEN:
        yield None
        return
    meter = Meter(what, BUDGET if budget is None else budget)
    _OPEN.append(meter)
    try:
        yield meter
    finally:
        _OPEN.clear()


def charge(cost: int = 1) -> None:
    """Charge *cost* questions against the open budget; free where none is open.

    The over-budget meter stays open: the run is over, and a caller that swallows
    the diagnostic and asks again is told the same thing rather than granted a
    fresh allowance. Closing it is the opening context's job.

    Raises:
        HimarkBudgetError: the run has spent past its budget.
    """
    if not _OPEN:
        return
    meter = _OPEN[0]
    meter.spent += cost
    if meter.spent > meter.budget:
        msg = (
            f"{meter.what} ran past the host's work budget of {meter.budget} "
            f"membership questions; the run is polynomial but not affordable here"
        )
        raise HimarkBudgetError(msg)
