"""Encode the floor AST to portable JSON: a tagged mirror of the constructors."""

from __future__ import annotations

from hejmark.core.floor.json import encode_member, encode_query, encode_universe
from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Final,
    Fold,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def test_a_face_encodes_as_code_points() -> None:
    assert encode_member(Face("ab")) == {"kind": "face", "text": [97, 98]}


def test_a_range_encodes_its_endpoints_as_code_points() -> None:
    assert encode_member(Range("0", "9")) == {"kind": "range", "lo": 48, "hi": 57}


def test_a_final_segment_encodes_its_start_as_code_points() -> None:
    assert encode_member(Final("y")) == {"kind": "final", "lo": [121]}


def test_a_fold_nests_its_universe() -> None:
    inner = {"members": [{"kind": "face", "text": [120]}]}
    assert encode_member(Fold(UniverseNode((Face("x"),)))) == {"kind": "fold", "universe": inner}


def test_a_subtraction_nests_its_universe() -> None:
    inner = {"members": [{"kind": "face", "text": [98]}]}
    assert encode_member(Subtract(UniverseNode((Face("b"),)))) == {
        "kind": "subtract",
        "universe": inner,
    }


def test_a_product_encodes_its_factors_including_the_closure_token() -> None:
    product = Product((Closure(), UniverseNode((Face("b"),))))
    assert encode_member(product) == {
        "kind": "product",
        "factors": [
            {"kind": "closure"},
            {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [98]}]}},
        ],
    }


def test_a_bare_closure_encodes_as_a_kind_alone() -> None:
    assert encode_member(Closure()) == {"kind": "closure"}


def test_a_universe_lists_its_members_in_order() -> None:
    node = UniverseNode((Face("a"), Face("b")))
    assert encode_universe(node) == {
        "members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}],
    }


def test_a_query_wraps_one_universe_per_factor() -> None:
    left = UniverseNode((Face("a"),))
    right = UniverseNode((Face("b"),))
    assert encode_query((left, right)) == {
        "universes": [
            {"members": [{"kind": "face", "text": [97]}]},
            {"members": [{"kind": "face", "text": [98]}]},
        ],
    }
