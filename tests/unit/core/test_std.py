"""The seeded std: written in-language, resolved like any other declarations."""

from __future__ import annotations

from hejmark import parse
from hejmark.adapters.parser import AntlrParser
from hejmark.core.std import SOURCE, std_env

_to_ast = AntlrParser().to_ast


def test_the_std_declares_the_derivations_l1_5_spells() -> None:
    """The finish line is the std being writable over the surface, exactly as spec'd."""
    env = std_env(_to_ast)
    assert set(env.defs) == {
        "fill",
        "nonzero",
        "numerals",
        "shorter",
        "upto",
        "longer",
        "where",
        "pad",
    }
    assert set(env.unis) == {"hex", "spellings", "C"}


def test_hex_is_the_l2_radix() -> None:
    """`uni hex` ships in the std, denoting the sixteen digits in value order."""
    universe = parse("{@hex}").universes[0]
    assert [entry.faces[0] for entry in universe.entries()] == list("0123456789abcdef")


def test_the_code_point_set_is_seeded_not_written() -> None:
    """`C` is the one `uni` the spec seeds: the surface spells no code point."""
    assert "uni C" not in SOURCE
    assert "C" in std_env(_to_ast).unis


def test_the_std_parses_as_ordinary_source() -> None:
    """Nothing in the std is special-cased; it goes through the same grammar."""
    assert len(_to_ast(SOURCE).lines) == 10


def test_the_std_is_resolved_once() -> None:
    """The std is the same for every script, so it is parsed once and shared."""
    assert std_env(_to_ast) is std_env(_to_ast)
