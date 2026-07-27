"""The engine half of the protocol: verbs decoded into an engine's own arguments."""

from __future__ import annotations

import json
from io import StringIO

from hejmark.adapters.serve import serve
from hejmark.core.engine.service import InProcess
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.codec import encode_universe
from hejmark.core.ir.program import (
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    Program,
    TextPart,
)
from hejmark.core.ir.wire import encode_program


def _served(*requests: dict) -> list[dict]:
    """What the reference engine answers to *requests*, in order."""
    reader = StringIO("".join(json.dumps(request) + "\n" for request in requests))
    writer = StringIO()
    serve(InProcess(), reader, writer)
    return [json.loads(line) for line in writer.getvalue().splitlines()]


def _universe(*faces: str) -> dict[str, object]:
    """One brace group of literal faces, as the codec's shape."""
    return encode_universe(UniverseNode(tuple(Face(face) for face in faces)))


def test_run_executes_the_program_it_is_handed() -> None:
    """The verb that is the whole job: a payload in, a spliced document out."""
    query = CompiledQuery("{a}", (EagerFactor(UniverseNode((Face("a"),))),))
    program = Program((CompiledStatement((query, CompiledTemplate((TextPart("X"),)))),), ())
    request = {
        "id": 1,
        "verb": "run",
        "params": {"program": encode_program(program), "document": [98, 97, 100]},
    }

    assert _served(request) == [{"id": 1, "ok": {"document": [98, 88, 100]}}]


def test_zero_answers_one_face() -> None:
    """`@0` asks for the head's zero entry and is owed exactly that."""
    request = {"id": 1, "verb": "zero", "params": {"universe": _universe("a", "b")}}

    assert _served(request) == [{"id": 1, "ok": {"face": [97]}}]


def test_zero_is_null_for_a_universe_with_no_entries() -> None:
    """Emptiness is an answer here, never a refusal."""
    request = {"id": 1, "verb": "zero", "params": {"universe": _universe()}}

    assert _served(request) == [{"id": 1, "ok": {"face": None}}]


def test_digits_answers_every_face_in_value_order() -> None:
    """A value cut is defined by the head radix's digits, so it reads all of them."""
    request = {"id": 1, "verb": "digits", "params": {"universe": _universe("a", "b")}}

    assert _served(request) == [{"id": 1, "ok": {"faces": [[97], [98]]}}]


def test_an_unknown_verb_is_refused_as_a_malformed_payload() -> None:
    """The codec's rule, applied to the conversation: never guess at half a message."""
    answers = _served({"id": 1, "verb": "denote", "params": {}})

    assert answers[0]["error"]["category"] == "payload"


def test_a_malformed_parameter_is_refused_rather_than_repaired() -> None:
    """A request that does not decode is refused with its category, not dropped."""
    answers = _served({"id": 1, "verb": "zero", "params": {}})

    assert answers[0]["error"]["category"] == "payload"


def test_serving_ends_when_the_far_side_hangs_up() -> None:
    """A served engine finishes on end of input, having answered what it was asked."""
    assert _served() == []
