"""Generating the conformance corpus: the inputs, and what derives from them.

The other half of `test_conformance_cases.py`, split from it because the corpus
is expected to grow. This module owns the authored inputs and the code that
turns them into `static/conformance/*.json`; that one owns running the result.
Nothing is shared but the small constants each needs, so neither can quietly
depend on the other's state.

What is authored here is the *coverage* -- rows chosen for what a second
implementation is most likely to get wrong. The answers are generated, because
the Python implementation is today's reference engine and the corpus is how
that reference becomes portable.
"""

from __future__ import annotations

import json
import os
from collections.abc import Iterator
from itertools import islice
from pathlib import Path

import pytest

import hejmark
from hejmark.core.engine.denote.universe import Entry, Universe, denote
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


UPDATE = os.environ.get("HEJMARK_UPDATE_CONFORMANCE", "")

# The fields derived from the *engine*. Everything else in a case is either
# authored or derived from the compiler, so only these have to freeze the day
# the reference engine stops existing -- see `_read`.
EXPECTATION_FIELDS = frozenset({"entries", "contains", "match", "output", "error"})

# (source, entry limit, spellings to probe for membership). The limit is None
# for a finite universe (assert every entry), an integer for an infinite one
# (assert that many), or 0 where the entries cannot be enumerated at all --
# `padfree` gives one entry wearing unboundedly many faces, so such a case
# asserts membership only.
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
    # The L3 standard library, which is ordinary surface source: every row here
    # expands to the five constructors, so the payload is eager and standalone.
    ("{@hex}", None, ("0", "f", "g")),
    ("{0..9}[where 8..12]", None, ("8", "12", "7", "13")),
    ("{0..9}[below 8..12]", None, ("8", "11", "12", "13")),
    ("{a..z}[where aa..cc]", 6, ("a", "cc", "cd")),
    ("{0..9}[where 8..12][pad 1..2]", None, ("8", "88", "08")),
    ("{a,b}^1..2", None, ("a", "ab", "aaa")),
    ("{a,b}^3..1", None, ("a", "")),
    ("{@str}", 1, ("", "a", "abc", "\ufdd0")),
    # One entry, unboundedly many faces: enumerating it never returns, so this
    # row is membership only. A port that materializes an entry's faces hangs.
    ("{0..9}[where 3..5 padfree]", 0, ("4", "04", "0005", "06", "2", "")),
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
    # The `resolve` channel, which one case cannot cover. A slot may read a
    # factor that is not its neighbour, read two at once, be one of several
    # reading the same factor, or drive a value cut -- and each distinct
    # binding is a separate resolution the engine must key its memo on.
    ('{a..z}{0..9}{$1} => "!"', "a1a b2b x9y"),
    ('{a..z}{0..9}{$1$2} => "!"', "a1a1 b2b2 c3d4"),
    ('{a..z}{$1}{$1} => "!"', "aaa bbb abc"),
    ('{a..z}{$1} => "[{{$1}}]"', "aabbcc"),
    ('{0..9}{0..9}[below 0..$1] => "<"', "53 35 90"),
)

# (name, stage that refuses, script source, document).
REFUSE_RUN: tuple[tuple[str, str, str, str], ...] = (
    ("ingest-spells-a-sentinel", "ingest", '{a} => "b"', "a﷐b"),
    ("capture-on-a-detached-branch", "engine", '"{{$}}"', "abc"),
    ("factor-read-past-the-query", "engine", '{a..z} => "{{$2}}"', "hi"),
)

# (name, malformed wire object a decoder must refuse rather than repair).
_WELL_FORMED: dict[str, object] = {
    "format": "hejmark-program",
    "version": 4,
    "sentinels": [],
    "statements": [],
}
_BAD_POINT = [{"kind": "template", "parts": [{"kind": "text", "text": [1114112]}]}]
REFUSE_PAYLOAD: tuple[tuple[str, object], ...] = (
    ("not-an-object", "hejmark-program"),
    ("wrong-format", {**_WELL_FORMED, "format": "other"}),
    ("wrong-version", {**_WELL_FORMED, "version": 1}),
    ("missing-statements", {k: v for k, v in _WELL_FORMED.items() if k != "statements"}),
    ("unknown-statement-kind", {**_WELL_FORMED, "statements": [{"kind": "nonesuch", "steps": []}]}),
    (
        "code-point-past-the-plane-space",
        {**_WELL_FORMED, "statements": [{"kind": "statement", "steps": _BAD_POINT}]},
    ),
)


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
        entries = None if limit == 0 else [list(e.faces) for e in _stream(universe, limit)]
        built.append(
            {
                "name": source,
                "source": wrapped,
                "universe": payload,
                "limit": limit,
                "entries": entries,
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


@pytest.mark.parametrize("name", list(BUILDERS), ids=list(BUILDERS))
def test_suite_is_fresh(name: str) -> None:
    """Re-deriving a suite from its sources reproduces the checked-in file."""
    assert _read(name) == _suite(name), (
        f"{name}.json is stale -- rerun with HEJMARK_UPDATE_CONFORMANCE=1 and review the diff"
    )
