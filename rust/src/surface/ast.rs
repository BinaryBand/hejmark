//! Surface AST errors (the surface layer's first slice).
//!
//! Mirrors the error types of `hejmark/core/surface/ast.py`. The full surface
//! AST -- names, definitions, pipelines, back-references -- is not yet ported;
//! this module exists so the scan layer can name the scope error it shares with
//! the surface, exactly as the Python does (`scan` imports it from `surface`).

use std::fmt;

/// Raised when a read reaches outside the scope a binding can satisfy.
///
/// The scan layer raises it for a spelling the measure does not wear, and for a
/// capture read (canonical face, factor split, address) that outruns its budget.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HimarkScopeError {
    /// A human-readable description of the out-of-scope read.
    pub message: String,
}

impl fmt::Display for HimarkScopeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for HimarkScopeError {}
