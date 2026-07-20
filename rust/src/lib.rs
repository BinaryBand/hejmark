//! Hejmark in Rust: a standalone port of `core/`, grown one self-contained
//! slice at a time.
//!
//! The Python package under `hejmark/` is the reference implementation; this
//! crate mirrors it piece by piece, starting from the leaves that depend on
//! nothing else. It is a plain library with no dependencies, exercised by
//! `cargo test` -- which the Python suite drives through `tests/test_rust.py`.
//!
//! [`floor`] is the bottom stratum of `core`: the six constructors' AST
//! ([`floor::syntax`]), the shortlex spelling order beneath them
//! ([`floor::order`]), the two leaf analyses that read that AST without denoting
//! anything ([`floor::binder`], [`floor::window`]), and the interpreter that
//! denotes those nodes to lazy universes ([`floor::universe`]). The scan layer
//! that matches a denoted universe against text is the next slice to port.

pub mod floor;
