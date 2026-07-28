"""The boundary's exception vocabulary, shared by compiler and engine.

:class:`HimarkScopeError` is raised on both sides of the boundary -- by the
compiler when a name or read is refused, and by the engine when a capture read
finds no wearer or outruns its budget -- so it lives in the stratum both sides
import. :class:`HimarkPayloadError` belongs to the boundary itself: a payload
that does not decode is neither side's program.

The other three are L2's own: programs that denote perfectly well, declined
because *this host* cannot finish them.
:class:`HimarkSentinelError` guards the sentinel space at both its edges,
:class:`HimarkUnsettledError` is absence with no stage bound, and
:class:`HimarkBudgetError` is a run that outspends its host. They sit in the
shared stratum for the same reason the other two do: the L2 contract, the
engine and the compiler each raise some of them, and none of the three may
import another.

:data:`CATEGORIES` names them all for a wire that cannot carry a Python class.
``docs/protocol.md`` states them as the protocol's error categories, and this is
that table: a refusal crossing a process boundary travels as its name and
arrives as the same exception on the far side.
"""

from __future__ import annotations


class HimarkScopeError(ValueError):
    """Raised when the surface refuses a scope: L1.5 is the layer that rejects.

    Unknown or cyclic name, malformed definition or arity, a register outside a
    definition body, an operand token no application binds, a capture read that
    no branch anchors. Emptiness is never one of these -- a query denoting the
    empty universe matches nothing and says so.
    """


class HimarkSentinelError(ValueError):
    """Raised at the sentinel boundary: an L2 refusal, not a scope diagnostic.

    The sentinel space is engine-private noncharacters, and it is finite, so
    L2 (docs/foundation/L2.md) refuses at both edges of it. A document that
    arrives already spelling a noncharacter is refused at ingest, so nothing
    engine-private can be forged or collided with from outside; a script
    declaring more sentinels than the pool seats is refused at allocation, a
    finite pool outrun being kin to a budget. Either script denotes -- this is
    L2 declining to run one, never L1.5 declining to expand it.
    """


class HimarkUnsettledError(ValueError):
    """Raised when membership in an unguarded closure has no stage bound.

    A guarded body lengthens at every pass, so a spelling of length ``n`` is
    settled by stage ``n + 1`` and absence is *decided*. An unguarded one --
    ``{a, &}``, whose pass may reproduce itself -- can go on producing forever,
    so presence is still reported the moment a stage shows it while absence has
    no bound at all. Answering "no" there would be a guess dressed as an answer,
    which is the one thing the contract will not do: the denotation is total and
    the spelling either is or is not worn, and this says only that no stage
    *this host* can reach settles which.
    """


class HimarkBudgetError(ValueError):
    """Raised when a run spends past the host's work budget.

    Its own class rather than a read's :class:`HimarkScopeError`: a read that
    outruns its budget cannot name an entry, where this run could name every one
    of them and simply could not afford to. Polynomial is not the same as
    affordable, and at the boundary a hang is indistinguishable from a wrong
    answer, so a run past the budget is a diagnostic and never a longer wait.
    The budget's *existence* is the contract; its size is the host's choice.
    """


class HimarkPayloadError(ValueError):
    """Raised when a serialized payload does not decode to the IR.

    An unknown tag, a missing field, or a code point past the plane space is a
    malformed payload, never a guess: decoding refuses rather than repairing,
    so a reader on the far side of the wire never runs on something it only
    half understood.
    """


CATEGORIES: dict[str, type[ValueError]] = {
    "payload": HimarkPayloadError,
    "scope": HimarkScopeError,
    "sentinel": HimarkSentinelError,
    "unsettled": HimarkUnsettledError,
    "budget": HimarkBudgetError,
}
"""The refusals a host and an engine can name to each other, by wire name.

Messages are deliberately unpinned -- a port must agree on *which* refusal it
is, never on how it reads. Nothing here is engine-private: every one is raised
on both sides of the wire, and a category that is not in this table is a
malformed payload rather than a refusal to be relayed.
"""
