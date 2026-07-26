"""Every shipped example runs, and produces what its comment claims.

The glob-versus-table check is what keeps this honest: a new example with no
expectation fails the suite rather than being quietly uncovered.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from hejmark import finditer, parse, run

EXAMPLES = Path(__file__).resolve().parents[2] / "static" / "examples"

# Examples live in three groups: `simple/` one-expression find queries,
# `demos/` multi-statement run scripts, and `programs/` whole programs doing
# a real job. Keys are paths relative to EXAMPLES.

# Query examples: the file, a text to scan, and the leftmost match expected.
QUERIES = {
    "simple/closure.hmk": ("xabbby", "abbb"),
    "simple/consonant.hmk": ("aeiobxy", "b"),
    "simple/empty.hmk": ("anything", None),
    "simple/foundation.hmk": ("a fold here", "fold"),
    "simple/hex-digit.hmk": ("zzz7f", "7"),
    "simple/letter-pair.hmk": ("9abz", "ab"),
    "simple/lowercase.hmk": ("9a9", "a"),
    "simple/pipeline.hmk": ("x08y", "08"),
    "simple/synonym.hmk": ("my feline", "feline"),
}

# Script examples: the file, a document, and the document after running it.
SCRIPTS = {
    "demos/emit.hmk": ("my feline", "my cat"),
    "demos/redact-vowels.hmk": ("pattern", "pttrn"),
    "demos/synonyms.hmk": ("my kitty met your feline", "my cat met your cat"),
    "demos/wrap-bold.hmk": ("abc", "<b>abc</b>"),
    "demos/mask-replace.hmk": ("cat catalog", "feline catalog"),
    "demos/double-letter.hmk": ("book keeper", "bo!k ke!per"),
    "demos/sort-swap.hmk": ("bbaa", "aabb"),
    "demos/bubble-sort.hmk": ("3,1,2", "1,2,3"),
    "programs/html-escape.hmk": (
        '<a href="x">Tom & Jerry</a>',
        "&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&lt;/a&gt;",
    ),
    "programs/normalize-space.hmk": ("a  \t b\n\nc", "a b c"),
    "programs/slugify.hmk": ("Héllo, World!", "hello-world-"),
    "programs/wrap.hmk": ("abcdef-", "abcdef"),
    "programs/markdown-to-html.hmk": (
        "# Title\nsome *b* and `c`\n## Sub",
        "<h1>Title</h1>\nsome <b>b</b> and <code>c</code>\n<h2>Sub</h2>",
    ),
}


def test_every_example_is_covered() -> None:
    """The table and the directory agree, so nothing ships untested."""
    shipped = {path.relative_to(EXAMPLES).as_posix() for path in EXAMPLES.rglob("*.hmk")}
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
