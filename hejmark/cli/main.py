"""cli.main: the command-line interface.

Keep it thin -- parse arguments, wire adapters into core use-cases, format results. Typer is the
standard framework: declare commands with @app.command() and describe any
arguments/options with typing.Annotated so `ty` sees real signatures.

The commands: `find` (scan a target file with a query) and `run` (execute a
whole script against a target file) are the language; `emit-json` and
`emit-program` are the same two, stopped at the compiler so another engine can
finish them; `gen-parser` (rebuild the ANTLR parser from the grammars),
`parse-file` (dump a parse tree) and `status` (version echo) are the tooling
around it.
"""

from __future__ import annotations

from importlib.metadata import version
from pathlib import Path
from typing import Annotated

import click
import typer

import hejmark
from hejmark.adapters.antlr import AntlrGenerationError, AntlrGenerator, AntlrToolNotFoundError
from hejmark.adapters.parser import AntlrParser, GeneratedParserMissingError

app = typer.Typer(add_completion=False, no_args_is_help=True)

DEFAULT_GRAMMARS = (
    Path("static/grammar/HimarkLexer.g4"),
    Path("static/grammar/HimarkParser.g4"),
)
DEFAULT_OUTPUT_DIR = Path("hejmark/adapters/_gen")


@app.command()
def status() -> None:
    """Print the installed package name and version -- minimal runnable seed."""
    typer.echo(f"hejmark {version('hejmark')}")


SOURCE_ARG = typer.Argument(exists=True, dir_okay=False, readable=True)


@app.command()
def find(
    query_file: Annotated[Path, SOURCE_ARG],
    target_file: Annotated[Path, SOURCE_ARG],
) -> None:
    """Scan a target file with a query, printing one line per match."""
    source = query_file.read_text().strip()
    text = target_file.read_text()
    try:
        found = list(hejmark.finditer(source, text))
    except ValueError as exc:
        msg = f"invalid query: {exc}"
        raise click.UsageError(msg) from exc
    for one in found:
        start, end = one.span
        typer.echo(f"{start}:{end}\t{text[start:end]!r}")
    typer.echo()
    typer.echo(f"{len(found)} match(es).")


@app.command()
def run(
    script_file: Annotated[Path, SOURCE_ARG],
    target_file: Annotated[Path, SOURCE_ARG],
) -> None:
    """Run a whole script against a target file, printing the spliced document."""
    try:
        result = hejmark.run(script_file.read_text(), target_file.read_text())
    except ValueError as exc:
        msg = f"invalid script: {exc}"
        raise click.UsageError(msg) from exc
    typer.echo(result, nl=False)


@app.command("gen-parser")
def gen_parser(
    grammar: Annotated[
        list[Path] | None,
        typer.Option(help="Path to a .g4 grammar file; repeat for a lexer/parser pair."),
    ] = None,
    output_dir: Annotated[
        Path, typer.Option(help="Directory to write generated parser sources into.")
    ] = DEFAULT_OUTPUT_DIR,
    language: Annotated[str, typer.Option(help="Target language for antlr4 -Dlanguage=.")] = (
        "Python3"
    ),
) -> None:
    """Regenerate the parser from the ANTLR grammars via the external antlr4 tool."""
    grammars = list(DEFAULT_GRAMMARS) if grammar is None else grammar
    try:
        AntlrGenerator().generate(grammars, output_dir, language=language)
    except (AntlrToolNotFoundError, AntlrGenerationError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    names = ", ".join(str(path) for path in grammars)
    typer.echo(f"Generated {language} parser for {names} into {output_dir}")


@app.command("emit-json")
def emit_json(
    query_file: Annotated[Path, SOURCE_ARG],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the floor JSON here instead of the console."),
    ] = None,
) -> None:
    """Emit a query's expanded floor AST as JSON, the portable hand-off to the Rust port."""
    source = query_file.read_text().strip()
    try:
        payload = hejmark.emit_json(source)
    except ValueError as exc:
        msg = f"invalid query: {exc}"
        raise click.UsageError(msg) from exc
    if out is None:
        typer.echo(payload)
    else:
        out.write_text(payload)
        typer.echo(f"{query_file}: OK, floor JSON written to {out}")


@app.command("emit-program")
def emit_program(
    script_file: Annotated[Path, SOURCE_ARG],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the program JSON here instead of the console."),
    ] = None,
) -> None:
    """Emit a whole script as the versioned Program JSON, the hand-off for a remote run."""
    try:
        payload = hejmark.emit_program(script_file.read_text())
    except ValueError as exc:
        msg = f"invalid script: {exc}"
        raise click.UsageError(msg) from exc
    if out is None:
        typer.echo(payload)
    else:
        out.write_text(payload)
        typer.echo(f"{script_file}: OK, program JSON written to {out}")


@app.command("parse-file")
def parse_file(
    path: Annotated[Path, typer.Argument(help="Path to a .hmk source file to parse.")],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the parse tree here instead of the console."),
    ] = None,
) -> None:
    """Parse a hejmark source file, reporting syntax errors or dumping its parse tree."""
    source = path.read_text()
    parser = AntlrParser()
    try:
        errors = parser.parse(source)
    except GeneratedParserMissingError as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    if errors:
        for error in errors:
            typer.echo(f"{path}: {error}", err=True)
        raise typer.Exit(1)
    tree = parser.parse_tree(source)
    if out is None:
        typer.echo(tree)
    else:
        out.write_text(tree)
        typer.echo(f"{path}: OK, parse tree written to {out}")


def main() -> None:
    """Run the command-line interface."""
    app()
