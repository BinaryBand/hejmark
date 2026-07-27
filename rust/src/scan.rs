//! Leftmost-greedy matching, and what a capture reads on a hit.
//!
//! A port of `scan/match.py` and `scan/capture.py`. The matcher knows only
//! spellings: at each product position it probes prefixes of the remaining text
//! longest-first, and a single `contains` accepts or rejects each. The first
//! length that lets the rest of the product match wins. The empty spelling is
//! never accepted -- no zero-width match.
//!
//! The reads are the subtle half. `$` is the hit as it hit and costs nothing,
//! but membership says *whether* a spelling is worn and not by which entry, so
//! `$0` and `$k` stream entries to price the wearer. Where a hit splits more
//! than one way the floor gives it to the least `<value, face>` address, which
//! is **not** the matcher's greedy witness -- `{a,ab}{c,bc}` on `abc` matches as
//! `ab`+`c` and binds as `a`+`bc`. A port that reports the greedy split passes
//! nearly the whole corpus and fails exactly there.

use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use crate::denote::{Denoter, Univ};
use crate::errors::{scope, Answer};
use crate::spelling::{spelling, Point, Spelling, GO, STOP};
use crate::syntax::NodeId;

/// How a late slot is expanded: the host that compiled it answers.
pub type Resolver<'a> = &'a dyn Fn(u32, &[Spelling]) -> Answer<NodeId>;

/// The engine at run time: a denotation, plus the one call back to the host.
pub struct Engine<'a> {
    /// The denotation every query shares.
    pub den: Denoter,
    /// The late resolver, which is the boundary's one back edge.
    pub resolve: Resolver<'a>,
}

/// A back-referencing factor: the boundary's one back edge, memoised.
pub struct Slot {
    slot: u32,
    needs: Vec<u32>,
    cache: RefCell<HashMap<Vec<Spelling>, Univ>>,
}

/// One product position of a query: denoted, or awaiting its binding.
pub enum Factor {
    /// A factor denoted at load.
    Eager(Univ),
    /// A factor that denotes only under the faces bound to its left.
    Late(Slot),
}

/// A denoted query: its source plus one factor per written unit, in order.
pub struct Query {
    /// The source, for diagnostics only.
    pub source: String,
    /// One factor per product position.
    pub factors: Vec<Factor>,
    /// The first depth from which no factor back-references.
    plain: usize,
}

impl Query {
    /// Load a compiled query: denote the eager factors, wire the slots.
    pub fn load(den: &Denoter, source: String, factors: Vec<crate::wire::WireFactor>) -> Self {
        let factors: Vec<Factor> = factors
            .into_iter()
            .map(|factor| match factor {
                crate::wire::WireFactor::Universe(node) => Factor::Eager(den.denote(node)),
                crate::wire::WireFactor::Slot { slot, needs } => {
                    Factor::Late(Slot { slot, needs, cache: RefCell::new(HashMap::new()) })
                }
            })
            .collect();
        let plain = factors
            .iter()
            .rposition(|factor| matches!(factor, Factor::Late(_)))
            .map_or(0, |last| last + 1);
        Self { source, factors, plain }
    }
}

/// What matched at one product position: its span and the face that hit.
#[derive(Clone, Debug)]
pub struct MatchPart {
    /// Half-open span into the text object, in code points.
    pub span: (usize, usize),
    /// The face that hit.
    pub face: Spelling,
}

/// A whole match: its overall span and one part per product position.
#[derive(Clone, Debug)]
pub struct Match {
    /// Half-open span into the text object, in code points.
    pub span: (usize, usize),
    /// One part per product position.
    pub parts: Vec<MatchPart>,
}

/// The chart one scan shares: what the product from a depth found at a position.
///
/// The answer is a function of the factors, the text and the two indices, so it
/// stands for every start position and every match of one scan. Not for a late
/// factor, though: a slot denotes only under the faces bound to its left, so the
/// same depth at the same position is not the same question twice. `plain` is
/// the first depth whose tail carries no slot, and only from there down does
/// the chart apply.
type Chart = HashMap<(usize, usize), Option<Vec<MatchPart>>>;

impl Engine<'_> {
    /// Resolve one factor under the faces bound to its left.
    pub fn universe_at(&self, factor: &Factor, bound: &[Spelling]) -> Answer<Univ> {
        match factor {
            Factor::Eager(universe) => Ok(*universe),
            Factor::Late(slot) => {
                let key: Vec<Spelling> =
                    slot.needs.iter().map(|index| bound[*index as usize - 1].clone()).collect();
                if let Some(found) = slot.cache.borrow().get(&key) {
                    return Ok(*found);
                }
                let node = (self.resolve)(slot.slot, &key)?;
                let universe = self.den.denote(node);
                slot.cache.borrow_mut().insert(key, universe);
                Ok(universe)
            }
        }
    }

    /// The leftmost match at or after *start*, or `None` if there is none.
    pub fn find(&self, query: &Query, text: &[Point], start: usize) -> Answer<Option<Match>> {
        let mut chart = Chart::new();
        self.leftmost(query, text, &mut chart, start)
    }

    /// Every non-overlapping match, left to right, resuming past each span.
    ///
    /// One chart serves the whole scan: the text does not change between
    /// matches, so a tail derived for one match answers for the next.
    pub fn find_all(&self, query: &Query, text: &[Point]) -> Answer<Vec<Match>> {
        let mut chart = Chart::new();
        let mut found = Vec::new();
        let mut pos = 0;
        while let Some(hit) = self.leftmost(query, text, &mut chart, pos)? {
            pos = hit.span.1.max(pos + 1);
            found.push(hit);
        }
        Ok(found)
    }

    fn leftmost(
        &self,
        query: &Query,
        text: &[Point],
        chart: &mut Chart,
        start: usize,
    ) -> Answer<Option<Match>> {
        for pos in start..=text.len() {
            if let Some(parts) = self.try_product(query, text, chart, pos, 0, &mut Vec::new())? {
                let end = parts.last().map_or(pos, |part| part.span.1);
                return Ok(Some(Match { span: (pos, end), parts }));
            }
        }
        Ok(None)
    }

    fn try_product(
        &self,
        query: &Query,
        text: &[Point],
        chart: &mut Chart,
        pos: usize,
        depth: usize,
        bound: &mut Vec<Spelling>,
    ) -> Answer<Option<Vec<MatchPart>>> {
        if depth < query.plain {
            return self.probe(query, text, chart, pos, depth, bound);
        }
        if let Some(found) = chart.get(&(depth, pos)) {
            return Ok(found.clone());
        }
        let found = self.probe(query, text, chart, pos, depth, bound)?;
        chart.insert((depth, pos), found.clone());
        Ok(found)
    }

    /// Try each face this factor could wear here, longest first, and recurse.
    fn probe(
        &self,
        query: &Query,
        text: &[Point],
        chart: &mut Chart,
        pos: usize,
        depth: usize,
        bound: &mut Vec<Spelling>,
    ) -> Answer<Option<Vec<MatchPart>>> {
        if depth == query.factors.len() {
            return Ok(Some(Vec::new()));
        }
        let universe = self.universe_at(&query.factors[depth], bound)?;
        for length in (1..=text.len() - pos).rev() {
            let face = spelling(&text[pos..pos + length]);
            if !self.den.contains(universe, &face) {
                continue;
            }
            let end = pos + length;
            bound.push(face.clone());
            let tail = self.try_product(query, text, chart, end, depth + 1, bound);
            bound.pop();
            if let Some(mut tail) = tail? {
                let mut parts = vec![MatchPart { span: (pos, end), face }];
                parts.append(&mut tail);
                return Ok(Some(parts));
            }
        }
        Ok(None)
    }

    /// The canonical face of the entry wearing *face*, or `None` if none does.
    ///
    /// Streams entries until it finds the wearer, because membership says
    /// whether a spelling is worn and not by which entry. A worn spelling always
    /// sits at a finite position, so the search terminates -- though the position
    /// can be astronomically large over an infinite universe.
    pub fn canonical(&self, universe: Univ, face: &Spelling) -> Option<Spelling> {
        let mut found = None;
        let _drained = self.den.entries(universe, &mut |entry| {
            if entry.faces.iter().any(|worn| worn == face) {
                found = Some(entry.faces[0].clone());
                return STOP;
            }
            GO
        });
        found
    }

    /// The `<value, face>` address of the entry wearing *face*.
    ///
    /// Value survives only as iteration order, so the value half is the wearer's
    /// stream position and the face half its index among the wearer's faces.
    fn address(&self, universe: Univ, face: &Spelling) -> Answer<(usize, usize)> {
        let mut found = None;
        let mut position = 0usize;
        let _drained = self.den.entries(universe, &mut |entry| {
            if let Some(index) = entry.faces.iter().position(|worn| worn == face) {
                found = Some((position, index));
                return STOP;
            }
            position += 1;
            GO
        });
        found.map_or_else(|| scope(format!("cannot address {face:?}: no entry wears it")), Ok)
    }

    /// Every exact tiling of *text* by *factors*, one face per factor.
    ///
    /// Faces are never empty -- the matcher accepts no zero-width part, and the
    /// re-split honours the same rule. A late factor resolves under the faces
    /// this tiling has already chosen, so each candidate carries its own bindings.
    fn splits(&self, query: &Query, text: &[Point]) -> Answer<Vec<Vec<Spelling>>> {
        let mut out = Vec::new();
        let mut bound: Vec<Spelling> = Vec::new();
        self.tile(query, text, 0, 0, &mut bound, &mut out)?;
        Ok(out)
    }

    fn tile(
        &self,
        query: &Query,
        text: &[Point],
        pos: usize,
        depth: usize,
        bound: &mut Vec<Spelling>,
        out: &mut Vec<Vec<Spelling>>,
    ) -> Answer<()> {
        if depth == query.factors.len() {
            if pos == text.len() {
                out.push(bound.clone());
            }
            return Ok(());
        }
        let universe = self.universe_at(&query.factors[depth], bound)?;
        for end in pos + 1..=text.len() {
            let face = spelling(&text[pos..end]);
            if !self.den.contains(universe, &face) {
                continue;
            }
            bound.push(face);
            let outcome = self.tile(query, text, end, depth + 1, bound, out);
            bound.pop();
            outcome?;
        }
        Ok(())
    }

    /// A split's sort key under the collision rule: values first, faces to break ties.
    fn claim(&self, query: &Query, split: &[Spelling]) -> Answer<(Vec<usize>, Vec<usize>)> {
        let mut values = Vec::with_capacity(split.len());
        let mut faces = Vec::with_capacity(split.len());
        for (depth, face) in split.iter().enumerate() {
            let universe = self.universe_at(&query.factors[depth], &split[..depth])?;
            let (value, index) = self.address(universe, face)?;
            values.push(value);
            faces.push(index);
        }
        Ok((values, faces))
    }

    /// The hit split as the floor binds it: one face per factor, the least claimant.
    ///
    /// A split the text pins uniquely -- the common case, anchor-pinned -- streams
    /// nothing; an ambiguous one prices each face's address exactly as
    /// [`Engine::canonical`] prices the wearer.
    pub fn factor_faces(&self, query: &Query, found: &Match) -> Answer<Vec<Spelling>> {
        let text: Vec<Point> =
            found.parts.iter().flat_map(|part| part.face.iter().copied()).collect();
        let splits = self.splits(query, &text)?;
        if splits.len() == 1 {
            return Ok(splits.into_iter().next().expect("one split"));
        }
        let mut best: Option<((Vec<usize>, Vec<usize>), Vec<Spelling>)> = None;
        for split in splits {
            let key = self.claim(query, &split)?;
            if best.as_ref().is_none_or(|(seen, _)| key < *seen) {
                best = Some((key, split));
            }
        }
        best.map_or_else(
            || scope("the hit splits no way at all"),
            |(_, split)| Ok(split),
        )
    }

    /// The bound entry re-spelled canonically: each factor's face 0, concatenated.
    ///
    /// `$0` canonicalises the *bound* split, not the matcher's greedy membership
    /// witness -- reading the raw parts would let `$0` disagree with `$1..$n`
    /// wherever the hit splits more than one way.
    pub fn canonical_face(&self, query: &Query, found: &Match) -> Answer<Spelling> {
        let split = self.factor_faces(query, found)?;
        let mut pieces: Vec<Point> = Vec::new();
        for (depth, face) in split.iter().enumerate() {
            let universe = self.universe_at(&query.factors[depth], &split[..depth])?;
            let canonical = self.canonical(universe, face).unwrap_or_else(|| face.clone());
            pieces.extend(canonical.iter().copied());
        }
        Ok(Rc::from(pieces))
    }
}
