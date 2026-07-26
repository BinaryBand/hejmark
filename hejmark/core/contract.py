"""The L2 seam: the finite-execution contract, as a ``Program -> Program`` pass.

L1's denotation is total and L1.5's surface adds none, yet a run must be finite.
L2 (``docs/foundation/L2.md``) is where that is enforced: meaning-preserving
rewrites that narrow what a program computes (reach, the value-cut collapse) and
the refusals that decline a program that would not settle. All of it acts on the
compiler's pure-data output, :class:`~hejmark.core.ir.program.Program`, before
the engine runs it -- the one seam between the two.

This module is that seam, not its contents. It imports only the payload
(:mod:`hejmark.core.ir`), never the compiler that produced a program nor the
engine that consumes one, so it stays an *optional* stage: a program crosses it
whether or not it rewrites anything. Today it rewrites nothing -- :func:`apply`
is the identity -- so the pipeline point exists and is exercised, and landing an
actual rewrite is a change here, never to the driver that calls it.
"""

from __future__ import annotations

from hejmark.core.ir.program import Program


def apply(program: Program) -> Program:
    """Pass a compiled program through the contract, unchanged.

    The seam does nothing yet: it takes the compiler's :class:`Program` and
    returns it as it stands, so the engine runs exactly what was compiled. When
    L2 grows, its rewrites and refusals compose into this function -- each a
    total ``Program -> Program`` step -- and every caller already routes through
    here.
    """
    return program
