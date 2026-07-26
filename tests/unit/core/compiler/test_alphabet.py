"""The seeded alphabet `char`: the code space minus the noncharacters."""

from __future__ import annotations

from hejmark import parse
from hejmark.core.compiler.alphabet import char
from hejmark.core.compiler.ast import Expr


def test_char_is_an_expression() -> None:
    """`char` is host-supplied surface data -- one `uni`-shaped expression."""
    assert isinstance(char(), Expr)


def test_char_excludes_the_sentinel_space() -> None:
    """`char` subtracts the noncharacters, so no `@char`-derived universe holds one."""
    universe = parse("{@char}").universe()
    assert universe.contains("a")
    assert universe.contains("\ufdcf")
    assert not universe.contains("\ufdd0")
    assert not universe.contains("\uffff")
    assert not universe.contains("\U0010fffe")
