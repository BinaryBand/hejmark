"""The standard-library seam: the namespace the compiler resolves against.

The compiler's namespace is the seeded alphabet ``char`` plus, optionally, the
L3 derivations. ``char`` is base -- always seeded (:mod:`.alphabet`) -- because
no surface syntax spells a code point. The derivations are the standard library,
supplied as the source text of ``static/std.hmk`` (read by an adapter, since
``core`` does no I/O) and merged in. ``None`` is the library switched off, and a
program using ``pad``/``where``/... then meets the ordinary scope error.

This is the one place a standard library enters the pipeline. :func:`prelude_env`
builds the prelude namespace; :func:`hejmark.core.compiler.compile.script` merges
it under a script's own declarations. A host wanting a different std passes its
source in ``prelude``'s place; a host wanting none passes ``None``.
"""

from __future__ import annotations

from functools import cache

from hejmark.core.compiler.alphabet import char
from hejmark.core.compiler.ports import ToAst
from hejmark.core.compiler.resolve import Env, collect


@cache
def prelude_env(to_ast: ToAst, prelude: str | None) -> Env:
    """The seeded namespace: ``char`` always, plus the std derivations if given.

    ``prelude`` is the source text of the standard library (``static/std.hmk``),
    or ``None`` to seed only ``char``. Parsed and resolved once per distinct
    text, since it is the same for every script that shares it. ``char`` is
    injected after collection, as the reserved name it is -- the std source may
    read it but never declares it.
    """
    env = collect(to_ast(prelude)) if prelude is not None else Env({}, {})
    env.unis["char"] = char()
    return env
