//! The capture reads: what `$`, `$0` and `$1..$n` see on a hit.
//!
//! A port of `hejmark/core/scan/capture.py`. The floor already carries the
//! pair, so a capture is a binding and never a store. `$` is the hit as it hit;
//! `$0` is its canonical face -- the entry's face 0; `$k` is factor `k` of the
//! hit, a component of the bound tuple.
//!
//! Membership says *whether* a spelling is worn, not which entry wears it -- yet
//! the canonical face is that entry's face 0, and the bound tuple is the least
//! `<value, face>` claimant where a spelling splits more than one way. Both
//! reads therefore stream the entries (value order being iteration order) and
//! refuse past [`BUDGET`] rather than hang.
//!
//! The Python's `Factor` also admits a back-referencing `Late`, resolved per
//! candidate split under the faces already chosen; that belongs to the surface
//! layer, so here every factor is a plain denoted universe and the split need
//! carry no bindings.

use crate::floor::universe::Universe;
use crate::scan::r#match::{Match, Query};
use crate::surface::ast::HimarkScopeError;

/// How many entries a canonical-face read streams before giving up.
///
/// Reaching a wearer costs its position, and a position is not bounded by
/// anything the matcher knows: `{a..}` wears `zz`, but only after every shorter
/// spelling and every two-character one below it over the whole code space --
/// some 137 million entries. The budget is far above any hand-written fold (the
/// case `$0` exists for) and far below that.
pub const BUDGET: usize = 100_000;

/// One face per factor: the split of a hit the floor binds.
type Split = Vec<Vec<u32>>;

/// A split's collision key: the wearers' stream positions, then their face indices.
type Claim = (Vec<usize>, Vec<usize>);

/// The canonical face of the entry wearing `spelling`, or `None` if none does.
///
/// # Errors
///
/// Returns a [`HimarkScopeError`] when the wearer is not reached within
/// [`BUDGET`]: a worn spelling always sits at a finite but possibly astronomical
/// position, and the matcher that accepted the hit cannot say which case it is.
pub fn canonical(
    universe: &Universe,
    spelling: &[u32],
) -> Result<Option<Vec<u32>>, HimarkScopeError> {
    for (position, entry) in universe.entries().enumerate() {
        if entry.faces.iter().any(|face| face.as_slice() == spelling) {
            return Ok(Some(entry.faces[0].clone()));
        }
        if position >= BUDGET {
            return Err(HimarkScopeError {
                message: format!(
                    "cannot read the canonical face of {spelling:?}: no entry wearing it \
                     appears within the first {BUDGET} of an unbounded universe"
                ),
            });
        }
    }
    Ok(None)
}

/// Every exact tiling of `text` by the factors, one non-empty face per factor.
fn splits_of(factors: &[Universe], text: &[u32]) -> Result<Vec<Split>, HimarkScopeError> {
    let mut found: Vec<Split> = Vec::new();
    extend_splits(factors, text, 0, 0, &mut Vec::new(), &mut found)?;
    Ok(found)
}

/// Extend `acc` with every tiling of `text[pos..]` by `factors[depth..]`.
fn extend_splits(
    factors: &[Universe],
    text: &[u32],
    depth: usize,
    pos: usize,
    acc: &mut Split,
    found: &mut Vec<Split>,
) -> Result<(), HimarkScopeError> {
    if depth == factors.len() {
        if pos == text.len() {
            found.push(acc.clone());
            if found.len() > BUDGET {
                return Err(HimarkScopeError {
                    message: format!(
                        "cannot bind the factors of {text:?}: more than {BUDGET} splits"
                    ),
                });
            }
        }
        return Ok(());
    }
    for end in (pos + 1)..=text.len() {
        let face = &text[pos..end];
        if !factors[depth].contains(face) {
            continue;
        }
        acc.push(face.to_vec());
        extend_splits(factors, text, depth + 1, end, acc, found)?;
        acc.pop();
    }
    Ok(())
}

/// The `<value, face>` address of the entry wearing `face`: stream position, then face index.
///
/// # Errors
///
/// Returns a [`HimarkScopeError`] when the wearer is not reached within [`BUDGET`].
fn address(universe: &Universe, face: &[u32]) -> Result<(usize, usize), HimarkScopeError> {
    for (position, entry) in universe.entries().enumerate() {
        if let Some(index) = entry.faces.iter().position(|f| f.as_slice() == face) {
            return Ok((position, index));
        }
        if position >= BUDGET {
            break;
        }
    }
    Err(HimarkScopeError {
        message: format!(
            "cannot address {face:?}: no entry wearing it appears within the first \
             {BUDGET} of an unbounded universe"
        ),
    })
}

/// A split's sort key under the collision rule: values first, faces to break ties.
fn claim(factors: &[Universe], split: &Split) -> Result<Claim, HimarkScopeError> {
    let mut values = Vec::with_capacity(split.len());
    let mut faces = Vec::with_capacity(split.len());
    for (factor, face) in factors.iter().zip(split.iter()) {
        let (value, index) = address(factor, face)?;
        values.push(value);
        faces.push(index);
    }
    Ok((values, faces))
}

/// The hit split as the floor binds it: one face per factor, the least claimant.
///
/// The matcher's parts are a membership witness -- any split proves the hit --
/// but the floor gives a contested spelling to its least `<value, face>` address,
/// so a factor read consults the collision rule wherever the hit splits more than
/// one way. A uniquely pinned split streams nothing.
///
/// # Errors
///
/// Returns a [`HimarkScopeError`] when the splits, or an address, outrun [`BUDGET`].
pub fn factor_faces(query: &Query, found: &Match) -> Result<Split, HimarkScopeError> {
    let text: Vec<u32> = found
        .parts
        .iter()
        .flat_map(|part| part.face.iter().copied())
        .collect();
    let mut splits = splits_of(&query.universes, &text)?;
    if splits.len() == 1 {
        return Ok(splits.swap_remove(0));
    }
    let mut best: Option<(Split, Claim)> = None;
    for split in splits {
        let key = claim(&query.universes, &split)?;
        let replace = match &best {
            Some((_, best_key)) => key < *best_key,
            None => true,
        };
        if replace {
            best = Some((split, key));
        }
    }
    Ok(best.expect("a matched hit always has at least one split").0)
}

/// The whole match re-spelled canonically: each part's face 0, concatenated.
///
/// Adjacency is the product, so a compound query is one entry and one binding.
/// Where a part's wearer cannot be found, the part stands as it hit.
///
/// # Errors
///
/// Returns a [`HimarkScopeError`] when a canonical-face read outruns [`BUDGET`].
pub fn canonical_face(query: &Query, found: &Match) -> Result<Vec<u32>, HimarkScopeError> {
    let mut spelling: Vec<u32> = Vec::new();
    for (factor, part) in query.universes.iter().zip(found.parts.iter()) {
        let piece = canonical(factor, &part.face)?.unwrap_or_else(|| part.face.clone());
        spelling.extend(piece);
    }
    Ok(spelling)
}

#[cfg(test)]
mod tests {
    use super::{canonical, canonical_face, factor_faces};
    use crate::floor::syntax::{Member, UniverseNode};
    use crate::floor::universe::{denote, Universe};
    use crate::scan::r#match::{match_, Query};

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    fn node(members: Vec<Member>) -> UniverseNode {
        UniverseNode { members }
    }

    fn face(text: &str) -> Member {
        Member::Face(cp(text))
    }

    /// A fold of the given faces: one entry worn by all of them.
    fn folded(faces: &[&str]) -> Universe {
        let inner = node(faces.iter().map(|f| face(f)).collect());
        denote(&node(vec![Member::Fold(inner)]))
    }

    fn query(universes: Vec<Universe>) -> Query {
        Query::new("<hand-built>", universes)
    }

    #[test]
    fn canonical_finds_the_wearer_of_a_later_face() {
        // A fold's entry is worn by every face; face 0 is the canonical one.
        let universe = folded(&["cat", "feline"]);
        assert_eq!(
            canonical(&universe, &cp("feline")).unwrap(),
            Some(cp("cat"))
        );
        assert_eq!(canonical(&universe, &cp("cat")).unwrap(), Some(cp("cat")));
    }

    #[test]
    fn canonical_is_none_when_no_entry_wears_the_spelling() {
        let universe = denote(&node(vec![face("a"), face("b")]));
        assert_eq!(canonical(&universe, &cp("z")).unwrap(), None);
    }

    #[test]
    fn canonical_reaches_a_wearer_near_the_front_of_an_infinite_stream() {
        let universe = denote(&node(vec![Member::Final(cp("a"))]));
        assert_eq!(canonical(&universe, &cp("b")).unwrap(), Some(cp("b")));
    }

    #[test]
    fn canonical_refuses_a_wearer_it_cannot_reach() {
        // `{a..}` wears `zz`, but only past millions of shorter spellings.
        let universe = denote(&node(vec![Member::Final(cp("a"))]));
        let error = canonical(&universe, &cp("zz")).unwrap_err();
        assert!(
            error.message.contains("canonical face"),
            "{}",
            error.message
        );
    }

    #[test]
    fn canonical_face_rejoins_a_product() {
        let q = query(vec![folded(&["cat", "feline"]), folded(&["dog", "canine"])]);
        let found = match_(&q, &cp("felinecanine"), 0).unwrap();
        assert_eq!(canonical_face(&q, &found).unwrap(), cp("catdog"));
    }

    #[test]
    fn canonical_face_leaves_a_part_as_it_hit_when_unfound() {
        // The read stays total: a reachable part re-spells to itself here.
        let q = query(vec![denote(&node(vec![Member::Final(cp("a"))]))]);
        let found = match_(&q, &cp("q"), 0).unwrap();
        assert_eq!(canonical_face(&q, &found).unwrap(), cp("q"));
    }

    #[test]
    fn factor_faces_reads_a_pinned_split_without_streaming() {
        let q = query(vec![
            denote(&node(vec![face("ab")])),
            denote(&node(vec![face("c")])),
        ]);
        let found = match_(&q, &cp("abc"), 0).unwrap();
        assert_eq!(factor_faces(&q, &found).unwrap(), vec![cp("ab"), cp("c")]);
    }

    #[test]
    fn factor_faces_binds_the_least_claimant_of_an_ambiguous_split() {
        // The greedy witness is `(ab, c)` -- value 2 -- but the floor binds
        // `(a, bc)`, the value-1 claimant, and the reads follow the floor.
        let q = query(vec![
            denote(&node(vec![face("a"), face("ab")])),
            denote(&node(vec![face("c"), face("bc")])),
        ]);
        let found = match_(&q, &cp("abc"), 0).unwrap();
        assert_eq!(found.parts[0].face, cp("ab"));
        assert_eq!(factor_faces(&q, &found).unwrap(), vec![cp("a"), cp("bc")]);
    }

    #[test]
    fn factor_faces_breaks_a_value_tie_by_face_index() {
        // Two splits over the same entries part on the face axis; lower index wins.
        let q = query(vec![folded(&["a", "ab"]), folded(&["bc", "c"])]);
        let found = match_(&q, &cp("abc"), 0).unwrap();
        assert_eq!(factor_faces(&q, &found).unwrap(), vec![cp("a"), cp("bc")]);
    }

    #[test]
    fn factor_faces_refuses_an_address_it_cannot_reach() {
        // `zzb` splits as `z|zb` and `zz|b`; settling which is least streams to
        // a two-character address, millions in. The read refuses rather than hang.
        let q = query(vec![
            denote(&node(vec![Member::Final(cp("a"))])),
            denote(&node(vec![Member::Final(cp("a"))])),
        ]);
        let found = match_(&q, &cp("zzb"), 0).unwrap();
        let error = factor_faces(&q, &found).unwrap_err();
        assert!(
            error.message.contains("cannot address"),
            "{}",
            error.message
        );
    }
}
