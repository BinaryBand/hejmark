"""app: orchestration and use-cases.

Wires concrete adapters to the core ports they satisfy and runs the
application's workflows. May import from adapters and core; never from cli.
"""

from __future__ import annotations
