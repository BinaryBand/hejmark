//! The scan layer: read a denoted universe against text.
//!
//! Mirrors `hejmark/core/engine/scan/`. [`r#match`](self::match) is the leftmost-greedy,
//! maximal-munch matcher over a product of denoted universes; [`capture`] reads
//! `$`/`$0`/`$k` off a hit; [`measure`] compares entry order for the contracting
//! `<=>`. [`error`] carries the read refusal both of the latter two raise. The
//! back-referencing `Late` factor (which rides the query and re-denotes per
//! attempt) arrives with a port of the compiler, which this crate does not have.

pub mod capture;
pub mod error;
pub mod r#match;
pub mod measure;
