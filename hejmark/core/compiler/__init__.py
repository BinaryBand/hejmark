"""core.compiler: L1.5, the layer that rewrites itself away.

Three phases, each a stratum of this package. ``resolve`` binds names (P1),
``expand`` -- with ``valueline`` and the deferred half in ``late`` -- rewrites
the whole tree down to ``core.floor.syntax`` (P2), and ``compile`` assembles
the boundary's :class:`~hejmark.core.ir.program.Program` (P3). Everything the
compiler hands the engine is pure data from :mod:`hejmark.core.ir`, plus the
one callback a back-referencing program needs; the engine is never imported
here, and never imports back.
"""
