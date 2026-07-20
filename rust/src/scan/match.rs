//! Leftmost-greedy matcher: set membership over spellings, nothing else.
//!
//! A port of `hejmark/core/scan/match.py`. A query is a product of factors. At
//! each product position the matcher probes prefixes of the remaining text
//! longest-first (maximal munch): a candidate face is a prefix of `text[pos..]`,
//! so there are at most `text.len() - pos` of them, and a single `contains`
//! accepts or rejects each. The first length that lets the rest of the product
//! match wins -- the canonical parse. The matcher knows only spellings: no value
//! or ordinal semantics leak in, and the empty spelling is never accepted (no
//! zero-width match).
//!
//! A factor here is a denoted [`Universe`]. The Python's `Factor` is a union:
//! it also admits a back-referencing `Late` factor -- a surface object that
//! re-denotes per attempt under the faces bound to its left -- and so
//! `_try_product` threads those bound faces along. That variant belongs to the
//! surface layer, which is not yet ported; until it is, a factor is a plain
//! universe and the bound-face accumulator it needs is left out.
//!
//! As everywhere in this crate, text and faces are `[u32]` code points, so a
//! span is a code-point offset -- matching the Python's per-character indexing.

use crate::floor::universe::Universe;

/// A denoted query: its source plus one factor per written unit, in order.
#[derive(Clone)]
pub struct Query {
    /// The source text the query was parsed from (carried for callers; unused here).
    pub source: String,
    /// One denoted universe per product position, most-significant first.
    pub universes: Vec<Universe>,
}

impl Query {
    /// Build a query from its source and its denoted factors.
    pub fn new(source: impl Into<String>, universes: Vec<Universe>) -> Query {
        Query {
            source: source.into(),
            universes,
        }
    }

    /// The denoted universe at `index`, for callers that need one factor.
    ///
    /// The Python raises when the factor back-references (it denotes only under
    /// a binding); with no `Late` variant yet, every factor is already a
    /// universe, so this is a plain accessor.
    pub fn universe(&self, index: usize) -> &Universe {
        &self.universes[index]
    }
}

/// What matched at one product position: its span and the face that hit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchPart {
    /// The half-open `[start, end)` span the face occupies, in code points.
    pub span: (usize, usize),
    /// The face that hit at this position.
    pub face: Vec<u32>,
}

/// A whole match: its overall span and one part per product position.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Match {
    /// The half-open `[start, end)` span the whole match occupies.
    pub span: (usize, usize),
    /// One part per product position, in order.
    pub parts: Vec<MatchPart>,
}

/// Match the product from `depth` onward at `pos`; `None` if it cannot.
fn try_product(
    factors: &[Universe],
    text: &[u32],
    pos: usize,
    depth: usize,
) -> Option<Vec<MatchPart>> {
    if depth == factors.len() {
        return Some(Vec::new());
    }
    let universe = &factors[depth];
    for length in (1..=text.len() - pos).rev() {
        let face = &text[pos..pos + length];
        if !universe.contains(face) {
            continue;
        }
        let end = pos + length;
        if let Some(mut tail) = try_product(factors, text, end, depth + 1) {
            let mut parts = Vec::with_capacity(tail.len() + 1);
            parts.push(MatchPart {
                span: (pos, end),
                face: face.to_vec(),
            });
            parts.append(&mut tail);
            return Some(parts);
        }
    }
    None
}

/// Return the leftmost match at or after `start`, or `None` if there is none.
pub fn match_(query: &Query, text: &[u32], start: usize) -> Option<Match> {
    for pos in start..=text.len() {
        if let Some(parts) = try_product(&query.universes, text, pos, 0) {
            let end = parts.last().map_or(pos, |part| part.span.1);
            return Some(Match {
                span: (pos, end),
                parts,
            });
        }
    }
    None
}

/// Yield non-overlapping matches left to right, resuming past each span.
pub fn finditer<'a>(query: &'a Query, text: &'a [u32]) -> impl Iterator<Item = Match> + 'a {
    let mut pos = 0;
    std::iter::from_fn(move || {
        let found = match_(query, text, pos)?;
        pos = found.span.1.max(pos + 1);
        Some(found)
    })
}

#[cfg(test)]
mod tests {
    use super::{finditer, match_, Query};
    use crate::floor::syntax::{Member, UniverseNode};
    use crate::floor::universe::{denote, Universe};

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    /// A universe of single-faced entries in declaration order.
    fn universe(faces: &[&str]) -> Universe {
        let members = faces.iter().map(|face| Member::Face(cp(face))).collect();
        denote(&UniverseNode { members })
    }

    fn query(universes: Vec<Universe>) -> Query {
        Query::new("<hand-built>", universes)
    }

    #[test]
    fn leftmost_match_skips_unmatched_prefix() {
        let found = match_(&query(vec![universe(&["a"])]), &cp("xxa"), 0).unwrap();
        assert_eq!(found.span, (2, 3));
        assert_eq!(found.parts[0].face, cp("a"));
    }

    #[test]
    fn no_match_returns_none() {
        assert!(match_(&query(vec![universe(&["a"])]), &cp("zzz"), 0).is_none());
    }

    #[test]
    fn start_offset_is_honoured() {
        let found = match_(&query(vec![universe(&["a"])]), &cp("aXa"), 1).unwrap();
        assert_eq!(found.span, (2, 3));
    }

    #[test]
    fn longest_face_wins() {
        // Candidates are tried longest-first regardless of declaration order.
        let found = match_(&query(vec![universe(&["a", "ab"])]), &cp("ab"), 0).unwrap();
        assert_eq!(found.span, (0, 2));
        assert_eq!(found.parts[0].face, cp("ab"));
    }

    #[test]
    fn backtracks_when_the_greedy_choice_strands_the_rest() {
        // `ab` is longest at position 0, but then `b` cannot match -- back off to `a`.
        let found = match_(
            &query(vec![universe(&["a", "ab"]), universe(&["b"])]),
            &cp("ab"),
            0,
        )
        .unwrap();
        assert_eq!(found.span, (0, 2));
        let faces: Vec<Vec<u32>> = found.parts.iter().map(|part| part.face.clone()).collect();
        assert_eq!(faces, vec![cp("a"), cp("b")]);
    }

    #[test]
    fn empty_universe_in_a_product_matches_nothing() {
        assert!(match_(&query(vec![universe(&["a"]), universe(&[])]), &cp("a"), 0).is_none());
    }

    #[test]
    fn zero_width_is_never_accepted() {
        // The unit universe wears only the empty spelling, so no match exists.
        let unit = denote(&UniverseNode {
            members: vec![Member::Fold(UniverseNode { members: vec![] })],
        });
        assert!(match_(&query(vec![unit]), &cp("anything"), 0).is_none());
    }

    #[test]
    fn matching_is_membership_by_any_face() {
        // A fold's alternate spelling hits like any other.
        let folded = denote(&UniverseNode {
            members: vec![Member::Fold(UniverseNode {
                members: vec![Member::Face(cp("cat")), Member::Face(cp("feline"))],
            })],
        });
        let found = match_(&query(vec![folded]), &cp("a feline"), 0).unwrap();
        assert_eq!(found.parts[0].face, cp("feline"));
    }

    #[test]
    fn finditer_yields_non_overlapping_matches() {
        let q = query(vec![universe(&["aa"])]);
        let text = cp("aaaa");
        let spans: Vec<(usize, usize)> = finditer(&q, &text).map(|m| m.span).collect();
        assert_eq!(spans, vec![(0, 2), (2, 4)]);
    }

    #[test]
    fn finditer_is_empty_when_nothing_matches() {
        let q = query(vec![universe(&["a"])]);
        let text = cp("zzz");
        assert_eq!(finditer(&q, &text).count(), 0);
    }
}
