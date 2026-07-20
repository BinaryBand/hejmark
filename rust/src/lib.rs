//! Hejmark in Rust: a standalone port of `core/`, grown one self-contained
//! slice at a time.
//!
//! The Python package under `hejmark/` is the reference implementation; this
//! crate mirrors it piece by piece, starting from the leaves that depend on
//! nothing else. It is a plain library with no dependencies, exercised by
//! `cargo test` -- which the Python suite drives through `tests/test_rust.py`.
//!
//! The first slice is [`order`], the shortlex spelling order that L1 fixes as
//! the foundation every constructor is built on.

pub mod order;
