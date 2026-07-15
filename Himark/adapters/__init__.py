"""adapters: all I/O lives here.

Database, HTTP, filesystem, subprocess, and clock access. Each adapter is a
concrete implementation of a Protocol declared in core.ports. May import from
core (to reference the ports); never from cli. This package is a namespace
shell -- logic lives in modules like adapters.main.
"""

from __future__ import annotations
