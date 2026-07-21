//! Load a floor AST from JSON, the portable hand-off from a host that can parse.
//!
//! This crate denotes and matches the floor AST but does not parse Himark source
//! -- the Python package owns the ANTLR grammar and the surface expansion. So the
//! division of labor is: Python parses source and expands it down to the floor's
//! six constructors, emits that floor AST as JSON, and this module reads the JSON
//! back into [`UniverseNode`] / [`QueryNode`] for [`super::universe::denote`].
//!
//! The schema is a tagged mirror of [`super::syntax`]. Spellings are arrays of
//! code points (integers `0..=0x10FFFF`), not JSON strings, so lone surrogates
//! survive exactly as they do in the rest of the crate:
//!
//! ```json
//! Query      = { "universes": [UniverseNode, ...] }
//! UniverseNode = { "members": [Member, ...] }
//! Member =
//!     { "kind": "face",     "text": [int, ...] }
//!   | { "kind": "range",    "lo": int, "hi": int }
//!   | { "kind": "final",    "lo": [int, ...] }
//!   | { "kind": "fold",     "universe": UniverseNode }
//!   | { "kind": "subtract", "universe": UniverseNode }
//!   | { "kind": "product",  "factors": [Factor, ...] }
//!   | { "kind": "closure" }
//! Factor =
//!     { "kind": "universe", "universe": UniverseNode }
//!   | { "kind": "closure" }
//! ```
//!
//! A dependency-free JSON reader keeps the crate's zero-dependency footprint;
//! the schema is small enough that a scoped reader is less risk than a general
//! one, and the emitter on the Python side writes exactly this shape.

use std::fmt;
use std::rc::Rc;

use super::syntax::{Factor, Member, QueryNode, UniverseNode};

/// The greatest code point a spelling may carry.
const MAX_CODE_POINT: u64 = 0x10FFFF;

/// Describes why a JSON document is not a valid floor AST.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JsonError {
    /// A human-readable description of the fault.
    pub message: String,
}

impl fmt::Display for JsonError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for JsonError {}

fn fault(message: impl Into<String>) -> JsonError {
    JsonError {
        message: message.into(),
    }
}

/// Read a whole query (a product of universes) from its JSON encoding.
///
/// # Errors
///
/// Returns a [`JsonError`] on malformed JSON or a document that does not match
/// the floor schema.
pub fn query_from_json(text: &str) -> Result<QueryNode, JsonError> {
    to_query(&parse(text)?)
}

/// Read a single universe from its JSON encoding.
///
/// # Errors
///
/// Returns a [`JsonError`] on malformed JSON or a document that does not match
/// the floor schema.
pub fn universe_from_json(text: &str) -> Result<Rc<UniverseNode>, JsonError> {
    to_universe(&parse(text)?)
}

// --- schema interpretation -------------------------------------------------

fn to_query(json: &Json) -> Result<QueryNode, JsonError> {
    let object = as_object(json)?;
    let universes = as_array(field(object, "universes")?)?
        .iter()
        .map(to_universe)
        .collect::<Result<_, _>>()?;
    Ok(QueryNode { universes })
}

/// Every nested node is decoded straight into an [`Rc`], so the tree the engine
/// denotes is the tree it keys its memos on -- see [`super::universe`].
fn to_universe(json: &Json) -> Result<Rc<UniverseNode>, JsonError> {
    let object = as_object(json)?;
    let members = as_array(field(object, "members")?)?
        .iter()
        .map(to_member)
        .collect::<Result<_, _>>()?;
    Ok(Rc::new(UniverseNode { members }))
}

fn to_member(json: &Json) -> Result<Member, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "face" => Ok(Member::Face(to_code_points(field(object, "text")?)?)),
        "range" => Ok(Member::Range {
            lo: to_code_point(field(object, "lo")?)?,
            hi: to_code_point(field(object, "hi")?)?,
        }),
        "final" => Ok(Member::Final(to_code_points(field(object, "lo")?)?)),
        "fold" => Ok(Member::Fold(to_universe(field(object, "universe")?)?)),
        "subtract" => Ok(Member::Subtract(to_universe(field(object, "universe")?)?)),
        "product" => Ok(Member::Product(
            as_array(field(object, "factors")?)?
                .iter()
                .map(to_factor)
                .collect::<Result<_, _>>()?,
        )),
        "closure" => Ok(Member::Closure),
        other => Err(fault(format!("unknown member kind {other:?}"))),
    }
}

fn to_factor(json: &Json) -> Result<Factor, JsonError> {
    let object = as_object(json)?;
    match as_str(field(object, "kind")?)? {
        "universe" => Ok(Factor::Universe(to_universe(field(object, "universe")?)?)),
        "closure" => Ok(Factor::Closure),
        other => Err(fault(format!("unknown factor kind {other:?}"))),
    }
}

fn to_code_points(json: &Json) -> Result<Vec<u32>, JsonError> {
    as_array(json)?.iter().map(to_code_point).collect()
}

fn to_code_point(json: &Json) -> Result<u32, JsonError> {
    let value = as_number(json)?;
    if value > MAX_CODE_POINT {
        return Err(fault(format!("code point {value} exceeds U+10FFFF")));
    }
    Ok(value as u32)
}

fn field<'a>(object: &'a [(String, Json)], key: &str) -> Result<&'a Json, JsonError> {
    object
        .iter()
        .find(|(name, _)| name == key)
        .map(|(_, value)| value)
        .ok_or_else(|| fault(format!("missing field {key:?}")))
}

fn as_object(json: &Json) -> Result<&[(String, Json)], JsonError> {
    match json {
        Json::Object(fields) => Ok(fields),
        _ => Err(fault("expected an object")),
    }
}

fn as_array(json: &Json) -> Result<&[Json], JsonError> {
    match json {
        Json::Array(items) => Ok(items),
        _ => Err(fault("expected an array")),
    }
}

fn as_str(json: &Json) -> Result<&str, JsonError> {
    match json {
        Json::Str(text) => Ok(text),
        _ => Err(fault("expected a string")),
    }
}

fn as_number(json: &Json) -> Result<u64, JsonError> {
    match json {
        Json::Number(value) => Ok(*value),
        _ => Err(fault("expected a non-negative integer")),
    }
}

// --- a minimal JSON reader -------------------------------------------------

/// The subset of JSON the floor schema uses.
enum Json {
    Number(u64),
    Str(String),
    Array(Vec<Json>),
    Object(Vec<(String, Json)>),
}

fn parse(text: &str) -> Result<Json, JsonError> {
    let mut reader = Reader {
        chars: text.chars().collect(),
        pos: 0,
    };
    reader.skip_whitespace();
    let value = reader.value()?;
    reader.skip_whitespace();
    if reader.peek().is_some() {
        return Err(fault("trailing characters after the JSON value"));
    }
    Ok(value)
}

struct Reader {
    chars: Vec<char>,
    pos: usize,
}

impl Reader {
    fn peek(&self) -> Option<char> {
        self.chars.get(self.pos).copied()
    }

    fn bump(&mut self) -> Option<char> {
        let current = self.peek();
        if current.is_some() {
            self.pos += 1;
        }
        current
    }

    fn skip_whitespace(&mut self) {
        while matches!(self.peek(), Some(' ' | '\t' | '\n' | '\r')) {
            self.pos += 1;
        }
    }

    fn expect(&mut self, expected: char) -> Result<(), JsonError> {
        match self.bump() {
            Some(found) if found == expected => Ok(()),
            _ => Err(fault(format!("expected {expected:?}"))),
        }
    }

    fn value(&mut self) -> Result<Json, JsonError> {
        self.skip_whitespace();
        match self.peek() {
            Some('{') => self.object(),
            Some('[') => self.array(),
            Some('"') => Ok(Json::Str(self.string()?)),
            Some(c) if c.is_ascii_digit() => self.number(),
            _ => Err(fault("expected a JSON value")),
        }
    }

    fn object(&mut self) -> Result<Json, JsonError> {
        self.expect('{')?;
        let mut fields = Vec::new();
        self.skip_whitespace();
        if self.peek() == Some('}') {
            self.pos += 1;
            return Ok(Json::Object(fields));
        }
        loop {
            self.skip_whitespace();
            let key = self.string()?;
            self.skip_whitespace();
            self.expect(':')?;
            let value = self.value()?;
            fields.push((key, value));
            self.skip_whitespace();
            match self.bump() {
                Some(',') => {}
                Some('}') => return Ok(Json::Object(fields)),
                _ => return Err(fault("expected ',' or '}' in object")),
            }
        }
    }

    fn array(&mut self) -> Result<Json, JsonError> {
        self.expect('[')?;
        let mut items = Vec::new();
        self.skip_whitespace();
        if self.peek() == Some(']') {
            self.pos += 1;
            return Ok(Json::Array(items));
        }
        loop {
            items.push(self.value()?);
            self.skip_whitespace();
            match self.bump() {
                Some(',') => {}
                Some(']') => return Ok(Json::Array(items)),
                _ => return Err(fault("expected ',' or ']' in array")),
            }
        }
    }

    fn string(&mut self) -> Result<String, JsonError> {
        self.expect('"')?;
        let mut text = String::new();
        loop {
            match self.bump() {
                Some('"') => return Ok(text),
                Some('\\') => text.push(self.escape()?),
                Some(c) => text.push(c),
                None => return Err(fault("unterminated string")),
            }
        }
    }

    fn escape(&mut self) -> Result<char, JsonError> {
        match self.bump() {
            Some('"') => Ok('"'),
            Some('\\') => Ok('\\'),
            Some('/') => Ok('/'),
            Some('n') => Ok('\n'),
            Some('t') => Ok('\t'),
            Some('r') => Ok('\r'),
            Some('b') => Ok('\u{8}'),
            Some('f') => Ok('\u{c}'),
            Some('u') => self.unicode_escape(),
            _ => Err(fault("invalid string escape")),
        }
    }

    fn unicode_escape(&mut self) -> Result<char, JsonError> {
        let mut value: u32 = 0;
        for _ in 0..4 {
            let digit = self
                .bump()
                .and_then(|c| c.to_digit(16))
                .ok_or_else(|| fault("invalid \\u escape"))?;
            value = value * 16 + digit;
        }
        char::from_u32(value).ok_or_else(|| fault("invalid \\u escape"))
    }

    fn number(&mut self) -> Result<Json, JsonError> {
        let mut value: u64 = 0;
        let mut digits = 0;
        while let Some(c) = self.peek() {
            let Some(digit) = c.to_digit(10) else { break };
            value = value
                .checked_mul(10)
                .and_then(|scaled| scaled.checked_add(u64::from(digit)))
                .ok_or_else(|| fault("integer overflow"))?;
            digits += 1;
            self.pos += 1;
        }
        if digits == 0 {
            return Err(fault("expected a digit"));
        }
        Ok(Json::Number(value))
    }
}

#[cfg(test)]
mod tests {
    use super::{query_from_json, universe_from_json, JsonError};
    use crate::floor::syntax::{Factor, Member, UniverseNode};
    use crate::floor::universe::denote;

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    use std::rc::Rc;

    /// Nested positions hold shared nodes, and `&Rc<T>` coerces to `&T`, so one
    /// helper serves both.
    fn node(members: Vec<Member>) -> Rc<UniverseNode> {
        Rc::new(UniverseNode { members })
    }

    #[test]
    fn every_member_kind_round_trips_to_the_hand_built_ast() {
        // fold, range, final, subtract, product-with-closure, closure, face -- one of each.
        let json = r#"
            { "members": [
                { "kind": "face", "text": [97, 98] },
                { "kind": "range", "lo": 48, "hi": 57 },
                { "kind": "final", "lo": [121] },
                { "kind": "fold", "universe": { "members": [ { "kind": "face", "text": [120] } ] } },
                { "kind": "subtract", "universe": { "members": [ { "kind": "face", "text": [98] } ] } },
                { "kind": "product", "factors": [
                    { "kind": "closure" },
                    { "kind": "universe", "universe": { "members": [ { "kind": "face", "text": [98] } ] } }
                ] },
                { "kind": "closure" }
            ] }
        "#;
        let expected = node(vec![
            Member::Face(cp("ab")),
            Member::Range { lo: 48, hi: 57 },
            Member::Final(cp("y")),
            Member::Fold(node(vec![Member::Face(cp("x"))])),
            Member::Subtract(node(vec![Member::Face(cp("b"))])),
            Member::Product(vec![
                Factor::Closure,
                Factor::Universe(node(vec![Member::Face(cp("b"))])),
            ]),
            Member::Closure,
        ]);
        assert_eq!(universe_from_json(json).unwrap(), expected);
    }

    #[test]
    fn a_denoted_json_universe_enumerates_like_its_source() {
        // {a, &{b}} in JSON: closure a, ab, abb, ...
        let json = r#"
            { "members": [
                { "kind": "face", "text": [97] },
                { "kind": "product", "factors": [
                    { "kind": "closure" },
                    { "kind": "universe", "universe": { "members": [ { "kind": "face", "text": [98] } ] } }
                ] }
            ] }
        "#;
        let universe = denote(&universe_from_json(json).unwrap());
        let faces: Vec<Vec<u32>> = universe
            .entries()
            .take(3)
            .map(|e| e.faces[0].clone())
            .collect();
        assert_eq!(faces, vec![cp("a"), cp("ab"), cp("abb")]);
    }

    #[test]
    fn a_query_reads_one_universe_per_factor() {
        let json = r#"
            { "universes": [
                { "members": [ { "kind": "face", "text": [97] }, { "kind": "face", "text": [97, 98] } ] },
                { "members": [ { "kind": "face", "text": [99] }, { "kind": "face", "text": [98, 99] } ] }
            ] }
        "#;
        let query = query_from_json(json).unwrap();
        assert_eq!(query.universes.len(), 2);
        assert_eq!(
            query.universes[0],
            node(vec![Member::Face(cp("a")), Member::Face(cp("ab"))])
        );
    }

    fn message(result: Result<Rc<UniverseNode>, JsonError>) -> String {
        result.unwrap_err().message
    }

    #[test]
    fn an_unknown_kind_is_reported() {
        let json = r#"{ "members": [ { "kind": "quotient" } ] }"#;
        assert!(message(universe_from_json(json)).contains("unknown member kind"));
    }

    #[test]
    fn a_missing_field_is_reported() {
        let json = r#"{ "members": [ { "kind": "face" } ] }"#;
        assert!(message(universe_from_json(json)).contains("missing field \"text\""));
    }

    #[test]
    fn a_code_point_past_the_maximum_is_reported() {
        let json = r#"{ "members": [ { "kind": "face", "text": [1114112] } ] }"#;
        assert!(message(universe_from_json(json)).contains("exceeds U+10FFFF"));
    }

    #[test]
    fn trailing_characters_are_reported() {
        let json = r#"{ "members": [] } oops"#;
        assert!(message(universe_from_json(json)).contains("trailing characters"));
    }
}
