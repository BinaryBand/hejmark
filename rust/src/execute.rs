//! Emit: threading a document through a compiled program.
//!
//! A port of `hejmark/core/engine/execute.py`. Two objects carry the whole
//! thing. A **text object** is where spellings live: the document a statement
//! runs against, or a string a template constructs. A **branch** is a span of
//! one text object carrying the capture its match bound -- the span and the
//! floor's `<value, face>` are one datum seen twice, since the text over the
//! span is exactly the bound face. Only branches cross `=>`.
//!
//! One join rule does the rest. A query step *refines*: it tiles the branch's
//! text, one sub-branch per match, and a query that matches nothing stops the
//! branch. A template step *constructs*: it builds a string that commits over
//! the branch's span, and each interpolation site continues as a sub-branch at
//! its rendered span, so decoration lands but never flows.

use std::rc::Rc;

use crate::errors::{scope, Answer};
use crate::scan::{Engine, Match, Query};
use crate::spelling::{spelling, Point, Spelling};
use crate::wire::{Line, Part, Program, Step, Template};

/// A span of one text object, carrying the capture its match bound.
///
/// `bound` is the query that matched, which every capture read needs; a branch
/// that no match anchors (the whole document, or a detached string) carries
/// `None`, and a capture read on it is refused.
struct Branch {
    text: Spelling,
    start: usize,
    end: usize,
    bound: Option<Rc<Query>>,
    found: Option<Match>,
}

impl Branch {
    /// The text over the span: the hit as it hit.
    fn face(&self) -> Spelling {
        spelling(&self.text[self.start..self.end])
    }
}

/// One runtime step: a loaded query, or a template straight off the program.
enum Loaded {
    Query(Rc<Query>),
    Template(Template),
}

/// One loaded line: an ordinary statement, or a contracting one.
enum Statement {
    Steps(Vec<Loaded>),
    Contract { query: Rc<Query>, template: Template },
}

impl Engine<'_> {
    /// Run a compiled program in source order, threading the document through.
    ///
    /// Queries load once, so a slot's memo serves every branch and every pass of
    /// its statement. Any sentinel still standing at exit is stripped, so nothing
    /// engine-private crosses the boundary.
    pub fn run(&self, program: &Program, document: &[Point]) -> Answer<Spelling> {
        let loaded: Vec<Statement> =
            program.statements.iter().map(|line| self.load(line)).collect();
        let mut document: Spelling = spelling(document);
        for statement in &loaded {
            document = match statement {
                Statement::Steps(_) => self.statement(statement, &document)?,
                Statement::Contract { .. } => self.iterate(statement, &document)?,
            };
        }
        Ok(strip(&document, &program.sentinels))
    }

    /// Load one program line: wire its queries to the resolver.
    fn load(&self, line: &Line) -> Statement {
        match line {
            Line::Iter { query, template } => Statement::Contract {
                query: Rc::new(Query::load(&self.den, query.source.clone(), query.factors.clone())),
                template: template.clone(),
            },
            Line::Statement(steps) => Statement::Steps(
                steps
                    .iter()
                    .map(|step| match step {
                        Step::Query(query) => Loaded::Query(Rc::new(Query::load(
                            &self.den,
                            query.source.clone(),
                            query.factors.clone(),
                        ))),
                        Step::Template(template) => Loaded::Template(template.clone()),
                    })
                    .collect(),
            ),
        }
    }

    /// Run one statement against *document*, returning the spliced result.
    ///
    /// A leading query branches into the document. A leading template is
    /// detached: the chain computes over its string and the document never
    /// changes.
    fn statement(&self, statement: &Statement, document: &Spelling) -> Answer<Spelling> {
        let Statement::Steps(steps) = statement else { return Ok(document.clone()) };
        let Some(head) = steps.first() else { return Ok(document.clone()) };
        if matches!(head, Loaded::Template(_)) {
            let detached =
                Branch { text: spelling(&[]), start: 0, end: 0, bound: None, found: None };
            self.steps(steps, &detached)?;
            return Ok(document.clone());
        }
        let root = Branch {
            text: document.clone(),
            start: 0,
            end: document.len(),
            bound: None,
            found: None,
        };
        self.steps(steps, &root)
    }

    /// Iterate a contracting statement to its fixpoint: the document unchanged.
    ///
    /// The pass is the ordinary two-step statement, re-run until it rewrites the
    /// document to itself. One that keeps moving the document never settles, and
    /// nothing here proves in advance which it is.
    fn iterate(&self, statement: &Statement, document: &Spelling) -> Answer<Spelling> {
        let Statement::Contract { query, template } = statement else {
            return Ok(document.clone());
        };
        let once = Statement::Steps(vec![
            Loaded::Query(query.clone()),
            Loaded::Template(template.clone()),
        ]);
        let mut document = document.clone();
        loop {
            let rewritten = self.statement(&once, &document)?;
            if rewritten == document {
                return Ok(document);
            }
            document = rewritten;
        }
    }

    /// Run a step chain over one branch, returning what commits over its span.
    fn steps(&self, steps: &[Loaded], branch: &Branch) -> Answer<Spelling> {
        let Some((head, rest)) = steps.split_first() else { return Ok(branch.face()) };
        match head {
            Loaded::Query(query) => self.refine(query, branch, rest),
            Loaded::Template(template) => self.construct(template, branch, rest),
        }
    }

    /// A query step: tile the branch's text, and continue on each sub-branch.
    fn refine(&self, query: &Rc<Query>, branch: &Branch, rest: &[Loaded]) -> Answer<Spelling> {
        let face = branch.face();
        let mut pieces = Vec::new();
        for found in self.find_all(query, &face)? {
            let (start, end) = found.span;
            let child = Branch {
                text: face.clone(),
                start,
                end,
                bound: Some(query.clone()),
                found: Some(found),
            };
            pieces.push((start, end, self.steps(rest, &child)?));
        }
        if pieces.is_empty() {
            return Ok(face);
        }
        Ok(splice(&face, &pieces))
    }

    /// A template step: build the string, and continue at each interpolation site.
    fn construct(&self, template: &Template, branch: &Branch, rest: &[Loaded]) -> Answer<Spelling> {
        let mut built: Vec<Point> = Vec::new();
        let mut sites = Vec::new();
        for part in &template.parts {
            match part {
                Part::Text(text) => built.extend(text.iter().copied()),
                Part::Capture(capture) => {
                    let rendered = self.read(branch, capture)?;
                    let start = built.len();
                    built.extend(rendered.iter().copied());
                    sites.push((start, built.len()));
                }
            }
        }
        let built: Spelling = Rc::from(built);
        if rest.is_empty() {
            return Ok(built);
        }
        let mut pieces = Vec::new();
        for (start, end) in sites {
            let site = Branch {
                text: built.clone(),
                start,
                end,
                bound: branch.bound.clone(),
                found: branch.found.clone(),
            };
            pieces.push((start, end, self.steps(rest, &site)?));
        }
        Ok(splice(&built, &pieces))
    }

    /// Render one capture read: `$` as it hit, `$0` canonical, `$k` factor `k`.
    ///
    /// Every read needs a branch a match anchors; on a detached or whole-text
    /// branch that none does, all three refuse alike -- there is no hit to read.
    fn read(&self, branch: &Branch, capture: &str) -> Answer<Spelling> {
        let (Some(query), Some(found)) = (branch.bound.as_ref(), branch.found.as_ref()) else {
            return scope(format!("{{{{{capture}}}}} reads a branch no match anchors"));
        };
        if capture == "$" {
            return Ok(branch.face());
        }
        if capture == "$0" {
            return self.canonical_face(query, found);
        }
        let faces = self.factor_faces(query, found)?;
        let Ok(index) = capture[1..].parse::<usize>() else {
            return scope(format!("{{{{{capture}}}}} is not a factor read"));
        };
        if index > faces.len() {
            return scope(format!(
                "{{{{{capture}}}}} reads past the query's {} factor(s)",
                faces.len()
            ));
        }
        Ok(faces[index - 1].clone())
    }
}

/// Lay committed strings over their spans, keeping the text between.
///
/// Spans are disjoint and in order, because a query's tiled matches are disjoint
/// and a template's interpolation sites are laid out left to right.
fn splice(text: &[Point], pieces: &[(usize, usize, Spelling)]) -> Spelling {
    let mut out: Vec<Point> = Vec::new();
    let mut cursor = 0;
    for (start, end, replacement) in pieces {
        out.extend(text[cursor..*start].iter().copied());
        out.extend(replacement.iter().copied());
        cursor = *end;
    }
    out.extend(text[cursor..].iter().copied());
    Rc::from(out)
}

/// Clear every declared sentinel from the final document.
///
/// A sentinel is a real noncharacter while the script runs, so statements can
/// match it; at exit it is stripped, so nothing engine-private crosses the
/// boundary and no cleanup statement has to be written.
fn strip(document: &[Point], sentinels: &[Spelling]) -> Spelling {
    let mut text: Vec<Point> = document.to_vec();
    for face in sentinels {
        if face.is_empty() {
            continue;
        }
        let mut out: Vec<Point> = Vec::new();
        let mut at = 0;
        while at < text.len() {
            if text[at..].starts_with(face) {
                at += face.len();
            } else {
                out.push(text[at]);
                at += 1;
            }
        }
        text = out;
    }
    Rc::from(text)
}
