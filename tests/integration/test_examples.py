"""Every shipped ``examples/*.hmk`` must compile and behave as documented.

Each example isolates one FOUNDATION construct. This suite proves two things:
every example file parses and denotes without error (it *compiles*), and each
one *works* -- it produces the documented match (or no match, for the reachable
empty universe) against a small sample text. The glob-vs-table check makes the
coverage exhaustive: a new example file with no expectation fails the suite.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from Himark import match, parse

EXAMPLES = Path(__file__).resolve().parents[2] / "examples"

# filename -> (sample text, expected first matched substring, construct shown).
# ``None`` means the query matches nothing (the empty universe is legal).
EXPECTATIONS: dict[str, tuple[str, str | None, str]] = {
    "foundation.hmk": ("a fold of every entry", "fold", "union of faces"),
    "lowercase.hmk": ("Hi", "i", "range a..z"),
    "hex-digit.hmk": ("code 3f2", "c", "union of two ranges"),
    "consonant.hmk": ("aegis", "g", "subtraction of vowels"),
    "synonym.hmk": ("a feline appeared", "feline", "fold: two faces, one entry"),
    "letter-pair.hmk": ("go", "go", "product (adjacency)"),
    "final-segment.hmk": ("hello", "hello", "final segment a.."),
    "empty.hmk": ("anything", None, "empty universe matches nothing"),
}


def test_every_example_file_has_an_expectation() -> None:
    """Guard against an example being added without a compile-and-work check."""
    on_disk = {path.name for path in EXAMPLES.glob("*.hmk")}
    assert on_disk == set(EXPECTATIONS)


@pytest.mark.parametrize("name", sorted(EXPECTATIONS))
def test_example_compiles_and_matches(name: str) -> None:
    """The file parses and denotes, then yields its documented first match."""
    source = (EXAMPLES / name).read_text(encoding="utf-8").strip()

    query = parse(source)  # parse + denote: this is "compiles".
    assert query.universes, f"{name} denoted to no universes"

    text, expected, _construct = EXPECTATIONS[name]
    found = match(query, text)

    if expected is None:
        assert found is None, f"{name} was expected to match nothing"
    else:
        assert found is not None, f"{name} failed to match in {text!r}"
        assert text[found.span[0] : found.span[1]] == expected
