"""Every shipped example runs, and produces what its comment claims.

The glob-versus-table check is what keeps this honest: a new example with no
expectation fails the suite rather than being quietly uncovered.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from hejmark import finditer, parse, run

EXAMPLES = Path(__file__).resolve().parents[2] / "static" / "examples"

# Query examples: the file, a text to scan, and the leftmost match expected.
QUERIES = {
    "closure.hmk": ("xabbby", "abbb"),
    "consonant.hmk": ("aeiobxy", "b"),
    "empty.hmk": ("anything", None),
    "final-segment.hmk": ("q", "q"),
    "foundation.hmk": ("a fold here", "fold"),
    "hex-digit.hmk": ("zzz7f", "7"),
    "letter-pair.hmk": ("9abz", "ab"),
    "lowercase.hmk": ("9a9", "a"),
    "pipeline.hmk": ("x08y", "08"),
    "synonym.hmk": ("my feline", "feline"),
}

# Script examples: the file, a document, and the document after running it.
SCRIPTS = {
    "emit.hmk": ("my feline", "my cat"),
}


def test_every_example_is_covered() -> None:
    """The table and the directory agree, so nothing ships untested."""
    shipped = {path.name for path in EXAMPLES.glob("*.hmk")}
    assert shipped
    assert shipped == set(QUERIES) | set(SCRIPTS)


@pytest.mark.parametrize(("name", "case"), sorted(QUERIES.items()))
def test_query_examples(name: str, case: tuple[str, str | None]) -> None:
    """Each query example compiles and finds what its comment describes."""
    text, expected = case
    query = parse((EXAMPLES / name).read_text())
    found = next(iter(finditer(query, text)), None)
    assert (None if found is None else text[found.span[0] : found.span[1]]) == expected


@pytest.mark.parametrize(("name", "case"), sorted(SCRIPTS.items()))
def test_script_examples(name: str, case: tuple[str, str]) -> None:
    """Each script example runs end to end and rewrites its document."""
    document, expected = case
    assert run((EXAMPLES / name).read_text(), document) == expected
