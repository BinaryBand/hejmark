"""core.floor: the L1 denotational floor as data -- five constructors, no more.

`syntax` is the AST every expansion targets: the five constructors and nothing
else. `binder` answers where a closure binds, which is a question about the
written tree rather than about what it denotes, so it too is settled here.

Denoting one of these trees is what it takes to *execute* it, so the denotation
itself lives on the engine's side of the boundary
(:mod:`hejmark.core.engine.denote`) and the compiler reaches it only through
:data:`~hejmark.core.ir.program.ToFaces`. What remains here is the shared
vocabulary both sides are written against. Nothing here knows that L1.5 exists,
and the import-linter "core partition" contract keeps it that way: this is the
bottom layer, so it may not import anything above it. That is L1.5's admission
rule ("a construct expands into the five constructors or it does not enter")
made structural.
"""

from __future__ import annotations
