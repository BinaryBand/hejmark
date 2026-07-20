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

use std::fmt;

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
    Universe(UniverseNode),
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
    Fold(UniverseNode),
    /// A `!{...}` member stripping the faces its inner universe spells.
    Subtract(UniverseNode),
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
    pub universes: Vec<UniverseNode>,
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
        let inner = node(vec![Member::Face(cp("a")), Member::Face(cp("a"))]);
        let query = QueryNode {
            universes: vec![node(vec![
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
        let left = node(vec![Member::Face(cp("a"))]);
        let right = node(vec![Member::Face(cp("b"))]);
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
