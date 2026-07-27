"""adapters.channel: the re-entrant line an out-of-process engine speaks over.

One JSON object per line, in both directions. A request is
``{"id", "verb", "params"}``; the answer to it is ``{"id", "ok"}`` or
``{"id", "error"}``. Nothing else crosses, and the payloads inside are the
shapes :mod:`hejmark.core.ir.wire` and :mod:`hejmark.core.ir.codec` already
define -- this module carries them, it does not know them.

:class:`Channel` is deliberately **symmetric**: the same class is both ends.
That is not tidiness, it is the protocol's first requirement. ``resolve`` runs
*inside* ``run`` -- the engine asks the host to expand a late slot while the
host is still waiting for its document, and expanding it asks the engine for a
denotation in turn. An end that could only talk or only listen would deadlock
on the first back-reference, so both ends do both, and waiting for an answer
(:meth:`Channel.call`) and answering (:meth:`Channel.serve`) are the same loop
with a different stopping condition. Nesting is just that loop re-entered.

A refusal crosses as a :class:`RefusalError` -- a category name from
:data:`~hejmark.core.ir.errors.CATEGORIES` and a message -- so a program the
far side declines to run raises the exception it would have raised here.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Protocol, cast

from hejmark.core.ir.errors import CATEGORIES

Params = dict[str, object]
Dispatch = Callable[["Channel", str, Params], object]


class Reader(Protocol):
    """Where messages arrive: anything that hands back one line at a time."""

    def readline(self) -> str:
        """The next line, or the empty string once the far side has hung up."""
        ...


class Writer(Protocol):
    """Where messages go: anything that takes a line and can be made to send it."""

    def write(self, text: str, /) -> int:
        """Take *text*; it need not have left yet."""
        ...

    def flush(self) -> None:
        """Send what has been taken. Every message is flushed, or nothing moves."""
        ...


class ChannelError(RuntimeError):
    """Raised when the far side stops speaking the protocol -- or stops.

    Not a refusal: a refusal is an answer, and this is the absence of one. A
    truncated line, a response to a call nobody made, or a hang-up while a call
    is outstanding all mean the conversation cannot continue, which is a
    different thing from an engine declining a program.
    """


class RefusalError(RuntimeError):
    """A refusal that crossed the wire: a category name and its message.

    The category is a string here because the channel carries the language
    rather than knowing it; :func:`restore` turns it back into the exception
    the far side actually raised.
    """

    def __init__(self, category: str, detail: str) -> None:
        """Name the refusal and keep both halves readable separately."""
        super().__init__(f"{category}: {detail}")
        self.category = category
        self.detail = detail


def refuse(error: ValueError) -> RefusalError:
    """The wire form of a boundary refusal.

    Raises:
        ValueError: *error* is not one of the categories a wire can name, so
            relaying it would invent a refusal the far side cannot read back.
    """
    for name, kind in CATEGORIES.items():
        if isinstance(error, kind):
            return RefusalError(name, str(error))
    raise error


def restore(refusal: RefusalError) -> Exception:
    """The exception *refusal* was raised as on the far side.

    An unknown category stays a :class:`RefusalError`: a host that has not heard of
    it must not pretend it has, and the message survives either way.
    """
    kind = CATEGORIES.get(refusal.category)
    return refusal if kind is None else kind(refusal.detail)


class Channel:
    """One end of a bidirectional request/response line over two text streams.

    *dispatch* answers what arrives; it receives the channel back as its first
    argument, so an inbound request can issue outbound ones of its own without
    either end holding a reference to the other.
    """

    def __init__(self, reader: Reader, writer: Writer, dispatch: Dispatch) -> None:
        """Take the two streams and what should answer what arrives on them."""
        self._reader = reader
        self._writer = writer
        self._dispatch = dispatch
        self._next = 1

    def call(self, verb: str, params: Params) -> object:
        """Ask the far side for *verb*, servicing its requests until it answers.

        Raises:
            RefusalError: the far side declined the call.
            ChannelError: it stopped speaking the protocol instead.
        """
        ident = self._next
        self._next += 1
        self._send({"id": ident, "verb": verb, "params": params})
        return self._pump(ident)

    def serve(self) -> None:
        """Answer inbound requests until the far side hangs up."""
        self._pump(None)

    def _pump(self, awaiting: int | None) -> object:
        """Read messages, answering requests, until call *awaiting* is answered.

        With *awaiting* set this is the tail of :meth:`call` and it returns that
        call's result; with it ``None`` this is :meth:`serve` and it returns at
        end of input. The two differ only in when they stop, which is what makes
        a nested exchange cost nothing but another frame.
        """
        while True:
            message = self._receive()
            if message is None:
                if awaiting is None:
                    return None
                msg = f"the far side hung up while call {awaiting} was outstanding"
                raise ChannelError(msg)
            if "verb" in message:
                self._answer(message)
            elif awaiting is None:
                msg = f"unsolicited answer to call {message.get('id')!r}"
                raise ChannelError(msg)
            else:
                return _result(message, awaiting)

    def _answer(self, message: dict[str, object]) -> None:
        """Dispatch one inbound request and send back its answer or its refusal."""
        ident = message.get("id")
        verb = message["verb"]
        params = message.get("params")
        if not isinstance(verb, str) or not isinstance(params, dict):
            msg = f"malformed request {ident!r}"
            raise ChannelError(msg)
        try:
            result = self._dispatch(self, verb, cast("Params", params))
        except RefusalError as refusal:
            error = {"category": refusal.category, "message": refusal.detail}
            self._send({"id": ident, "error": error})
        else:
            self._send({"id": ident, "ok": result})

    def _send(self, message: dict[str, object]) -> None:
        """Write one message and flush it: a line the far side can act on now."""
        self._writer.write(json.dumps(message) + "\n")
        self._writer.flush()

    def _receive(self) -> dict[str, object] | None:
        """Read one message, or ``None`` at end of input.

        Raises:
            ChannelError: the line is not a JSON object.
        """
        line = self._reader.readline()
        if not line:
            return None
        try:
            message = json.loads(line)
        except json.JSONDecodeError as error:
            msg = f"not a protocol message: {line!r}"
            raise ChannelError(msg) from error
        if not isinstance(message, dict):
            msg = f"not a protocol message: {line!r}"
            raise ChannelError(msg)
        return cast("dict[str, object]", message)


def _result(message: dict[str, object], awaiting: int) -> object:
    """The value an answer carries, or the refusal it carries instead.

    Raises:
        RefusalError: the answer is a refusal.
        ChannelError: it answers a different call, or answers nothing.
    """
    if message.get("id") != awaiting:
        msg = f"answer to call {message.get('id')!r} while awaiting {awaiting}"
        raise ChannelError(msg)
    error = message.get("error")
    if isinstance(error, dict):
        detail = cast("dict[str, object]", error)
        raise RefusalError(str(detail.get("category")), str(detail.get("message")))
    if "ok" not in message:
        msg = f"answer to call {awaiting} is neither a result nor a refusal"
        raise ChannelError(msg)
    return message["ok"]
