"""cli.main: the command-line interface.

Keep it thin -- parse arguments, wire adapters into core use-cases, format results. Typer is the
standard framework: declare commands with @app.command() and describe any
arguments/options with typing.Annotated so `ty` sees real signatures. A Typer
app needs at least one command to run, so `status` below is the minimal runnable
seed -- add your own commands alongside it or replace it. While it is the only
command, Typer runs it directly (invoke the app as `hejmark`, not
`hejmark status`); it becomes a named subcommand once a second is added.
"""

from __future__ import annotations

from importlib.metadata import version

import typer

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command()
def status() -> None:
    """Print the installed package name and version -- minimal runnable seed."""
    typer.echo(f"hejmark {version('hejmark')}")


def main() -> None:
    """Run the command-line interface."""
    app()
