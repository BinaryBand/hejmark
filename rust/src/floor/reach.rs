//! The face reach: how long a face a universe can wear.
//!
//! A port of `hejmark/core/floor/reach.py`. A matcher probing a product position
//! has no reason to offer a factor a span longer than the longest face that
//! factor could ever wear, and `L2.md`'s *Permitted rewrites* names exactly that:
//! the bound is read off the expression, never by streaming entries, and no span
//! longer than it can match.
//!
//! The bound is an upper one, and only ever that. A face is its own length, a
//! range spells single code points, a product sums its factors; anything
//! unbounded -- a final segment, a closure, a factor beside one -- returns
//! `None`, "no known bound", which is the correct answer rather than a failure to
//! find one. A subtraction adds no face, so it never raises the bound;
//! over-approximating is safe here (a probe too many costs time),
//! under-approximating would drop a match, so a shape not priced exactly is
//! priced `None`.
//!
//! [`cuts`] is the load-bearing export, and it reads *both* ends of a split
//! search's cut range off the expression. The second end is the one that pays:
//! a cut leaving the factors after it more text than they can spell between them
//! is completed by nothing, so it need not be tried at all.

use std::cell::RefCell;
use std::collections::HashMap;
use std::ops::Range;
use std::rc::Rc;

use super::syntax::{Factor, Member, NodeId, UniverseNode};

thread_local! {
    /// Reaches already measured, keyed by node identity.
    ///
    /// Reach is a pure function of the expression, so this changes no answer.
    /// It is worth keeping because [`cuts`] runs inside a split search's inner
    /// loop, where recomputing a subtree's reach per candidate cut is the cost
    /// the rewrite exists to remove.
    static REACHES: RefCell<HashMap<NodeId, Option<usize>>> = RefCell::new(HashMap::new());
}

/// The length of the longest face the universe wears, or `None` when unbounded.
///
/// Structural: no entry is streamed and no universe denoted, so an infinite
/// universe is priced as cheaply as a finite one. A universe with no member
/// wears nothing and reaches `0`.
///
/// A closure binder is priced through its members like any other node -- the free
/// `&` it binds is itself a member (or a product factor), and that is what
/// returns `None`. A binder whose `&` occurs only inside subtractions adds no
/// face through it, so its adding members bound it exactly.
pub fn reach(node: &Rc<UniverseNode>) -> Option<usize> {
    let key = NodeId(node.clone());
    if let Some(known) = REACHES.with(|memo| memo.borrow().get(&key).copied()) {
        return known;
    }
    // The borrow is dropped before recursing: `measure` re-enters this function
    // through folds and products, and a live borrow would panic.
    let measured = measure(node);
    REACHES.with(|memo| memo.borrow_mut().insert(key, measured));
    measured
}

/// The longest face any adding member of the node contributes.
fn measure(node: &UniverseNode) -> Option<usize> {
    let mut longest = 0;
    for member in &node.members {
        // Stripping faces can only shorten the set, never lengthen it.
        if matches!(member, Member::Subtract(_)) {
            continue;
        }
        let far = member_reach(member)?;
        longest = longest.max(far);
    }
    Some(longest)
}

/// The longest face one adding member contributes, or `None` when unbounded.
fn member_reach(member: &Member) -> Option<usize> {
    match member {
        Member::Face(text) => Some(text.len()),
        Member::Range { lo, hi } => Some(usize::from(lo <= hi)),
        Member::Fold(inner) => reach(inner),
        // A product's faces are concatenations, so its reach is its factors' sum.
        Member::Product(factors) => suffixes(factors)[0],
        Member::Final(_) | Member::Closure => None,
        Member::Subtract(_) => unreachable!("a subtraction adds no face"),
    }
}

/// A product factor's reach; the closure token reads a stage and carries none.
pub fn factor_reach(factor: &Factor) -> Option<usize> {
    match factor {
        Factor::Closure => None,
        Factor::Universe(inner) => reach(inner),
    }
}

/// How far each suffix of a product reaches: `suffixes(f)[i]` covers `f[i..]`.
///
/// One entry longer than `factors`, ending at `0`: no factor left spells nothing.
/// This is the bound read from the *other* end of a split search -- a cut that
/// leaves the factors after it more text than they can ever spell cannot be
/// completed, so it need not be tried. `None` propagates leftward from the first
/// unbounded factor, since nothing to its left has a bounded tail either.
pub fn suffixes(factors: &[Factor]) -> Vec<Option<usize>> {
    tails_of(&factors.iter().map(factor_reach).collect::<Vec<_>>())
}

/// [`suffixes`] over reaches already in hand, for a caller holding no `Factor`s.
///
/// The scan layer's split searches run over denoted universes rather than over
/// AST factors, and wrapping each back into a `Factor` just to be measured would
/// allocate a shape nobody reads.
pub fn tails_of(reaches: &[Option<usize>]) -> Vec<Option<usize>> {
    let mut tails: Vec<Option<usize>> = Vec::with_capacity(reaches.len() + 1);
    tails.push(Some(0));
    for far in reaches.iter().rev() {
        let tail = tails[tails.len() - 1];
        tails.push(match (far, tail) {
            (Some(far), Some(tail)) => Some(far + tail),
            _ => None,
        });
    }
    tails.reverse();
    tails
}

/// Where a split search may cut for this factor, given what its tail can spell.
///
/// Both ends are reach read off the expression. The factor cannot take a piece
/// longer than *it* reaches, so the cut stops there; the factors after it cannot
/// cover more than `tail`, so a cut leaving more than that behind can never be
/// completed and the cut starts there. Where either side is unbounded the text
/// itself is the only bound, which is the honest answer rather than a missing one.
///
/// This is what collapses the language's idiomatic closure, `{@x, &@x}`: the `&`
/// reaches nowhere, but the single-character factor beside it pins the cut to the
/// last position, turning a scan of every cut into a look at one.
pub fn cuts(factor: &Factor, tail: Option<usize>, pos: usize, length: usize) -> Range<usize> {
    cut_range(factor_reach(factor), tail, pos, length)
}

/// [`cuts`] from a reach already in hand -- the same two ends, no `Factor` needed.
pub fn cut_range(
    far: Option<usize>,
    tail: Option<usize>,
    pos: usize,
    length: usize,
) -> Range<usize> {
    let stop = match far {
        Some(far) => (pos + far).min(length),
        None => length,
    };
    let start = match tail {
        Some(tail) => pos.max(length.saturating_sub(tail)),
        None => pos,
    };
    start..stop + 1
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    fn node(members: Vec<Member>) -> Rc<UniverseNode> {
        Rc::new(UniverseNode { members })
    }

    fn face(text: &str) -> Member {
        Member::Face(cp(text))
    }

    #[test]
    fn a_face_reaches_its_own_length() {
        assert_eq!(reach(&node(vec![face("abc")])), Some(3));
    }

    #[test]
    fn a_union_reaches_its_longest_member() {
        assert_eq!(reach(&node(vec![face("a"), face("abcd")])), Some(4));
    }

    #[test]
    fn an_empty_universe_wears_nothing() {
        assert_eq!(reach(&node(vec![])), Some(0));
    }

    #[test]
    fn a_range_spells_one_code_point_and_a_reversed_one_spells_none() {
        let lo = 'a' as u32;
        let hi = 'z' as u32;
        assert_eq!(reach(&node(vec![Member::Range { lo, hi }])), Some(1));
        assert_eq!(
            reach(&node(vec![Member::Range { lo: hi, hi: lo }])),
            Some(0)
        );
    }

    #[test]
    fn a_final_segment_and_a_closure_are_unbounded() {
        assert_eq!(reach(&node(vec![Member::Final(cp("a"))])), None);
        assert_eq!(reach(&node(vec![Member::Closure])), None);
    }

    #[test]
    fn a_product_sums_its_factors() {
        let product = Member::Product(vec![
            Factor::Universe(node(vec![face("ab")])),
            Factor::Universe(node(vec![face("cde")])),
        ]);
        assert_eq!(reach(&node(vec![product])), Some(5));
    }

    #[test]
    fn a_factor_beside_a_closure_is_unbounded() {
        let product = Member::Product(vec![
            Factor::Universe(node(vec![face("a")])),
            Factor::Closure,
        ]);
        assert_eq!(reach(&node(vec![product])), None);
    }

    #[test]
    fn a_subtraction_never_raises_the_bound() {
        let n = node(vec![
            face("ab"),
            Member::Subtract(node(vec![face("abcdef")])),
        ]);
        assert_eq!(reach(&n), Some(2));
    }

    #[test]
    fn a_fold_reaches_through_to_its_inner_universe() {
        let n = node(vec![Member::Fold(node(vec![face("a"), face("abc")]))]);
        assert_eq!(reach(&n), Some(3));
    }

    #[test]
    fn suffixes_run_one_longer_than_the_factors_and_end_at_zero() {
        let factors = vec![
            Factor::Universe(node(vec![face("ab")])),
            Factor::Universe(node(vec![face("c")])),
        ];
        assert_eq!(suffixes(&factors), vec![Some(3), Some(1), Some(0)]);
    }

    #[test]
    fn an_unbounded_factor_unbounds_every_suffix_to_its_left() {
        let factors = vec![
            Factor::Universe(node(vec![face("a")])),
            Factor::Closure,
            Factor::Universe(node(vec![face("b")])),
        ];
        assert_eq!(suffixes(&factors), vec![None, None, Some(1), Some(0)]);
    }

    #[test]
    fn a_factors_own_reach_caps_the_cut() {
        // A two-character factor cannot wear more than two of the ten left.
        // The tail is unbounded here so that only the cap is under test.
        let factor = Factor::Universe(node(vec![face("ab")]));
        assert_eq!(cuts(&factor, None, 0, 10), 0..3);
    }

    #[test]
    fn a_bounded_factor_with_nothing_after_it_must_finish_the_text() {
        // The last factor's tail reaches zero, so the only admissible cut is the
        // end of the text -- and a two-character factor ten characters from the
        // end leaves no cut at all, which is the range being empty rather than
        // an error.
        let factor = Factor::Universe(node(vec![face("ab")]));
        assert!(cuts(&factor, Some(0), 0, 10).is_empty());
        assert_eq!(cuts(&factor, Some(0), 8, 10), 10..11);
    }

    #[test]
    fn the_tails_reach_floors_the_cut() {
        // Ten characters left and a tail spelling at most three: a cut before
        // position seven strands text nothing can complete.
        let factor = Factor::Closure;
        assert_eq!(cuts(&factor, Some(3), 0, 10), 7..11);
    }

    #[test]
    fn an_unbounded_factor_beside_a_bounded_one_pins_the_cut() {
        // `{@x, &@x}`: the `&` reaches nowhere, but its single-character
        // neighbour leaves exactly one cut worth trying.
        let factor = Factor::Closure;
        assert_eq!(cuts(&factor, Some(1), 0, 9).count(), 2);
    }

    #[test]
    fn both_ends_unbounded_leaves_the_text_as_the_only_bound() {
        assert_eq!(cuts(&Factor::Closure, None, 2, 10), 2..11);
    }

    #[test]
    fn a_tail_longer_than_the_text_floors_at_the_position() {
        // The subtraction here is saturating: a tail that outreaches the text
        // constrains nothing, and must not wrap.
        let factor = Factor::Universe(node(vec![face("a")]));
        assert_eq!(cuts(&factor, Some(100), 3, 10), 3..5);
    }
}
