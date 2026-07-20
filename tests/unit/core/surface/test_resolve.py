"""Name resolution: declarations, acyclicity, pipeline binding, canonicalization."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.surface.ast import HimarkScopeError, PipeItem
from hejmark.core.surface.resolve import (
    SENTINEL_LIMIT,
    Env,
    bind,
    canonicalize,
    collect,
    merge,
    noncharacter,
    statements,
)

_to_ast = AntlrParser().to_ast


def _env(source: str) -> Env:
    """Resolve a script's declarations."""
    return collect(_to_ast(source))


def test_collect_separates_unis_from_definitions() -> None:
    """One namespace, two kinds: a ``uni`` is an expression, a ``:=`` takes parameters."""
    env = _env("uni d = {0..9}\nfill := {{{}, @0}}")
    assert set(env.unis) == {"d"}
    assert set(env.defs) == {"fill"}


def test_statements_are_not_declarations() -> None:
    """A script's statements are what it runs; declarations only furnish names."""
    node = _to_ast("uni d = {0..9}\n{@d}\n{a}")
    assert len(statements(node)) == 2


def test_lookup_reports_an_unknown_name() -> None:
    """An unknown name is a diagnostic, not an empty universe."""
    with pytest.raises(HimarkScopeError, match="unknown name"):
        _env("uni d = {a}").lookup("nope")


def test_a_name_may_not_be_declared_twice() -> None:
    """One namespace means a second declaration is a collision, not a shadow."""
    with pytest.raises(HimarkScopeError, match="duplicate name"):
        _env("uni d = {a}\nuni d = {b}")


def test_a_direct_cycle_is_refused() -> None:
    """`&` is the only self-reference and it lives on the floor."""
    with pytest.raises(HimarkScopeError, match="cyclic name"):
        _env("uni d = {@d}")


def test_an_indirect_cycle_is_refused() -> None:
    """Acyclicity is what makes every expansion finite."""
    with pytest.raises(HimarkScopeError, match="cyclic name"):
        _env("uni a = {@b}\nuni b = {@a}")


def test_a_sentinel_is_a_uni_over_one_noncharacter_face() -> None:
    """The name enters the ordinary namespace, so patterns need no extra path."""
    env = _env("sentinel start\nsentinel end")
    assert set(env.sentinels) == {"start", "end"}
    assert set(env.unis) == {"start", "end"}
    faces = list(env.sentinels.values())
    assert all(noncharacter(face) for face in faces)
    assert len(set(faces)) == len(faces)


def test_sentinel_faces_are_allocated_in_declaration_order() -> None:
    """Allocation is deterministic: the same script always masks the same way."""
    first = _env("sentinel a\nsentinel b")
    second = _env("sentinel a\nsentinel b")
    assert first.sentinels == second.sentinels
    assert ord(first.sentinels["b"]) == ord(first.sentinels["a"]) + 1


def test_the_sentinel_space_is_finite() -> None:
    """The block runs out at its limit, as a diagnostic rather than an overflow."""
    source = "\n".join(f"sentinel s{index}" for index in range(SENTINEL_LIMIT + 1))
    with pytest.raises(HimarkScopeError, match="sentinel space exhausted"):
        _env(source)


def test_a_sentinel_name_collides_like_any_other() -> None:
    """One namespace: a sentinel may not redeclare a uni, nor the reverse."""
    with pytest.raises(HimarkScopeError, match="duplicate name"):
        _env("uni d = {a}\nsentinel d")


def test_merge_layers_the_std_under_a_script() -> None:
    """A script's names sit alongside the std's, and may not redeclare one."""
    base = _env("uni seeded = {a}")
    merged = merge(base, _env("uni mine = {b}"))
    assert set(merged.unis) == {"seeded", "mine"}
    with pytest.raises(HimarkScopeError, match="duplicate name"):
        merge(base, _env("uni seeded = {b}"))


def test_bind_splits_the_flat_item_list_by_arity() -> None:
    """Stage names and arguments lex alike; only arity tells them apart."""
    env = _env("where lo..hi := {a}\npad w..w' := {b}")
    stages = bind(
        (PipeItem("where", None), PipeItem("8", "12"), PipeItem("pad"), PipeItem("1", "2")), env
    )
    assert [stage.definition.name for stage in stages] == ["where", "pad"]
    assert stages[0].arguments[0].lo == "8"
    assert stages[0].arguments[0].hi == "12"


def test_bind_reports_a_stage_that_names_no_definition() -> None:
    """A pipeline stage must name something applicable."""
    with pytest.raises(HimarkScopeError, match="names no definition"):
        bind((PipeItem("nope"),), _env("uni d = {a}"))


def test_bind_reports_missing_arguments() -> None:
    """Arity is the contract: a stage that runs out of items is malformed."""
    with pytest.raises(HimarkScopeError, match="argument"):
        bind((PipeItem("shorter"),), _env("shorter w := {a}"))


def test_canonicalize_strips_leading_zero_digits() -> None:
    """``aa`` binds as ``a`` when the head's zero entry is ``a``; the last one stays."""
    assert canonicalize("aa", "a") == "a"
    assert canonicalize("08", "0") == "8"
    assert canonicalize("12", "0") == "12"
    assert canonicalize("000", "0") == "0"
