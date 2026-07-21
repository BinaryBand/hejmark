//! The floor: the bottom stratum of `core`, mirroring `hejmark/core/floor/`.
//!
//! [`order`] fixes the shortlex spelling order. [`syntax`] is the faithful AST
//! of the six constructors. [`binder`] and [`window`] are leaf analyses that
//! read that AST -- where a closure binds, and how a run of ranges is carved --
//! without denoting anything. [`universe`] sits above them: it is the
//! interpreter that turns these nodes into a lazy denotation, alternating
//! membership and enumeration, and is deliberately kept one module. [`json`]
//! reads the AST back from its portable JSON encoding -- the hand-off from a
//! host that parses and expands Himark, since this crate does neither.

pub mod binder;
pub mod json;
pub mod order;
pub mod syntax;
pub mod universe;
pub mod window;
