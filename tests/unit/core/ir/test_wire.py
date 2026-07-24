"""The Program wire format round-trips and refuses what it cannot read."""

from __future__ import annotations

import json
from typing import cast

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.compile import compile_script, script
from hejmark.core.engine import execute
from hejmark.core.floor.syntax import Closure, Face, Product, Range, UniverseNode
from hejmark.core.ir.errors import HimarkPayloadError
from hejmark.core.ir.program import (
    CapturePart,
    CompiledIter,
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    LateSlot,
    Program,
    Sentinel,
    SentinelPart,
    TextPart,
)
from hejmark.core.ir.wire import decode_program, encode_program


def _walk(obj: object, *path: str | int) -> object:
    """Descend a decoded JSON tree, asserting the container shape at each step."""
    for step in path:
        if isinstance(step, str):
            assert isinstance(obj, dict)
            obj = cast("dict[str, object]", obj)[step]
        else:
            assert isinstance(obj, list)
            obj = cast("list[object]", obj)[step]
    return obj


def _program() -> Program:
    """One program touching every IR node kind."""
    eager = UniverseNode((Face("a"), Range("0", "9"), Product((Closure(),))))
    query = CompiledQuery("{a,0..9,{&}}{$1}", (EagerFactor(eager), LateSlot(0, (1,))))
    template = CompiledTemplate((TextPart("<"), CapturePart("$1"), SentinelPart("end")))
    contract = CompiledIter(query, template)
    return Program(
        (CompiledStatement((query, template)), contract),
        (Sentinel("end", "﷐"),),
    )


def test_a_program_round_trips_through_json() -> None:
    """Encode, dump, load, decode: structural equality end to end."""
    program = _program()
    assert decode_program(json.loads(json.dumps(encode_program(program)))) == program


def test_the_wire_object_is_versioned_and_tagged() -> None:
    """A reader can dispatch on the format tag before touching anything else."""
    encoded = encode_program(_program())
    assert encoded["format"] == "hejmark-program"
    assert encoded["version"] == 3


def test_a_slot_rides_as_an_id_and_its_reads() -> None:
    """A back-referencing factor crosses as a hole, never as compiler objects."""
    encoded = encode_program(_program())
    factor = _walk(encoded, "statements", 0, "steps", 0, "factors", 1)
    assert factor == {"kind": "slot", "slot": 0, "needs": [1]}


def test_a_foreign_format_tag_is_refused() -> None:
    """A payload naming another format is not guessed at."""
    encoded = encode_program(_program())
    encoded["format"] = "someone-else"
    with pytest.raises(HimarkPayloadError, match="format"):
        decode_program(encoded)


def test_a_future_version_is_refused() -> None:
    """Version drift refuses rather than misreads."""
    encoded = encode_program(_program())
    encoded["version"] = 4
    with pytest.raises(HimarkPayloadError, match="version"):
        decode_program(encoded)


def test_an_unknown_statement_kind_is_refused() -> None:
    """A statement is a statement or a contraction; anything else is malformed."""
    encoded = encode_program(_program())
    line = _walk(encoded, "statements", 0)
    assert isinstance(line, dict)
    cast("dict[str, object]", line)["kind"] = "loop"
    with pytest.raises(HimarkPayloadError, match="unknown kind"):
        decode_program(encoded)


def test_an_unknown_part_kind_is_refused() -> None:
    """Template parts are text, capture, or sentinel; anything else is malformed."""
    encoded = encode_program(_program())
    parts = _walk(encoded, "statements", 0, "steps", 1, "parts")
    assert isinstance(parts, list)
    cast("list[object]", parts)[0] = {"kind": "pipe", "name": "trim"}
    with pytest.raises(HimarkPayloadError, match="unknown kind"):
        decode_program(encoded)


def test_a_missing_field_is_refused() -> None:
    """No field is defaulted: an absent table is a malformed program."""
    encoded = encode_program(_program())
    del encoded["sentinels"]
    with pytest.raises(HimarkPayloadError, match="sentinels"):
        decode_program(encoded)


_to_ast = AntlrParser().to_ast


def test_a_compiled_script_round_trips() -> None:
    """A real script -- sentinel, back-reference, contraction -- survives the wire."""
    source = 'sentinel end\n{a,b}{$1} => "{{$1}}{{@end}}"\n{-}{-} <=>[@str] "-"'
    node, env = script(_to_ast, source)
    program, _ = compile_script(node, env)
    assert decode_program(json.loads(json.dumps(encode_program(program)))) == program


def test_a_decoded_slot_free_program_is_standalone() -> None:
    """A slot-free program executes from its wire form alone; the resolver is never called."""

    def never(_slot: int, _reads: tuple[str, ...]) -> UniverseNode:
        msg = "a slot-free program called the resolver"
        raise AssertionError(msg)

    node, env = script(_to_ast, '{a} => "x"\n{b}{c} => "<{{$0}}>"')
    program, _ = compile_script(node, env)
    decoded = decode_program(json.loads(json.dumps(encode_program(program))))
    assert execute.run(decoded, "abca bc", never) == execute.run(program, "abca bc", never)
