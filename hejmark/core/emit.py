"""Emit: the write half of using a universe against text.

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

from hejmark.core.engine import query as _denote_query
from hejmark.core.scan.capture import canonical_face, factor_faces
from hejmark.core.scan.match import Query, finditer
from hejmark.core.surface.ast import (
    Expr,
    HimarkScopeError,
    Interp,
    RefInterp,
    Statement,
    Step,
    Template,
    Text,
)
from hejmark.core.surface.resolve import Env, noncharacter


class HimarkSentinelError(ValueError):
    """Raised at the document boundary: sentinels are engine-private.

    A document that arrives spelling a noncharacter is refused -- Unicode
    reserves them for internal use, and the engine's internal use is sentinels.
    A sentinel surviving into the final document is a script error (a cleanup
    rule that did not fire), never something to strip silently.
    """


@dataclass(frozen=True)
class Branch:
    """A span of one text object, carrying the capture its match bound.

    ``bound`` is the query that matched, which is what a canonical-face read
    needs; a branch that no match anchors (the whole document, or a detached
    string) carries ``None`` and reads ``$0`` as ``$``.
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


def _read(branch: Branch, capture: str) -> str:
    """Render one capture read: ``$`` as it hit, ``$0`` canonical, ``$k`` factor ``k``.

    Raises:
        HimarkScopeError: a factor read on a branch no match anchors, or past
            the factors the query wrote.
    """
    if capture in {"$", "$0"}:
        if capture == "$" or branch.bound is None or branch.found is None:
            return branch.face
        return canonical_face(branch.bound, branch.found)  # ty: ignore[invalid-argument-type]
    if branch.bound is None or branch.found is None:
        msg = f"{{{{{capture}}}}} reads a branch no match anchors"
        raise HimarkScopeError(msg)
    faces = factor_faces(branch.bound, branch.found)  # ty: ignore[invalid-argument-type]
    index = int(capture[1:])
    if index > len(faces):
        msg = f"{{{{{capture}}}}} reads past the query's {len(faces)} factor(s)"
        raise HimarkScopeError(msg)
    return faces[index - 1]


def _sentinel(part: RefInterp, env: Env) -> str:
    """Render one sentinel read: the face a ``sentinel`` declaration allocated.

    Raises:
        HimarkScopeError: the name declares no sentinel.
    """
    face = env.sentinels.get(part.name)
    if face is None:
        msg = f"{{{{@{part.name}}}}} reads no sentinel"
        raise HimarkScopeError(msg)
    return face


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


def _refine(expr: Expr, branch: Branch, rest: tuple[Step, ...], env: Env) -> str:
    """A query step: tile the branch's text, and continue on each sub-branch."""
    denoted = _denote_query(expr, env)
    face = branch.face
    pieces = []
    for found in finditer(denoted, face):
        start, end = found.span
        child = Branch(face, start, end, denoted, found)
        pieces.append((start, end, _steps(rest, child, env)))
    if not pieces:
        return face
    return _splice(face, pieces)


def _construct(template: Template, branch: Branch, rest: tuple[Step, ...], env: Env) -> str:
    """A template step: build the string, and continue at each interpolation site."""
    out = []
    sites = []
    for part in template.parts:
        if isinstance(part, Text):
            out.append(part.text)
            continue
        rendered = _read(branch, part.capture) if isinstance(part, Interp) else _sentinel(part, env)
        start = sum(len(piece) for piece in out)
        out.append(rendered)
        sites.append((start, start + len(rendered)))
    built = "".join(out)
    if not rest:
        return built
    pieces = [
        (start, end, _steps(rest, Branch(built, start, end, branch.bound, branch.found), env))
        for start, end in sites
    ]
    return _splice(built, pieces)


def _steps(steps: tuple[Step, ...], branch: Branch, env: Env) -> str:
    """Run a step chain over one branch, returning what commits over its span."""
    if not steps:
        return branch.face
    head, rest = steps[0], steps[1:]
    if isinstance(head, Expr):
        return _refine(head, branch, rest, env)
    return _construct(head, branch, rest, env)


def statement(stmt: Statement, document: str, env: Env) -> str:
    """Run one statement against *document*, returning the spliced result.

    A leading query branches into the document. A leading template is detached:
    the chain computes over its string and the document never changes.
    """
    if not stmt.steps:
        return document
    if isinstance(stmt.steps[0], Template):
        detached = Branch("", 0, 0)
        _steps(stmt.steps, detached, env)
        return document
    root = Branch(document, 0, len(document))
    return _steps(stmt.steps, root, env)


def _guard(document: str, env: Env | None) -> None:
    """Refuse a document that spells a noncharacter, at either boundary.

    With *env* in hand (the exit side) the message names the sentinel that
    survived; without it (ingest) the document simply is not interchange text.

    Raises:
        HimarkSentinelError: the document carries a noncharacter.
    """
    for index, char in enumerate(document):
        if not noncharacter(char):
            continue
        if env is None:
            msg = f"document spells a noncharacter at index {index}: {char!r}"
        else:
            names = {face: name for name, face in env.sentinels.items()}
            msg = f"sentinel @{names.get(char, '?')} survived the script at index {index}"
        raise HimarkSentinelError(msg)


def run(statements: tuple[Statement, ...], document: str, env: Env) -> str:
    """Run each statement in source order, threading the document through.

    Sentinels are engine-private, so the document is guarded at both ends: a
    noncharacter at ingest is refused, and one at exit is a sentinel a cleanup
    rule left behind.
    """
    _guard(document, None)
    for stmt in statements:
        document = statement(stmt, document, env)
    _guard(document, env)
    return document
