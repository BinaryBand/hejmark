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
//! ([`floor::universe`]). [`ir`] is the stratum above it: the pure-data program
//! a compiler emits, and the reader that recovers one from JSON. [`scan`] sits
//! above the floor too -- it matches denoted universes against text, reads
//! captures off a hit, and compares entry order for the contracting measure --
//! and [`execute`] sits above both, threading a document through a whole
//! compiled script. That last pair is the difference between *where does this
//! hit* and *what does the document become*, which is to say between `find` and
//! `run`.
//!
//! **This crate parses no Himark**, and that is the whole of its interface. A
//! host that does -- the Python package, wherever it runs, including embedded in
//! an Android app -- hands it something already compiled, as JSON. There are two
//! shapes and they nest: one query's floor AST, read by [`floor::json`] and
//! matched by the `find` binary; and a whole script, read by [`ir::wire`] and
//! executed by the `run` binary, with a compiled query at each of its leaves.
//! [`ffi`] puts both behind a C ABI. Neither way in admits source, so there is
//! nothing here that can be behind the compiler.
//!
//! The Python's `core/` is partitioned into compiler and engine over a shared
//! `ir/` and `floor/`. This crate ports the engine side and both shared strata,
//! and the compiler side not at all -- which is exactly why a
//! [`ir::program::LateSlot`] decodes here and then refuses to run: resolving one
//! is a call into the missing half.
//!
//! [`floor::work`] is the host's work budget, `core/floor/work.py` ported: a
//! match or a contracting pass opens a budget,
//! [`floor::universe::Universe::contains`] charges it at the recursion's one
//! chokepoint, and a run past it unwinds with a
//! [`floor::work::HimarkBudgetError`] rather than hanging. The membership memo
//! is capped behind that budget now, which is safe only because of it -- see
//! [`floor::universe`] for why capping it without a budget open was worse than
//! not capping it at all.

pub mod diagnose;
pub mod execute;
pub mod ffi;
pub mod floor;
pub mod ir;
pub mod scan;
