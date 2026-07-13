"""Tests for the cli registry (decorator-based command registration)."""

from __future__ import annotations

import typer
from typer.testing import CliRunner

from Himark.cli.registry import _COMMANDS, command, wire


def _reset_commands() -> None:
    """Clear the registry between tests."""
    _COMMANDS.clear()


def test_command_registers_function() -> None:
    """@command appends the function to the global registry."""
    _reset_commands()

    @command("test-cmd")
    def my_cmd() -> None:
        pass

    assert len(_COMMANDS) == 1
    name, func, kwargs = _COMMANDS[0]
    assert name == "test-cmd"
    assert func is my_cmd
    assert kwargs == {"group": None}


def test_command_defaults_to_hyphenated_name() -> None:
    """When no explicit name is given, underscores become hyphens."""
    _reset_commands()

    @command()
    def my_long_command() -> None:
        pass

    assert _COMMANDS[0][0] == "my-long-command"


def test_command_with_group() -> None:
    """@command(group=...) records the group in kwargs."""
    _reset_commands()

    @command("show", group="config")
    def config_show() -> None:
        pass

    assert _COMMANDS[0] == ("show", config_show, {"group": "config"})


def test_command_returns_function_unchanged() -> None:
    """The decorator must not wrap or alter the original function."""
    _reset_commands()

    def original() -> str:
        return "ok"

    decorated = command("x")(original)
    assert decorated is original
    assert original() == "ok"


def test_wire_registers_commands_on_app() -> None:
    """wire() drains the registry and registers each command on the app."""
    _reset_commands()

    @command("alpha")
    def alpha() -> None:
        """Alpha command."""

    @command("beta")
    def beta() -> None:
        """Beta command."""

    app = typer.Typer(add_completion=False, no_args_is_help=True)
    wire(app)

    runner = CliRunner()
    result = runner.invoke(app, ["--help"])
    assert "alpha" in result.output
    assert "beta" in result.output


def test_wire_groups_commands() -> None:
    """Commands with the same group land under one sub-Typer."""
    _reset_commands()

    @command("show", group="cfg")
    def cfg_show() -> None:
        """Show config."""

    @command("set", group="cfg")
    def cfg_set() -> None:
        """Set config."""

    app = typer.Typer(add_completion=False, no_args_is_help=True)
    wire(app)

    runner = CliRunner()
    result = runner.invoke(app, ["--help"])
    assert "cfg" in result.output
