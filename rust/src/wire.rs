//! The payload, decoded: `hejmark-program` and the floor codec.
//!
//! A port of `hejmark/core/ir/{codec,wire}.py`, decode half only -- the engine
//! never sends a universe, it only ever receives one. Faces, template text and
//! sentinel faces arrive as code-point arrays (the lone-surrogate rule);
//! capture spellings and the diagnostic `source` are JSON strings.
//!
//! Decoding refuses rather than guesses: an unknown tag, a missing field or a
//! code point past the plane space is a `payload` refusal, never a repair. A
//! reader on this side of the wire must never run on something it only half
//! understood.

use std::rc::Rc;

use serde_json::Value;

use crate::errors::{payload, Answer};
use crate::spelling::{Point, Spelling};
use crate::syntax::{Arena, Factor, Member, NodeId};

/// The wire format tag and version this engine speaks.
const FORMAT: &str = "hejmark-program";
/// The payload version this engine speaks.
const VERSION: u64 = 4;
/// The last code point: nothing past the seventeenth plane decodes.
const MAX_POINT: u64 = 0x0010_FFFF;

/// One query factor as the payload carries it.
#[derive(Clone, Debug)]
pub enum WireFactor {
    /// A factor already lowered to a floor universe.
    Universe(NodeId),
    /// A back-referencing factor, awaiting the faces it reads.
    Slot {
        /// Which slot the host should expand.
        slot: u32,
        /// Which factors to its left it reads, one-based.
        needs: Vec<u32>,
    },
}

/// A query step.
#[derive(Clone, Debug)]
pub struct WireQuery {
    /// The source, for diagnostics only.
    pub source: String,
    /// One factor per product position.
    pub factors: Vec<WireFactor>,
}

/// One piece of a template.
#[derive(Clone, Debug)]
pub enum Part {
    /// Literal text.
    Text(Spelling),
    /// A capture read: `$`, `$0` or `$k`.
    Capture(String),
}

/// A template step.
#[derive(Clone, Debug)]
pub struct Template {
    /// The parts, in order.
    pub parts: Vec<Part>,
}

/// One step of a statement.
#[derive(Clone, Debug)]
pub enum Step {
    /// A query step: refine.
    Query(WireQuery),
    /// A template step: construct.
    Template(Template),
}

/// One line of a program.
#[derive(Clone, Debug)]
pub enum Line {
    /// An ordinary statement: its steps in order.
    Statement(Vec<Step>),
    /// A contracting statement, iterated to its fixpoint.
    Iter {
        /// The query it matches with.
        query: WireQuery,
        /// The template it rewrites to.
        template: Template,
    },
}

/// A compiled script.
#[derive(Clone, Debug)]
pub struct Program {
    /// The statements, in source order.
    pub statements: Vec<Line>,
    /// The sentinel faces to clear at exit.
    pub sentinels: Vec<Spelling>,
}

/// Read *key* from a payload object, refusing anything else.
fn field<'a>(value: &'a Value, key: &str, what: &str) -> Answer<&'a Value> {
    value.get(key).map_or_else(|| payload(format!("malformed {what}: missing {key:?}")), Ok)
}

/// Require an array.
fn array<'a>(value: &'a Value, what: &str) -> Answer<&'a Vec<Value>> {
    value.as_array().map_or_else(|| payload(format!("malformed {what}: not an array")), Ok)
}

/// Require a JSON string.
fn text(value: &Value, what: &str) -> Answer<String> {
    value.as_str().map_or_else(
        || payload(format!("malformed {what}: not a string")),
        |found| Ok(found.into()),
    )
}

/// Require an integer.
fn integer(value: &Value, what: &str) -> Answer<u64> {
    value.as_u64().map_or_else(|| payload(format!("malformed {what}: not an integer")), Ok)
}

/// Decode one code point, refusing anything outside the plane space.
fn point(value: &Value) -> Answer<Point> {
    match value.as_u64() {
        Some(found) if found <= MAX_POINT => {
            Ok(u32::try_from(found).expect("checked against the plane space"))
        }
        _ => payload(format!("malformed spelling: {value} is no code point")),
    }
}

/// Decode a code-point array back to a spelling.
pub fn spelling(value: &Value) -> Answer<Spelling> {
    let points: Answer<Vec<Point>> = array(value, "spelling")?.iter().map(point).collect();
    Ok(Rc::from(points?))
}

/// Decode `{"members": [...]}` into the arena, returning its node.
pub fn universe(value: &Value, arena: &Arena) -> Answer<NodeId> {
    let members: Answer<Vec<Member>> = array(field(value, "members", "universe")?, "members")?
        .iter()
        .map(|member| self_member(member, arena))
        .collect();
    Ok(arena.push(members?))
}

/// Decode one tagged member back to its constructor.
fn self_member(value: &Value, arena: &Arena) -> Answer<Member> {
    let kind = text(field(value, "kind", "member")?, "kind")?;
    match kind.as_str() {
        "face" => Ok(Member::Face(spelling(field(value, "text", "face")?)?)),
        "range" => {
            let lo = point(field(value, "lo", "range")?)?;
            let hi = point(field(value, "hi", "range")?)?;
            Ok(Member::Range(lo, hi))
        }
        "fold" => Ok(Member::Fold(universe(field(value, "universe", "fold")?, arena)?)),
        "subtract" => Ok(Member::Subtract(universe(field(value, "universe", "subtract")?, arena)?)),
        "product" => {
            let factors: Answer<Vec<Factor>> =
                array(field(value, "factors", "product")?, "factors")?
                    .iter()
                    .map(|factor| self_factor(factor, arena))
                    .collect();
            Ok(Member::Product(factors?))
        }
        "closure" => Ok(Member::Closure),
        other => payload(format!("malformed member: unknown kind {other:?}")),
    }
}

/// Decode a product factor: a nested universe, or the closure token.
fn self_factor(value: &Value, arena: &Arena) -> Answer<Factor> {
    match text(field(value, "kind", "factor")?, "kind")?.as_str() {
        "closure" => Ok(Factor::Closure),
        "universe" => Ok(Factor::Universe(universe(field(value, "universe", "factor")?, arena)?)),
        other => payload(format!("malformed factor: unknown kind {other:?}")),
    }
}

/// Decode the versioned wire object back to a program.
pub fn program(value: &Value, arena: &Arena) -> Answer<Program> {
    if text(field(value, "format", "program")?, "format")? != FORMAT {
        return payload(format!("malformed program: format is not {FORMAT:?}"));
    }
    if integer(field(value, "version", "program")?, "version")? != VERSION {
        return payload(format!("malformed program: version is not {VERSION}"));
    }
    let sentinels: Answer<Vec<Spelling>> =
        array(field(value, "sentinels", "program")?, "sentinels")?.iter().map(spelling).collect();
    let statements: Answer<Vec<Line>> =
        array(field(value, "statements", "program")?, "statements")?
            .iter()
            .map(|line| self_line(line, arena))
            .collect();
    Ok(Program { statements: statements?, sentinels: sentinels? })
}

/// Decode one tagged statement.
fn self_line(value: &Value, arena: &Arena) -> Answer<Line> {
    match text(field(value, "kind", "statement")?, "kind")?.as_str() {
        "statement" => {
            let steps: Answer<Vec<Step>> = array(field(value, "steps", "statement")?, "steps")?
                .iter()
                .map(|step| self_step(step, arena))
                .collect();
            Ok(Line::Statement(steps?))
        }
        "iter" => Ok(Line::Iter {
            query: self_query(field(value, "query", "iter")?, arena)?,
            template: self_template(field(value, "template", "iter")?)?,
        }),
        other => payload(format!("malformed statement: unknown kind {other:?}")),
    }
}

/// Decode one tagged step.
fn self_step(value: &Value, arena: &Arena) -> Answer<Step> {
    match text(field(value, "kind", "step")?, "kind")?.as_str() {
        "query" => Ok(Step::Query(self_query(value, arena)?)),
        "template" => Ok(Step::Template(self_template(value)?)),
        other => payload(format!("malformed step: unknown kind {other:?}")),
    }
}

/// Decode a query step, requiring its tag.
fn self_query(value: &Value, arena: &Arena) -> Answer<WireQuery> {
    if text(field(value, "kind", "query")?, "kind")? != "query" {
        return payload("malformed query: kind is not 'query'");
    }
    let factors: Answer<Vec<WireFactor>> = array(field(value, "factors", "query")?, "factors")?
        .iter()
        .map(|factor| self_query_factor(factor, arena))
        .collect();
    Ok(WireQuery { source: text(field(value, "source", "query")?, "source")?, factors: factors? })
}

/// Decode one tagged query factor.
fn self_query_factor(value: &Value, arena: &Arena) -> Answer<WireFactor> {
    match text(field(value, "kind", "factor")?, "kind")?.as_str() {
        "universe" => {
            Ok(WireFactor::Universe(universe(field(value, "universe", "factor")?, arena)?))
        }
        "slot" => {
            let needs: Answer<Vec<u32>> = array(field(value, "needs", "slot")?, "needs")?
                .iter()
                .map(|read| Ok(u32::try_from(integer(read, "needs")?).unwrap_or(u32::MAX)))
                .collect();
            Ok(WireFactor::Slot {
                slot: u32::try_from(integer(field(value, "slot", "slot")?, "slot")?)
                    .unwrap_or(u32::MAX),
                needs: needs?,
            })
        }
        other => payload(format!("malformed factor: unknown kind {other:?}")),
    }
}

/// Decode a template step, requiring its tag.
fn self_template(value: &Value) -> Answer<Template> {
    if text(field(value, "kind", "template")?, "kind")? != "template" {
        return payload("malformed template: kind is not 'template'");
    }
    let parts: Answer<Vec<Part>> =
        array(field(value, "parts", "template")?, "parts")?.iter().map(self_part).collect();
    Ok(Template { parts: parts? })
}

/// Decode one tagged template part.
fn self_part(value: &Value) -> Answer<Part> {
    match text(field(value, "kind", "part")?, "kind")?.as_str() {
        "text" => Ok(Part::Text(spelling(field(value, "text", "text")?)?)),
        "capture" => Ok(Part::Capture(text(field(value, "capture", "capture")?, "capture")?)),
        other => payload(format!("malformed part: unknown kind {other:?}")),
    }
}

/// A spelling as the code-point array the wire carries.
pub fn points(face: &[Point]) -> Value {
    Value::Array(face.iter().map(|point| Value::from(*point)).collect())
}
