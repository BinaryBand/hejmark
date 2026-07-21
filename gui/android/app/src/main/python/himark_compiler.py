"""The compiler, as the Android app calls it: one rule in, floor-AST JSON out.

Chaquopy embeds CPython in the app, and this module is the only thing it calls.
Everything under it is the repository's real package -- ``adapters`` parses with
ANTLR, ``core.compiler`` expands L1.5 down to the floor's six constructors --
staged next to this file by ``gui/tool/stage_python.sh``. So the device compiles
every construct the language has, not the floor subset
``rust/src/surface/parse.rs`` reads, and the JSON it emits goes straight to
``hejmark_find_json`` in the same engine the desktop uses.

The reply is the status shape ``rust/src/ffi.rs`` already defines -- a status
line, then a body -- for one reason: the app now has two device paths that both
answer a rule, and one reply format across both means the Kotlin in between
transports and never decides. There is no ``unported`` here; this *is* the full
compiler, so a refusal from it is final.
"""

import hejmark


def compile_query(source: str) -> str:
    r"""Lower one rule to floor-AST JSON.

    Args:
        source: Himark source for a single query.

    Returns:
        ``ok\n<json>`` where it compiled, ``err\n<message>`` where it did not.
    """
    try:
        return "ok\n" + hejmark.emit_json(source)
    except Exception as error:  # noqa: BLE001 -- see below
        # Deliberately blind. This is a boundary: whatever the compiler raises
        # -- a syntax error, a scope error, an unbounded radix, a bug -- must
        # come back as a reply, because the alternative is a Python exception
        # crossing into Kotlin as a crash in a text field. The five Himark
        # errors are the expected ones; the catch is wider than the expectation
        # on purpose.
        return "err\n" + _first_line(str(error))


def _first_line(message: str) -> str:
    """Return the first non-empty line of *message*, or a fallback."""
    for line in message.splitlines():
        if line.strip():
            return line.strip()
    return "the rule could not be compiled"
