"""Engine wiring: source in, denoted query or spliced document out."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.engine import finditer, floor_forms, match, parse, script
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.floor.universe import denote
from hejmark.core.scan.match import Query
from hejmark.core.surface.ast import HimarkScopeError
from hejmark.core.surface.late import Late

_to_ast = AntlrParser().to_ast


def test_parse_denotes_source_to_a_query() -> None:
    """The source rides along on the query, which is what diagnostics quote."""
    query = parse(_to_ast, "{a,b}")
    assert isinstance(query, Query)
    assert query.source == "{a,b}"


def test_universes_stay_most_significant_first() -> None:
    """Adjacency is the product, and the leftmost factor moves slowest."""
    query = parse(_to_ast, "{a}{b}{c}")
    assert len(query.universes) == 3
    assert query.universe().contains("a")
    assert query.universe(2).contains("c")


def test_script_resolves_declarations_over_the_std() -> None:
    """A script's own names sit alongside the seeded ones."""
    node, env = script(_to_ast, "uni mine = {a}")
    assert len(node.lines) == 1
    assert "mine" in env.unis
    assert "spellings" in env.unis


def test_parse_refuses_anything_but_a_single_query() -> None:
    """The query-level API takes a query; a whole script goes through ``run``."""
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, '{a} => "x"')
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, "uni d = {a}")
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, '{a} <=>[@spellings] "x"')


def test_match_and_finditer_accept_source_or_a_denoted_query() -> None:
    """Denoting once and scanning many times is the same as scanning source."""
    query = parse(_to_ast, "{a}")
    assert match(_to_ast, query, "banana") == match(_to_ast, "{a}", "banana")
    assert len(list(finditer(_to_ast, query, "banana"))) == 3


def test_match_honours_the_start_offset() -> None:
    """Scanning resumes where the caller says, not always at zero."""
    found = match(_to_ast, "{a}", "banana", 2)
    assert found is not None
    assert found.span[0] == 3


def test_a_back_referencing_unit_enters_the_query_late() -> None:
    """A unit reading a factor to its left cannot denote yet; it rides as `Late`."""
    query = parse(_to_ast, "{a,b}{$1}")
    assert isinstance(query.universes[1], Late)
    assert query.universe(0).contains("a")


def test_a_read_not_strictly_left_is_refused() -> None:
    """A read of the reading factor, one to its right, or past the query, binds nothing."""
    for source in ("{$1}", "{a}{$2}", "{a}{$3}"):
        with pytest.raises(HimarkScopeError, match="stand to its left"):
            parse(_to_ast, source)


def test_floor_forms_expands_each_factor_to_its_pre_denotation_ast() -> None:
    """The lowered form denotes to the same universes ``parse`` would build."""
    forms = floor_forms(_to_ast, "{a,b}{c}")
    assert len(forms) == 2
    assert all(isinstance(form, UniverseNode) for form in forms)
    # {a,b} carries both faces, in order.
    assert forms[0].members == (Face("a"), Face("b"))
    assert denote(forms[1]).contains("c")


def test_floor_forms_refuses_a_back_referencing_factor() -> None:
    """A ``Late`` factor denotes only under a binding, so it cannot be lowered."""
    with pytest.raises(HimarkScopeError, match="back-referencing"):
        floor_forms(_to_ast, "{a,b}{$1}")


def test_floor_forms_refuses_anything_but_a_single_query() -> None:
    with pytest.raises(HimarkScopeError, match="single query expression"):
        floor_forms(_to_ast, "uni d = {a}")
