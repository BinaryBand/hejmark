"""The product split search: tilings, and the reach bounds that narrow them.

The oracle is threaded in, so these drive the search over a toy membership
function and never denote anything. Two properties matter: the tilings found are
exactly the tilings that exist (reach must not lose one), and the cuts the
oracle is *asked* about shrink (reach must actually do something).
"""

from __future__ import annotations

from hejmark.core.engine.denote.split import splits
from hejmark.core.floor.syntax import Closure, Face, Range, UniverseNode


def _lit(*faces: str) -> UniverseNode:
    """A universe wearing exactly the given faces."""
    return UniverseNode(tuple(Face(face) for face in faces))


def _holds(factor: UniverseNode | Closure, piece: str) -> bool:
    """A toy oracle: a universe wears a face it declares, a range any one character."""
    if isinstance(factor, Closure):
        return True
    return any(
        (isinstance(m, Face) and m.text == piece)
        or (isinstance(m, Range) and len(piece) == 1 and m.lo <= piece <= m.hi)
        for m in factor.members
    )


def test_a_single_factor_tiles_only_the_whole_spelling() -> None:
    """One factor, one piece: the spelling either is a face or it is not."""
    assert splits((_lit("cat"),), "cat", _holds)
    assert not splits((_lit("cat"),), "cats", _holds)


def test_two_factors_tile_by_concatenation() -> None:
    """The product spells the concatenations, so the search is for a cut."""
    factors = (_lit("a", "ab"), _lit("c", "bc"))
    assert splits(factors, "abc", _holds)
    assert splits(factors, "ac", _holds)
    assert not splits(factors, "abd", _holds)


def test_a_factor_may_take_the_empty_piece() -> None:
    """A universe that folds to the unit wears ``""``, so a cut may advance nothing.

    The one place this differs from the matcher, which accepts no zero-width
    part -- and the reason the lower bound here is the cut position rather than
    one past it.
    """
    assert splits((_lit(""), _lit("a")), "a", _holds)


def test_no_factors_tile_only_the_empty_spelling() -> None:
    """The empty product spells the empty spelling and nothing else."""
    assert splits((), "", _holds)
    assert not splits((), "a", _holds)


def test_reach_narrows_the_cuts_without_losing_a_tiling() -> None:
    """The bound is spent on the *asking*, so the answer is unchanged and cheaper.

    A one-character head beside a one-character tail can only cut in the middle
    of a two-character spelling; without reach the search would offer the head
    the empty piece and the whole spelling as well. Recording what the oracle is
    asked is what makes the saving visible rather than merely claimed.
    """
    asked: list[str] = []

    def watching(factor: UniverseNode | Closure, piece: str) -> bool:
        asked.append(piece)
        return _holds(factor, piece)

    factors = (UniverseNode((Range("a", "z"),)), UniverseNode((Range("0", "9"),)))
    assert splits(factors, "a1", watching)
    assert asked == ["a", "1"]


def test_an_unbounded_factor_still_offers_every_cut() -> None:
    """`&` reaches nowhere, so the text is the only bound -- the honest fallback."""
    assert splits((Closure(), _lit("z")), "anythingz", _holds)
    assert not splits((Closure(), _lit("z")), "anythingy", _holds)


def test_a_bounded_tail_pins_an_unbounded_head() -> None:
    """The idiom `{@x,&@x}{\\!}`: one probe, because the tail spells one character.

    Reach cannot bound the head at all, but it bounds what follows -- and a cut
    leaving the tail more than one character can never be completed. That is the
    bound read from the far end, and it is the case the rewrite exists for.
    """
    asked: list[str] = []

    def watching(factor: UniverseNode | Closure, piece: str) -> bool:
        asked.append(piece)
        return _holds(factor, piece)

    assert splits((Closure(), _lit("!")), "hello!", watching)
    assert asked == ["hello", "!"]
