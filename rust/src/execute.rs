//! Run a whole compiled script over a document: the write half of the engine.
//!
//! A port of `hejmark/core/engine/execute.py`, and the reason [`crate::ir`]
//! exists here at all. [`crate::scan`] answers *where does this query hit*; this
//! module answers *what does the document become*, which is the difference
//! between `find` and `run`.
//!
//! Two objects carry the whole section, exactly as they do in the Python. A
//! **text object** is where spellings live -- the document a statement runs
//! against, or a string a template constructs. A **branch** is a span of one
//! text object carrying the capture its match bound; the span and the floor's
//! `<value, face>` are one datum seen twice, since the text over the span is the
//! bound face. Only branches cross `=>`.
//!
//! One join rule then does the rest. A query step *refines*: it tiles the
//! branch's text, one sub-branch per match, and a query that matches nothing
//! stops the branch. A template step *constructs*: it builds a string that
//! commits over the branch's span, and each interpolation site continues as a
//! sub-branch at its rendered span, so decoration lands but never flows.
//!
//! **A slotted program is refused at load, not mid-run.** The Python resolves a
//! back-referencing factor through a callback into the compiler; that callback
//! is a function, not data, so it does not serialize and no wire format can
//! carry it. A program arriving here with a late slot names a compiler this
//! crate does not have, and [`RunError::Late`] says so before the run starts --
//! a host learns it has to fall back rather than discovering it half a document
//! in. [`crate::ir::program::Program::is_late`] answers the same question
//! without loading anything.
//!
//! Text is `[u32]` code points throughout, as everywhere in this crate, so a
//! span is a code-point offset and the sentinel guard reads whole code points.

use std::collections::HashMap;
use std::fmt;

use crate::floor::universe::{denote_shared, Universe};
use crate::floor::work::budgeted;
use crate::ir::program::{
    noncharacter, CompiledIter, CompiledLine, CompiledQuery, CompiledStatement, CompiledStep,
    CompiledTemplate, Program, QueryFactor, TemplatePart,
};
use crate::scan::capture::{canonical_face, factor_faces};
use crate::scan::error::HimarkScopeError;
use crate::scan::measure::precedes;
use crate::scan::r#match::{finditer, Match, Query};

/// The sentinel table as the run reads it: declared name to allocated face.
type Sentinels = HashMap<String, Vec<u32>>;

/// Raised at the document boundary: sentinels are engine-private.
///
/// A document that arrives spelling a noncharacter is refused -- Unicode
/// reserves them for internal use, and the engine's internal use is sentinels.
/// A sentinel surviving into the final document is a script error (a cleanup
/// rule that did not fire), never something to strip silently.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HimarkSentinelError {
    /// A human-readable description of the boundary violation.
    pub message: String,
}

impl fmt::Display for HimarkSentinelError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for HimarkSentinelError {}

/// Why a run did not produce a document.
///
/// Three ways, and the third is this crate's alone: the Python has no `Late`
/// case because it always holds the resolver that answers it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RunError {
    /// A read reached outside the scope a binding can satisfy, or a contracting
    /// pass failed to descend its measure.
    Scope(HimarkScopeError),
    /// A noncharacter crossed the document boundary, at ingest or at exit.
    Sentinel(HimarkSentinelError),
    /// The program carries a late slot, so only its own compiler can run it.
    Late(String),
}

impl fmt::Display for RunError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RunError::Scope(error) => write!(f, "{error}"),
            RunError::Sentinel(error) => write!(f, "{error}"),
            RunError::Late(message) => write!(f, "{message}"),
        }
    }
}

impl std::error::Error for RunError {}

impl From<HimarkScopeError> for RunError {
    fn from(error: HimarkScopeError) -> RunError {
        RunError::Scope(error)
    }
}

fn scope(message: impl Into<String>) -> RunError {
    RunError::Scope(HimarkScopeError {
        message: message.into(),
    })
}

/// A span of one text object, carrying the capture its match bound.
///
/// `bound` is the query that matched, which is what a canonical-face read needs;
/// a branch no match anchors (the whole document, or a detached string) carries
/// `None` and reads `$0` as `$`.
struct Branch<'a> {
    text: &'a [u32],
    start: usize,
    end: usize,
    bound: Option<&'a Query>,
    found: Option<&'a Match>,
}

impl Branch<'_> {
    /// The text over the span: the hit as it hit.
    fn face(&self) -> &[u32] {
        &self.text[self.start..self.end]
    }
}

/// One runtime step: a loaded query, or a template straight off the program.
enum Step {
    Query(Query),
    Template(CompiledTemplate),
}

/// One loaded statement: its steps, queries already denoted.
struct Statement {
    steps: Vec<Step>,
}

/// One loaded contracting statement: query and measure denoted once.
struct Contract {
    query: Query,
    measure_name: String,
    measure: Universe,
    template: CompiledTemplate,
}

/// One loaded line, ready to take a document.
enum Loaded {
    Statement(Statement),
    Contract(Contract),
}

/// Render one capture read: `$` as it hit, `$0` canonical, `$k` factor `k`.
fn read(branch: &Branch<'_>, capture: &str) -> Result<Vec<u32>, RunError> {
    let (Some(bound), Some(found)) = (branch.bound, branch.found) else {
        // No match anchors this branch: `$` and `$0` are the face, and a factor
        // read has nothing to bind.
        if capture == "$" || capture == "$0" {
            return Ok(branch.face().to_vec());
        }
        return Err(scope(format!(
            "{{{{{capture}}}}} reads a branch no match anchors"
        )));
    };
    if capture == "$" {
        return Ok(branch.face().to_vec());
    }
    if capture == "$0" {
        return Ok(canonical_face(bound, found)?);
    }
    let index: usize = capture[1..]
        .parse()
        .map_err(|_| scope(format!("{{{{{capture}}}}} is not a capture read")))?;
    let faces = factor_faces(bound, found)?;
    if index == 0 || index > faces.len() {
        return Err(scope(format!(
            "{{{{{capture}}}}} reads past the query's {} factor(s)",
            faces.len()
        )));
    }
    Ok(faces[index - 1].clone())
}

/// Render one sentinel read: the face a `sentinel` declaration allocated.
fn sentinel(name: &str, sentinels: &Sentinels) -> Result<Vec<u32>, RunError> {
    sentinels
        .get(name)
        .cloned()
        .ok_or_else(|| scope(format!("{{{{@{name}}}}} reads no sentinel")))
}

/// Lay committed strings over their spans, keeping the text between.
///
/// Spans are disjoint and in order, because a query's tiled matches are disjoint
/// and a template's interpolation sites are laid out left to right.
fn splice(text: &[u32], pieces: &[(usize, usize, Vec<u32>)]) -> Vec<u32> {
    let mut out = Vec::new();
    let mut cursor = 0;
    for (start, end, replacement) in pieces {
        out.extend_from_slice(&text[cursor..*start]);
        out.extend_from_slice(replacement);
        cursor = *end;
    }
    out.extend_from_slice(&text[cursor..]);
    out
}

/// A query step: tile the branch's text, and continue on each sub-branch.
fn refine(
    query: &Query,
    branch: &Branch<'_>,
    rest: &[Step],
    sentinels: &Sentinels,
) -> Result<Vec<u32>, RunError> {
    let face = branch.face().to_vec();
    let mut pieces: Vec<(usize, usize, Vec<u32>)> = Vec::new();
    for found in finditer(query, &face) {
        let (start, end) = found.span;
        let child = Branch {
            text: &face,
            start,
            end,
            bound: Some(query),
            found: Some(&found),
        };
        pieces.push((start, end, steps(rest, &child, sentinels)?));
    }
    if pieces.is_empty() {
        return Ok(face);
    }
    Ok(splice(&face, &pieces))
}

/// A template step: build the string, and continue at each interpolation site.
fn construct(
    template: &CompiledTemplate,
    branch: &Branch<'_>,
    rest: &[Step],
    sentinels: &Sentinels,
) -> Result<Vec<u32>, RunError> {
    let mut built: Vec<u32> = Vec::new();
    let mut sites: Vec<(usize, usize)> = Vec::new();
    for part in &template.parts {
        let rendered = match part {
            TemplatePart::Text(text) => {
                built.extend_from_slice(text);
                continue;
            }
            TemplatePart::Capture(capture) => read(branch, capture)?,
            TemplatePart::Sentinel(name) => sentinel(name, sentinels)?,
        };
        let start = built.len();
        built.extend_from_slice(&rendered);
        sites.push((start, built.len()));
    }
    if rest.is_empty() {
        return Ok(built);
    }
    let mut pieces: Vec<(usize, usize, Vec<u32>)> = Vec::with_capacity(sites.len());
    for (start, end) in sites {
        let child = Branch {
            text: &built,
            start,
            end,
            bound: branch.bound,
            found: branch.found,
        };
        pieces.push((start, end, steps(rest, &child, sentinels)?));
    }
    Ok(splice(&built, &pieces))
}

/// Run a step chain over one branch, returning what commits over its span.
fn steps(chain: &[Step], branch: &Branch<'_>, sentinels: &Sentinels) -> Result<Vec<u32>, RunError> {
    let Some((head, rest)) = chain.split_first() else {
        return Ok(branch.face().to_vec());
    };
    match head {
        Step::Query(query) => refine(query, branch, rest, sentinels),
        Step::Template(template) => construct(template, branch, rest, sentinels),
    }
}

/// Run one statement against `document`, returning the spliced result.
///
/// A leading query branches into the document. A leading template is detached:
/// the chain computes over its string and the document never changes.
fn statement(
    stmt: &Statement,
    document: &[u32],
    sentinels: &Sentinels,
) -> Result<Vec<u32>, RunError> {
    let Some(first) = stmt.steps.first() else {
        return Ok(document.to_vec());
    };
    if matches!(first, Step::Template(_)) {
        let detached = Branch {
            text: &[],
            start: 0,
            end: 0,
            bound: None,
            found: None,
        };
        steps(&stmt.steps, &detached, sentinels)?;
        return Ok(document.to_vec());
    }
    let root = Branch {
        text: document,
        start: 0,
        end: document.len(),
        bound: None,
        found: None,
    };
    steps(&stmt.steps, &root, sentinels)
}

/// Run a contracting statement: passes to settlement, each strictly descending.
///
/// The pass is the ordinary two-step statement; passes repeat until one finds
/// nothing to rewrite. Each pass is checked, not trusted: the document before
/// and after are read as spellings of the declared measure, and the after must
/// sit strictly earlier in its entry order -- a well-order, so checked descent
/// is the termination proof, not a hope.
///
/// The pass count is finite with no bound stated in advance -- a well-order
/// carries no numeral -- but each pass is priced: one work budget covers the
/// whole pass, its scan and its measure comparison together. This is the second
/// of the Python's two budget sites, and until this module existed it was the
/// one [`crate::floor::work`] had nothing to attach to.
fn iterate(
    contract: &Contract,
    document: &[u32],
    sentinels: &Sentinels,
) -> Result<Vec<u32>, RunError> {
    let once = Statement {
        steps: vec![
            Step::Query(contract.query.clone()),
            Step::Template(contract.template.clone()),
        ],
    };
    let mut document = document.to_vec();
    loop {
        let _budget = budgeted("a contracting pass");
        if finditer(&contract.query, &document).next().is_none() {
            return Ok(document);
        }
        let result = statement(&once, &document, sentinels)?;
        for text in [&document, &result] {
            if !contract.measure.contains(text) {
                return Err(scope(format!(
                    "@{} does not spell the document between passes",
                    contract.measure_name
                )));
            }
        }
        if !precedes(&contract.measure, &result, &document)? {
            return Err(scope(format!(
                "a pass failed to shrink @{}",
                contract.measure_name
            )));
        }
        document = result;
    }
}

/// Refuse a document that spells a noncharacter, at either boundary.
///
/// With the sentinel table in hand (the exit side) the message names the
/// sentinel that survived; without it (ingest) the document simply is not
/// interchange text.
fn guard(document: &[u32], sentinels: Option<&Sentinels>) -> Result<(), RunError> {
    for (index, point) in document.iter().enumerate() {
        if !noncharacter(*point) {
            continue;
        }
        let message = match sentinels {
            None => format!("document spells a noncharacter at index {index}: U+{point:04X}"),
            Some(table) => {
                let name = table
                    .iter()
                    .find(|(_, face)| face.as_slice() == [*point])
                    .map_or("?", |(name, _)| name.as_str());
                format!("sentinel @{name} survived the script at index {index}")
            }
        };
        return Err(RunError::Sentinel(HimarkSentinelError { message }));
    }
    Ok(())
}

/// Denote a compiled query's factors, refusing a late slot rather than guessing.
fn load_query(compiled: &CompiledQuery) -> Result<Query, RunError> {
    let mut universes = Vec::with_capacity(compiled.factors.len());
    for (index, factor) in compiled.factors.iter().enumerate() {
        match factor {
            QueryFactor::Universe(node) => universes.push(denote_shared(node)),
            QueryFactor::Late(_) => {
                return Err(RunError::Late(format!(
                    "factor {} back-references, and resolving it needs the compiler \
                     that emitted this program; this engine has none",
                    index + 1
                )))
            }
        }
    }
    Ok(Query::new(compiled.source.clone(), universes))
}

/// Load one program line: denote its queries, and its measure if it has one.
fn load(line: &CompiledLine) -> Result<Loaded, RunError> {
    match line {
        CompiledLine::Iter(CompiledIter {
            query,
            measure_name,
            measure,
            template,
        }) => Ok(Loaded::Contract(Contract {
            query: load_query(query)?,
            measure_name: measure_name.clone(),
            measure: denote_shared(measure),
            template: template.clone(),
        })),
        CompiledLine::Statement(CompiledStatement { steps }) => {
            let mut loaded = Vec::with_capacity(steps.len());
            for step in steps {
                loaded.push(match step {
                    CompiledStep::Query(query) => Step::Query(load_query(query)?),
                    CompiledStep::Template(template) => Step::Template(template.clone()),
                });
            }
            Ok(Loaded::Statement(Statement { steps: loaded }))
        }
    }
}

/// Run a compiled program in source order, threading the document through.
///
/// The one place a program's data becomes live objects: queries denote once, so
/// their memos serve every branch and every pass of their statement. Sentinels
/// are engine-private, so the document is guarded at both ends -- a
/// noncharacter at ingest is refused, and one at exit is a sentinel a cleanup
/// rule left behind.
///
/// # Errors
///
/// Returns a [`RunError`] for a program carrying a late slot, a capture or
/// sentinel read that nothing binds, a contracting pass that fails to descend
/// its measure, or a noncharacter at either boundary.
///
/// # Panics
///
/// Unwinds with a [`crate::floor::work::HimarkBudgetError`] payload when a match
/// or a contracting pass runs past the host's work budget, and with a
/// [`crate::floor::universe::HimarkUnsettledError`] for an unsettled closure --
/// the same two panics [`crate::scan::r#match::finditer`] already carries.
pub fn run(program: &Program, document: &[u32]) -> Result<Vec<u32>, RunError> {
    let sentinels: Sentinels = program
        .sentinels
        .iter()
        .map(|entry| (entry.name.clone(), entry.face.clone()))
        .collect();
    let loaded: Vec<Loaded> = program
        .statements
        .iter()
        .map(load)
        .collect::<Result<_, _>>()?;
    guard(document, None)?;
    let mut document = document.to_vec();
    for stmt in &loaded {
        document = match stmt {
            Loaded::Contract(contract) => iterate(contract, &document, &sentinels)?,
            Loaded::Statement(statement_) => statement(statement_, &document, &sentinels)?,
        };
    }
    guard(&document, Some(&sentinels))?;
    Ok(document)
}

/// [`run`] over Rust strings, for a host whose documents are text.
///
/// The crate works in code points, and a `str` cannot hold a lone surrogate --
/// so a spelling that carries one (only a program's own template text can, since
/// the wire format's code-point arrays admit it) renders as U+FFFD here. Callers
/// that must keep such a spelling intact take [`run`] and its `[u32]` directly.
///
/// # Errors
///
/// As [`run`].
///
/// # Panics
///
/// As [`run`].
pub fn run_text(program: &Program, document: &str) -> Result<String, RunError> {
    let points: Vec<u32> = document.chars().map(u32::from).collect();
    Ok(run(program, &points)?
        .into_iter()
        .map(|point| char::from_u32(point).unwrap_or(char::REPLACEMENT_CHARACTER))
        .collect())
}

#[cfg(test)]
mod tests {
    use super::{run_text, RunError};
    use crate::ir::wire::program_from_json;

    /// Every fixture here is verbatim `hejmark emit-program` output, so what is
    /// tested is the format the Python really writes rather than one invented to
    /// be easy to read.
    ///
    /// `{a} => "A"`.
    const REWRITE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, {"kind": "template", "parts": [{"kind": "text", "text": [65]}]}]}]}"#;

    /// `uni m = {a, b, &{a,b}}` then `{b}{a} <=>[@m] "{{$2}}{{$1}}"` -- a
    /// two-letter bubble sort, and the smallest real contracting statement.
    const BUBBLE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "iter", "query": {"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [98]}]}}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, "measure_name": "m", "measure": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}, {"kind": "product", "factors": [{"kind": "closure"}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]}}]}]}, "template": {"kind": "template", "parts": [{"kind": "capture", "capture": "$2"}, {"kind": "capture", "capture": "$1"}]}}]}"#;

    /// `sentinel mark`, then `{a} => "{{@mark}}"`, then `{{@mark}} => "b"`:
    /// a sentinel allocated, spliced, and cleaned up again.
    const SENTINELS: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [{"name": "mark", "face": [64976]}], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, {"kind": "template", "parts": [{"kind": "sentinel", "name": "mark"}]}]}, {"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "fold", "universe": {"members": [{"kind": "face", "text": [64976]}]}}]}}]}, {"kind": "template", "parts": [{"kind": "text", "text": [98]}]}]}]}"#;

    /// `{a}{$1} => "{{$1}}{{$2}}"` -- the one shape this engine cannot run.
    const BACK_REFERENCE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}, {"kind": "slot", "slot": 0, "needs": [1], "reach": 1}]}, {"kind": "template", "parts": [{"kind": "capture", "capture": "$1"}, {"kind": "capture", "capture": "$2"}]}]}]}"#;

    fn go(program: &str, document: &str) -> Result<String, RunError> {
        run_text(&program_from_json(program).unwrap(), document)
    }

    #[test]
    fn a_two_step_statement_rewrites_every_hit_and_keeps_the_text_between() {
        assert_eq!(go(REWRITE, "banana").unwrap(), "bAnAnA");
    }

    #[test]
    fn a_document_with_no_hit_comes_back_unchanged() {
        assert_eq!(go(REWRITE, "xyz").unwrap(), "xyz");
    }

    #[test]
    fn a_contracting_statement_runs_to_settlement() {
        // Each pass swaps one adjacent `ba`, and the measure's entry order is
        // what proves the passes stop.
        assert_eq!(go(BUBBLE, "ba").unwrap(), "ab");
        assert_eq!(go(BUBBLE, "bba").unwrap(), "abb");
        assert_eq!(go(BUBBLE, "bbaa").unwrap(), "aabb");
    }

    #[test]
    fn a_settled_document_costs_a_contracting_statement_nothing() {
        assert_eq!(go(BUBBLE, "aabb").unwrap(), "aabb");
    }

    #[test]
    fn a_sentinel_is_spliced_by_one_statement_and_cleaned_up_by_the_next() {
        // Nothing of the sentinel survives, which is what the exit guard checks.
        assert_eq!(go(SENTINELS, "cat").unwrap(), "cbt");
    }

    #[test]
    fn a_sentinel_that_no_rule_cleans_up_is_an_error_rather_than_output() {
        // The same program with its cleanup statement removed: the splice lands
        // and nothing takes it back out, so the exit guard names it.
        let uncleaned = SENTINELS.replace(
            r#", {"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "fold", "universe": {"members": [{"kind": "face", "text": [64976]}]}}]}}]}, {"kind": "template", "parts": [{"kind": "text", "text": [98]}]}]}"#,
            "",
        );
        let error = go(&uncleaned, "cat").unwrap_err();
        assert!(
            matches!(&error, RunError::Sentinel(_)),
            "{error} is not a sentinel refusal"
        );
        assert!(
            error.to_string().contains("sentinel @mark survived"),
            "{error}"
        );
    }

    #[test]
    fn a_document_arriving_with_a_noncharacter_is_refused_at_ingest() {
        let error = go(REWRITE, "a\u{fdd0}b").unwrap_err();
        assert!(error.to_string().contains("U+FDD0"), "{error}");
    }

    #[test]
    fn a_late_slot_is_refused_at_load_and_says_what_it_needs() {
        let error = go(BACK_REFERENCE, "aa").unwrap_err();
        assert!(matches!(&error, RunError::Late(_)), "{error}");
        assert!(
            error.to_string().contains("factor 2 back-references"),
            "{error}"
        );
    }

    #[test]
    fn spans_are_code_points_so_astral_text_stays_aligned() {
        assert_eq!(
            go(REWRITE, "\u{1d11e}a\u{1d11e}").unwrap(),
            "\u{1d11e}A\u{1d11e}"
        );
    }
}
