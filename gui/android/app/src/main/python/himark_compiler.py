"""The compiler, as the Android app calls it: source in, compiled JSON out.

Chaquopy embeds CPython in the app, and this module is the only thing it calls.
Everything under it is the repository's real package -- ``adapters`` parses with
ANTLR, ``core.compiler`` expands L1.5 down to the floor's six constructors --
reached through the committed ``hejmark`` symlink beside this file. So the
device compiles every construct the language has, and what it emits goes
straight to the engine linked beside it: one rule's floor-AST JSON to
``hejmark_find_json``, or a whole script's Program JSON to ``hejmark_run_json``
-- the language's two verbs, each with its own program shape.

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


def compile_program(source: str) -> str:
    r"""Lower a whole script to Program JSON, for ``hejmark_run_json``.

    Args:
        source: Himark source for a whole script.

    Returns:
        ``ok\n<json>`` where it compiled, ``err\n<message>`` where it did not.
        The same blind catch as :func:`compile_query`, for the same boundary
        reason. A back-referencing script compiles fine here -- the program
        carries it as a late slot -- and it is the *engine* that refuses it,
        by name, at load.
    """
    try:
        return "ok\n" + hejmark.emit_program(source)
    except Exception as error:  # noqa: BLE001 -- the same boundary as above
        return "err\n" + _first_line(str(error))


def _first_line(message: str) -> str:
    """Return the first non-empty line of *message*, or a fallback."""
    for line in message.splitlines():
        if line.strip():
            return line.strip()
    return "the rule could not be compiled"
