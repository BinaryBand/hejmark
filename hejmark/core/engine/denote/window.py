"""The shortlex-window view of a member, and symbolic carving.

A range is an interval in shortlex order, so it has a ``Window`` -- and a run of
them can have subtractions cut out of it *without* enumerating either side, so
``{a..z}![b..d]`` carves symbolically rather than filtering face by face.

The carving is deliberately partial. ``carve`` only cuts operands that are
plainly window-shaped; anything else is left alone here and re-checked face by
face by the caller, so a missed carve costs a wider enumeration but never
correctness.

Leaf module: reads :mod:`hejmark.core.engine.denote.order` and the AST, and
nothing above it. No universe is denoted to answer these questions.
"""

from __future__ import annotations

from hejmark.core.engine.denote.order import Window, successor
from hejmark.core.floor.syntax import Face, Range, UniverseNode


def window_of(member: Range) -> Window:
    """The shortlex window a range denotes."""
    return Window(member.lo, successor(member.hi))


def carve(window: Window, strips: tuple[UniverseNode, ...]) -> list[Window]:
    """Cut the window-shaped strips out of a run's window, symbolically.

    Operands that are not plainly window-shaped carve nothing here; they are
    still applied face by face downstream.
    """
    pieces = [window]
    for operand in strips:
        for cut in windows_of(operand) or []:
            pieces = [part for piece in pieces for part in piece.minus(cut)]
    return pieces


def windows_of(node: UniverseNode) -> list[Window] | None:
    """The node's face set as windows when every member is one, else ``None``."""
    windows: list[Window] = []
    for member in node.members:
        if isinstance(member, Face):
            windows.append(Window(member.text, successor(member.text)))
        elif isinstance(member, Range):
            windows.append(window_of(member))
        else:
            return None
    return windows
