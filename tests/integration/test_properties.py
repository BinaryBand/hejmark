"""Hypothesis property-based tests for the hejmark engine.

Properties verified:
1. Union idempotence: a face list concatenated with itself denotes the same
   entries as the list alone.
2. Product tiling: a text built by concatenating one surviving face per
   universe matches at position 0.
3. Range cardinality: :math:`\\max(0, \\mathrm{ord}(hi) - \\mathrm{ord}(lo) + 1)`.
4. The settlement theorem as an oracle: membership in a guarded closure agrees
   with its stage-:math:`(L + 1)` truncation, presence and absence alike.
"""

from __future__ import annotations

from hypothesis import assume, given, settings
from hypothesis.strategies import integers, lists, text

from hejmark import match as match_source
from hejmark import parse
from hejmark.core.engine.denote.universe import Universe

# Buildable face characters: alphanumerics are unambiguous and free of reserved
# chars ('{,}',!.\\&). We exclude them so the constructed source round-trips
# without needing escape machinery.
_FACE = text(
    alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    min_size=1,
    max_size=6,
)


def _faces_of(source: str) -> list[tuple[str, ...]]:
    """Denote *source* and materialize its (finite) entries as face tuples."""
    return [entry.faces for entry in parse(source).universe().entries()]


@given(faces=lists(_FACE, min_size=0, max_size=10))
def test_union_idempotence(faces: list[str]) -> None:
    """Denoting a face list concatenated with itself yields the same entries."""
    once = _faces_of("{" + ",".join(faces) + "}")
    twice = _faces_of("{" + ",".join(faces + faces) + "}")
    assert once == twice


@given(faces_per_universe=lists(lists(_FACE, min_size=1, max_size=4), min_size=1, max_size=3))
def test_product_tiling_matches_at_zero(faces_per_universe: list[list[str]]) -> None:
    """Concatenating one face per universe builds a text the product matches at 0.

    The matched span need not be the whole text (a canonical parse may tile it
    differently), but a match must exist and must start at position 0.
    """
    source = "".join("{" + ",".join(faces) + "}" for faces in faces_per_universe)
    built = "".join(faces[0] for faces in faces_per_universe)

    found = match_source(source, built)
    assert found is not None
    assert found.span[0] == 0


@given(lo=integers(min_value=0x21, max_value=0x7A), hi=integers(min_value=0x21, max_value=0x7A))
def test_range_cardinality(lo: int, hi: int) -> None:
    """A range ``{lo..hi}`` has ``max(0, ord(hi) - ord(lo) + 1)`` entries."""
    # BRACES mode carves the structural set out of the face alphabet; each of
    # these is spellable only with a `\` escape, so a raw one is not a face.
    reserved = set('{}()[],!.\\&@_^$" \t\r\n')
    assume(chr(lo) not in reserved)
    assume(chr(hi) not in reserved)

    source = "{" + chr(lo) + ".." + chr(hi) + "}"
    assert len(_faces_of(source)) == max(0, hi - lo + 1)


@settings(deadline=None)  # a cold memo makes the first deep unfolding slow, later runs instant
@given(seed=_FACE, step=_FACE, depth=integers(min_value=0, max_value=4))
def test_settlement_theorem_is_the_membership_oracle(seed: str, step: str, depth: int) -> None:
    """For the guarded closure ``{seed,&{step}}``, full membership equals the
    stage-``len + 1`` truncation -- the fixpoint theorem, executable."""
    universe = parse("{" + seed + ",&{" + step + "}}").universe()
    inside = seed + step * depth
    outside = inside + "#"

    truncated = Universe(universe.node, universe.amp, len(inside) + 1)
    assert universe.contains(inside)
    assert truncated.contains(inside)
    assert universe.contains(outside) == Universe(
        universe.node, universe.amp, len(outside) + 1
    ).contains(outside)
