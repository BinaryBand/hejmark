"""The standard-library seam: `char` seeded, the derivations optional."""

from __future__ import annotations

from hejmark import parse
from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.prelude import prelude_env

_to_ast = AntlrParser().to_ast


def test_char_is_seeded_even_with_no_library() -> None:
    """`char` is base: seeded whether or not the std is supplied, never declared."""
    assert "char" in prelude_env(_to_ast, None).unis
    assert "uni char" not in standard_library()


def test_the_library_is_off_when_no_prelude_is_given() -> None:
    """`None` is the std switched off: only `char`, none of the derivations."""
    env = prelude_env(_to_ast, None)
    assert set(env.defs) == set()
    assert set(env.unis) == {"char"}


def test_the_prelude_declares_the_derivations_l1_5_spells() -> None:
    """Given the std source, the derivations resolve into the namespace."""
    env = prelude_env(_to_ast, standard_library())
    assert set(env.defs) == {
        "fill",
        "shorter",
        "upto",
        "longer",
        "where",
        "below",
        "pad",
        "zeros",
        "zfold",
        "padfree",
    }
    assert set(env.unis) == {"hex", "str", "char"}


def test_the_prelude_is_resolved_once_per_source() -> None:
    """The std is the same for every script that shares it, so it is parsed once."""
    assert prelude_env(_to_ast, standard_library()) is prelude_env(_to_ast, standard_library())


def test_the_std_parses_as_ordinary_source() -> None:
    """Nothing in the std is special-cased; it goes through the same grammar."""
    assert len(_to_ast(standard_library()).lines) == 12


def test_hex_is_the_l2_radix() -> None:
    """`uni hex` ships in the std, denoting the sixteen digits in value order."""
    universe = parse("{@hex}").universe()
    assert [entry.faces[0] for entry in universe.entries()] == list("0123456789abcdef")


def test_below_cuts_the_value_line_less_its_top_endpoint() -> None:
    """`below lo..hi` is `where` half-open: the value cut without its top value."""
    universe = parse("{0..9}[below 8..12]").universe()
    assert universe.contains("8")
    assert universe.contains("11")
    # The top endpoint is dropped -- half-open -- and nothing above it enters.
    assert not universe.contains("12")
    assert not universe.contains("13")


def test_padfree_wears_every_zero_padding() -> None:
    """`zfold` has order type 1, so the product pads the face axis and no value moves."""
    universe = parse("{0..9}[where 3..5 padfree]").universe()
    assert universe.contains("4")
    assert universe.contains("04")
    assert universe.contains("0005")
    assert not universe.contains("06")
    assert not universe.contains("2")
    assert not universe.contains("")


def test_the_value_line_stays_denotable_without_an_open_cut() -> None:
    """Path B drops `where 0..`; the whole value line is still spelled as the closure.

    Conservativity: the open cut's set was a closure/subtraction set all along --
    the canonical-numeral closure `{0,{1..9,&{0..9}}}` -- so removing the open
    surface form loses no denotable universe, only a single-primitive spelling.
    """
    universe = parse("{0,{1..9,&{0..9}}}").universe()
    assert universe.contains("10")
    assert universe.contains("0")
    assert not universe.contains("07")
