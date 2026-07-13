"""adapters: all I/O lives here.

Database, HTTP, filesystem, subprocess, and clock access. Each adapter is a
concrete implementation of a Protocol declared in core.ports. May import from
core (to reference the ports) and lib; never from app or cli.
"""

from __future__ import annotations
