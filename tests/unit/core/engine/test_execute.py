"""Emit: branches, the two step kinds, the splice, and the sentinel boundary."""

from __future__ import annotations

from unittest import mock

import pytest

from hejmark import HimarkBudgetError, HimarkScopeError, run
from hejmark.core.engine import budget
from hejmark.core.engine.execute import Branch


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
    assert run('{@str} => "X"', "") == ""


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


def test_a_surviving_sentinel_is_stripped_at_exit() -> None:
    """A sentinel left in the document is cleared at exit, not shipped."""
    assert run('sentinel s\n{a} => "{{@s}}"', "a") == ""


def test_a_back_reference_matches_only_its_factors_re_spelling() -> None:
    """`{a,b}{$1}` hits the echoes and nothing else; the reads see the bound split."""
    assert run('{a,b}{$1} => "{{$1}}!"', "aa ab bb") == "a! ab b!"


def test_a_range_bound_back_reference_cuts_by_the_bound_value() -> None:
    """`where 0..$1` regenerates the value line cut at the face factor 1 bound."""
    assert run('{1,2}{0..9}[where 0..$1] => "<{{$2}}>"', "21 10 12") == "<1> <0> 12"


def test_a_contracting_statement_settles_at_its_fixpoint() -> None:
    """The letter sort: passes rewrite until one leaves the document unchanged."""
    assert run('{ba} <=> "ab"', "bbaa") == "aabb"


def test_a_contracting_statement_that_never_matches_returns_the_document() -> None:
    """No pass runs, so the document stands -- emptiness stays legal."""
    assert run('{z} <=> "y"', "abc") == "abc"


def test_a_contraction_settles_when_a_pass_reproduces_the_text() -> None:
    """The fixpoint is `document unchanged`, not `query stops matching`.

    `{a} <=> "a"` matches every `a` and rewrites it to `a`, so the first pass
    leaves the document unchanged and the run settles -- it does not spin on the
    query that still matches.
    """
    assert run('{a} <=> "a"', "banana") == "banana"


def test_a_canonical_or_bare_read_on_a_detached_branch_is_a_scope_error() -> None:
    """`$` and `$0` refuse on an unanchored branch, exactly as `$k` does -- no hit to read."""
    with pytest.raises(HimarkScopeError, match="no match anchors"):
        run('"{{$}}"', "abc")
    with pytest.raises(HimarkScopeError, match="no match anchors"):
        run('"{{$0}}"', "abc")


def test_a_canonical_read_follows_the_floors_split() -> None:
    """`$0` canonicalizes the collision split, so it agrees with the factor reads.

    `{{a,abc},ab}{{C,c},bc}` spells `abc` as the greedy `(ab, c)` but the floor
    binds `(a, bc)`; `$0` reads that entry's canonical face `a`+`bc`, not `ab`+`C`.
    """
    assert run('{{a,abc},ab}{{C,c},bc} => "{{$0}}"', "abc") == "abc"


def test_a_contraction_that_never_settles_is_refused() -> None:
    """L2 bounds the one statement L1.5 cannot prove terminates.

    `{a} <=> "aa"` grows the document at every pass, so no pass ever leaves it
    unchanged and the fixpoint is never reached. Nothing on the arrow says in
    advance which contraction is which -- L1.5 declines to guess -- so the run
    is metered and refused rather than waited on.

    The budget is lowered here rather than the default spent: the size is the
    host's choice and the contract is only that one exists, so pinning the
    number would be testing the wrong thing.
    """
    with mock.patch.object(budget, "BUDGET", 2000), pytest.raises(HimarkBudgetError):
        run('{a} <=> "aa"', "a")


def test_a_contraction_that_settles_is_untouched_by_the_budget() -> None:
    """The bound must not cost the contractions that do reach a fixpoint.

    Three passes rewrite `bbaa` toward sorted and the fourth leaves it alone,
    which is well inside any budget worth having -- the north-star bubble sort
    depends on exactly this.
    """
    with mock.patch.object(budget, "BUDGET", 2000):
        assert run('{ba} <=> "ab"', "bbaa") == "aabb"
