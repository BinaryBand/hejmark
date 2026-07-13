"""app: orchestration and use-cases.

Wires concrete adapters to the core ports they satisfy and runs the
application's workflows. May import from adapters and core; never from cli. This
package is a namespace shell -- logic lives in modules like app.main.
"""

from __future__ import annotations
