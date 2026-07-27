"""The conformance corpus: what any hejmark engine must agree on, as JSON.

`static/conformance/*.json` is the language-neutral contract between engine
implementations. Every case carries the *lowered payload* -- floor JSON or a
`Program` -- beside its expected answer, so a host with an engine and no
compiler can run the whole corpus without parsing a line of hejmark. That is
the point: the corpus proves the payload is sufficient.

Two test families keep it honest, and they check opposite directions:

- `test_*_case` runs the **checked-in payload** through the engine's decode
  path and asserts the checked-in answer. This is exactly what a port runs, and
  nothing here reaches for the compiler unless a case says it must.
- `test_suite_is_fresh` re-derives each suite from its source and asserts it
  reproduces the file byte for byte, so a change in lowering shows up as a
  corpus diff in review rather than as silent drift.

Expected answers are generated, not hand-written -- the Python implementation
is today's source of truth and the corpus is how that truth becomes portable.
What is authored here is the *coverage*: rows chosen for what a second
implementation is most likely to get wrong. Regenerate with
`HEJMARK_UPDATE_CONFORMANCE=1 uv run pytest tests/integration/test_conformance.py`.
"""

from __future__ import annotations

import json
import os
from itertools import islice
from pathlib import Path
from typing import cast

import pytest

import hejmark
from hejmark.core.engine import execute
from hejmark.core.engine.denote.universe import denote
from hejmark.core.engine.scan.capture import canonical_face, factor_faces
from hejmark.core.engine.scan.match import load_query
from hejmark.core.engine.scan.match import match as engine_match
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.codec import decode_universe
from hejmark.core.ir.errors import HimarkPayloadError, HimarkScopeError, HimarkSentinelError
from hejmark.core.ir.program import (
    CompiledQuery,
    CompiledStatement,
    EagerFactor,
    LateSlot,
    Program,
)
from hejmark.core.ir.wire import decode_program

CORPUS = Path(__file__).resolve().parents[2] / "static" / "conformance"
FORMAT = "hejmark-conformance"
VERSION = 1
UPDATE = os.environ.get("HEJMARK_UPDATE_CONFORMANCE", "")

# The fields derived from the *engine*. Everything else in a case is either
# authored or derived from the compiler, so only these have to freeze the day
# the reference engine stops existing -- see `_read`.
EXPECTATION_FIELDS = frozenset({"entries", "contains", "match", "output", "error"})

ERRORS = {
    "scope": HimarkScopeError,
    "sentinel": HimarkSentinelError,
    "payload": HimarkPayloadError,
}

# (source, entry limit or None when finite, spellings to probe for membership).
DENOTE: tuple[tuple[str, int | None, tuple[str, ...]], ...] = (
    ("{a,b,c}", None, ("a", "c", "d", "")),
    ("{a,b,a}", None, ("a", "b")),
    ("{a..e}", None, ("a", "e", "f")),
    ("{e..a}", None, ("a", "e")),
    ("{{cat,feline}}", None, ("cat", "feline", "dog")),
    ("{a..h,!{b,d}}", None, ("a", "b", "c", "d", "h")),
    ("{{cat,feline},!{feline}}", None, ("cat", "feline")),
    ("{cat}{dog}", None, ("catdog", "cat", "dogcat")),
    ("{{a,ab}{b,c}}", None, ("ab", "ac", "abb", "abc", "a")),
    ("{{a,ab}{c,bc}}", None, ("ac", "abc", "abbc", "ab")),
    ("{a,!{a}}", None, ("a", "")),
    ("{{}}", None, ("", "a")),
    ("{{{},0}}", None, ("", "0", "00")),
    ("{{{},0}}{0,00}", None, ("0", "00", "000")),
    ("{&}", None, ("a", "")),
    ("{a,&}", None, ("a", "aa")),
    ("{a,b,&{a,b}}", 6, ("a", "ab", "abab", "c")),
    ("{a,b,&{a,b}}{b}", 4, ("ab", "aab", "a")),
    ("{0,{1..9,&{0..9}}}", 12, ("0", "10", "1024", "01")),
    ("{ab,{a}&{b}}", 4, ("ab", "aabb", "ba")),
)

# (query source, target text): the leftmost match, its parts and its captures.
MATCH: tuple[tuple[str, str], ...] = (
    ("{b}", "abc"),
    ("{b}", "xyz"),
    ("{a..z}", "Hi"),
    ("{a..z}", "HELLO"),
    ("{a,ab}", "abc"),
    ("{a,ab}{b,c}", "ab"),
    ("{a,ab}{b,c}", "abc"),
    ("{a,ab}{b,c}", "xyz"),
    ("{{cat,feline}}", "the cat sat"),
    ("{{cat,feline}}", "a feline appeared"),
    ("{a..z,!{a,e,i,o,u}}", "aegis"),
    ("{a,&{b}}", "xabbby"),
    ("{0,{1..9,&{0..9}}}", "a1024z"),
    ("{{a,ab}{c,bc}}", "abc"),
    # Two factors, and "abc" splits both ways (a+bc, ab+c): the matcher's
    # greedy witness is one split, the collision rule picks the binding.
    ("{a,ab}{c,bc}", "abc"),
    ("{{}}", "abc"),
)

# (script source, document): the spliced document a whole program produces.
RUN: tuple[tuple[str, str], ...] = (
    ('{a..z} => "X"', "hi there"),
    ('{a..z} => "{{$}}"', "hi"),
    ('{{a,ab}{c,bc}} => "{{$0}}"', "abc"),
    ('{a..z}{0..9} => "{{$2}}{{$1}}"', "a1 b2"),
    ('{a..z} => "[" => "{{$}}"', "hi"),
    ('{a} <=> "a"', "aaa"),
    ('sentinel end\n{@str} => "{{$}}{{@end}}"\n{-}{@end} => "{{@end}}"', "abc-"),
    ('{a..z}{$1} => "!"', "aab"),
)

# (name, stage that refuses, script source, document).
REFUSE_RUN: tuple[tuple[str, str, str, str], ...] = (
    ("ingest-spells-a-sentinel", "ingest", '{a} => "b"', "a﷐b"),
    ("capture-on-a-detached-branch", "engine", '"{{$}}"', "abc"),
    ("factor-read-past-the-query", "engine", '{a..z} => "{{$2}}"', "hi"),
)

# (name, malformed wire object a decoder must refuse rather than repair).
REFUSE_PAYLOAD: tuple[tuple[str, object], ...] = (
    ("not-an-object", "hejmark-program"),
    ("wrong-format", {"format": "other", "version": 4, "sentinels": [], "statements": []}),
    (
        "wrong-version",
        {"format": "hejmark-program", "version": 1, "sentinels": [], "statements": []},
    ),
    ("missing-statements", {"format": "hejmark-program", "version": 4, "sentinels": []}),
    (
        "unknown-statement-kind",
        {
            "format": "hejmark-program",
            "version": 4,
            "sentinels": [],
            "statements": [{"kind": "nonesuch", "steps": []}],
        },
    ),
    (
        "code-point-past-the-plane-space",
        {
            "format": "hejmark-program",
            "version": 4,
            "sentinels": [],
            "statements": [
                {
                    "kind": "statement",
                    "steps": [{"kind": "template", "parts": [{"kind": "text", "text": [1114112]}]}],
                }
            ],
        },
    ),
)


def _no_resolver(_slot: int, _faces: tuple[str, ...]) -> UniverseNode:
    """The resolver a standalone payload must never reach for."""
    msg = "a slot-free payload must not need a late resolver"
    raise AssertionError(msg)


def _one_universe(source: str) -> str:
    """Wrap a top-level product so it denotes as one universe, as L1's table does."""
    return "{" + source + "}" if len(hejmark.parse(source).universes) > 1 else source


def _needs_resolver(program: Program) -> bool:
    """Whether any factor of *program* is a late slot, so a port cannot run it alone."""
    queries = [
        step
        for line in program.statements
        for step in (line.steps if isinstance(line, CompiledStatement) else (line.query,))
        if isinstance(step, CompiledQuery)
    ]
    return any(isinstance(factor, LateSlot) for query in queries for factor in query.factors)


def _build_denote() -> list[dict[str, object]]:
    """Each row's floor payload, its entries (or a prefix) and its membership answers."""
    built = []
    for source, limit, probes in DENOTE:
        wrapped = _one_universe(source)
        payload = json.loads(hejmark.emit_json(wrapped))["universes"][0]
        universe = denote(decode_universe(payload))
        stream = universe.entries() if limit is None else islice(universe.entries(), limit)
        built.append(
            {
                "name": source,
                "source": wrapped,
                "universe": payload,
                "limit": limit,
                "entries": [list(entry.faces) for entry in stream],
                "contains": {probe: universe.contains(probe) for probe in probes},
            }
        )
    return built


def _build_match() -> list[dict[str, object]]:
    """Each row's query payload, the leftmost match, and what `$0`/`$k` bind."""
    built = []
    for source, text in MATCH:
        payload = json.loads(hejmark.emit_json(source))["universes"]
        query = load_query(
            CompiledQuery(source, tuple(EagerFactor(decode_universe(u)) for u in payload)),
            _no_resolver,
        )
        found = engine_match(query, text)
        case: dict[str, object] = {
            "name": f"{source} on {text!r}",
            "source": source,
            "query": payload,
            "text": text,
            "match": None
            if found is None
            else {
                "span": list(found.span),
                "parts": [{"span": list(p.span), "face": p.face} for p in found.parts],
                "canonical": canonical_face(query, found),
                "factors": list(factor_faces(query, found)),
            },
        }
        built.append(case)
    return built


def _build_run() -> list[dict[str, object]]:
    """Each script's Program payload and the document it splices."""
    built = []
    for source, document in RUN:
        payload = json.loads(hejmark.emit_program(source))
        late = _needs_resolver(decode_program(payload))
        built.append(
            {
                "name": f"{source.splitlines()[0]} on {document!r}",
                "source": source,
                "program": payload,
                "document": document,
                "output": hejmark.run(source, document),
                "requires": ["late-resolver"] if late else [],
            }
        )
    return built


def _build_refuse() -> list[dict[str, object]]:
    """The refusals: a run that must raise, and a payload that must not decode."""
    built: list[dict[str, object]] = []
    for name, stage, source, document in REFUSE_RUN:
        with pytest.raises(ValueError) as raised:  # noqa: PT011
            hejmark.run(source, document)
        kind = next(k for k, cls in ERRORS.items() if isinstance(raised.value, cls))
        built.append(
            {
                "name": name,
                "case": "run",
                "stage": stage,
                "source": source,
                "program": json.loads(hejmark.emit_program(source)),
                "document": document,
                "error": kind,
            }
        )
    built.extend(
        {"name": name, "case": "payload", "stage": "decode", "payload": payload, "error": "payload"}
        for name, payload in REFUSE_PAYLOAD
    )
    return built


BUILDERS = {
    "denote": _build_denote,
    "match": _build_match,
    "run": _build_run,
    "refuse": _build_refuse,
}


def _suite(name: str, cases: list[dict[str, object]] | None = None) -> dict[str, object]:
    """One suite as the object its file holds."""
    built = BUILDERS[name]() if cases is None else cases
    return {"format": FORMAT, "version": VERSION, "suite": name, "cases": built}


def _freeze(stored: list[dict[str, object]], built: list[dict[str, object]]) -> list:
    """Rebuilt cases, with the engine-derived answers taken from *stored*."""
    kept = {case["name"]: case for case in stored}
    return [
        {**case, **{k: v for k, v in kept.get(case["name"], {}).items() if k in EXPECTATION_FIELDS}}
        for case in built
    ]


def _read(name: str) -> dict[str, object]:
    """The checked-in suite, regenerated first when the update flag asks.

    ``payloads`` re-derives the compiler's half and keeps every expected answer
    as checked in; ``all`` regenerates the answers too, which is meaningful only
    while a reference engine exists. See `static/conformance/README.md`.
    """
    path = CORPUS / f"{name}.json"
    if UPDATE in {"1", "all", "payloads"}:
        cases = BUILDERS[name]()
        if UPDATE == "payloads" and path.exists():
            cases = _freeze(json.loads(path.read_text())["cases"], cases)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(_suite(name, cases), indent=2, ensure_ascii=False) + "\n")
    return json.loads(path.read_text())


def _cases(name: str) -> list[dict[str, object]]:
    """The checked-in cases of one suite, for parametrization."""
    return cast("list[dict[str, object]]", _read(name)["cases"])


@pytest.mark.parametrize("name", list(BUILDERS), ids=list(BUILDERS))
def test_suite_is_fresh(name: str) -> None:
    """Re-deriving a suite from its sources reproduces the checked-in file."""
    assert _read(name) == _suite(name), (
        f"{name}.json is stale -- rerun with HEJMARK_UPDATE_CONFORMANCE=1 and review the diff"
    )


@pytest.mark.parametrize("case", _cases("denote"), ids=lambda c: c["name"])
def test_denote_case(case: dict) -> None:
    """A floor payload denotes to the corpus's entries and membership answers."""
    universe = denote(decode_universe(case["universe"]))
    limit = case["limit"]
    stream = universe.entries() if limit is None else islice(universe.entries(), limit)

    assert [list(entry.faces) for entry in stream] == case["entries"]
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
