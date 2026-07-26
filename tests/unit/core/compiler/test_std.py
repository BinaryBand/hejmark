"""The seeded std: written in-language, resolved like any other declarations."""

from __future__ import annotations

from hejmark import parse
from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.std import SOURCE, std_env

_to_ast = AntlrParser().to_ast


def test_the_std_declares_the_derivations_l1_5_spells() -> None:
    """The finish line is the std being writable over the surface, exactly as spec'd."""
    env = std_env(_to_ast)
    assert set(env.defs) == {
        "fill",
        "shorter",
        "upto",
        "longer",
        "where",
        "pad",
        "zeros",
        "zfold",
        "padfree",
    }
    assert set(env.unis) == {"hex", "str", "char"}


def test_hex_is_the_l2_radix() -> None:
    """`uni hex` ships in the std, denoting the sixteen digits in value order."""
    universe = parse("{@hex}").universe()
    assert [entry.faces[0] for entry in universe.entries()] == list("0123456789abcdef")


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


def test_padfree_wears_every_zero_padding() -> None:
    """`zfold` has order type 1, so the product pads the face axis and no value moves."""
    universe = parse("{0..9}[where 3..5 padfree]").universe()
    assert universe.contains("4")
    assert universe.contains("04")
    assert universe.contains("0005")
    assert not universe.contains("06")
    assert not universe.contains("2")
    assert not universe.contains("")


def test_the_alphabet_is_seeded_not_written() -> None:
    """`char` is the one `uni` the spec seeds: the surface spells no code point."""
    assert "uni char" not in SOURCE
    assert "char" in std_env(_to_ast).unis


def test_the_alphabet_excludes_the_sentinel_space() -> None:
    """`char` subtracts the noncharacters, so no `@char`-derived universe holds one."""
    universe = parse("{@char}").universe()
    assert universe.contains("a")
    assert universe.contains("\ufdcf")
    assert not universe.contains("\ufdd0")
    assert not universe.contains("\uffff")
    assert not universe.contains("\U0010fffe")


def test_the_std_parses_as_ordinary_source() -> None:
    """Nothing in the std is special-cased; it goes through the same grammar."""
    assert len(_to_ast(SOURCE).lines) == 11


def test_the_std_is_resolved_once() -> None:
    """The std is the same for every script, so it is parsed once and shared."""
    assert std_env(_to_ast) is std_env(_to_ast)
