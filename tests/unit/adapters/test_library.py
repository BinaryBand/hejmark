"""The adapter that reads the bundled standard-library source."""

from __future__ import annotations

from hejmark.adapters.library import standard_library


def test_reads_the_bundled_standard_library() -> None:
    """`standard_library()` returns the surface source of `static/std.hmk`."""
    source = standard_library()
    assert "def pad w..w'" in source
    assert "uni hex" in source
    # `char` is seeded by the host, never written in the std source.
    assert "uni char" not in source


def test_is_read_once() -> None:
    """The file is read once and shared -- the same source every call."""
    assert standard_library() is standard_library()
