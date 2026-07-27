"""Emit: the write half of using a universe against text.

The engine's executor: it takes a compiled
:class:`~hejmark.core.ir.program.Program` -- pure data -- plus the compiler's
late resolver, and threads a document through it. Nothing language-shaped
happens here; every name was settled at compilation.

Two objects carry the whole section. A **text object** is where spellings live:
the document a statement runs against, or a string a template constructs. A
**branch** is a span of one text object carrying the capture its match bound --
the span and the floor's ``<value, face>`` are one datum seen twice, since the
text over the span is exactly the bound face. Only branches cross ``=>``.

One join rule then does the rest. A query step *refines*: it tiles the branch's
text, one sub-branch per match, and a query that matches nothing stops the
branch -- the guard reading. A template step *constructs*: it builds a string
that commits over the branch's span, and each interpolation site continues as a
sub-branch at its rendered span, so decoration lands but never flows.

Everything else falls out rather than being cased. A leading template has no
incoming branch, so its string is detached and the document never changes. The
whole-document rewrite is the idiom ``{@spellings} => "..."``, which tiles the
whole text because maximal munch takes the longest face -- and does not fire on
an empty document, since the only face on offer is the empty spelling and
zero-width never matches.
"""

from __future__ import annotations

from dataclasses import dataclass

from hejmark.core.engine.scan.capture import canonical_face, factor_faces
from hejmark.core.engine.scan.match import Query, finditer, load_query
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import (
    CompiledIter,
    CompiledLine,
    CompiledQuery,
    CompiledTemplate,
    LateResolver,
    Program,
    TextPart,
)


@dataclass(frozen=True)
class Branch:
    """A span of one text object, carrying the capture its match bound.

    ``bound`` is the query that matched, which every capture read needs; a
    branch that no match anchors (the whole document, or a detached string)
    carries ``None``, and a capture read on it is refused.
    """

    text: str
    start: int
    end: int
    bound: Query | None = None
    found: object = None

    @property
    def face(self) -> str:
        """The text over the span: the hit as it hit."""
        return self.text[self.start : self.end]


# One runtime step: a loaded query, or a template straight off the program.
_Step = Query | CompiledTemplate


@dataclass(frozen=True)
class _Statement:
    """One loaded statement: its steps, queries already wired to the resolver."""

    steps: tuple[_Step, ...]


@dataclass(frozen=True)
class _Contract:
    """One loaded contracting statement: its query and template."""

    query: Query
    template: CompiledTemplate


def _read(branch: Branch, capture: str) -> str:
    """Render one capture read: ``$`` as it hit, ``$0`` canonical, ``$k`` factor ``k``.

    Every read needs a branch a match anchors; on a detached or whole-text
    branch that none does, all three refuse alike -- there is no hit to read.

    Raises:
        HimarkScopeError: a capture read on a branch no match anchors, or a
            factor read past the factors the query wrote.
    """
    if branch.bound is None or branch.found is None:
        msg = f"{{{{{capture}}}}} reads a branch no match anchors"
        raise HimarkScopeError(msg)
    if capture == "$":
        return branch.face
    if capture == "$0":
        return canonical_face(branch.bound, branch.found)  # ty: ignore[invalid-argument-type]
    faces = factor_faces(branch.bound, branch.found)  # ty: ignore[invalid-argument-type]
    index = int(capture[1:])
    if index > len(faces):
        msg = f"{{{{{capture}}}}} reads past the query's {len(faces)} factor(s)"
        raise HimarkScopeError(msg)
    return faces[index - 1]


def _splice(text: str, pieces: list[tuple[int, int, str]]) -> str:
    """Lay committed strings over their spans, keeping the text between.

    Spans are disjoint and in order, because a query's tiled matches are
    disjoint and a template's interpolation sites are laid out left to right.
    """
    out = []
    cursor = 0
    for start, end, replacement in pieces:
        out.append(text[cursor:start])
        out.append(replacement)
        cursor = end
    out.append(text[cursor:])
    return "".join(out)


def _refine(query: Query, branch: Branch, rest: tuple[_Step, ...]) -> str:
    """A query step: tile the branch's text, and continue on each sub-branch."""
    face = branch.face
    pieces = []
    for found in finditer(query, face):
        start, end = found.span
        child = Branch(face, start, end, query, found)
        pieces.append((start, end, _steps(rest, child)))
    if not pieces:
        return face
    return _splice(face, pieces)


def _construct(template: CompiledTemplate, branch: Branch, rest: tuple[_Step, ...]) -> str:
    """A template step: build the string, and continue at each interpolation site."""
    out = []
    sites = []
    for part in template.parts:
        if isinstance(part, TextPart):
            out.append(part.text)
            continue
        rendered = _read(branch, part.capture)
        start = sum(len(piece) for piece in out)
        out.append(rendered)
        sites.append((start, start + len(rendered)))
    built = "".join(out)
    if not rest:
        return built
    pieces = [
        (start, end, _steps(rest, Branch(built, start, end, branch.bound, branch.found)))
        for start, end in sites
    ]
    return _splice(built, pieces)


def _steps(steps: tuple[_Step, ...], branch: Branch) -> str:
    """Run a step chain over one branch, returning what commits over its span."""
    if not steps:
        return branch.face
    head, rest = steps[0], steps[1:]
    if isinstance(head, Query):
        return _refine(head, branch, rest)
    return _construct(head, branch, rest)


def _statement(stmt: _Statement, document: str) -> str:
    """Run one statement against *document*, returning the spliced result.

    A leading query branches into the document. A leading template is detached:
    the chain computes over its string and the document never changes.
    """
    if not stmt.steps:
        return document
    if isinstance(stmt.steps[0], CompiledTemplate):
        detached = Branch("", 0, 0)
        _steps(stmt.steps, detached)
        return document
    root = Branch(document, 0, len(document))
    return _steps(stmt.steps, root)


def _iterate(stmt: _Contract, document: str) -> str:
    """Iterate a contracting statement to its fixpoint: the document unchanged.

    The pass is the ordinary two-step statement, re-run until it rewrites the
    document to itself -- the true fixpoint. A contraction whose matches
    reproduce the text they cover settles at once; one that keeps moving the
    document (an oscillating re-dress) never settles, and nothing here proves in
    advance which it is.
    """
    once = _Statement((stmt.query, stmt.template))
    while True:
        rewritten = _statement(once, document)
        if rewritten == document:
            return document
        document = rewritten


def _strip(document: str, sentinels: tuple[str, ...]) -> str:
    """Clear every declared sentinel from the final document.

    A sentinel is a real noncharacter while the script runs, so statements can
    match it; at exit it is stripped, so nothing engine-private crosses the
    boundary and no cleanup statement has to be written.
    """
    for face in sentinels:
        document = document.replace(face, "")
    return document


def _load(line: CompiledLine, resolver: LateResolver) -> _Statement | _Contract:
    """Load one program line: wire its queries to the resolver."""
    if isinstance(line, CompiledIter):
        return _Contract(load_query(line.query, resolver), line.template)
    return _Statement(
        tuple(
            load_query(step, resolver) if isinstance(step, CompiledQuery) else step
            for step in line.steps
        )
    )


def run(program: Program, document: str, resolver: LateResolver) -> str:
    """Run a compiled program in source order, threading the document through.

    The one place a program's data becomes live objects: queries load once, so
    a slot's memo serves every branch and every pass of its statement.
    Sentinels are engine-private: any sentinel still standing at exit is
    stripped, so nothing engine-private crosses the boundary.
    """
    loaded = tuple(_load(line, resolver) for line in program.statements)
    for stmt in loaded:
        if isinstance(stmt, _Contract):
            document = _iterate(stmt, document)
        else:
            document = _statement(stmt, document)
    return _strip(document, program.sentinels)
