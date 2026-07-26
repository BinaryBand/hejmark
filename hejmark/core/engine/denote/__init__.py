"""engine.denote: L1 denotation -- the floor's syntax made computational.

The compiler emits :mod:`hejmark.core.floor.syntax` trees; denoting one is what
it takes to *execute* a query, so it lives here, on the engine's side of the
boundary. ``order`` fixes the shortlex spelling order, ``window`` views a range
as a half-open interval of it, and ``universe`` denotes a whole brace expression
to the two questions execution asks: does this universe wear a spelling, and
what are its entries in declaration order.

Nothing here reads the surface or the program shapes -- only floor syntax in,
answers out -- so this is the one stratum a host in another language must
reimplement to run a compiled program, and the one the compiler reaches only
through :data:`~hejmark.core.ir.program.ToFaces`.
"""

from __future__ import annotations
