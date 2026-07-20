"""The L2 standard library, written over the L1.5 surface.

:data:`SOURCE` is hejmark, not Python: it is parsed by the same grammar as user
source and resolved into the same namespace, so nothing in it is special-cased.
That is what the L1.5 finish line asks for -- the language writes its own std --
and it is why the derivations below are transcribed from
``docs/foundation/L1_5.md`` rather than reimplemented.

The one exception is ``C``, the code-point set, which ``L1_5.md`` names as the
one ``uni`` the spec *seeds*: it is a bounded range over the whole code space,
and the surface has no escape that spells a code point, so the host supplies it.
It is seeded as a range node, which is what writing it in-language would mean.

Core stays free of I/O, so the source lives here as a constant rather than in a
file an adapter would have to read.
"""

from __future__ import annotations

from functools import lru_cache

from hejmark.core.ports import ToAst
from hejmark.core.resolve import Env, collect
from hejmark.core.surface import Expr, Unit, UniverseNode
from hejmark.core.syntax import Range

# The greatest code point; the least is the null character.
_MAX = "\U0010ffff"
_MIN = "\x00"

SOURCE = """\
uni spellings = {{{}}, &@C}

fill         := {{{}, @0}}
nonzero      := {@, !{@0}}
numerals     := {@0, {@nonzero, &@}}
shorter w    := {@spellings, !{@C^w @spellings}}
upto w       := {@shorter w, @C^w}
longer w     := {@spellings, !{@upto w}}
where lo..hi := {@numerals, !{@numerals, !{ {lo..hi} }}}
pad w..w'    := {@fill^{w'} _, !{@shorter w}, !{@longer w'}}
"""

# `C` as a bounded range over the whole code space -- the seeded declaration.
_CODE_POINTS = Expr((Unit(UniverseNode((Range(_MIN, _MAX),))),))


@lru_cache(maxsize=1)
def _parsed(to_ast: ToAst) -> Env:
    """Parse and resolve the std once; it is the same for every script."""
    env = collect(to_ast(SOURCE))
    env.unis["C"] = _CODE_POINTS
    return env


def std_env(to_ast: ToAst) -> Env:
    """The seeded standard namespace: ``C`` plus the derivations of ``L1_5.md``."""
    return _parsed(to_ast)
