"""find: run a .hmk query file against a target file and report matches."""

from __future__ import annotations

from pathlib import Path  # noqa: TC003 -- Typer resolves this annotation at runtime

import click
import typer

from Himark.adapters.parser import to_ast
from Himark.cli.registry import command
from Himark.core.engine import finditer


@command("find")
def find(
    query_file: Path = typer.Argument(
        ...,
        exists=True,
        dir_okay=False,
        readable=True,
        help="Path to a .hmk query file.",
    ),
    target_file: Path = typer.Argument(
        ...,
        exists=True,
        dir_okay=False,
        readable=True,
        help="Path to the text file to search.",
    ),
) -> None:
    """Run the query in QUERY_FILE against TARGET_FILE and print each match.

    Each line reports the match span, the matched substring, and both axis
    values (entry ``value`` and ``face``). A trailing line reports the count.
    """
    # Strip the query: the grammar treats whitespace as a CHAR and the engine
    # does not normalize, so a file's trailing newline would fail to parse.
    query_source = query_file.read_text(encoding="utf-8").strip()
    text = target_file.read_text(encoding="utf-8")

    count = 0
    try:
        for m in finditer(to_ast, query_source, text):
            start, end = m.span
            print(f"{start}:{end}\t{text[start:end]!r}\tvalue={m.value} face={m.face_value}")
            count += 1
    except ValueError as err:  # HimarkSyntaxError subclasses ValueError (core stays unimported).
        msg = f"invalid query: {err}"
        raise click.UsageError(msg) from err

    print(f"\n{count} match(es).")
