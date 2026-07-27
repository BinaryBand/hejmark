"""The host half of the protocol: an engine reached by message rather than call."""

from __future__ import annotations

import json
from io import StringIO

import pytest

from hejmark.adapters.remote import Remote, reference_engine
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import Program


def _no_resolver(_slot: int, _faces: tuple[str, ...]) -> UniverseNode:
    """A slot-free program must never reach for the resolver."""
    msg = "unexpected resolver call"
    raise AssertionError(msg)


def _answers(*messages: dict) -> StringIO:
    """A reader holding what the far side is going to say, in order."""
    return StringIO("".join(json.dumps(message) + "\n" for message in messages))


def _sent(writer: StringIO) -> list[dict]:
    """Every message the remote wrote, in order."""
    return [json.loads(line) for line in writer.getvalue().splitlines()]


def test_run_sends_the_program_and_decodes_the_document() -> None:
    """The whole of `run`: payload out, spliced document back."""
    writer = StringIO()
    reader = _answers({"id": 1, "ok": {"document": [104, 105]}})

    result = Remote(reader, writer).run(Program((), ()), "ab", _no_resolver)

    assert result == "hi"
    request = _sent(writer)[0]
    assert request["verb"] == "run"
    assert request["params"]["document"] == [97, 98]
    assert request["params"]["program"]["format"] == "hejmark-program"


def test_taking_one_face_pays_for_zero_alone() -> None:
    """`@0` reads one entry, so it must cost one call.

    This is the difference between reading a universe's zero and enumerating
    it, and on an unbounded universe it is the difference between an answer and
    no answer at all. The in-process engine gets this from laziness; over a wire
    it has to be arranged, and here is where.
    """
    writer = StringIO()
    reader = _answers({"id": 1, "ok": {"face": [97]}})

    faces = Remote(reader, writer).canonical_faces(UniverseNode((Face("a"), Face("b"))))

    assert next(faces) == "a"
    assert [message["verb"] for message in _sent(writer)] == ["zero"]


def test_taking_every_face_reads_the_digits() -> None:
    """A value cut wants them all, which is the second call and no more."""
    writer = StringIO()
    reader = _answers(
        {"id": 1, "ok": {"face": [97]}},
        {"id": 2, "ok": {"faces": [[97], [98], [99]]}},
    )

    faces = Remote(reader, writer).canonical_faces(UniverseNode((Face("a"),)))

    assert list(faces) == ["a", "b", "c"]
    assert [message["verb"] for message in _sent(writer)] == ["zero", "digits"]


def test_an_empty_universe_has_no_faces_and_costs_one_call() -> None:
    """A null zero ends the stream: there is nothing to ask `digits` about."""
    writer = StringIO()
    reader = _answers({"id": 1, "ok": {"face": None}})

    assert list(Remote(reader, writer).canonical_faces(UniverseNode(()))) == []
    assert [message["verb"] for message in _sent(writer)] == ["zero"]


def test_an_inbound_resolve_reaches_the_running_program_s_resolver() -> None:
    """The back channel: the engine asks, the compiler that emitted the slot answers."""
    writer = StringIO()
    reader = _answers(
        {"id": 3, "verb": "resolve", "params": {"slot": 0, "faces": [[97]]}},
        {"id": 1, "ok": {"document": []}},
    )
    seen: list[tuple[int, tuple[str, ...]]] = []

    def resolver(slot: int, faces: tuple[str, ...]) -> UniverseNode:
        seen.append((slot, faces))
        return UniverseNode((Face("z"),))

    Remote(reader, writer).run(Program((), ()), "", resolver)

    assert seen == [(0, ("a",))]
    assert _sent(writer)[1]["ok"]["universe"] == {"members": [{"kind": "face", "text": [122]}]}


def test_a_resolve_outside_a_run_is_refused() -> None:
    """Nothing holds a resolver between runs, and inventing one would be a guess."""
    writer = StringIO()
    reader = _answers({"id": 3, "verb": "resolve", "params": {"slot": 0, "faces": []}})

    Remote(reader, writer)._channel.serve()

    assert _sent(writer)[0]["error"]["category"] == "payload"


def test_a_refusal_arrives_as_the_error_it_was() -> None:
    """A program the far side declines raises here what it would have raised there."""
    reader = _answers({"id": 1, "error": {"category": "scope", "message": "nothing anchors it"}})

    with pytest.raises(HimarkScopeError):
        Remote(reader, StringIO()).run(Program((), ()), "", _no_resolver)


def test_the_reference_engine_is_this_package_served() -> None:
    """What a host spawns to get a known-correct engine on the far end."""
    assert reference_engine()[1:] == ("-m", "hejmark", "serve-engine")
