"""The L2 seam: the finite-execution contract, as a ``Program -> Program`` pass.

L1's denotation is total and L1.5's surface adds none, yet a run must be finite.
L2 (``docs/foundation/L2.md``) is where that is enforced: meaning-preserving
rewrites that narrow what a program computes (reach, the value-cut collapse) and
the refusals that decline a program that would not settle. All of it acts on the
compiler's pure-data output, :class:`~hejmark.core.ir.program.Program`, before
the engine runs it -- the one seam between the two.

This module is that seam. It imports only the payload (:mod:`hejmark.core.ir`),
never the compiler that produced a program nor the engine that consumes one, so
it stays an *optional* stage: a program crosses it whether or not it rewrites
anything. Two halves of the contract live here -- :func:`apply`, the
``Program -> Program`` rewrite (today the identity), and :func:`check_ingest`,
the boundary refusal that guards what may enter the engine. When L2 grows, its
rewrites and refusals land here, never in the driver that calls them.
"""

from __future__ import annotations

from hejmark.core.ir.errors import HimarkSentinelError
from hejmark.core.ir.program import Program, is_noncharacter


def apply(program: Program) -> Program:
    """Pass a compiled program through the contract, unchanged.

    The rewrite half does nothing yet: it takes the compiler's :class:`Program`
    and returns it as it stands, so the engine runs exactly what was compiled.
    When L2 grows, its meaning-preserving rewrites (reach, the value-cut
    collapse) compose into this function -- each a total ``Program -> Program``
    step -- and every caller already routes through here.
    """
    return program


def check_ingest(document: str) -> None:
    """Refuse a document that arrives spelling a noncharacter.

    The way *in* to the sentinel boundary, complementing the engine's exit
    strip: the way out clears every declared sentinel, and the way in refuses a
    document already carrying one, so nothing engine-private is forged from
    outside and the masking idiom stays sound. A clean document passes silently.

    Raises:
        HimarkSentinelError: the document spells a noncharacter.
    """
    for position, character in enumerate(document):
        if is_noncharacter(ord(character)):
            msg = (
                f"document spells the noncharacter U+{ord(character):04X} at "
                f"position {position}: the sentinel space is engine-private"
            )
            raise HimarkSentinelError(msg)
