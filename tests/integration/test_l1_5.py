"""The L1.5 north-star tables, executable.

``docs/foundation/L1_5.md`` carries two tables: the modifier pipeline over the
seeded std, and emit. They are the layer's acceptance criteria, so they live
here as tests rather than as prose -- if the surface stops denoting a row, this
file stops passing.

The pipeline rows assert a *prefix* of the entry stream. That is not a hedge:
``where`` cuts an infinite value line down to finitely many survivors, and a
lazy stream cannot prove it has passed the last one. Membership is the exact
oracle, so each row also pins its boundary with ``contains``.
"""

from __future__ import annotations

from itertools import islice

import pytest

from hejmark import parse, run

# Expression -> the faces of its entries, in order. From L1_5.md's first table.
PIPELINE_ROWS = (
    ("{0..9}[where 8..12]", [("8",), ("9",), ("10",), ("11",), ("12",)]),
    ("{8,9,10,11,12}[pad 2]", [("88",), ("89",), ("10",), ("11",), ("12",)]),
    (
        "{0..9}[where 8..12 pad 1..2]",
        [("8", "08"), ("9", "09"), ("10",), ("11",), ("12",)],
    ),
)

# Statement, document, expected result. From L1_5.md's emit table.
EMIT_ROWS = (
    ('{{cat,feline}} => "{{$0}}"', "my feline", "my cat"),
    ('{a,e,i,o,u} => ""', "pattern", "pttrn"),
    ('{@spellings} => "<b>{{$}}</b>"', "abc", "<b>abc</b>"),
    ("{a} => {b}", "banana", "banana"),
    ('"seed" => {e} => "E"', "anything", "anything"),
    ('{a,ab}{c,bc} => "{{$2}}"', "abc", "bc"),
    ('{a,b}{$1} => "{{$1}}!"', "aa ab", "a! ab"),
    ('{ba} <=>[@spellings] "ab"', "bbaa", "aabb"),
)

# The bubble sort, verbatim from L1_5.md's north-star section: the layer's
# witness, and the reason `<=>` exists.
SORT = r"""
sentinel start
sentinel end

uni c      = {@C, !{\n}}
uni line   = {@c, &@c}
uni d      = {0..9}
uni digits = {@d, &@d}
uni value  = {0..9}[numerals padfree]
uni list   = {@value, &{\,}{@value}}
uni sorted = {{@start}{@list}{@end}, &{\n}{@start}{@list}{@end}}

{@line} => "{{@start}}{{$}}{{@end}}"
{@start,\,}{@digits}{\,}{{0..9}[where 0..$2 padfree], !{{0..9}[where $2 padfree]}}{@end,\,}
  <=>[@sorted] "{{$1}}{{$4}},{{$2}}{{$5}}"
{@start,@end} => ""
"""


@pytest.mark.parametrize(("source", "expected"), PIPELINE_ROWS)
def test_pipeline_rows(source: str, expected: list[tuple[str, ...]]) -> None:
    """Each pipeline row denotes the entries L1_5.md says it does."""
    universe = parse(source).universe()
    assert [entry.faces for entry in islice(universe.entries(), len(expected))] == expected


def test_where_cuts_the_value_line_exactly() -> None:
    """``where`` is a cut of the value line, so membership is exact at the boundary."""
    universe = parse("{0..9}[where 8..12]").universe()
    assert universe.contains("8")
    assert universe.contains("12")
    assert not universe.contains("7")
    assert not universe.contains("13")


def test_where_binds_its_argument_canonically() -> None:
    """``aa`` binds as ``a``, so the width-1 numerals enter the range: 55 entries."""
    universe = parse("{a..z}[where aa..cc]").universe()
    faces = [entry.faces[0] for entry in islice(universe.entries(), 55)]
    assert faces[:3] == ["a", "b", "c"]
    assert faces[-3:] == ["ca", "cb", "cc"]
    assert universe.contains("cc")
    assert not universe.contains("cd")


@pytest.mark.parametrize(("source", "document", "expected"), EMIT_ROWS)
def test_emit_rows(source: str, document: str, expected: str) -> None:
    """Each emit row rewrites its document as L1_5.md says it does."""
    assert run(source, document) == expected


def test_a_leading_template_never_touches_the_document() -> None:
    """The chain computes over the detached string; the document is returned as given."""
    assert run('"seed" => {e} => "E"', "") == ""
    assert run('"seed" => {e} => "E"', "seed") == "seed"


def test_the_whole_document_idiom_does_not_fire_on_an_empty_document() -> None:
    """The only face on offer is the empty spelling, and zero-width never matches."""
    assert run('{@spellings} => "<b>{{$}}</b>"', "") == ""


def test_declarations_resolve_before_statements() -> None:
    """A ``uni`` declared in the script stands wherever a universe stands."""
    source = 'uni synonym = {{cat,feline}}\n{@synonym} => "{{$0}}"'
    assert run(source, "my feline") == "my cat"


def test_sentinels_carry_the_masking_idiom_end_to_end() -> None:
    """Wrap, anchor on the wrapped whole, clean up -- the north star's first move.

    Without the mask, ``{cat}`` would also hit the ``cat`` inside ``catalog``;
    the sentinels make the wrapped word an exact anchor, and the cleanup line
    is what the exit guard demands of every script that wraps.
    """
    source = (
        "sentinel start\n"
        "sentinel end\n"
        "uni c = {a..z}\n"
        "uni word = {@c, &@c}\n"
        '{@word} => "{{@start}}{{$}}{{@end}}"\n'
        '{@start}{cat}{@end} => "feline"\n'
        '{@start,@end} => ""'
    )
    assert run(source, "cat catalog") == "feline catalog"


@pytest.mark.parametrize(
    ("document", "expected"),
    [
        ("3,1,2", "1,2,3"),
        ("10,9", "9,10"),  # value order sorts, where spelling order would not
        ("12,05", "05,12"),  # each numeral re-emits at the width it arrived
        ("3,3,1", "1,3,3"),  # the strict cut never matches an equal pair, so duplicates settle
        ("5,05", "5,05"),  # equal values at different paddings are already sorted
        ("1,2,3", "1,2,3"),  # a sorted line matches nothing: zero passes
        ("2,1\n10,9,1", "1,2\n1,9,10"),  # lines tile and sort independently
    ],
)
def test_the_bubble_sort_north_star(document: str, expected: str) -> None:
    """The north-star sort runs as written.

    Every pass swaps the adjacent out-of-order pairs its tiling reaches, and
    the declared measure `@sorted` -- wrapped numeral lines over the value
    line at any padding -- strictly descends until no pair is out of order.
    """
    assert run(SORT, document) == expected
