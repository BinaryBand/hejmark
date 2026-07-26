"""adapters.library: reads the bundled standard-library source.

``core`` does no I/O, so the standard library -- ``static/std.hmk``, written in
the surface language -- is read here and handed to the compiler as text (the
``prelude`` the seam in :mod:`hejmark.core.compiler.prelude` merges). The file is
located relative to this package, not the current directory, so it is found from
anywhere the way the tests locate other ``static/`` resources.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

_STD = Path(__file__).resolve().parents[2] / "static" / "std.hmk"


@lru_cache(maxsize=1)
def standard_library() -> str:
    """The bundled standard-library source, ``static/std.hmk``, read once."""
    return _STD.read_text(encoding="utf-8")
