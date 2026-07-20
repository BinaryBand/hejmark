"""Emit: branches, the two step kinds, and the splice."""

from __future__ import annotations

from hejmark import run
from hejmark.core.emit import Branch


def test_a_branch_reads_its_span_as_the_bound_face() -> None:
    """The span and the floor's face are one datum seen twice."""
    assert Branch("my feline", 3, 9).face == "feline"


def test_a_query_step_tiles_its_branch() -> None:
    """One sub-branch per match, and the text between is kept."""
    assert run('{a,e,i,o,u} => "-"', "pattern") == "p-tt-rn"


def test_a_query_that_matches_nothing_stops_the_branch() -> None:
    """The guard reading: a mid-chain query with no match leaves its branch alone."""
    assert run('{z} => "!"', "banana") == "banana"


def test_a_template_commits_over_its_branch_span() -> None:
    """A template constructs, and the string lands over the span that anchored it."""
    assert run('{a} => "X"', "banana") == "bXnXnX"


def test_an_interpolation_continues_as_a_sub_branch() -> None:
    """Decoration lands but never flows: the chain continues inside the site only."""
    assert run('{b} => "[{{$}}]" => "Z"', "abc") == "a[Z]c"


def test_a_template_with_no_site_ends_its_branch() -> None:
    """Nothing is left pointing anywhere, so a following step cannot fire."""
    assert run('{a} => "-" => "X"', "banana") == "b-n-n-"


def test_a_leading_template_is_detached() -> None:
    """No incoming branch means the string is computed off the document."""
    assert run('"seed" => {e} => "E"', "banana") == "banana"


def test_statements_run_in_source_order() -> None:
    """Each statement threads the document through to the next."""
    assert run('{a} => "x"\n{b} => "y"', "ab") == "xy"


def test_the_empty_document_offers_only_the_empty_spelling() -> None:
    """Zero-width never matches, so nothing fires and nothing changes."""
    assert run('{@spellings} => "X"', "") == ""
