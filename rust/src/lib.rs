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
//! the contracting measure. [`surface`] is only begun -- its scope error, which
//! the scan layer shares. The surface AST and expansion down to the floor are the
//! next slices to port.
//!
//! Because this crate parses no Himark, a host that does (the Python package)
//! hands it an already-expanded query as JSON: [`floor::json`] reads that back
//! into the floor AST, and the `find` binary denotes and matches it.
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

pub mod floor;
pub mod scan;
pub mod surface;
