"""adapters.serve: this package's engine, answering the protocol on a pipe.

The engine half of ``docs/protocol.md``, and the mirror of
:mod:`hejmark.adapters.remote`. It decodes each request into the arguments an
:class:`~hejmark.core.ir.ports.Engine` already takes, calls it, and encodes the
answer -- so the engine behind it is unchanged, and what is being tested when a
suite runs through here is the wire rather than the language.

That is the point of it. An engine in another language is written against this
conversation, and writing the transport first with a known-correct engine
behind it means a failure is the transport's. When the port lands this module
stays as the reference the ported engine is diffed against.

``resolve`` is the direction that makes this more than a pipe. A late slot
cannot be lowered before its reads bind, so executing one asks the *host* --
the compiler that emitted the slot -- to expand it, from inside the ``run``
this is still answering. :func:`_resolver` is that call, and it is why serving
is a :class:`~hejmark.adapters.channel.Channel` rather than a read-eval loop.
"""

from __future__ import annotations

import sys

from hejmark.adapters.channel import (
    Channel,
    Dispatch,
    Params,
    Reader,
    RefusalError,
    Writer,
    refuse,
    restore,
)
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.codec import decode_text, decode_universe, require_field
from hejmark.core.ir.errors import CATEGORIES, HimarkPayloadError
from hejmark.core.ir.ports import Engine
from hejmark.core.ir.program import LateResolver
from hejmark.core.ir.wire import decode_program


def serve(engine: Engine, reader: Reader, writer: Writer) -> None:
    """Answer protocol verbs for *engine* until the far side hangs up."""
    Channel(reader, writer, _verbs(engine)).serve()


def serve_stdio(engine: Engine) -> None:
    """Serve *engine* on this process's own stdin and stdout."""
    serve(engine, sys.stdin, sys.stdout)


def _verbs(engine: Engine) -> Dispatch:
    """The dispatch *engine* answers with, refusals turned into wire refusals.

    Every refusal in :data:`~hejmark.core.ir.errors.CATEGORIES` crosses, read off
    that table rather than listed again here: the table is what says which
    exceptions have a wire name, so a refusal L2 adds later travels the moment it
    is named there. Anything else is a fault in this process, not a refusal, and
    is left to propagate as one.
    """

    def dispatch(channel: Channel, verb: str, params: Params) -> object:
        try:
            return _answer(engine, channel, verb, params)
        except tuple(CATEGORIES.values()) as error:
            raise refuse(error) from error

    return dispatch


def _answer(engine: Engine, channel: Channel, verb: str, params: Params) -> object:
    """One verb, decoded into the engine's own arguments and encoded back.

    Raises:
        HimarkPayloadError: the verb is not one of the three, or its parameters
            do not decode. Refusing an unknown verb is the same rule the codec
            follows for an unknown tag: never guess at half a message.
    """
    if verb == "run":
        program = decode_program(require_field(params, "program", "run"))
        document = decode_text(require_field(params, "document", "run"))
        return {"document": _points(engine.run(program, document, _resolver(channel)))}
    if verb == "zero":
        face = next(engine.canonical_faces(_universe(params, verb)), None)
        return {"face": None if face is None else _points(face)}
    if verb == "digits":
        return {
            "faces": [_points(face) for face in engine.canonical_faces(_universe(params, verb))]
        }
    msg = f"unknown verb {verb!r}"
    raise HimarkPayloadError(msg)


def _resolver(channel: Channel) -> LateResolver:
    """A late resolver that is a call back to the host, over the same channel.

    Re-entrancy lives here: this runs while ``run`` is still unanswered, and the
    expansion it triggers on the far side will ask this engine for denotations
    before it replies. The channel services those inbound calls itself.
    """

    def resolve(slot: int, faces: tuple[str, ...]) -> UniverseNode:
        params: Params = {"slot": slot, "faces": [_points(face) for face in faces]}
        try:
            answer = channel.call("resolve", params)
        except RefusalError as refusal:
            raise restore(refusal) from refusal
        return decode_universe(require_field(answer, "universe", "resolve"))

    return resolve


def _universe(params: Params, verb: str) -> UniverseNode:
    """The single universe argument ``zero`` and ``digits`` share."""
    return decode_universe(require_field(params, "universe", verb))


def _points(text: str) -> list[int]:
    """A spelling as its code points -- the lone-surrogate rule, applied to text."""
    return [ord(character) for character in text]
