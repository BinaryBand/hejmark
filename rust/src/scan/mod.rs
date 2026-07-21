//! The scan layer: read a denoted universe against text.
//!
//! Mirrors `hejmark/core/engine/scan/`. [`r#match`](self::match) is the leftmost-greedy,
//! maximal-munch matcher over a product of denoted universes; [`capture`] reads
//! `$`/`$0`/`$k` off a hit; [`measure`] compares entry order for the contracting
//! `<=>`. [`error`] carries the read refusal both of the latter two raise.
//! [`super::execute`] is what puts them together over a whole script.
//!
//! The back-referencing `Late` factor -- which rides the query and re-denotes
//! per attempt -- is the one thing missing, and it needs a port of the compiler
//! rather than of anything here: a program carrying one now *decodes*
//! ([`super::ir::program::LateSlot`]) and is refused at load, so what used to be
//! a gap in the reader is now a stated boundary in the runner.

pub mod capture;
pub mod error;
pub mod r#match;
pub mod measure;
