//! The scan layer: match a denoted universe against text.
//!
//! Mirrors `hejmark/core/scan/`. [`r#match`](self::match) is the leftmost-greedy,
//! maximal-munch matcher over a product of denoted universes. The capture and
//! measure modules, and the back-referencing `Late` factor (which rides the
//! query and re-denotes per attempt), arrive with later slices once the surface
//! layer exists.

pub mod r#match;
