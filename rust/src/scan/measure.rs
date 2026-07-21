//! The contracting measure's read: which of two spellings sits earlier.
//!
//! A port of `hejmark/core/engine/scan/measure.py`. A `<=>` statement settles because
//! every pass strictly descends its declared measure's entry order -- iteration
//! order, value order as ever, a well-order with no infinite descent. This
//! module decides the descent: [`precedes`] says whether one spelling's entry
//! sits strictly before another's.
//!
//! Nothing here streams entries. The stream's order is structural -- member-major
//! across a union, spelling order inside a window, leftmost-slowest across a
//! product, stage-major up a closure -- so the comparison recurses down the same
//! structure the stream walks, and an infinite stretch of entries between the two
//! spellings costs nothing to step over. The one search is a product's tilings,
//! budgeted exactly as a factor read is (on the `$0` shelf). Two spellings of one
//! entry compare equal, which [`precedes`] reports as not earlier.

use std::cmp::Ordering;
use std::rc::Rc;

use crate::floor::binder::binds;
use crate::floor::order::shortlex_cmp;
use crate::floor::reach::{cuts, suffixes};
use crate::floor::syntax::{Factor, Member};
use crate::floor::universe::{denote, walk, Amp, Universe};
use crate::floor::work::charge;
use crate::scan::capture::BUDGET;
use crate::surface::ast::HimarkScopeError;

/// One face per factor: a tiling of a spelling across a product's factors.
type Split = Vec<Vec<u32>>;

/// Whether `left`'s entry sits strictly earlier than `right`'s.
///
/// Both spellings must be worn by `universe`; membership is the caller's exact
/// oracle for that. Faces of one entry are nowhere earlier than each other, so
/// they compare not-earlier in both directions.
///
/// # Errors
///
/// Returns a [`HimarkScopeError`] for a spelling the universe does not wear, or a
/// split search past [`BUDGET`].
pub fn precedes(
    universe: &Universe,
    left: &[u32],
    right: &[u32],
) -> Result<bool, HimarkScopeError> {
    Ok(compare(universe, left, right)? == Ordering::Less)
}

/// The not-worn refusal: order is asked only of members.
fn refuse(spelling: &[u32]) -> HimarkScopeError {
    HimarkScopeError {
        message: format!("the measure does not spell {spelling:?}"),
    }
}

/// Three-way entry order of `left` against `right`.
fn compare(universe: &Universe, left: &[u32], right: &[u32]) -> Result<Ordering, HimarkScopeError> {
    if left == right {
        return Ok(Ordering::Equal);
    }
    let node = universe.node();
    if !binds(node) {
        return within(&node.members, universe.amp(), left, right);
    }
    let lo = stage_of(universe, left)?;
    let hi = stage_of(universe, right)?;
    if lo != hi {
        return Ok(lo.cmp(&hi));
    }
    let staged: Amp = Some(Rc::new(universe.at_stage(lo - 1)));
    within(&node.members, &staged, left, right)
}

/// The stage a closure first spells `spelling` at; settled bodies bound it.
fn stage_of(universe: &Universe, spelling: &[u32]) -> Result<usize, HimarkScopeError> {
    let mut bound = spelling.len() + 1;
    if let Some(limit) = universe.stage_limit() {
        bound = bound.min(limit);
    }
    for stage in 1..=bound {
        if universe.at_stage(stage).contains(spelling) {
            return Ok(stage);
        }
    }
    Err(refuse(spelling))
}

/// Compare inside one member list: owner-major, then within the owner.
fn within(
    members: &[Member],
    amp: &Amp,
    left: &[u32],
    right: &[u32],
) -> Result<Ordering, HimarkScopeError> {
    let (lo, owner) = owner_of(members, amp, left)?;
    let (hi, _other) = owner_of(members, amp, right)?;
    if lo != hi {
        return Ok(lo.cmp(&hi));
    }
    same(owner, amp, left, right)
}

/// The member whose stream carries `face`, with its index.
///
/// Mirrors the stream's conditions: the member wears the face, no member to the
/// left already claims it, and no subtraction to the right strips it. Dropped
/// faces shift positions but never reorder, so the owner index carries the
/// member-major half of the order.
///
/// The three walks here go to the member-level oracle rather than through
/// `contains`, so the open budget is charged for them by hand, exactly as the
/// Python's `_owner` does.
fn owner_of<'a>(
    members: &'a [Member],
    amp: &Amp,
    face: &[u32],
) -> Result<(usize, &'a Member), HimarkScopeError> {
    for (index, member) in members.iter().enumerate() {
        if matches!(member, Member::Subtract(_)) {
            continue;
        }
        charge(1);
        if !walk(std::slice::from_ref(member), amp, face) {
            continue;
        }
        if walk(&members[..index], amp, face) {
            continue;
        }
        let stripped = members[index + 1..].iter().any(|member| match member {
            Member::Subtract(inner) => walk(&inner.members, amp, face),
            _ => false,
        });
        if stripped {
            continue;
        }
        return Ok((index, member));
    }
    Err(refuse(face))
}

/// Compare two faces the same member carries, by that member's own order.
fn same(
    member: &Member,
    amp: &Amp,
    left: &[u32],
    right: &[u32],
) -> Result<Ordering, HimarkScopeError> {
    match member {
        Member::Face(_) => Ok(Ordering::Equal),
        // A binder's brace splices its closure; anything else folds to one entry.
        // Either way the brace seals its own `&`, so no amp reaches in.
        Member::Fold(inner) => {
            if binds(inner) {
                compare(&denote(inner), left, right)
            } else {
                Ok(Ordering::Equal)
            }
        }
        Member::Range { .. } | Member::Final(_) => Ok(shortlex_cmp(left, right)),
        Member::Closure => compare(&amp_universe(amp), left, right),
        Member::Product(factors) => product(factors, amp, left, right),
        Member::Subtract(_) => unreachable!("owner is never a subtraction"),
    }
}

/// Compare inside a product: leftmost factor moves slowest, so lex by factor.
fn product(
    factors: &[Factor],
    amp: &Amp,
    left: &[u32],
    right: &[u32],
) -> Result<Ordering, HimarkScopeError> {
    let first = least(factors, amp, left)?;
    let second = least(factors, amp, right)?;
    for ((factor, one), other) in factors.iter().zip(first.iter()).zip(second.iter()) {
        let ordering = compare(&factor_universe(factor, amp), one, other)?;
        if ordering != Ordering::Equal {
            return Ok(ordering);
        }
    }
    Ok(Ordering::Equal)
}

/// The split the floor binds: the least claimant among every tiling of `face`.
fn least(factors: &[Factor], amp: &Amp, face: &[u32]) -> Result<Split, HimarkScopeError> {
    let splits = tilings(factors, amp, face)?;
    let mut best = splits[0].clone();
    for split in &splits[1..] {
        if lex(factors, amp, split, &best)? == Ordering::Less {
            best = split.clone();
        }
    }
    Ok(best)
}

/// Compare two tilings of one spelling, factor entry by factor entry.
fn lex(
    factors: &[Factor],
    amp: &Amp,
    split: &Split,
    other: &Split,
) -> Result<Ordering, HimarkScopeError> {
    for ((factor, one), two) in factors.iter().zip(split.iter()).zip(other.iter()) {
        let ordering = compare(&factor_universe(factor, amp), one, two)?;
        if ordering != Ordering::Equal {
            return Ok(ordering);
        }
    }
    Ok(Ordering::Equal)
}

/// What a tiling search carries unchanged as it descends.
struct Tiling<'a> {
    factors: &'a [Factor],
    tails: Vec<Option<usize>>,
    amp: &'a Amp,
    spelling: &'a [u32],
}

/// Every split of `spelling` into consecutive factor faces, empty pieces included.
fn tilings(
    factors: &[Factor],
    amp: &Amp,
    spelling: &[u32],
) -> Result<Vec<Split>, HimarkScopeError> {
    let search = Tiling {
        factors,
        tails: suffixes(factors),
        amp,
        spelling,
    };
    let mut found: Vec<Split> = Vec::new();
    extend_tilings(&search, 0, 0, &mut Vec::new(), &mut found)?;
    if found.is_empty() {
        return Err(refuse(spelling));
    }
    Ok(found)
}

/// Extend `acc` with every tiling of `spelling[pos..]` from `depth` on.
///
/// The seating search asks what the floor's own split search asks, so it takes
/// the same permitted rewrite: [`cuts`] reads both ends of the cut range off the
/// expression rather than trying every position.
fn extend_tilings(
    search: &Tiling<'_>,
    depth: usize,
    pos: usize,
    acc: &mut Split,
    found: &mut Vec<Split>,
) -> Result<(), HimarkScopeError> {
    let spelling = search.spelling;
    if depth == search.factors.len() {
        if pos == spelling.len() {
            found.push(acc.clone());
            if found.len() > BUDGET {
                return Err(HimarkScopeError {
                    message: format!(
                        "cannot seat {spelling:?} in the measure: more than {BUDGET} splits"
                    ),
                });
            }
        }
        return Ok(());
    }
    let factor = &search.factors[depth];
    let universe = factor_universe(factor, search.amp);
    for end in cuts(factor, search.tails[depth + 1], pos, spelling.len()) {
        if universe.contains(&spelling[pos..end]) {
            acc.push(spelling[pos..end].to_vec());
            extend_tilings(search, depth + 1, end, acc, found)?;
            acc.pop();
        }
    }
    Ok(())
}

/// A product factor as a universe; the closure token reads the binder's stage.
fn factor_universe(factor: &Factor, amp: &Amp) -> Rc<Universe> {
    match factor {
        Factor::Closure => amp_universe(amp),
        Factor::Universe(inner) => Rc::new(denote(inner)),
    }
}

/// The universe a free `&` reads; the grammar guarantees a binder exists.
fn amp_universe(amp: &Amp) -> Rc<Universe> {
    match amp {
        Some(universe) => universe.clone(),
        None => panic!("free `&` outside any binder"),
    }
}

#[cfg(test)]
mod tests {
    use super::precedes;
    use crate::floor::syntax::{Factor, Member, UniverseNode};
    use crate::floor::universe::{denote, Universe};

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    use std::rc::Rc;

    /// Nested positions hold shared nodes, and `&Rc<T>` coerces to `&T`, so one
    /// helper serves both.
    fn node(members: Vec<Member>) -> Rc<UniverseNode> {
        Rc::new(UniverseNode { members })
    }

    fn face(text: &str) -> Member {
        Member::Face(cp(text))
    }

    fn range(lo: char, hi: char) -> Member {
        Member::Range {
            lo: lo as u32,
            hi: hi as u32,
        }
    }

    /// The universe of a single-factor query, denoted from a hand-built node.
    fn universe(members: Vec<Member>) -> Universe {
        denote(&node(members))
    }

    /// A product member of two brace-group factors.
    fn product(left: Vec<Member>, right: Vec<Member>) -> Member {
        Member::Product(vec![
            Factor::Universe(node(left)),
            Factor::Universe(node(right)),
        ])
    }

    fn earlier(u: &Universe, left: &str, right: &str) -> bool {
        precedes(u, &cp(left), &cp(right)).unwrap()
    }

    #[test]
    fn union_order_is_member_major() {
        // Entries stream in declaration order, so the written order is the order.
        let u = universe(vec![face("z"), face("a")]);
        assert!(earlier(&u, "z", "a"));
        assert!(!earlier(&u, "a", "z"));
    }

    #[test]
    fn window_order_is_spelling_order() {
        let u = universe(vec![range('a', 'z')]);
        assert!(earlier(&u, "b", "c"));
        assert!(!earlier(&u, "c", "b"));
    }

    #[test]
    fn faces_of_one_entry_are_nowhere_earlier() {
        // A fold is one entry, so re-spelling it is no descent either way.
        let u = universe(vec![Member::Fold(node(vec![face("cat"), face("feline")]))]);
        assert!(!earlier(&u, "cat", "feline"));
        assert!(!earlier(&u, "feline", "cat"));
    }

    #[test]
    fn product_order_runs_leftmost_slowest() {
        // The most significant factor moves slowest, so the order is lex by factor.
        let u = universe(vec![product(
            vec![face("a"), face("b")],
            vec![face("c"), face("d")],
        )]);
        assert!(earlier(&u, "ac", "ad"));
        assert!(earlier(&u, "ad", "bc"));
        assert!(!earlier(&u, "bc", "ad"));
    }

    #[test]
    fn closure_order_is_stage_major() {
        // A later stage sits after every entry of an earlier one, however spelled.
        // `{a, &a}` -> Product((&, {a})).
        let u = universe(vec![
            face("a"),
            Member::Product(vec![
                Factor::Closure,
                Factor::Universe(node(vec![face("a")])),
            ]),
        ]);
        assert!(earlier(&u, "a", "aa"));
        assert!(earlier(&u, "aa", "aaa"));
        assert!(!earlier(&u, "aaa", "aa"));
    }

    #[test]
    fn a_subtraction_moves_the_owner_rightward() {
        // A face stripped from the run belongs to the member that re-adds it.
        let u = universe(vec![
            range('a', 'c'),
            Member::Subtract(node(vec![face("b")])),
            face("b"),
        ]);
        assert!(earlier(&u, "c", "b"));
        assert!(!earlier(&u, "b", "c"));
    }

    #[test]
    fn a_spelling_the_universe_does_not_wear_is_refused() {
        // Order is asked only of members; anything else is a scope error.
        let u = universe(vec![face("a")]);
        let error = precedes(&u, &cp("z"), &cp("a")).unwrap_err();
        assert!(
            error.message.contains("does not spell"),
            "{}",
            error.message
        );
    }
}
