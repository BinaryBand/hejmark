"""Emit: branches, the two step kinds, the splice, and the sentinel boundary."""

from __future__ import annotations

import pytest

from hejmark import HimarkScopeError, HimarkSentinelError, run
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


def test_a_factor_read_takes_the_floors_split() -> None:
    """`abc` splits two ways; the read follows collision, not the greedy witness."""
    assert run('{a,ab}{c,bc} => "{{$2}}"', "abc") == "bc"


def test_factor_reads_address_written_units() -> None:
    """An exponent's repetitions stay inside their unit: two factors, not four."""
    assert run('{a}^3{b} => "{{$2}}{{$1}}"', "aaab") == "baaa"


def test_a_factor_read_past_the_factors_is_a_scope_error() -> None:
    """`$k` addresses the written factors, and a query wrote only so many."""
    with pytest.raises(HimarkScopeError, match="past the query's 2 factor"):
        run('{a}{b} => "{{$3}}"', "ab")


def test_a_factor_read_on_a_detached_branch_is_a_scope_error() -> None:
    """A leading template anchors no match, so a factor read has nothing to read."""
    with pytest.raises(HimarkScopeError, match="no match anchors"):
        run('"{{$1}}"', "abc")


def test_a_sentinel_read_renders_its_allocated_face() -> None:
    """`{{@name}}` splices the face the declaration allocated; cleanup strips it."""
    source = 'sentinel s\n{a} => "{{@s}}{{$}}"\n{@s}{a} => "A"\n{@s} => ""'
    assert run(source, "banana") == "bAnAnA"


def test_a_sentinel_read_of_no_sentinel_is_a_scope_error() -> None:
    """The read is of the environment, and an undeclared name refuses."""
    with pytest.raises(HimarkScopeError, match="reads no sentinel"):
        run('{a} => "{{@nope}}"', "a")


def test_a_document_spelling_a_noncharacter_is_refused() -> None:
    """Sentinels are engine-private, so ingest refuses what could forge one."""
    with pytest.raises(HimarkSentinelError, match="noncharacter"):
        run('{a} => "b"', "x\ufdd0y")


def test_a_surviving_sentinel_is_a_script_error() -> None:
    """A sentinel at exit is a cleanup rule that did not fire, named as such."""
    with pytest.raises(HimarkSentinelError, match="sentinel @s survived"):
        run('sentinel s\n{a} => "{{@s}}"', "a")
