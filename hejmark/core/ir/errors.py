"""The boundary's exception vocabulary, shared by compiler and engine.

:class:`HimarkScopeError` is raised on both sides of the boundary -- by the
compiler when a name or read is refused, and by the engine when a capture read
finds no wearer in a finite universe -- so it lives in the stratum both sides
import. :class:`HimarkPayloadError` belongs to the boundary itself: a payload
that does not decode is neither side's program. :class:`HimarkSentinelError` is
an L2 refusal -- a program that denotes, declined at the sentinel boundary --
so it too sits in the shared stratum, where the L2 contract can raise it.
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
    """Raised when the sentinel boundary is crossed: an L2 refusal, not a scope.

    The sentinel space is engine-private noncharacters. A document that arrives
    already spelling one is refused at ingest (docs/foundation/L2.md), so
    nothing engine-private can be forged or collided with from outside. The
    program denotes -- this is L2 declining to run it, never L1.5 declining to
    expand it.
    """


class HimarkPayloadError(ValueError):
    """Raised when a serialized payload does not decode to the IR.

    An unknown tag, a missing field, or a code point past the plane space is a
    malformed payload, never a guess: decoding refuses rather than repairing,
    so a reader on the far side of the wire never runs on something it only
    half understood.
    """
