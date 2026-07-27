"""adapters.remote: an engine that lives in another process.

The host half of ``docs/protocol.md``. :class:`Remote` satisfies
:class:`~hejmark.core.ir.ports.Engine` by sending the payload
:mod:`hejmark.core.ir.wire` already produces down a :class:`~
hejmark.adapters.channel.Channel` and reading the answer back, so
:class:`~hejmark.core.driver.Adapters` swaps it in for the in-process engine
with nothing above it changing. That substitution is the whole point: the
engine is the piece meant to be rewritten in another language, and this is
where the seam it will be rewritten behind actually cuts.

Two verbs go out and one comes back. ``run`` is a single call carrying the
whole program; ``zero`` and ``digits`` are the compiler's bounded reads of a
denotation, and :meth:`Remote.canonical_faces` keeps them bounded -- a caller
taking one face pays for ``zero`` alone, which is what keeps ``@0`` on an
unbounded universe from asking for a radix that does not end. ``resolve``
arrives *inbound*, while ``run`` is outstanding, and is answered from the
resolver that came with the program.
"""

from __future__ import annotations

import subprocess
import sys
from collections.abc import Iterator, Sequence
from contextlib import contextmanager

from hejmark.adapters.channel import Channel, Params, Reader, RefusalError, Writer, refuse, restore
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.codec import (
    decode_text,
    encode_universe,
    require_array,
    require_field,
)
from hejmark.core.ir.errors import HimarkPayloadError, HimarkScopeError, HimarkSentinelError
from hejmark.core.ir.program import LateResolver, Program
from hejmark.core.ir.wire import encode_program


class Remote:
    """The :class:`~hejmark.core.ir.ports.Engine` port, answered over a pipe."""

    def __init__(self, reader: Reader, writer: Writer) -> None:
        """Speak to the engine on *reader* and *writer*, answering it in turn."""
        self._channel = Channel(reader, writer, self._answer)
        self._resolver: LateResolver | None = None

    def run(self, program: Program, document: str, resolver: LateResolver) -> str:
        """Send *program* and *document* over; see :meth:`Engine.run`.

        *resolver* is not sent -- it cannot be, it is the one thing in a
        compilation that is not data. It is held for the duration of the call
        instead, and answers the ``resolve`` requests that arrive while the far
        side is executing.
        """
        self._resolver = resolver
        try:
            answer = self._call(
                "run", {"program": encode_program(program), "document": _points(document)}
            )
        finally:
            self._resolver = None
        return decode_text(require_field(answer, "document", "run"))

    def canonical_faces(self, node: UniverseNode) -> Iterator[str]:
        """Read *node*'s canonical faces; see :meth:`Engine.canonical_faces`.

        A generator on purpose. In this process laziness is free and one lazy
        verb expresses both protocol reads; over a wire it is two calls, and
        this is where that translation happens -- ``zero`` on the first face,
        ``digits`` only if a second is ever asked for.
        """
        universe: Params = {"universe": encode_universe(node)}
        first = require_field(self._call("zero", universe), "face", "zero")
        if first is None:
            return
        yield decode_text(first)
        answer = self._call("digits", universe)
        faces = require_array(require_field(answer, "faces", "digits"), "faces")
        for face in faces[1:]:
            yield decode_text(face)

    def _call(self, verb: str, params: Params) -> object:
        """Make one outbound call, re-raising a refusal as the error it was."""
        try:
            return self._channel.call(verb, params)
        except RefusalError as refusal:
            raise restore(refusal) from refusal

    def _answer(self, _channel: Channel, verb: str, params: Params) -> object:
        """Answer the one inbound verb: expand a late slot, now that it binds.

        Raises:
            RefusalError: the verb is not ``resolve``, or expansion refused.
        """
        if verb != "resolve" or self._resolver is None:
            msg = f"unexpected inbound verb {verb!r}"
            raise refuse(HimarkPayloadError(msg))
        slot = require_field(params, "slot", "resolve")
        faces = require_array(require_field(params, "faces", "resolve"), "faces")
        if not isinstance(slot, int) or isinstance(slot, bool):
            msg = f"malformed slot: {slot!r} is not an integer"
            raise refuse(HimarkPayloadError(msg))
        try:
            node = self._resolver(slot, tuple(decode_text(face) for face in faces))
        except (HimarkPayloadError, HimarkScopeError, HimarkSentinelError) as error:
            raise refuse(error) from error
        return {"universe": encode_universe(node)}


@contextmanager
def connect(command: Sequence[str]) -> Iterator[Remote]:
    """Run *command* as an engine and yield it as a :class:`Remote`.

    The process gets this one's stderr, so an engine that dies says why on the
    console rather than into a closed pipe; on the way out its input is closed,
    which is the hang-up :meth:`Channel.serve` returns on.
    """
    process = subprocess.Popen(  # noqa: S603
        list(command),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=None,
        text=True,
        encoding="utf-8",
        bufsize=1,
    )
    if process.stdin is None or process.stdout is None:
        msg = f"{command[0]} started without pipes"
        raise RuntimeError(msg)
    try:
        yield Remote(process.stdout, process.stdin)
    finally:
        process.stdin.close()
        process.wait(timeout=_HANGUP_SECONDS)


def reference_engine() -> tuple[str, ...]:
    """The command that serves this package's own engine, for a host to spawn.

    A real deployment names its own binary. This exists so the transport can be
    exercised against an engine already known to be correct -- any failure is
    then unambiguously the wire's, which is the only reason to have a reference
    engine at all.
    """
    return (sys.executable, "-m", "hejmark", "serve-engine")


def _points(text: str) -> list[int]:
    """A spelling as its code points -- the lone-surrogate rule, applied to text."""
    return [ord(character) for character in text]


# Long enough for an engine to notice its input closed, short enough to fail a
# test rather than hang one.
_HANGUP_SECONDS = 10
