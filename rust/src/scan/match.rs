//! Leftmost-greedy matcher: set membership over spellings, nothing else.
//!
//! A port of `hejmark/core/engine/scan/match.py`. A query is a product of factors. At
//! each product position the matcher probes prefixes of the remaining text
//! longest-first (maximal munch): a candidate face is a prefix of `text[pos..]`,
//! so there are at most `text.len() - pos` of them, and a single `contains`
//! accepts or rejects each. The first length that lets the rest of the product
//! match wins -- the canonical parse. The matcher knows only spellings: no value
//! or ordinal semantics leak in, and the empty spelling is never accepted (no
//! zero-width match).
//!
//! A factor here is a denoted [`Universe`]. The Python's `Factor` is a union:
//! it also admits a back-referencing `Late` factor -- a compiler object that
//! re-denotes per attempt under the faces bound to its left -- and so
//! `_try_product` threads those bound faces along. That variant needs a
//! resolver channel back into a compiler this crate does not have, so a factor
//! here is a plain universe and the bound-face accumulator it needs is left
//! out. A program carrying a late slot is one a host must run in Python, and
//! [`super::super::execute`] says so at load rather than leaving it implicit.
//!
//! As everywhere in this crate, text and faces are `[u32]` code points, so a
//! span is a code-point offset -- matching the Python's per-character indexing.

use std::collections::HashMap;

use crate::floor::reach::reach;
use crate::floor::universe::Universe;
use crate::floor::work::budgeted;

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

/// The longest span worth offering a factor: the text left, capped by its reach.
///
/// A factor cannot wear a face longer than its expression reaches, so a longer
/// span is a probe whose answer is already known. Where the expression is
/// unbounded -- a final segment, a closure -- the remaining text is the only cap
/// there is, which is the honest answer rather than a missing one.
fn longest(universe: &Universe, remaining: usize) -> usize {
    match reach(universe.shared_node()) {
        Some(far) => far.min(remaining),
        None => remaining,
    }
}

/// One query against one text, with the chart the attempts share.
///
/// `chart` remembers what the product from a depth found at a position. The
/// answer is a function of the factors, the text and the two indices -- L2's
/// *equal questions have equal answers* -- so it stands for every start position
/// and for every match of one scan, which is what keeps the whole scan from
/// re-deriving the same tails.
///
/// The Python guards the chart with a `plain` depth, because its factors may
/// include a back-referencing `Slot` that denotes only under the faces bound to
/// its left -- for those, the same depth at the same position is not the same
/// question twice. The port has no slot, so the chart holds from depth 0 and
/// there is no constant to carry.
struct Search<'a> {
    factors: &'a [Universe],
    text: &'a [u32],
    chart: HashMap<(usize, usize), Option<Vec<MatchPart>>>,
}

impl<'a> Search<'a> {
    fn new(query: &'a Query, text: &'a [u32]) -> Search<'a> {
        Search {
            factors: &query.universes,
            text,
            chart: HashMap::new(),
        }
    }

    /// Match the product from `depth` onward at `pos`; `None` if it cannot.
    fn try_product(&mut self, pos: usize, depth: usize) -> Option<Vec<MatchPart>> {
        if let Some(charted) = self.chart.get(&(depth, pos)) {
            return charted.clone();
        }
        let parts = self.probe(pos, depth);
        self.chart.insert((depth, pos), parts.clone());
        parts
    }

    /// Try each face this factor could wear here, longest first, and recurse.
    fn probe(&mut self, pos: usize, depth: usize) -> Option<Vec<MatchPart>> {
        if depth == self.factors.len() {
            return Some(Vec::new());
        }
        let universe = &self.factors[depth];
        for length in (1..=longest(universe, self.text.len() - pos)).rev() {
            let face = &self.text[pos..pos + length];
            if !universe.contains(face) {
                continue;
            }
            let end = pos + length;
            let face = face.to_vec();
            if let Some(mut tail) = self.try_product(end, depth + 1) {
                let mut parts = Vec::with_capacity(tail.len() + 1);
                parts.push(MatchPart {
                    span: (pos, end),
                    face,
                });
                parts.append(&mut tail);
                return Some(parts);
            }
        }
        None
    }

    /// Walk start positions left to right, returning the first that matches.
    fn leftmost(&mut self, start: usize) -> Option<Match> {
        for pos in start..=self.text.len() {
            if let Some(parts) = self.try_product(pos, 0) {
                let end = parts.last().map_or(pos, |part| part.span.1);
                return Some(Match {
                    span: (pos, end),
                    parts,
                });
            }
        }
        None
    }
}

/// Return the leftmost match at or after `start`, or `None` if there is none.
///
/// # Panics
///
/// Unwinds with a [`crate::floor::work::HimarkBudgetError`] payload when the
/// match runs past the host's work budget.
pub fn match_(query: &Query, text: &[u32], start: usize) -> Option<Match> {
    let _budget = budgeted("a match");
    Search::new(query, text).leftmost(start)
}

/// Yield non-overlapping matches left to right, resuming past each span.
///
/// One chart serves the whole scan: the text does not change between matches, so
/// a tail derived for one match answers for the next. Each match carries its own
/// work budget, unless an outer run already holds one.
///
/// # Panics
///
/// Unwinds with a [`crate::floor::work::HimarkBudgetError`] payload when a
/// match runs past the host's work budget.
pub fn finditer<'a>(query: &'a Query, text: &'a [u32]) -> impl Iterator<Item = Match> + 'a {
    let mut search = Search::new(query, text);
    let mut pos = 0;
    std::iter::from_fn(move || {
        let found = {
            let _budget = budgeted("a match");
            search.leftmost(pos)
        }?;
        pos = found.span.1.max(pos + 1);
        Some(found)
    })
}

#[cfg(test)]
mod tests {
    use super::{finditer, match_, Query};
    use std::rc::Rc;

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
            members: vec![Member::Fold(Rc::new(UniverseNode { members: vec![] }))],
        });
        assert!(match_(&query(vec![unit]), &cp("anything"), 0).is_none());
    }

    #[test]
    fn matching_is_membership_by_any_face() {
        // A fold's alternate spelling hits like any other.
        let folded = denote(&UniverseNode {
            members: vec![Member::Fold(Rc::new(UniverseNode {
                members: vec![Member::Face(cp("cat")), Member::Face(cp("feline"))],
            }))],
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
    fn a_many_factor_product_stays_tractable() {
        // Six ambiguous factors over a long text: without the chart the search
        // re-derives each tail once per way of reaching it, which grows like
        // n^k. The assertion is the spans; the point is that it returns at all.
        let factors: Vec<Universe> = (0..6).map(|_| universe(&["a", "aa"])).collect();
        let text = cp(&"a".repeat(32));
        let spans: Vec<(usize, usize)> = finditer(&query(factors), &text).map(|m| m.span).collect();
        assert_eq!(spans, vec![(0, 12), (12, 24), (24, 32)]);
    }

    #[test]
    fn finditer_is_empty_when_nothing_matches() {
        let q = query(vec![universe(&["a"])]);
        let text = cp("zzz");
        assert_eq!(finditer(&q, &text).count(), 0);
    }
}
