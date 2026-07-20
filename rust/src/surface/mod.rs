//! The surface layer: L1.5 over the floor.
//!
//! Mirrors `hejmark/core/surface/`. Only [`ast`]'s scope error is ported so far
//! -- enough for the scan layer to name it, exactly as the Python does. The
//! surface AST proper (names, definitions, pipelines, the back-referencing
//! `Late`), and expansion down to the floor's six constructors, are later slices.

pub mod ast;
