//! The Program: what a compiler emits and this crate's engine executes.
//!
//! A port of `hejmark/core/ir/program.py`. Every type here is plain owned data
//! over `String`, `usize`, `Vec` and the floor's [`UniverseNode`] -- no
//! environment, no surface AST, no denoted universe. That is the property that
//! makes a program serializable at all, and therefore the property that lets a
//! script cross into this crate the way a single query already could.
//!
//! Spellings are `Vec<u32>` code points, as everywhere in this crate; the
//! Python's `str` fields that are *names* rather than spellings (a sentinel
//! name, a capture spelling, a query's diagnostic source) stay `String`.
//!
//! The sentinel space lives here for the same reason it does in the Python: the
//! program carries the allocations and the engine's exit guard reads the space,
//! so [`noncharacter`] belongs where both can see it.

use std::rc::Rc;

use crate::floor::syntax::UniverseNode;

/// Sentinel faces are allocated from the first noncharacter block, in
/// declaration order. The other noncharacters are every plane's last two code
/// points.
pub const SENTINEL_BASE: u32 = 0xFDD0;
const SENTINEL_TOP: u32 = 0xFDEF;
const PLANE_ENDER: u32 = 0xFFFE;

/// Whether `point` is one of Unicode's noncharacters -- the sentinel space.
///
/// The seeded `C` subtracts these, so no `@C`-derived universe can touch a
/// sentinel: only its declared name matches it.
#[must_use]
pub fn noncharacter(point: u32) -> bool {
    (SENTINEL_BASE..=SENTINEL_TOP).contains(&point) || point & PLANE_ENDER == PLANE_ENDER
}

/// A back-referencing factor: a hole the compiler resolves once its reads bind.
///
/// `needs` holds the 1-based indices of the factors it reads, in written order.
/// `reach` is a compile-time upper bound on the length of any face the
/// resolution could wear, or `None` where the shape was not confidently priced.
///
/// This crate decodes one and can do nothing with it: resolving a slot is a
/// call back into the compiler that emitted it, and there is no compiler here.
/// [`crate::execute`] refuses at load rather than at first use, so the refusal
/// names the program instead of one attempt inside it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LateSlot {
    /// The slot's id, as the emitting compiler's table keys it.
    pub slot: usize,
    /// The 1-based indices of the factors this slot reads, in written order.
    pub needs: Vec<usize>,
    /// A sound upper bound on the resolution's face length, if one was priced.
    pub reach: Option<usize>,
}

/// One factor of a compiled query: expanded already, or waiting on a binding.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QueryFactor {
    /// A factor the compiler fully expanded to the floor's six constructors.
    Universe(Rc<UniverseNode>),
    /// A factor that reads one to its left, and so could not be expanded yet.
    Late(LateSlot),
}

/// A query lowered to the floor: one factor per written unit, in order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledQuery {
    /// The query as written, carried for diagnostics only -- nothing runs it.
    pub source: String,
    /// One factor per product position, most-significant first.
    pub factors: Vec<QueryFactor>,
}

/// One piece of a template: literal text, a capture read, or a sentinel splice.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TemplatePart {
    /// Literal text, escapes already resolved.
    Text(Vec<u32>),
    /// A capture read, spelled exactly as written: `$`, `$0`, or `$k`.
    Capture(String),
    /// A sentinel splice `{{@name}}`, looked up in the program's table.
    Sentinel(String),
}

/// A template as its parts, in written order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledTemplate {
    /// The parts, left to right.
    pub parts: Vec<TemplatePart>,
}

/// One step of a statement: the two things `=>` joins.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CompiledStep {
    /// A query step, which refines the branch it runs on.
    Query(CompiledQuery),
    /// A template step, which constructs a string over the branch's span.
    Template(CompiledTemplate),
}

/// One ordinary statement: its steps, joined by `=>` in source order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledStatement {
    /// The steps, left to right.
    pub steps: Vec<CompiledStep>,
}

/// The contracting statement `query <=>[@m] template`.
///
/// The measure is expanded at compile time -- an unknown measure never reaches
/// here -- and `measure_name` survives only for the engine's diagnostics.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledIter {
    /// The query each pass runs.
    pub query: CompiledQuery,
    /// The measure's declared name, for the messages a failed pass writes.
    pub measure_name: String,
    /// The measure, already expanded to the floor.
    pub measure: Rc<UniverseNode>,
    /// The template each pass rewrites with.
    pub template: CompiledTemplate,
}

/// One line of a program: an ordinary statement, or a contracting one.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CompiledLine {
    /// `query => template`, run once.
    Statement(CompiledStatement),
    /// `query <=>[@m] template`, run to settlement under a checked descent.
    Iter(CompiledIter),
}

/// One sentinel allocation: a declared name and the noncharacter face it got.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Sentinel {
    /// The name the `sentinel` declaration gave it.
    pub name: String,
    /// The face allocated to it, one code point from the sentinel space.
    pub face: Vec<u32>,
}

/// A compiled script: statements in source order, plus the sentinel table.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Program {
    /// The statements, in the order they were written.
    pub statements: Vec<CompiledLine>,
    /// Every sentinel the script declared, in allocation order.
    pub sentinels: Vec<Sentinel>,
}

impl Program {
    /// Whether any query in the program carries a late slot.
    ///
    /// A slot-free program is fully self-contained and this crate can run it; a
    /// slotted one needs the compiler's resolver and cannot leave the process
    /// that compiled it. Reported here rather than discovered mid-run, so a host
    /// can route the program before spending anything on it.
    #[must_use]
    pub fn is_late(&self) -> bool {
        self.statements.iter().any(|line| match line {
            CompiledLine::Statement(statement) => statement.steps.iter().any(|step| match step {
                CompiledStep::Query(query) => query_is_late(query),
                CompiledStep::Template(_) => false,
            }),
            CompiledLine::Iter(iter) => query_is_late(&iter.query),
        })
    }
}

/// Whether one query carries a late slot.
fn query_is_late(query: &CompiledQuery) -> bool {
    query
        .factors
        .iter()
        .any(|factor| matches!(factor, QueryFactor::Late(_)))
}

#[cfg(test)]
mod tests {
    use super::{
        noncharacter, CompiledLine, CompiledQuery, CompiledStatement, CompiledStep,
        CompiledTemplate, LateSlot, Program, QueryFactor, SENTINEL_BASE,
    };
    use crate::floor::syntax::{Member, UniverseNode};
    use std::rc::Rc;

    fn eager() -> QueryFactor {
        QueryFactor::Universe(Rc::new(UniverseNode {
            members: vec![Member::Face(vec![97])],
        }))
    }

    fn program(factors: Vec<QueryFactor>) -> Program {
        Program {
            statements: vec![CompiledLine::Statement(CompiledStatement {
                steps: vec![
                    CompiledStep::Query(CompiledQuery {
                        source: "{a}".to_string(),
                        factors,
                    }),
                    CompiledStep::Template(CompiledTemplate { parts: Vec::new() }),
                ],
            })],
            sentinels: Vec::new(),
        }
    }

    #[test]
    fn the_sentinel_block_and_every_plane_ender_are_noncharacters() {
        assert!(noncharacter(SENTINEL_BASE));
        assert!(noncharacter(0xFDEF));
        assert!(noncharacter(0xFFFE));
        assert!(noncharacter(0xFFFF));
        assert!(noncharacter(0x10FFFE));
        assert!(!noncharacter(0xFDF0));
        assert!(!noncharacter(u32::from('a')));
    }

    #[test]
    fn a_slot_free_program_is_not_late() {
        assert!(!program(vec![eager()]).is_late());
    }

    #[test]
    fn one_slot_anywhere_makes_the_whole_program_late() {
        let slot = QueryFactor::Late(LateSlot {
            slot: 0,
            needs: vec![1],
            reach: Some(1),
        });
        assert!(program(vec![eager(), slot]).is_late());
    }
}
