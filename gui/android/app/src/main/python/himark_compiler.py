"""The compiler, as the Android app calls it: source in, compiled JSON out.

Chaquopy embeds CPython in the app, and this module is the only thing it calls.
Everything under it is the repository's real package -- ``adapters`` parses with
ANTLR, ``core.compiler`` expands L1.5 down to the floor's six constructors --
reached through the committed ``hejmark`` symlink beside this file. So the
device compiles every construct the language has, and what it emits goes
straight to the engine linked beside it: one floor-AST JSON per rule to
``hejmark_find_json``, or a whole script's Program JSON to ``hejmark_run_json``
-- the language's two verbs, each with its own program shape.

The reply is the status shape ``rust/src/ffi.rs`` already defines -- a status
line, then a body -- for one reason: the app now has two device paths that both
answer a rule, and one reply format across both means the Kotlin in between
transports and never decides. There is no ``unported`` here; this *is* the full
compiler, so a refusal from it is final.
"""

import hejmark


def compile_fragments(sources: list) -> str:
    r"""Lower a project's rules to one floor-AST JSON each, under shared names.

    The rules of a project are the lines of one script, so a name declared in
    any of them is in scope in the rest and a rule that only declares lowers to
    ``null`` rather than an error. A rule that will not compile carries its own
    ``{"error": ...}`` entry and the rest still lower; only a refusal about the
    *set* -- a name two rules declare -- fails the call.

    Args:
        sources: Himark source for each rule, in the project's order.

    Returns:
        ``ok\n<json array>`` where the set compiled, ``err\n<message>`` where
        it did not.
    """
    try:
        return "ok\n" + hejmark.emit_fragments([str(one) for one in sources])
    except Exception as error:  # noqa: BLE001 -- see below
        # Deliberately blind. This is a boundary: whatever the compiler raises
        # -- a syntax error, a scope error, an unbounded radix, a bug -- must
        # come back as a reply, because the alternative is a Python exception
        # crossing into Kotlin as a crash in a text field. The five Himark
        # errors are the expected ones; the catch is wider than the expectation
        # on purpose.
        return "err\n" + _first_line(str(error))


def compile_program(sources: list) -> str:
    r"""Lower a whole script to Program JSON, for ``hejmark_run_json``.

    Args:
        sources: a one-element list holding the whole script. A list because
            both entry points here take one, which is what lets the Kotlin
            between Dart and this module transport a single argument shape and
            decide nothing about which verb it is carrying.

    Returns:
        ``ok\n<json>`` where it compiled, ``err\n<message>`` where it did not.
        The same blind catch as :func:`compile_fragments`, for the same boundary
        reason. A back-referencing script compiles fine here -- the program
        carries it as a late slot -- and it is the *engine* that refuses it,
        by name, at load.
    """
    try:
        return "ok\n" + hejmark.emit_program(str(sources[0]) if sources else "")
    except Exception as error:  # noqa: BLE001 -- the same boundary as above
        return "err\n" + _first_line(str(error))


def _first_line(message: str) -> str:
    """Return the first non-empty line of *message*, or a fallback."""
    for line in message.splitlines():
        if line.strip():
            return line.strip()
    return "the rule could not be compiled"
