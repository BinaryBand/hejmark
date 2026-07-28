"""The corpus, run over a real wire against an engine in another process.

`test_conformance_cases.py` proves the payload is sufficient; this proves it
survives the trip. Same expected answers, same reference engine -- the only
thing under test here is the channel between them, which is why the engine
behind it is deliberately the one already known to be correct.

The interesting cases are the ones marked `late-resolver`. Those run the
protocol in both directions at once: the host is waiting for a document while
the engine waits for an expansion while the host asks for a denotation. That
nesting is a correctness requirement rather than an optimization, and
`test_a_late_slot_nests_the_two_directions` is it, stated as an assertion.

Set `HEJMARK_ENGINE` to another engine's command and this becomes a conformance
run for that engine, over the same wire and against the same answers.
"""

from __future__ import annotations

import json
import os
import shlex
from collections.abc import Iterator
from pathlib import Path

import pytest

import hejmark
from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.adapters.remote import Remote, connect, reference_engine
from hejmark.core.driver import Adapters, run
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.errors import HimarkScopeError, HimarkUnsettledError
from hejmark.core.ir.ports import Engine
from hejmark.core.ir.program import LateResolver, Program

CORPUS = Path(__file__).resolve().parents[2] / "static" / "conformance"


def _cases(name: str) -> list[dict]:
    """The checked-in cases of one suite, for parametrization."""
    loaded = json.loads((CORPUS / f"{name}.json").read_text())["cases"]
    assert isinstance(loaded, list)
    return loaded


class _Recorder:
    """An engine that notes when each verb is entered and left, then passes it on.

    The wire is opaque from here on purpose -- what this watches is the *order*
    the verbs interleave in, which is the only part of re-entrancy a host can
    observe without opening the pipe.
    """

    def __init__(self, engine: Engine) -> None:
        self._engine = engine
        self.log: list[str] = []

    def run(self, program: Program, document: str, resolver: LateResolver) -> str:
        self.log.append("run")
        try:
            return self._engine.run(program, document, resolver)
        finally:
            self.log.append("ran")

    def canonical_faces(self, node: UniverseNode) -> Iterator[str]:
        self.log.append("faces")
        return self._engine.canonical_faces(node)


@pytest.fixture(scope="module")
def wire() -> Iterator[Remote]:
    """One engine process, shared by every case in this module."""
    named = os.environ.get("HEJMARK_ENGINE")
    with connect(shlex.split(named) if named else reference_engine()) as remote:
        yield remote


@pytest.fixture(scope="module")
def adapters(wire: Remote) -> Adapters:
    """The parser here, the engine over there."""
    return Adapters(AntlrParser().to_ast, wire)


@pytest.mark.parametrize("case", _cases("run"), ids=lambda c: c["name"])
def test_run_case_over_the_wire(case: dict, adapters: Adapters) -> None:
    """A script compiled here and executed there splices the corpus's document."""
    assert run(adapters, case["source"], case["document"], standard_library()) == case["output"]


def test_a_late_slot_nests_the_two_directions(wire: Remote) -> None:
    """A denotation is read *inside* a run: the engine asked while it was asked.

    `[below 0..$1]` is a value cut over a factor that is not bound until match
    time, so expanding its slot re-enters the compiler, which needs the head
    radix's digits -- an outbound call made while the inbound `run` is still
    unanswered. A transport that could not do that would deadlock here.
    """
    recorder = _Recorder(wire)
    adapters = Adapters(AntlrParser().to_ast, recorder)

    run(adapters, '{0..9}{0..9}[below 0..$1] => "<"', "53 35 90", standard_library())

    assert "run" in recorder.log
    during = recorder.log[recorder.log.index("run") : recorder.log.index("ran")]
    assert "faces" in during


def test_a_slot_free_program_never_uses_the_back_channel(wire: Remote) -> None:
    """One-way traffic is the common case, and the protocol stays one-way for it."""
    recorder = _Recorder(wire)
    adapters = Adapters(AntlrParser().to_ast, recorder)

    run(adapters, '{a..z} => "X"', "hi there", standard_library())

    during = recorder.log[recorder.log.index("run") : recorder.log.index("ran")]
    assert during == ["run"]


def test_a_refusal_crosses_as_the_error_it_was(adapters: Adapters) -> None:
    """The engine declines and the host raises what it would have raised in process."""
    with pytest.raises(HimarkScopeError):
        run(adapters, '{a..z} => "{{$2}}"', "hi", standard_library())


def test_an_l2_refusal_keeps_its_own_category_across_the_wire(adapters: Adapters) -> None:
    """An unsettled membership arrives as itself, not flattened into a scope error.

    The category table is what carries it, so this is really a test that a
    refusal L2 added later travels: the engine raises `HimarkUnsettledError`
    deep inside a scan, the wire names the category, and the host reconstructs
    the same class. Getting this wrong looks like working code -- the run still
    fails -- until a caller tries to tell the two refusals apart.
    """
    with pytest.raises(HimarkUnsettledError):
        run(adapters, '{a,&} => "X"', "b", standard_library())


def test_a_denotation_is_read_across_the_wire(wire: Remote) -> None:
    """`zero` and `digits`, through the port the compiler actually reaches them by."""
    node = UniverseNode((Face("a"), Face("b")))

    assert list(wire.canonical_faces(node)) == ["a", "b"]


def test_the_wire_agrees_with_this_process(adapters: Adapters) -> None:
    """The point of the exercise: substituting the engine changes no answer."""
    source = '{0..9}[where 8..12][pad 1..2] => "<{{$0}}>"'

    assert run(adapters, source, "x 08 12 y", standard_library()) == hejmark.run(
        source, "x 08 12 y"
    )
