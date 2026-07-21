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
//! denotes those nodes to lazy universes ([`floor::universe`]). [`scan`] sits
//! above the floor: it matches denoted universes against text, reads captures
//! off a hit, and compares entry order for the contracting measure. [`surface`]
//! is only begun -- its scope error, which the scan layer shares. The surface
//! AST and expansion down to the floor are the next slices to port.
//!
//! Because this crate parses no Himark, a host that does (the Python package)
//! hands it an already-expanded query as JSON: [`floor::json`] reads that back
//! into the floor AST, and the `find` binary denotes and matches it.

pub mod floor;
pub mod scan;
pub mod surface;
