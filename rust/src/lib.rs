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
//! ([`floor::order`]), the three leaf analyses that read that AST without
//! denoting anything ([`floor::binder`], [`floor::window`], [`floor::reach`]),
//! and the interpreter that denotes those nodes to lazy universes
//! ([`floor::universe`]). [`scan`] sits above the floor: it matches denoted
//! universes against text, reads captures off a hit, and compares entry order for
//! the contracting measure.
//!
//! **This crate parses no Himark**, and that is the whole of its interface. A
//! host that does -- the Python package, wherever it runs, including embedded in
//! an Android app -- hands it an already-expanded query as JSON: [`floor::json`]
//! reads that back into the floor AST, and the `find` binary ([`ffi`] behind a C
//! ABI) denotes and matches it. There is exactly one way in, so there is nothing
//! here that can be behind the compiler.
//!
//! The Python has since partitioned `core/` into compiler and engine, which this
//! crate does not mirror: it ports only the engine side plus the floor beneath
//! both, so the split has nothing to land on yet.
//!
//! [`floor::work`] is the host's work budget, `core/floor/work.py` ported: a
//! match (and, once a contracting-pass runner exists here, a pass) opens a
//! budget, [`floor::universe::Universe::contains`] charges it at the
//! recursion's one chokepoint, and a run past it unwinds with a
//! [`floor::work::HimarkBudgetError`] rather than hanging. The membership memo
//! is capped behind that budget now, which is safe only because of it -- see
//! [`floor::universe`] for why capping it without a budget open was worse than
//! not capping it at all.

pub mod ffi;
pub mod floor;
pub mod scan;
