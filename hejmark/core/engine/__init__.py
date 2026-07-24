"""core.engine: execution over pure data, with no knowledge of the language.

The engine consumes what the compiler emits -- floor nodes and the
:mod:`hejmark.core.ir` program shapes -- and never the surface: ``scan``
matches and captures, ``execute`` runs whole programs. It is dumb about the
language and smart about the search; the memos and the chart live on this side,
because what they manage is priced by the document, which only execution sees.
"""
