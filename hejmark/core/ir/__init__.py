"""core.ir: the pure-data boundary between the compiler and the engine.

Everything that crosses the compiler -> engine boundary is defined here, and
all of it is dumb data: strings, ints, tuples and tagged variants over the
floor's :mod:`~hejmark.core.floor.syntax` nodes. No environment, no surface
AST and no live universe ever rides the payload -- a compiled
:class:`~hejmark.core.ir.program.Program` plus a document is everything an
engine needs, and a slot-free program is fully self-contained.
"""
