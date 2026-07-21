//! The Program wire format: a compiled script as versioned, tagged JSON.
//!
//! The read half of `hejmark/core/ir/wire.py`, whose module docstring is the
//! non-normative reference for the shape. This crate never writes one -- it has
//! no compiler -- so there is a decoder here and no encoder, exactly as
//! [`super::super::floor::json`] is a decoder and no encoder one stratum down.
//!
//! ```json
//! Program   = { "format": "hejmark-program", "version": 1,
//!               "sentinels": [Sentinel, ...], "statements": [Line, ...] }
//! Sentinel  = { "name": string, "face": [int, ...] }
//! Line =
//!     { "kind": "statement", "steps": [Step, ...] }
//!   | { "kind": "iter", "query": Step, "measure_name": string,
//!       "measure": UniverseNode, "template": Step }
//! Step =
//!     { "kind": "query", "source": string, "factors": [Factor, ...] }
//!   | { "kind": "template", "parts": [Part, ...] }
//! Factor =
//!     { "kind": "universe", "universe": UniverseNode }
//!   | { "kind": "slot", "slot": int, "needs": [int, ...], "reach": int | null }
//! Part =
//!     { "kind": "text", "text": [int, ...] }
//!   | { "kind": "capture", "capture": string }
//!   | { "kind": "sentinel", "name": string }
//! ```
//!
//! `UniverseNode` is the floor schema, read by the module below this one --
//! which is the whole reason the two formats nest rather than compete: a query
//! this crate could already `find` is a leaf of a program it can now `run`.
//!
//! **The version is checked, not assumed.** The Python has emitted `version: 1`
//! from the format's first day and the check is what makes that worth
//! something: a future format arriving at an old engine is refused by name here
//! rather than half-read into something that looks like a program.

use std::rc::Rc;

use crate::floor::json::{
    as_array, as_number, as_object, as_str, fault, field, parse, to_code_points, to_universe, Json,
    JsonError,
};
use crate::floor::syntax::UniverseNode;
use crate::ir::program::{
    CompiledIter, CompiledLine, CompiledQuery, CompiledStatement, CompiledStep, CompiledTemplate,
    LateSlot, Program, QueryFactor, Sentinel, TemplatePart,
};

/// The format tag every program carries.
pub const FORMAT: &str = "hejmark-program";

/// The version this reader understands. Anything else is refused.
pub const VERSION: u64 = 1;

/// Read a whole compiled script from its JSON encoding.
///
/// # Errors
///
/// Returns a [`JsonError`] on malformed JSON, a format or version tag this
/// reader does not know, or a node that does not match the schema above.
pub fn program_from_json(text: &str) -> Result<Program, JsonError> {
    to_program(&parse(text)?)
}

fn to_program(json: &Json) -> Result<Program, JsonError> {
    let object = as_object(json)?;
    let format = as_str(field(object, "format")?)?;
    if format != FORMAT {
        return Err(fault(format!("format is {format:?}, not {FORMAT:?}")));
    }
    let version = as_number(field(object, "version")?)?;
    if version != VERSION {
        return Err(fault(format!(
            "program version is {version}, and this engine reads {VERSION}"
        )));
    }
    Ok(Program {
        statements: as_array(field(object, "statements")?)?
            .iter()
            .map(to_line)
            .collect::<Result<_, _>>()?,
        sentinels: as_array(field(object, "sentinels")?)?
            .iter()
            .map(to_sentinel)
            .collect::<Result<_, _>>()?,
    })
}

fn to_line(json: &Json) -> Result<CompiledLine, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "statement" => Ok(CompiledLine::Statement(CompiledStatement {
            steps: as_array(field(object, "steps")?)?
                .iter()
                .map(to_step)
                .collect::<Result<_, _>>()?,
        })),
        "iter" => Ok(CompiledLine::Iter(CompiledIter {
            query: to_query(field(object, "query")?)?,
            measure_name: as_str(field(object, "measure_name")?)?.to_string(),
            measure: to_measure(field(object, "measure")?)?,
            template: to_template(field(object, "template")?)?,
        })),
        other => Err(fault(format!("unknown statement kind {other:?}"))),
    }
}

/// A contracting statement's measure is a bare universe, not a tagged step.
fn to_measure(json: &Json) -> Result<Rc<UniverseNode>, JsonError> {
    to_universe(json)
}

fn to_step(json: &Json) -> Result<CompiledStep, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "query" => Ok(CompiledStep::Query(to_query(json)?)),
        "template" => Ok(CompiledStep::Template(to_template(json)?)),
        other => Err(fault(format!("unknown step kind {other:?}"))),
    }
}

/// Read a query step, requiring its tag: `iter` names one by position, so the
/// tag is what stops a template landing where a query belongs.
fn to_query(json: &Json) -> Result<CompiledQuery, JsonError> {
    let object = as_object(json)?;
    let kind = as_str(field(object, "kind")?)?;
    if kind != "query" {
        return Err(fault(format!("expected a query step, found {kind:?}")));
    }
    Ok(CompiledQuery {
        source: as_str(field(object, "source")?)?.to_string(),
        factors: as_array(field(object, "factors")?)?
            .iter()
            .map(to_factor)
            .collect::<Result<_, _>>()?,
    })
}

/// Read a template step, requiring its tag, for the same reason as above.
fn to_template(json: &Json) -> Result<CompiledTemplate, JsonError> {
    let object = as_object(json)?;
    let kind = as_str(field(object, "kind")?)?;
    if kind != "template" {
        return Err(fault(format!("expected a template step, found {kind:?}")));
    }
    Ok(CompiledTemplate {
        parts: as_array(field(object, "parts")?)?
            .iter()
            .map(to_part)
            .collect::<Result<_, _>>()?,
    })
}

fn to_factor(json: &Json) -> Result<QueryFactor, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "universe" => Ok(QueryFactor::Universe(to_universe(field(
            object, "universe",
        )?)?)),
        "slot" => Ok(QueryFactor::Late(LateSlot {
            slot: to_index(field(object, "slot")?)?,
            needs: as_array(field(object, "needs")?)?
                .iter()
                .map(to_index)
                .collect::<Result<_, _>>()?,
            reach: to_reach(field(object, "reach")?)?,
        })),
        other => Err(fault(format!("unknown factor kind {other:?}"))),
    }
}

fn to_part(json: &Json) -> Result<TemplatePart, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "text" => Ok(TemplatePart::Text(to_code_points(field(object, "text")?)?)),
        "capture" => Ok(TemplatePart::Capture(
            as_str(field(object, "capture")?)?.to_string(),
        )),
        "sentinel" => Ok(TemplatePart::Sentinel(
            as_str(field(object, "name")?)?.to_string(),
        )),
        other => Err(fault(format!("unknown template part kind {other:?}"))),
    }
}

fn to_sentinel(json: &Json) -> Result<Sentinel, JsonError> {
    let object = as_object(json)?;
    Ok(Sentinel {
        name: as_str(field(object, "name")?)?.to_string(),
        face: to_code_points(field(object, "face")?)?,
    })
}

/// A slot's reach is an integer or JSON `null` -- "no known bound", never a
/// guess, exactly the convention [`crate::floor::reach`] already follows.
fn to_reach(json: &Json) -> Result<Option<usize>, JsonError> {
    match json {
        Json::Null => Ok(None),
        _ => Ok(Some(to_index(json)?)),
    }
}

fn to_index(json: &Json) -> Result<usize, JsonError> {
    usize::try_from(as_number(json)?).map_err(|_| fault("index does not fit this host's usize"))
}

#[cfg(test)]
mod tests {
    use super::program_from_json;
    use crate::ir::program::{
        CompiledLine, CompiledStep, LateSlot, QueryFactor, TemplatePart, SENTINEL_BASE,
    };

    /// `{a} => "A"` as `hejmark emit-program` writes it.
    ///
    /// Every fixture in this module is verbatim compiler output. Hand-built JSON
    /// would test the reader against itself; this tests it against the only
    /// writer that exists.
    const REWRITE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, {"kind": "template", "parts": [{"kind": "text", "text": [65]}]}]}]}"#;

    #[test]
    fn a_two_step_statement_reads_back_as_a_query_and_a_template() {
        let program = program_from_json(REWRITE).unwrap();
        assert!(program.sentinels.is_empty());
        let CompiledLine::Statement(statement) = &program.statements[0] else {
            panic!("expected an ordinary statement");
        };
        assert!(matches!(statement.steps[0], CompiledStep::Query(_)));
        let CompiledStep::Template(template) = &statement.steps[1] else {
            panic!("expected a template step");
        };
        assert_eq!(template.parts, vec![TemplatePart::Text(vec![65])]);
        assert!(!program.is_late());
    }

    #[test]
    fn the_format_tag_is_checked_before_anything_is_read() {
        let json = REWRITE.replace("hejmark-program", "hejmark-query");
        let message = program_from_json(&json).unwrap_err().message;
        assert!(message.contains("not \"hejmark-program\""), "{message}");
    }

    #[test]
    fn a_future_version_is_refused_by_name_rather_than_half_read() {
        let json = REWRITE.replace("\"version\": 1", "\"version\": 2");
        let message = program_from_json(&json).unwrap_err().message;
        assert!(message.contains("program version is 2"), "{message}");
    }

    #[test]
    fn a_bare_query_is_not_a_program() {
        // What `emit-json` writes, handed to the reader for `emit-program`.
        let json = r#"{"universes": [{"members": [{"kind": "face", "text": [97]}]}]}"#;
        let message = program_from_json(json).unwrap_err().message;
        assert!(message.contains("missing field \"format\""), "{message}");
    }

    /// `{a}{$1} => "{{$1}}{{$2}}"` -- a back-reference, so a late slot.
    const BACK_REFERENCE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}, {"kind": "slot", "slot": 0, "needs": [1], "reach": 1}]}, {"kind": "template", "parts": [{"kind": "capture", "capture": "$1"}, {"kind": "capture", "capture": "$2"}]}]}]}"#;

    #[test]
    fn a_late_slot_decodes_faithfully_and_is_reported_as_late() {
        let program = program_from_json(BACK_REFERENCE).unwrap();
        let CompiledLine::Statement(statement) = &program.statements[0] else {
            panic!("expected an ordinary statement");
        };
        let CompiledStep::Query(query) = &statement.steps[0] else {
            panic!("expected a query step");
        };
        assert_eq!(
            query.factors[1],
            QueryFactor::Late(LateSlot {
                slot: 0,
                needs: vec![1],
                reach: Some(1),
            })
        );
        assert!(program.is_late());
    }

    #[test]
    fn an_unpriced_reach_arrives_as_json_null() {
        let json = BACK_REFERENCE.replace("\"reach\": 1", "\"reach\": null");
        let program = program_from_json(&json).unwrap();
        let CompiledLine::Statement(statement) = &program.statements[0] else {
            panic!("expected an ordinary statement");
        };
        let CompiledStep::Query(query) = &statement.steps[0] else {
            panic!("expected a query step");
        };
        assert_eq!(
            query.factors[1],
            QueryFactor::Late(LateSlot {
                slot: 0,
                needs: vec![1],
                reach: None,
            })
        );
    }

    /// A script declaring a sentinel and splicing it, verbatim:
    /// `sentinel mark` then `{a} => "{{@mark}}"`.
    const SENTINELS: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [{"name": "mark", "face": [64976]}], "statements": [{"kind": "statement", "steps": [{"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, {"kind": "template", "parts": [{"kind": "sentinel", "name": "mark"}]}]}]}"#;

    #[test]
    fn the_sentinel_table_carries_its_allocation() {
        let program = program_from_json(SENTINELS).unwrap();
        assert_eq!(program.sentinels[0].name, "mark");
        assert_eq!(program.sentinels[0].face, vec![SENTINEL_BASE]);
    }

    /// A contracting statement, verbatim: a two-letter bubble sort.
    ///
    /// `uni m = {a, b, &{a,b}}` then `{b}{a} <=>[@m] "{{$2}}{{$1}}"`, which takes
    /// `bbaa` to `aabb`. The measure is a bare universe rather than a tagged
    /// step, and the query and template are named by position -- so this fixture
    /// is what exercises the one place the tags are load-bearing.
    const BUBBLE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "iter", "query": {"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [98]}]}}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, "measure_name": "m", "measure": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}, {"kind": "product", "factors": [{"kind": "closure"}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]}}]}]}, "template": {"kind": "template", "parts": [{"kind": "capture", "capture": "$2"}, {"kind": "capture", "capture": "$1"}]}}]}"#;

    #[test]
    fn a_contracting_statement_reads_back_with_its_measure_denoted_as_a_universe() {
        let program = program_from_json(BUBBLE).unwrap();
        let CompiledLine::Iter(iter) = &program.statements[0] else {
            panic!("expected a contracting statement");
        };
        assert_eq!(iter.measure_name, "m");
        assert_eq!(iter.measure.members.len(), 3);
        assert_eq!(iter.query.factors.len(), 2);
        assert_eq!(
            iter.template.parts,
            vec![
                TemplatePart::Capture("$2".to_string()),
                TemplatePart::Capture("$1".to_string()),
            ]
        );
    }

    #[test]
    fn a_template_where_a_query_belongs_is_refused_by_its_tag() {
        // `iter` names its query by position, so only the tag stops a template
        // from landing there -- which is why `to_query` checks it at all.
        let json = BUBBLE.replacen(r#""kind": "query""#, r#""kind": "template""#, 1);
        let message = program_from_json(&json).unwrap_err().message;
        assert!(
            message.contains("expected a query step, found \"template\""),
            "{message}"
        );
    }

    #[test]
    fn an_unknown_statement_kind_is_reported() {
        let json = REWRITE.replace(r#""kind": "statement""#, r#""kind": "loop""#);
        let message = program_from_json(&json).unwrap_err().message;
        assert!(
            message.contains("unknown statement kind \"loop\""),
            "{message}"
        );
    }
}
