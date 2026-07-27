"""The in-process engine presented as the `Engine` port."""

from __future__ import annotations

from hejmark.core.engine.service import InProcess
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.ports import Engine
from hejmark.core.ir.program import (
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    Program,
    TextPart,
)


def _no_resolver(_slot: int, _faces: tuple[str, ...]) -> UniverseNode:
    """A slot-free program must never reach for the resolver."""
    msg = "unexpected resolver call"
    raise AssertionError(msg)


def test_in_process_satisfies_the_engine_port() -> None:
    """The structural check the driver relies on: it is substitutable."""
    engine: Engine = InProcess()

    assert isinstance(engine, InProcess)


def test_run_executes_a_program_against_a_document() -> None:
    """The `run` verb: statements in order, spliced document out."""
    query = CompiledQuery("{a}", (EagerFactor(UniverseNode((Face("a"),))),))
    template = CompiledTemplate((TextPart("X"),))
    program = Program((CompiledStatement((query, template)),), ())

    assert InProcess().run(program, "banana", _no_resolver) == "bXnXnX"


def test_run_strips_the_sentinel_faces_it_is_given() -> None:
    """The engine's one sentinel job: clear the faces the program carries."""
    program = Program((), ("﷐",))

    assert InProcess().run(program, "a﷐b", _no_resolver) == "ab"


def test_canonical_faces_streams_the_entries_of_a_node() -> None:
    """The `zero`/`digits` verb, lazily -- one face per entry, in order."""
    node = UniverseNode((Face("a"), Face("b")))

    assert list(InProcess().canonical_faces(node)) == ["a", "b"]
