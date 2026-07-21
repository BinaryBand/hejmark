//! A floor-subset parser: Himark source text straight to the floor AST.
//!
//! This is **not** the L1.5 parser. The Python compiler lexes with a five-mode
//! ANTLR grammar and expands names, definitions, pipelines, registers and
//! exponents down to the floor's six constructors; that whole pipeline is still
//! an unported slice, and `hejmark emit-json` remains the reference hand-off.
//!
//! What this module ports is the fragment a host can parse without any of that
//! machinery: the brace syntax whose constructs *are already* the six
//! constructors, plus the two surface conveniences that expand with no
//! environment to consult -- the exponent `^n`, which is a product written
//! short, and the `@name` splice, resolved against the small table in
//! [`super::std`]. Everything else -- pipelines `[...]`, definitions, registers,
//! back-references -- is refused by name, so a caller can tell "this device
//! cannot compile that" from "that is not Himark".
//!
//! It exists because the floor engine alone cannot serve a host that has no
//! Python to lean on: [`crate::floor::json`] reads a query someone else already
//! compiled. A phone has no `emit-json` to call, so the fragment a user actually
//! types into an editor -- ranges, unions, products, exponents, `@hex` -- is
//! parsed here and matched by the same [`crate::scan`] the desktop uses.
//!
//! The lowering mirrors the Python's observable output rather than reimplementing
//! its reasoning: every shape this accepts was read off `emit-json` and is pinned
//! by the tests below. Where the two disagree the Python is right.

use std::rc::Rc;

use crate::floor::syntax::{Factor, HimarkSyntaxError, Member, QueryNode, UniverseNode};
use crate::surface::std::resolve;

/// The characters BRACES mode carves out of the face alphabet.
///
/// Spell any of them with a leading `\`. Whitespace is carved out too, and is
/// handled separately because it is skipped rather than refused.
const RESERVED: &str = "{}[],!.\\&@_^$\":";

/// The largest exponent this parser will expand.
///
/// `^n` is a product written short, so the expansion is literally `n` copies of
/// the operand; an unbounded count would let one keystroke ask for a tree that
/// does not fit in memory. The floor's work budget prices *matching*, not
/// parsing, so this is the parser's own guard rather than a duplicate of it.
const MAX_EXPONENT: usize = 1024;

/// The deepest brace nesting this parser will descend.
///
/// The descent is recursive and Rust does not budget its stack, so a source of
/// nothing but `{` would abort the process rather than raise. This turns that
/// into an ordinary syntax error.
const MAX_DEPTH: usize = 64;

/// One operand of a member sequence, before exponents and splices are lowered.
///
/// The distinction this carries that the floor AST does not is *how the operand
/// was written*, which is what decides its lowering: a brace group standing
/// alone folds, whereas a splice standing alone inlines its members.
enum Base {
    /// A brace group `{...}`.
    Group(Rc<UniverseNode>),
    /// A `@name` splice, already resolved to the node it names.
    Splice(Rc<UniverseNode>),
    /// A `!{...}` subtraction.
    Subtract(Rc<UniverseNode>),
    /// The self-reference token `&`.
    Closure,
    /// A literal face, range or final segment.
    Literal(Member),
}

/// Why a source did not parse -- and, load-bearingly, whose fault that is.
///
/// The two arms are not decoration: a host that can reach the full compiler
/// should retry an [`Unported`](ParseRefusal::Unported) source there and must
/// not retry a [`Syntax`](ParseRefusal::Syntax) one, because the full compiler
/// would refuse it too. Collapsing both into one message would leave that
/// decision to be made by reading English, which is not a boundary.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParseRefusal {
    /// The source is not well-formed Himark. Nothing will compile it.
    Syntax(HimarkSyntaxError),
    /// Well-formed Himark outside the floor subset. The full compiler takes it.
    Unported(String),
}

impl ParseRefusal {
    /// The human-readable reason, whichever arm this is.
    pub fn message(&self) -> &str {
        match self {
            ParseRefusal::Syntax(error) => &error.message,
            ParseRefusal::Unported(message) => message,
        }
    }
}

/// Parses one query expression -- the whole of what the GUI calls a rule.
///
/// # Errors
///
/// Returns [`ParseRefusal::Syntax`] for malformed source and
/// [`ParseRefusal::Unported`] for well-formed L1.5 outside the floor subset --
/// a pipeline, a back-reference, an unresolvable `@name`.
pub fn parse_query(source: &str) -> Result<QueryNode, ParseRefusal> {
    let mut parser = Parser {
        chars: source.chars().collect(),
        pos: 0,
        depth: 0,
    };
    let query = parser.query()?;
    Ok(query)
}

struct Parser {
    chars: Vec<char>,
    pos: usize,
    depth: usize,
}

impl Parser {
    fn error<T>(&self, message: impl Into<String>) -> Result<T, ParseRefusal> {
        Err(ParseRefusal::Syntax(HimarkSyntaxError {
            message: format!("{} (at character {})", message.into(), self.pos + 1),
        }))
    }

    /// A refusal the full compiler would not share: well-formed Himark this
    /// parser does not reach.
    fn unported<T>(&self, message: impl Into<String>) -> Result<T, ParseRefusal> {
        Err(ParseRefusal::Unported(message.into()))
    }

    fn peek(&self) -> Option<char> {
        self.chars.get(self.pos).copied()
    }

    fn bump(&mut self) -> Option<char> {
        let next = self.peek();
        if next.is_some() {
            self.pos += 1;
        }
        next
    }

    fn skip_space(&mut self) {
        while self.peek().is_some_and(char::is_whitespace) {
            self.pos += 1;
        }
    }

    /// `query := unit+` -- juxtaposed units, each denoting one universe.
    ///
    /// Juxtaposition at the top level is the *query's* product, not a member's:
    /// `{a}{b}` is two universes, where the same spelling inside braces is one
    /// [`Member::Product`].
    fn query(&mut self) -> Result<QueryNode, ParseRefusal> {
        let mut universes = Vec::new();
        self.skip_space();
        while self.peek().is_some() {
            universes.push(self.top_unit()?);
            self.skip_space();
        }
        if universes.is_empty() {
            return self.error("a query needs at least one brace group");
        }
        Ok(QueryNode { universes })
    }

    fn top_unit(&mut self) -> Result<Rc<UniverseNode>, ParseRefusal> {
        let base = self.base()?;
        let count = self.exponent(&base)?;
        // A group or splice written plain *is* the universe -- it does not fold,
        // which is the one place the top level differs from a member position.
        if count == 1 {
            if let Base::Group(node) | Base::Splice(node) = &base {
                return Ok(node.clone());
            }
        }
        if matches!(base, Base::Literal(_)) {
            return self.error("a bare face needs braces around it");
        }
        let members = lower(&[(base, count)]);
        Ok(Rc::new(UniverseNode { members }))
    }

    /// `group := '{' [member (',' member)*] '}'`, the opening brace consumed.
    fn group_body(&mut self) -> Result<Rc<UniverseNode>, ParseRefusal> {
        let mut members = Vec::new();
        self.skip_space();
        if self.peek() == Some('}') {
            self.bump();
            return Ok(Rc::new(UniverseNode { members }));
        }
        loop {
            let terms = self.terms()?;
            if terms.is_empty() {
                return self.error("a brace group has an empty member");
            }
            members.extend(lower(&terms));
            self.skip_space();
            match self.bump() {
                Some(',') => continue,
                Some('}') => break,
                Some(found) => return self.error(format!("unexpected '{found}' in a brace group")),
                None => return self.error("unclosed brace group"),
            }
        }
        Ok(Rc::new(UniverseNode { members }))
    }

    /// One member: a run of adjacent operands, up to a `,` or the closing brace.
    fn terms(&mut self) -> Result<Vec<(Base, usize)>, ParseRefusal> {
        let mut terms = Vec::new();
        loop {
            self.skip_space();
            if matches!(self.peek(), None | Some(',') | Some('}')) {
                break;
            }
            let base = self.base()?;
            let count = self.exponent(&base)?;
            terms.push((base, count));
        }
        Ok(terms)
    }

    fn base(&mut self) -> Result<Base, ParseRefusal> {
        self.skip_space();
        match self.peek() {
            None => self.error("unexpected end of query"),
            Some('{') => {
                self.bump();
                Ok(Base::Group(self.nested()?))
            }
            Some('!') => {
                self.bump();
                self.skip_space();
                if self.bump() != Some('{') {
                    return self
                        .error("'!' subtracts a brace group, so it must be followed by '{'");
                }
                Ok(Base::Subtract(self.nested()?))
            }
            Some('&') => {
                self.bump();
                Ok(Base::Closure)
            }
            Some('@') => {
                self.bump();
                let name = self.name();
                if name.is_empty() {
                    return self.error("'@' needs a name after it");
                }
                match resolve(&name) {
                    Some(node) => Ok(Base::Splice(node)),
                    None => self.unported(unknown_name(&name)),
                }
            }
            Some('.') => {
                self.error("'..' needs a lower endpoint before it; a literal '.' is spelled '\\.'")
            }
            Some(found) => match unported_construct(found) {
                Some(reason) => self.unported(reason),
                None => Ok(Base::Literal(self.literal()?)),
            },
        }
    }

    /// Descends into a brace group, keeping the recursion inside [`MAX_DEPTH`].
    fn nested(&mut self) -> Result<Rc<UniverseNode>, ParseRefusal> {
        if self.depth >= MAX_DEPTH {
            return self.error(format!("braces nest deeper than {MAX_DEPTH}"));
        }
        self.depth += 1;
        let node = self.group_body();
        self.depth -= 1;
        node
    }

    /// `'^' digits`, or nothing. Only a group or a splice may carry one.
    fn exponent(&mut self, base: &Base) -> Result<usize, ParseRefusal> {
        self.skip_space();
        if self.peek() != Some('^') {
            return Ok(1);
        }
        if !matches!(base, Base::Group(_) | Base::Splice(_)) {
            return self.error("'^' repeats a brace group or a name, and nothing else");
        }
        self.bump();
        self.skip_space();
        let mut digits = String::new();
        while self.peek().is_some_and(|c| c.is_ascii_digit()) {
            digits.push(self.bump().unwrap_or_default());
        }
        if digits.is_empty() {
            return self.error("'^' needs a decimal count after it");
        }
        match digits.parse::<usize>() {
            Ok(count) if count <= MAX_EXPONENT => Ok(count),
            _ => self.error(format!("an exponent may not exceed {MAX_EXPONENT}")),
        }
    }

    fn name(&mut self) -> String {
        let mut name = String::new();
        while self
            .peek()
            .is_some_and(|c| c.is_ascii_alphanumeric() || c == '_')
        {
            name.push(self.bump().unwrap_or_default());
        }
        name
    }

    /// A face, a range `lo..hi`, or a final segment `lo..`.
    fn literal(&mut self) -> Result<Member, ParseRefusal> {
        let lo = self.face()?;
        if !self.at_range_mark() {
            return Ok(Member::Face(lo));
        }
        self.pos += 2;
        let hi = self.face()?;
        if hi.is_empty() {
            return Ok(Member::Final(lo));
        }
        match (lo.as_slice(), hi.as_slice()) {
            ([lo], [hi]) => Ok(Member::Range { lo: *lo, hi: *hi }),
            _ => self.error("a range runs between single characters"),
        }
    }

    fn at_range_mark(&self) -> bool {
        self.chars.get(self.pos) == Some(&'.') && self.chars.get(self.pos + 1) == Some(&'.')
    }

    /// A run of face characters, with escapes resolved to their code points.
    ///
    /// Whitespace inside a run is skipped rather than spelled -- it is
    /// insignificant inside braces, which is exactly why `\n`, `\t` and `\r`
    /// exist as the only way to spell it.
    fn face(&mut self) -> Result<Vec<u32>, ParseRefusal> {
        let mut spelling = Vec::new();
        loop {
            self.skip_space();
            match self.peek() {
                Some('\\') => {
                    self.bump();
                    match self.bump() {
                        None => return self.error("a trailing '\\' escapes nothing"),
                        Some('n') => spelling.push(u32::from('\n')),
                        Some('t') => spelling.push(u32::from('\t')),
                        Some('r') => spelling.push(u32::from('\r')),
                        Some(escaped) => spelling.push(escaped as u32),
                    }
                }
                Some(found) if !RESERVED.contains(found) => {
                    spelling.push(found as u32);
                    self.bump();
                }
                _ => break,
            }
        }
        Ok(spelling)
    }
}

/// The L1.5 construct a character opens, when it opens one this parser does not
/// reach.
///
/// Naming the construct is the point: a host that cannot compile a pipeline can
/// say so and offer the full compiler, which it cannot do from "unexpected '['".
fn unported_construct(found: char) -> Option<&'static str> {
    match found {
        '[' | ']' => Some("a pipeline ([...]) needs the full compiler"),
        '$' => Some("a back-reference ($n) needs the full compiler"),
        '_' => Some("a register (_) needs the full compiler"),
        '"' => Some("a template needs the full compiler"),
        ':' => Some("a definition (:=) needs the full compiler"),
        _ => None,
    }
}

fn unknown_name(name: &str) -> String {
    format!(
        "unknown name @{name}: the on-device subset resolves only {}",
        crate::surface::std::names().join(", ")
    )
}

/// Lowers one member's operand run to the floor members it denotes.
///
/// Returns a vector because a splice standing alone contributes its node's
/// members *in place* rather than one member of its own -- `{@hex}` is
/// `{0..9,a..f}`, where `{{a}}` is a fold. That asymmetry is the surface's, and
/// it is the only reason this is not a one-member function.
fn lower(terms: &[(Base, usize)]) -> Vec<Member> {
    if let [(base, 1)] = terms {
        return match base {
            Base::Splice(node) => node.members.clone(),
            Base::Group(node) => vec![Member::Fold(node.clone())],
            Base::Subtract(node) => vec![Member::Subtract(node.clone())],
            Base::Closure => vec![Member::Closure],
            Base::Literal(member) => vec![member.clone()],
        };
    }
    let mut factors = Vec::new();
    for (base, count) in terms {
        let factor = factor_of(base);
        factors.extend(std::iter::repeat_n(factor, *count));
    }
    if factors.is_empty() {
        // A product of no factors spells the empty face, which the floor writes
        // as a fold of the empty universe -- `{a}^0`, verbatim from `emit-json`.
        return vec![Member::Fold(Rc::new(UniverseNode {
            members: Vec::new(),
        }))];
    }
    vec![Member::Product(factors)]
}

/// The operand as one factor of a product. Everything but `&` wears a universe,
/// and a literal gets a one-member universe wrapped around it.
fn factor_of(base: &Base) -> Factor {
    match base {
        Base::Closure => Factor::Closure,
        Base::Group(node) | Base::Splice(node) => Factor::Universe(node.clone()),
        Base::Subtract(node) => Factor::Universe(Rc::new(UniverseNode {
            members: vec![Member::Subtract(node.clone())],
        })),
        Base::Literal(member) => Factor::Universe(Rc::new(UniverseNode {
            members: vec![member.clone()],
        })),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::floor::json::query_from_json;

    /// Every expectation here is `hejmark emit-json`'s actual output for the
    /// same source, so the two parsers are pinned to each other by construction.
    fn same(source: &str, emitted: &str) {
        let ours = parse_query(source).expect("source should parse");
        let theirs = query_from_json(emitted).expect("reference JSON should read");
        assert_eq!(ours, theirs, "diverged on {source}");
    }

    fn refused(source: &str) -> String {
        parse_query(source)
            .expect_err("source should be refused")
            .message()
            .to_string()
    }

    /// Refusals a host should retry against the full compiler, and refusals it
    /// must not -- the distinction the FFI protocol carries as its own status.
    fn arm(source: &str) -> ParseRefusal {
        parse_query(source).expect_err("source should be refused")
    }

    #[test]
    fn union_of_faces() {
        same(
            "{a,b}",
            r#"{"universes":[{"members":[{"kind":"face","text":[97]},
               {"kind":"face","text":[98]}]}]}"#,
        );
    }

    #[test]
    fn whitespace_inside_braces_is_insignificant() {
        same(
            "{ a , b }",
            r#"{"universes":[{"members":[{"kind":"face","text":[97]},
               {"kind":"face","text":[98]}]}]}"#,
        );
    }

    #[test]
    fn ranges_and_final_segments() {
        same(
            "{a..z,A..Z}",
            r#"{"universes":[{"members":[{"kind":"range","lo":97,"hi":122},
               {"kind":"range","lo":65,"hi":90}]}]}"#,
        );
        same(
            "{ab..}",
            r#"{"universes":[{"members":[{"kind":"final","lo":[97,98]}]}]}"#,
        );
    }

    #[test]
    fn a_lone_group_folds_but_a_lone_splice_inlines() {
        same(
            "{{a}}",
            r#"{"universes":[{"members":[{"kind":"fold","universe":
               {"members":[{"kind":"face","text":[97]}]}}]}]}"#,
        );
        same(
            "{@hex}",
            r#"{"universes":[{"members":[{"kind":"range","lo":48,"hi":57},
               {"kind":"range","lo":97,"hi":102}]}]}"#,
        );
    }

    #[test]
    fn adjacency_inside_braces_is_a_product() {
        same(
            "{a{b}}",
            r#"{"universes":[{"members":[{"kind":"product","factors":[
               {"kind":"universe","universe":{"members":[{"kind":"face","text":[97]}]}},
               {"kind":"universe","universe":{"members":[{"kind":"face","text":[98]}]}}]}]}]}"#,
        );
    }

    #[test]
    fn juxtaposition_at_the_top_level_is_separate_universes() {
        same(
            "{a..z}{0..9}",
            r#"{"universes":[{"members":[{"kind":"range","lo":97,"hi":122}]},
               {"members":[{"kind":"range","lo":48,"hi":57}]}]}"#,
        );
    }

    #[test]
    fn closure_is_a_product_factor() {
        same(
            "{ab,{a}&{b}}",
            r#"{"universes":[{"members":[{"kind":"face","text":[97,98]},
               {"kind":"product","factors":[
                 {"kind":"universe","universe":{"members":[{"kind":"face","text":[97]}]}},
                 {"kind":"closure"},
                 {"kind":"universe","universe":{"members":[{"kind":"face","text":[98]}]}}]}]}]}"#,
        );
    }

    #[test]
    fn subtraction_reads_as_its_own_member() {
        same(
            "{a,!{b}}",
            r#"{"universes":[{"members":[{"kind":"face","text":[97]},
               {"kind":"subtract","universe":{"members":[{"kind":"face","text":[98]}]}}]}]}"#,
        );
    }

    #[test]
    fn an_exponent_is_a_product_written_short() {
        same(
            "{a,b}^2",
            r#"{"universes":[{"members":[{"kind":"product","factors":[
               {"kind":"universe","universe":{"members":[
                 {"kind":"face","text":[97]},{"kind":"face","text":[98]}]}},
               {"kind":"universe","universe":{"members":[
                 {"kind":"face","text":[97]},{"kind":"face","text":[98]}]}}]}]}]}"#,
        );
    }

    #[test]
    fn an_exponent_of_one_repeats_nothing_and_of_zero_spells_the_empty_face() {
        same(
            "{a}^1",
            r#"{"universes":[{"members":[{"kind":"face","text":[97]}]}]}"#,
        );
        same(
            "{a}^0",
            r#"{"universes":[{"members":[{"kind":"fold","universe":{"members":[]}}]}]}"#,
        );
    }

    #[test]
    fn escapes_spell_the_reserved_characters() {
        same(
            r"{\#}",
            r#"{"universes":[{"members":[{"kind":"face","text":[35]}]}]}"#,
        );
        same(
            r"{\\}",
            r#"{"universes":[{"members":[{"kind":"face","text":[92]}]}]}"#,
        );
        same(
            r"{a\nb}",
            r#"{"universes":[{"members":[{"kind":"face","text":[97,10,98]}]}]}"#,
        );
    }

    #[test]
    fn the_empty_group_denotes_nothing_but_parses() {
        same(r"{}", r#"{"universes":[{"members":[]}]}"#);
    }

    #[test]
    fn the_seeded_hex_colour_rule_matches_emit_json() {
        let hex = r#"{"members":[{"kind":"range","lo":48,"hi":57},
                      {"kind":"range","lo":97,"hi":102}]}"#;
        let six = [hex; 6]
            .map(|node| format!(r#"{{"kind":"universe","universe":{node}}}"#))
            .join(",");
        same(
            r"{\#}{@hex}^6",
            &format!(
                r#"{{"universes":[{{"members":[{{"kind":"face","text":[35]}}]}},
                   {{"members":[{{"kind":"product","factors":[{six}]}}]}}]}}"#
            ),
        );
    }

    #[test]
    fn unported_constructs_are_refused_by_name() {
        assert!(refused("{a}[shorter 2]").contains("pipeline"));
        assert!(refused("{$1}").contains("back-reference"));
        assert!(refused(r#"{"x"}"#).contains("template"));
        assert!(refused("{@nope}").contains("unknown name @nope"));
    }

    #[test]
    fn a_refusal_says_whether_the_full_compiler_would_take_it() {
        // Well-formed L1.5 this parser does not reach: retrying is worthwhile.
        for source in ["{a}[shorter 2]", "{$1}", "{@nope}", r#"{"x"}"#] {
            assert!(
                matches!(arm(source), ParseRefusal::Unported(_)),
                "{source} should be retryable"
            );
        }
        // Not Himark at all: the full compiler would refuse it too.
        for source in ["{a", "{a,}", "abc", "{a^3}", "{ab..cd}"] {
            assert!(
                matches!(arm(source), ParseRefusal::Syntax(_)),
                "{source} should not be retryable"
            );
        }
    }

    #[test]
    fn malformed_source_is_refused_rather_than_guessed() {
        assert!(refused("{a").contains("unclosed"));
        assert!(refused("{a,}").contains("empty member"));
        assert!(refused("abc").contains("needs braces"));
        assert!(refused("").contains("at least one brace group"));
        assert!(refused(r"{a\}").contains("unclosed"));
        assert!(refused("{a^3}").contains("'^' repeats"));
        assert!(refused("{a}^").contains("decimal count"));
        assert!(refused("{a}^99999").contains("may not exceed"));
        assert!(refused("{ab..cd}").contains("single characters"));
    }

    #[test]
    fn nesting_past_the_depth_limit_raises_rather_than_overflows() {
        let deep = "{".repeat(MAX_DEPTH + 2);
        assert!(refused(&deep).contains("nest deeper"));
    }
}
