#!/usr/bin/env python3
"""Reformat GFM markdown tables in place.

Cells get minimal single-space padding rather than being aligned to their
column's widest cell, and each delimiter cell collapses to its minimal
width (e.g. `---`, `:--`, `--:`, `:-:`) while keeping any alignment colons.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

CELL_SPLIT = re.compile(r"(?<!\\)\|")
DELIMITER_CELL = re.compile(r"^:?-+:?$")


def split_row(line: str) -> list[str]:
    """Split a `| a | b |` table row into its stripped cell strings."""
    body = line.strip().removeprefix("|").removesuffix("|")
    return [cell.strip() for cell in CELL_SPLIT.split(body)]


def is_delimiter_row(line: str) -> bool:
    """Return whether `line` is a table's `| --- | :-: |`-style divider."""
    cells = split_row(line)
    return bool(cells) and all(DELIMITER_CELL.match(cell) for cell in cells)


def minimal_delimiter(cell: str) -> str:
    """Collapse a divider cell to its minimal-width equivalent."""
    left, right = cell.startswith(":"), cell.endswith(":")
    if left and right:
        return ":-:"
    if left:
        return ":--"
    if right:
        return "--:"
    return "---"


def format_table(lines: list[str]) -> list[str]:
    """Reformat one table's header/divider/body lines.

    Cells get minimal single-space padding, not padded to their column's
    widest cell -- an outlier long cell in one row would otherwise force
    every other row in that column to carry its width as trailing spaces.
    """
    rows = [split_row(line) for line in lines]
    delimiter = rows[1]

    out = []
    for row_index, row in enumerate(rows):
        cells = [minimal_delimiter(c) for c in delimiter] if row_index == 1 else row
        out.append("| " + " | ".join(cells) + " |")
    return out


def format_text(text: str) -> str:
    """Reformat every GFM table found in `text`, leaving everything else untouched."""
    lines = text.split("\n")
    out: list[str] = []
    in_fence = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r"^\s*(```|~~~)", line):
            in_fence = not in_fence
            out.append(line)
            i += 1
            continue
        if not in_fence and "|" in line and i + 1 < len(lines) and is_delimiter_row(lines[i + 1]):
            block = [line, lines[i + 1]]
            j = i + 2
            while j < len(lines) and "|" in lines[j] and lines[j].strip():
                block.append(lines[j])
                j += 1
            out.extend(format_table(block))
            i = j
            continue
        out.append(line)
        i += 1
    return "\n".join(out)


def main(argv: list[str]) -> int:
    """Reformat the markdown files named in `argv` in place."""
    for path in argv:
        file = Path(path)
        original = file.read_text(encoding="utf-8")
        updated = format_text(original)
        if updated != original:
            file.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
