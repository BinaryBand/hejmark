"""The shortlex-window view of a member, and symbolic carving."""

from __future__ import annotations

from itertools import islice

from hejmark.core.floor.order import Window
from hejmark.core.floor.syntax import Face, Final, Fold, Range, UniverseNode
from hejmark.core.floor.window import carve, window_of


def _node(*members):
    return UniverseNode(tuple(members))


def test_a_range_becomes_a_half_open_window_over_its_inclusive_endpoint():
    window = window_of(Range("a", "c"))
    assert [window.contains(s) for s in "abcd"] == [True, True, True, False]


def test_a_final_segment_becomes_an_unbounded_window():
    window = window_of(Final("y"))
    assert window.hi is None
    assert window.contains("y")
    assert window.contains("zzzz")
    assert not window.contains("x")


def test_windows_of_reads_a_face_as_a_single_point_window():
    windows = carve(Window("a", None), (_node(Face("b")),))
    spellings = [s for w in windows for s in islice(w, 4)]
    assert "b" not in spellings
    assert spellings[:3] == ["a", "c", "d"]


def test_carving_splits_a_run_in_two_and_drops_the_empty_piece():
    assert carve(Window("a", "f"), (_node(Range("c", "d")),)) == [
        Window("a", "c"),
        Window("e", "f"),
    ]
    assert carve(Window("a", "d"), (_node(Range("a", "z")),)) == []


def test_carving_an_infinite_tail_leaves_a_finite_prefix():
    # The point of carving symbolically: {a..}![c..] terminates.
    assert carve(Window("a", None), (_node(Final("c")),)) == [Window("a", "c")]


def test_a_non_window_shaped_operand_carves_nothing_and_is_left_to_the_caller():
    # A fold is not plainly window-shaped, so nothing is cut here; the stream
    # level re-checks it face by face, which is why this is safe rather than wrong.
    window = Window("a", "f")
    assert carve(window, (_node(Fold(_node(Face("c")))),)) == [window]


def test_strips_compose_left_to_right():
    assert carve(Window("a", "h"), (_node(Range("b", "b")), _node(Range("e", "f")))) == [
        Window("a", "b"),
        Window("c", "e"),
        Window("g", "h"),
    ]
