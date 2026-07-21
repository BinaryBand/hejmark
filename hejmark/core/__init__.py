"""core: the compiler -> Program -> engine partition, over a shared floor.

Bottom of the stack: no I/O and no imports from the other layers -- the
import-linter contracts guarantee this. Five subpackages, each a stratum of
the `core partition` contract: ``compiler`` lowers L1.5 source to the
pure-data :class:`~hejmark.core.ir.program.Program`; ``engine`` matches and
executes it; ``ir`` defines everything that crosses between them; ``floor``
is the shared L1 denotation core under both; and ``driver`` is the
composition root that wires a parser port through the compiler into the
engine. The compiler and the engine never import each other -- their one
run-time exchange, late-slot resolution, crosses as a callback value carrying
pure data both ways.
"""

from __future__ import annotations
