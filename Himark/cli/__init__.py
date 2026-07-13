"""cli: command-line entry points and argument parsing.

The only layer that may import from app, and the one place print() is allowed.
This package is a namespace shell -- logic lives in modules like cli.main, never
in this __init__.
"""

from __future__ import annotations
