"""Encode and decode the floor AST as portable JSON: a tagged constructor mirror."""

from __future__ import annotations

import pytest

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
from hejmark.core.ir.codec import (
    decode_member,
    decode_query,
    decode_universe,
    encode_member,
    encode_query,
    encode_universe,
)
from hejmark.core.ir.errors import HimarkPayloadError


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


def test_every_member_kind_round_trips() -> None:
    """Decode inverts encode on each of the seven tagged shapes."""
    members = (
        Face("ab"),
        Range("0", "9"),
        Final("y"),
        Fold(UniverseNode((Face("x"),))),
        Subtract(UniverseNode((Face("b"),))),
        Product((Closure(), UniverseNode((Face("b"),)))),
        Closure(),
    )
    for member in members:
        assert decode_member(encode_member(member)) == member


def test_a_query_round_trips_as_tuples() -> None:
    """Decoding rebuilds tuples, so the result hashes and compares like the source."""
    nodes = (UniverseNode((Face("a"),)), UniverseNode((Range("0", "9"),)))
    decoded = decode_query(encode_query(nodes))
    assert decoded == nodes
    assert isinstance(decoded, tuple)
    assert isinstance(decoded[0].members, tuple)


def test_a_lone_surrogate_survives_the_round_trip() -> None:
    """Code-point arrays exist so this exact case cannot corrupt."""
    face = Face("\ud800")
    assert decode_member(encode_member(face)) == face


def test_an_unknown_kind_is_refused() -> None:
    """No guessing: a tag the codec does not know is a malformed payload."""
    with pytest.raises(HimarkPayloadError, match="unknown kind"):
        decode_member({"kind": "loop"})


def test_a_missing_field_is_refused() -> None:
    """No defaulting: an absent field is a malformed payload."""
    with pytest.raises(HimarkPayloadError, match="members"):
        decode_universe({})


def test_a_code_point_past_the_planes_is_refused() -> None:
    """0x110000 is no code point, and decoding refuses it rather than guessing."""
    with pytest.raises(HimarkPayloadError, match="no code point"):
        decode_member({"kind": "face", "text": [0x110000]})


def test_a_boolean_is_not_a_code_point() -> None:
    """JSON booleans arrive as Python bools; they never spell anything."""
    with pytest.raises(HimarkPayloadError, match="no code point"):
        decode_member({"kind": "face", "text": [True]})
