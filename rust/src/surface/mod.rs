//! The surface layer: L1.5 over the floor.
//!
//! Mirrors `hejmark/core/compiler/`. Two slices are ported. [`ast`] carries the
//! scope error the scan layer shares with the surface, exactly as the Python
//! does. [`parse`] reads the *floor subset* of Himark source -- the brace
//! syntax whose constructs already are the six constructors, plus the exponent
//! and the `@name` splices [`std`] resolves -- so a host with no Python to call
//! can compile what a user types. The rest of L1.5 (definitions, pipelines,
//! registers, back-references, and expansion proper) is a later slice, and
//! [`parse`] refuses each of those by name rather than mis-parsing it.

pub mod ast;
pub mod parse;
pub mod std;
