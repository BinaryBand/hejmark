"""cli.main: the command-line interface.

Keep it thin -- parse arguments, wire adapters into core use-cases, format results. Typer is the
standard framework: declare commands with @app.command() and describe any
arguments/options with typing.Annotated so `ty` sees real signatures. A Typer
app needs at least one command to run, so `status` below is the minimal runnable
seed -- add your own commands alongside it or replace it. While it is the only
command, Typer runs it directly (invoke the app as `Himark`, not
`Himark status`); it becomes a named subcommand once a second is added.
"""

from __future__ import annotations

from importlib.metadata import version
from pathlib import Path
from typing import Annotated

import typer

from Himark.adapters.antlr import AntlrGenerationError, AntlrGenerator, AntlrToolNotFoundError
from Himark.adapters.parser import AntlrParser, GeneratedParserMissingError

app = typer.Typer(add_completion=False, no_args_is_help=True)

DEFAULT_GRAMMAR = Path("static/grammar/Himark.g4")
DEFAULT_OUTPUT_DIR = Path("Himark/adapters/_gen")


@app.command()
def status() -> None:
    """Print the installed package name and version -- minimal runnable seed."""
    typer.echo(f"Himark {version('Himark')}")


@app.command("gen-parser")
def gen_parser(
    grammar: Annotated[Path, typer.Option(help="Path to the .g4 grammar file.")] = DEFAULT_GRAMMAR,
    output_dir: Annotated[
        Path, typer.Option(help="Directory to write generated parser sources into.")
    ] = DEFAULT_OUTPUT_DIR,
    language: Annotated[str, typer.Option(help="Target language for antlr4 -Dlanguage=.")] = (
        "Python3"
    ),
) -> None:
    """Regenerate the parser from the ANTLR grammar via the external antlr4 tool."""
    try:
        AntlrGenerator().generate(grammar, output_dir, language=language)
    except (AntlrToolNotFoundError, AntlrGenerationError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    typer.echo(f"Generated {language} parser for {grammar} into {output_dir}")


@app.command("parse-file")
def parse_file(
    path: Annotated[Path, typer.Argument(help="Path to a .hmk source file to parse.")],
) -> None:
    """Parse a Himark source file and report syntax errors, if any."""
    try:
        errors = AntlrParser().parse(path.read_text())
    except GeneratedParserMissingError as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    if errors:
        for error in errors:
            typer.echo(f"{path}: {error}", err=True)
        raise typer.Exit(1)
    typer.echo(f"{path}: OK")


def main() -> None:
    """Run the command-line interface."""
    app()
