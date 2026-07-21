//! The IR: the payload the compiler emits and the engine executes.
//!
//! Mirrors `hejmark/core/ir/`, the stratum the Python's compiler and engine
//! share because neither may import the other. This crate ports only the engine
//! side, so nothing here is *written* -- [`program`] is the shape a compiled
//! script arrives in, and [`wire`] is the reader that recovers it from JSON.
//!
//! The Python's `ir/codec.py` -- the floor AST's own JSON -- landed a stratum
//! lower here, as [`super::floor::json`], because the floor AST is all it reads.
//! [`wire`] is the format wrapped around that one and shares its reader.
//!
//! One member of the Python's `ir/program.py` has no analogue here and cannot:
//! `LateResolver`, the callback the engine calls to resolve a back-referencing
//! factor. It is a function into the compiler, and this crate has no compiler,
//! so a [`program::LateSlot`] decodes faithfully and then refuses to load --
//! see [`super::execute`].

pub mod program;
pub mod wire;
