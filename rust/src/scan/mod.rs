//! The scan layer: read a denoted universe against text.
//!
//! Mirrors `hejmark/core/engine/scan/`. [`r#match`](self::match) is the leftmost-greedy,
//! maximal-munch matcher over a product of denoted universes; [`capture`] reads
//! `$`/`$0`/`$k` off a hit; [`measure`] compares entry order for the contracting
//! `<=>`. The back-referencing `Late` factor (which rides the query and
//! re-denotes per attempt) arrives once the surface layer exists.

pub mod capture;
pub mod r#match;
pub mod measure;
