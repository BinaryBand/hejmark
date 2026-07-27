"""Running the conformance corpus: what any hejmark engine must agree on.

Every case here is read from `static/conformance/*.json` and driven through the
engine's **decode path** -- the payload in the file, never a freshly compiled
one. That is exactly what a port runs, and it is what makes "the payload is
sufficient" a checked claim rather than an intention.

`test_conformance_build.py` generates those files and is where cases are added.
It collects first, so a regeneration run rewrites the corpus before this module
reads it.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from itertools import islice
from pathlib import Path

import pytest

import hejmark
from hejmark.core.engine import execute
from hejmark.core.engine.denote.universe import Entry, Universe, denote
from hejmark.core.engine.scan.capture import canonical_face, factor_faces
from hejmark.core.engine.scan.match import load_query
from hejmark.core.engine.scan.match import match as engine_match
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.codec import decode_universe
from hejmark.core.ir.errors import HimarkPayloadError, HimarkScopeError, HimarkSentinelError
from hejmark.core.ir.program import (
    CompiledQuery,
    EagerFactor,
)
from hejmark.core.ir.wire import decode_program

CORPUS = Path(__file__).resolve().parents[2] / "static" / "conformance"
FORMAT = "hejmark-conformance"
VERSION = 1

ERRORS = {
    "scope": HimarkScopeError,
    "sentinel": HimarkSentinelError,
    "payload": HimarkPayloadError,
}


def _no_resolver(_slot: int, _faces: tuple[str, ...]) -> UniverseNode:
    """The resolver a standalone payload must never reach for."""
    msg = "a slot-free payload must not need a late resolver"
    raise AssertionError(msg)


def _stream(universe: Universe, limit: int | None) -> Iterator[Entry]:
    """The entry stream, truncated to *limit* when the universe is infinite."""
    return universe.entries() if limit is None else islice(universe.entries(), limit)


def _cases(name: str) -> list[dict[str, object]]:
    """The checked-in cases of one suite, for parametrization."""
    loaded = json.loads((CORPUS / f"{name}.json").read_text())["cases"]
    assert isinstance(loaded, list)
    return loaded


@pytest.mark.parametrize("case", _cases("denote"), ids=lambda c: c["name"])
def test_denote_case(case: dict) -> None:
    """A floor payload denotes to the corpus's entries and membership answers."""
    universe = denote(decode_universe(case["universe"]))
    if case["entries"] is not None:
        assert [list(e.faces) for e in _stream(universe, case["limit"])] == case["entries"]
    assert {p: universe.contains(p) for p in case["contains"]} == case["contains"]


@pytest.mark.parametrize("case", _cases("match"), ids=lambda c: c["name"])
def test_match_case(case: dict) -> None:
    """A query payload finds the corpus's leftmost match, parts and captures."""
    query = load_query(
        CompiledQuery("", tuple(EagerFactor(decode_universe(u)) for u in case["query"])),
        _no_resolver,
    )
    found = engine_match(query, case["text"])
    if case["match"] is None:
        assert found is None
        return
    assert found is not None
    assert list(found.span) == case["match"]["span"]
    assert [{"span": list(p.span), "face": p.face} for p in found.parts] == case["match"]["parts"]
    assert canonical_face(query, found) == case["match"]["canonical"]
    assert list(factor_faces(query, found)) == case["match"]["factors"]


@pytest.mark.parametrize("case", _cases("run"), ids=lambda c: c["name"])
def test_run_case(case: dict) -> None:
    """A Program payload splices the corpus's document.

    A case needing the late resolver is run through the compiler instead, since
    the resolver is the one thing a payload cannot carry -- which is exactly
    what its `requires` marks for a host that has no compiler.
    """
    if case["requires"]:
        assert hejmark.run(case["source"], case["document"]) == case["output"]
        return
    program = decode_program(case["program"])
    assert execute.run(program, case["document"], _no_resolver) == case["output"]


@pytest.mark.parametrize("case", _cases("refuse"), ids=lambda c: c["name"])
def test_refuse_case(case: dict) -> None:
    """A refusal refuses, with the corpus's error, on the stage that owns it."""
    expected = ERRORS[case["error"]]
    if case["case"] == "payload":
        with pytest.raises(expected):
            decode_program(case["payload"])
        return
    with pytest.raises(expected):
        hejmark.run(case["source"], case["document"])
