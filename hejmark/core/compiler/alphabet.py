"""The seeded alphabet ``char``: the code space less the noncharacters.

``char`` is the one ``uni`` the spec seeds rather than writing, because the
surface has no escape that spells a code point (see ``docs/foundation/L1_5.md``).
It is the code space ``[U+0000, U+10FFFF]`` minus the noncharacters -- the
sentinel space -- so no ``@char``-derived universe can reach a sentinel.

This is host-supplied data, not I/O: the range is built here in Python and
seeded into the namespace by :func:`hejmark.core.compiler.prelude.prelude_env`.
The derivations that *read* ``@char`` are the standard library and live in
``static/std.hmk`` instead, since they are ordinary surface source.
"""

from __future__ import annotations

from hejmark.core.compiler.ast import Expr, Subtract, Unit, UniverseNode
from hejmark.core.floor.syntax import Range
from hejmark.core.ir.program import NONCHARACTER_RANGES

# The greatest code point; the least is the null character.
_MAX = "\U0010ffff"
_MIN = "\x00"

# The noncharacters, read from the boundary's own definition of the sentinel
# space (:mod:`hejmark.core.ir.program`) rather than restated here: Unicode
# reserves them for internal use, the engine's internal use is sentinels, so
# `char` subtracts them and no `@char`-derived universe can reach one.
_NONCHARACTERS = UniverseNode(tuple(Range(chr(lo), chr(hi)) for lo, hi in NONCHARACTER_RANGES))

# `char` as a bounded range over the whole code space, minus the sentinel space.
_CHAR = Expr((Unit(UniverseNode((Range(_MIN, _MAX), Subtract(_NONCHARACTERS)))),))


def char() -> Expr:
    """The seeded ``char`` universe: the code space minus the noncharacters."""
    return _CHAR
