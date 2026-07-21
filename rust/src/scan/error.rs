//! The scan layer's read refusal.
//!
//! Mirrors `hejmark/core/ir/errors.py`'s `HimarkScopeError`. The Python keeps it
//! in the shared stratum both the compiler and the engine can name; this crate
//! ports only the engine side, so `scan` is that stratum's whole reach here --
//! and it is also where both raisers live ([`super::capture`], [`super::measure`]).

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
