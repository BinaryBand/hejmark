"""Hypothesis property-based tests for the Himark engine.

Properties verified:
1. Union idempotence: a face list concatenated with itself denotes the same
   universe as the list alone.
2. Product index bounds: :math:`0 \\le \\mathrm{value} < \\prod_i b_i` for a
   text built by concatenating one chosen face per universe.
3. Range cardinality: :math:`\\max(0, \\mathrm{ord}(hi) - \\mathrm{ord}(lo) + 1)`.
"""

from __future__ import annotations

from hypothesis import assume, given
from hypothesis.strategies import integers, lists, text

from Himark import match, parse

# Buildable face characters: alphanumerics are unambiguous and free of reserved
# chars ('{,}',!.\\). We exclude them so the constructed source round-trips
# without needing escape machinery.
_FACE = text(
    alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    min_size=1,
    max_size=6,
)


@given(faces=lists(_FACE, min_size=0, max_size=10))
def test_union_idempotence(faces: list[str]) -> None:
    """Denoting a face list concatenated with itself yields the same universe."""
    source_one = "{" + ",".join(faces) + "}"
    source_double = "{" + ",".join(faces + faces) + "}"
    left = parse(source_one).universes
    right = parse(source_double).universes
    assert left == right


# ---------------------------------------------------------------------------
# Product index bounds
# ---------------------------------------------------------------------------


@given(faces_per_universe=lists(lists(_FACE, min_size=1, max_size=5), min_size=1, max_size=4))
def test_product_index_bounds(faces_per_universe: list[list[str]]) -> None:
    """Building a text by concatenating one chosen face per universe places the
    match value in :math:`[0, \\prod_i b_i)`.

    We do NOT assert the value equals the chosen-entry product index because
    non-uniquely-decodable face sets may canonically parse differently, which is
    correct.
    """
    # Build source: one universe per group, join as product (adjacent braces).
    universe_sources = ["{" + ",".join(faces) + "}" for faces in faces_per_universe]
    source = "".join(universe_sources)

    query = parse(source)
    product = 1
    for u in query.universes:
        product *= len(u.entries)

    if product == 0:
        # Empty universe anywhere -> nothing to match.
        return

    # Build a text by picking one face from each universe.
    chosen_faces: list[str] = []
    for faces, universe in zip(faces_per_universe, query.universes, strict=True):
        # Pick the first generated face that actually survives in the denoted universe.
        found = False
        for face in faces:
            if any(face in entry.faces for entry in universe.entries):
                chosen_faces.append(face)
                found = True
                break
        if not found:
            # None of the generated faces survived denotation (e.g. all duplicates).
            # Fall back to any face from the first entry (materialized faces are spellings).
            fallback = universe.entries[0].faces[0]
            chosen_faces.append(fallback if isinstance(fallback, str) else next(iter(fallback)))

    text = "".join(chosen_faces)

    result = match(source, text)
    assert result is not None
    assert 0 <= result.value < product


# ---------------------------------------------------------------------------
# Range cardinality
# ---------------------------------------------------------------------------


@given(lo=integers(min_value=0x21, max_value=0x7A), hi=integers(min_value=0x21, max_value=0x7A))
def test_range_cardinality(lo: int, hi: int) -> None:
    """A range ``{lo..hi}`` has ``max(0, ord(hi) - ord(lo) + 1)`` entries."""
    # Convert to characters; skip chars that are reserved in the grammar.
    reserved = set("\\{},!.")
    assume(chr(lo) not in reserved)
    assume(chr(hi) not in reserved)

    source = "{" + chr(lo) + ".." + chr(hi) + "}"
    result = parse(source)
    expected = max(0, hi - lo + 1)
    assert len(result.universes[0].entries) == expected


@given(lo=integers(min_value=0x7B, max_value=0x7E), hi=integers(min_value=0x7B, max_value=0x7E))
def test_range_cardinality_high_ascii(lo: int, hi: int) -> None:
    """Range cardinality for code points above the reserved set."""
    reserved = set("\\{},!.")
    assume(chr(lo) not in reserved)
    assume(chr(hi) not in reserved)

    source = "{" + chr(lo) + ".." + chr(hi) + "}"
    result = parse(source)
    expected = max(0, hi - lo + 1)
    assert len(result.universes[0].entries) == expected
