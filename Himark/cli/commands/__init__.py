"""cli.commands: one module per CLI command.

Each module decorates its function with ``@command`` from
:mod:`Himark.cli.registry`.  Importing a module here triggers the
registration so that :func:`~Himark.cli.registry.wire` can assemble
the full command tree.

When adding a new command, create a module in this package and add a
single import line below.
"""

from __future__ import annotations

from Himark.cli.commands import (
    find,  # noqa: F401
    gen_parser,  # noqa: F401
)
