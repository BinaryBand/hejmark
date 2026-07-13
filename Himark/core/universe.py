"""Universe algebra: denote a faithful AST to flat universes of entries.

Denotation applies the three constructors (union, subtraction, fold) plus the
range compression in a single left-to-right pass, maintaining the claim-set
invariant that ``claimed`` holds exactly the faces of the live entries. Values
are assigned by final index, so subtraction renumbers automatically.
"""

from __future__ import annotations

from dataclasses import dataclass

from Himark.core.syntax import Face, Fold, Range, Subtract, UniverseNode


@dataclass(frozen=True)
class Entry:
    """One member of a universe: its faces (ordered, unique) and its value."""

    faces: tuple[str, ...]
    value: int


@dataclass(frozen=True)
class Universe:
    """A denoted universe: a flat, ordered tuple of entries."""

    entries: tuple[Entry, ...]


@dataclass(frozen=True)
class Query:
    """A denoted query: its source plus its universes, most-significant-first."""

    source: str
    universes: tuple[Universe, ...]


def _fold_faces(universe: UniverseNode) -> list[str]:
    """Return the faces of a nested universe in entry order (its own scope)."""
    faces: list[str] = []
    for entry in denote(universe).entries:
        faces.extend(entry.faces)
    return faces


def _add_face(text: str, entries: list[list[str]], claimed: set[str]) -> None:
    """Union a single spelling: claim it as a new entry, or no-op if taken."""
    if text not in claimed:
        entries.append([text])
        claimed.add(text)


def _add_fold(node: Fold, entries: list[list[str]], claimed: set[str]) -> None:
    """Fold a nested universe into one entry, dropping already-claimed faces."""
    kept: list[str] = []
    for face in _fold_faces(node.universe):
        if face not in claimed:
            kept.append(face)
            claimed.add(face)
    if kept:
        entries.append(kept)


def _subtract(node: Subtract, entries: list[list[str]], claimed: set[str]) -> None:
    """Remove every live entry sharing a face with the subtracted universe."""
    doomed = set(_fold_faces(node.universe))
    entries[:] = [faces for faces in entries if doomed.isdisjoint(faces)]
    claimed.clear()
    claimed.update(face for faces in entries for face in faces)


def denote(node: UniverseNode) -> Universe:
    """Normalize a universe AST node to a flat, valued :class:`Universe`."""
    entries: list[list[str]] = []
    claimed: set[str] = set()
    for member in node.members:
        if isinstance(member, Face):
            _add_face(member.text, entries, claimed)
        elif isinstance(member, Range):
            for code_point in range(ord(member.lo), ord(member.hi) + 1):
                _add_face(chr(code_point), entries, claimed)
        elif isinstance(member, Fold):
            _add_fold(member, entries, claimed)
        else:
            _subtract(member, entries, claimed)
    return Universe(tuple(Entry(tuple(faces), i) for i, faces in enumerate(entries)))
