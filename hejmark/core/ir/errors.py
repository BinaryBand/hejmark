"""The boundary's exception vocabulary, shared by compiler and engine.

:class:`HimarkScopeError` is raised on both sides of the boundary -- by the
compiler when a name or read is refused, and by the engine when a bounded read
outruns its budget -- so it lives in the stratum both sides import.
:class:`HimarkPayloadError` belongs to the boundary itself: a payload that does
not decode is neither side's program.
"""

from __future__ import annotations


class HimarkScopeError(ValueError):
    """Raised when the surface refuses a scope: L1.5 is the layer that rejects.

    Unknown or cyclic name, malformed definition or arity, a register outside a
    definition body, an operand token no application binds, a capture read that
    no branch anchors. Emptiness is never one of these -- a query denoting the
    empty universe matches nothing and says so.
    """


class HimarkPayloadError(ValueError):
    """Raised when a serialized payload does not decode to the IR.

    An unknown tag, a missing field, or a code point past the plane space is a
    malformed payload, never a guess: decoding refuses exactly where the Rust
    reader does.
    """
