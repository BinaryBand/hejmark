"""Hand-written query cases, one table, minimal boilerplate.

Each query maps text samples to the expected *leftmost matched substring*
(``None`` means the query matches nothing in that text). To add coverage, add a
query block or a single ``text: expected`` line -- no new function needed. For
richer assertions (spans, face identity, values) reach for
:mod:`tests.integration.test_match`; this file is the fast, readable surface.
"""

from __future__ import annotations

import pytest

from hejmark import match

# query -> {text: expected matched substring, or None for no match}
CASES: dict[str, dict[str, str | None]] = {
    "{b}": {"abc": "b", "xyz": None},
    "{a..z}": {"Hi": "i", "HELLO": None},
    "{a,ab}": {"abc": "ab", "a": "a"},
    "{a,ab}{b,c}": {"ab": "ab", "abc": "abc", "xyz": None},
    "{{cat,feline}}": {"a feline appeared": "feline", "the cat sat": "cat"},
    "{a..z,!{a,e,i,o,u}}": {"aegis": "g", "aeiou": None},
    "{0..9,a..f}": {"code 3f2": "c", "3f2": "3"},
    "{a,!{a}}": {"xyz": None, "aaa": None},
    "{{cat,feline},!{feline}}": {"a feline appeared": None, "the cat sat": "cat"},
    "{a,&{b}}": {"xabbby": "abbb", "ba": "a"},
    "{ab,{a}&{b}}": {"aaabbbb": "aaabbb", "ab": "ab"},
    "{0,{1..9,&{0..9}}}": {"a1024z": "1024", "zero 0": "0"},
}


@pytest.mark.parametrize(
    ("query", "text", "expected"),
    [(q, t, e) for q, samples in CASES.items() for t, e in samples.items()],
    ids=lambda v: repr(v) if isinstance(v, str) else str(v),
)
def test_case(query: str, text: str, expected: str | None) -> None:
    """The leftmost match of *query* in *text* spans exactly *expected*."""
    found = match(query, text)
    actual = None if found is None else text[found.span[0] : found.span[1]]
    assert actual == expected
