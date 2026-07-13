"""cli.registry: decorator-based command registration.

Commands are declared at their definition site with :func:`command` and
assembled onto a Typer app by :func:`wire`.  This keeps ``cli.main`` thin
and makes the "one command = one decorated function" convention the path
of least resistance.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any, TypeVar

import typer

F = TypeVar("F", bound=Callable[..., Any])

_COMMANDS: list[tuple[str | None, Callable[..., Any], dict[str, Any]]] = []


def command(
    name: str | None = None,
    *,
    group: str | None = None,
    **kwargs: Any,  # noqa: ANN401
) -> Callable[[F], F]:
    """Register a function as a CLI command.

    The function is returned unchanged so it remains callable normally.
    Actual wiring into a :class:`typer.Typer` happens when :func:`wire`
    is called.

    Args:
        name: The CLI command name (e.g. ``"gen-parser"``).  Defaults to
            the function name with underscores replaced by hyphens.
        group: Optional command group name.  Commands sharing a group
            become subcommands of a ``typer.Typer(name=group)`` instance.
        **kwargs: Extra keyword arguments forwarded to
            ``Typer.command()`` (e.g. ``help``, ``hidden``).

    """

    def decorator(func: F) -> F:
        cmd_name = name or getattr(func, "__name__", "").replace("_", "-")
        _COMMANDS.append((cmd_name, func, {"group": group, **kwargs}))
        return func

    return decorator


def wire(app: typer.Typer) -> None:
    """Register all collected commands onto *app*.

    Grouped commands share a :class:`typer.Typer` sub-app that is created
    on demand and attached via :meth:`typer.Typer.add_typer`.
    """
    group_apps: dict[str, typer.Typer] = {}
    for cmd_name, func, kwargs in _COMMANDS:
        group = kwargs.pop("group", None)
        if group is not None:
            if group not in group_apps:
                group_apps[group] = typer.Typer(name=group)
                app.add_typer(group_apps[group])
            target: typer.Typer = group_apps[group]
        else:
            target = app
        target.command(cmd_name, **kwargs)(func)
