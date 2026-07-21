//! Faithful abstract syntax tree for Himark source.
//!
//! A port of `hejmark/core/floor/syntax.py`. These nodes mirror the parse
//! exactly: nothing is normalized, deduplicated, or rewritten here. All
//! constructor semantics (union no-ops, fold flattening, subtraction, closure
//! binding) happen later at denotation time in the `universe` interpreter.
//!
//! Where the Python stores spellings as `str`, this stores them as code points
//! -- `Vec<u32>`, or a bare `u32` for a range's single-code-point endpoints --
//! for the same surrogate-fidelity reason as [`super::order`]. The Python's
//! frozen dataclasses become plain enums and structs: Rust values are immutable
//! by default and compared structurally via `#[derive(PartialEq, Eq)]`, so the
//! "frozen, compares by value" behavior holds without any ceremony.
//!
//! Nested nodes are held behind [`Rc`] rather than owned outright. Python passes
//! its AST by reference for free; here an owned tree would be deep-copied every
//! time a factor or a fold is denoted -- once per candidate cut, inside the split
//! search's inner loop. Sharing makes that a refcount bump, and it is what gives
//! a denoted universe a stable node address to key its memo on (see
//! [`super::universe`]). The tree is immutable once built, so sharing it changes
//! nothing about the semantics.

use std::fmt;
use std::hash::{Hash, Hasher};
use std::rc::Rc;

/// A node compared and hashed by address rather than by structure.
///
/// The memo key both [`super::reach`] and [`super::universe`] use. It holds the
/// [`Rc`] rather than a bare pointer, and that is load-bearing rather than
/// convenient: an address only identifies a node for as long as the node is
/// alive, and a freed node's address can be handed straight back to the next
/// allocation. Keeping the node alive for the key's lifetime is what makes "same
/// address" mean "same node" -- without it a memo could answer a question about
/// a tree that no longer exists.
///
/// Identity implies structural equality, never the converse, so a memo keyed
/// this way can miss where a structural one would hit. That is a recomputation,
/// never a wrong answer.
#[derive(Debug, Clone)]
pub struct NodeId(pub Rc<UniverseNode>);

impl PartialEq for NodeId {
    fn eq(&self, other: &NodeId) -> bool {
        Rc::ptr_eq(&self.0, &other.0)
    }
}

impl Eq for NodeId {}

impl Hash for NodeId {
    fn hash<H: Hasher>(&self, state: &mut H) {
        (Rc::as_ptr(&self.0) as usize).hash(state);
    }
}

/// Signals that Himark source failed to lex or parse.
///
/// The parser slice that raises this is not yet ported; the type is defined
/// here so `syntax` presents the same surface as the Python module.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HimarkSyntaxError {
    /// A human-readable description of the failure.
    pub message: String,
}

impl fmt::Display for HimarkSyntaxError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for HimarkSyntaxError {}

/// One factor of a [`Member::Product`]: a nested universe, or the closure token.
///
/// Mirrors the Python `Product.factors` element type `UniverseNode | Closure`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Factor {
    /// A nested brace group standing as one factor.
    Universe(Rc<UniverseNode>),
    /// The self-reference token `&`.
    Closure,
}

/// A member of a brace group: one of the six constructors, or the closure token.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Member {
    /// A literal spelling; escapes are already resolved to their code points.
    Face(Vec<u32>),
    /// An inclusive character range `{lo..hi}` over single code points.
    Range {
        /// Inclusive lower endpoint.
        lo: u32,
        /// Inclusive upper endpoint.
        hi: u32,
    },
    /// A final segment `{a..}`: every spelling from `lo` onward in spelling order.
    Final(Vec<u32>),
    /// A nested universe used as a member -- the quotient constructor.
    Fold(Rc<UniverseNode>),
    /// A `!{...}` member stripping the faces its inner universe spells.
    Subtract(Rc<UniverseNode>),
    /// Adjacent factors as one member: tuples of entries, spelled by concatenation.
    Product(Vec<Factor>),
    /// The self-reference token `&`: it reads the binder's previous stage.
    Closure,
}

/// A brace group `{...}` with its members in declaration order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UniverseNode {
    /// The members, in the order they were written.
    pub members: Vec<Member>,
}

/// A whole query: one or more universes juxtaposed as a product.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QueryNode {
    /// The juxtaposed universes, in the order they were written.
    pub universes: Vec<Rc<UniverseNode>>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    fn node(members: Vec<Member>) -> UniverseNode {
        UniverseNode { members }
    }

    /// A shared node, as every nested position now holds one.
    fn rc(members: Vec<Member>) -> Rc<UniverseNode> {
        Rc::new(node(members))
    }

    #[test]
    fn nodes_compare_by_value() {
        assert_eq!(Member::Face(cp("a")), Member::Face(cp("a")));
        assert_ne!(Member::Face(cp("a")), Member::Face(cp("b")));
        assert_eq!(
            node(vec![Member::Face(cp("a"))]),
            node(vec![Member::Face(cp("a"))])
        );
    }

    #[test]
    fn nodes_nest_without_normalizing() {
        // The AST is faithful: a nested universe is preserved verbatim.
        let inner = rc(vec![Member::Face(cp("a")), Member::Face(cp("a"))]);
        let query = QueryNode {
            universes: vec![rc(vec![
                Member::Fold(inner.clone()),
                Member::Range {
                    lo: '0' as u32,
                    hi: '9' as u32,
                },
                Member::Subtract(inner.clone()),
            ])],
        };

        let members = &query.universes[0].members;
        assert_eq!(members[0], Member::Fold(inner.clone()));
        assert_eq!(
            members[1],
            Member::Range {
                lo: '0' as u32,
                hi: '9' as u32
            }
        );
        assert_eq!(members[2], Member::Subtract(inner.clone()));
        // The duplicate face survives: deduplication is denotation's job.
        assert_eq!(
            inner.members,
            vec![Member::Face(cp("a")), Member::Face(cp("a"))]
        );
    }

    #[test]
    fn product_holds_factors_in_order() {
        let left = rc(vec![Member::Face(cp("a"))]);
        let right = rc(vec![Member::Face(cp("b"))]);
        let product = Member::Product(vec![
            Factor::Universe(left.clone()),
            Factor::Closure,
            Factor::Universe(right.clone()),
        ]);

        assert_eq!(
            product,
            Member::Product(vec![
                Factor::Universe(left),
                Factor::Closure,
                Factor::Universe(right),
            ])
        );
        assert_eq!(Factor::Closure, Factor::Closure);
    }

    #[test]
    fn syntax_error_displays_its_message() {
        let err = HimarkSyntaxError {
            message: "bad token".to_string(),
        };
        assert_eq!(err.to_string(), "bad token");
    }
}
