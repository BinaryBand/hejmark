"""The L3 standard library, written over the L1.5 surface.

:data:`SOURCE` is hejmark, not Python: it is parsed by the same grammar as user
source and resolved into the same namespace, so nothing in it is special-cased.
That is what the L1.5 finish line asks for -- the language writes its own std --
and it is why the derivations below are transcribed from
``docs/foundation/L1_5.md`` rather than reimplemented.

The one exception is ``char``, the alphabet, which ``L1_5.md`` names as the one
``uni`` the spec *seeds*: it is the floor's code-point set ``C`` less the
noncharacters, and the surface has no escape that spells a code point, so the
host supplies it. It is seeded as a bounded range over the whole code space
minus the noncharacters, which is what writing ``{@C, !{noncharacters}}`` would
mean -- the noncharacters are the sentinel space, and carving them out here is
what makes a sentinel unreachable from any ``@char``-derived universe. The floor
``C`` (surrogates cut, noncharacters kept) is not separately materialized: no
surface escape spells it, and nothing but ``char``'s own seed would read it.

Core stays free of I/O, so the source lives here as a constant rather than in a
file an adapter would have to read.
"""

from __future__ import annotations

from functools import lru_cache

from hejmark.core.compiler.ast import Expr, Subtract, Unit, UniverseNode
from hejmark.core.compiler.ports import ToAst
from hejmark.core.compiler.resolve import Env, collect
from hejmark.core.floor.syntax import Range

# The greatest code point; the least is the null character.
_MAX = "\U0010ffff"
_MIN = "\x00"

SOURCE = """\
uni hex          = {0..9,a..f}
uni str          = {{{}},&@char}

def fill         = {{{},@0}}
def shorter w    = {_,!{@char^w_}}
def upto w       = {_[shorter w],@char^w}
def longer w     = {_,!{_[upto w]}}
def where lo..hi = {@lo..hi}
def pad w..w'    = {@fill^{w'}_,!{@str[shorter w]},!{@str[longer w']}}
def zeros        = {{{}},&@0}
def zfold        = {{@zeros}}
def padfree      = {@zfold_}
"""

# The noncharacters: one contiguous block plus the last two points of every
# plane. Unicode reserves them for internal use; the engine's internal use is
# sentinels, so `char` subtracts them and the alphabet never contains one.
_NONCHARACTERS = UniverseNode(
    (
        Range("\ufdd0", "\ufdef"),
        *(Range(chr(plane + 0xFFFE), chr(plane + 0xFFFF)) for plane in range(0, 0x110000, 0x10000)),
    )
)

# `char` as a bounded range over the whole code space, minus the sentinel space
# -- the seeded declaration.
_CODE_POINTS = Expr((Unit(UniverseNode((Range(_MIN, _MAX), Subtract(_NONCHARACTERS)))),))


@lru_cache(maxsize=1)
def _parsed(to_ast: ToAst) -> Env:
    """Parse and resolve the std once; it is the same for every script."""
    env = collect(to_ast(SOURCE))
    env.unis["char"] = _CODE_POINTS
    return env


def std_env(to_ast: ToAst) -> Env:
    """The seeded standard namespace: ``char`` plus the derivations of ``L1_5.md``."""
    return _parsed(to_ast)
