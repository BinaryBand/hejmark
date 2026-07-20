//! Universe algebra: denote a faithful AST to lazy, computational universes.
//!
//! A port of `hejmark/core/floor/universe.py`. A denoted [`Universe`] answers
//! two questions, both computed structurally from the AST rather than from a
//! stored table. [`Universe::contains`] is pure set algebra over the six
//! constructors, because collision never changes it (a claimed spelling merely
//! moves owner). [`Universe::entries`] streams the entries in declaration order
//! with the collision rule applied -- a spelling is claimed by the least
//! `<value, face>` address, every later claimant drops it, and an entry that
//! loses every face drops with them.
//!
//! The closure `&` binds to the innermost enclosing brace expression other than
//! a subtraction operand, which then denotes the closure at omega of its body:
//! inflationary stages, first-appearance order. Membership is decided at stage
//! `len(spelling) + 1` -- exact on settled (guarded) bodies; on an unsettled
//! body presence is still reported when a stage shows it, but absence has no
//! bound and unwinds with [`HimarkUnsettledError`], while `entries` streams any
//! closure stage by stage (denotation stays total).
//!
//! Two departures from the Python, neither of which changes a result:
//!
//! - `str` spellings become `Vec<u32>` code points, as everywhere in this crate.
//! - The Python memoizes `_contains` on an `lru_cache`; that cache is a
//!   performance optimization (membership is a pure function), so this port
//!   omits it for now and keeps only the local, correctness-bearing split memo.
//!   Its absence is why `Universe` needs no `Hash`.
//!
//! Laziness is the one discipline: nothing here materializes an infinite object,
//! so iterating an infinite universe simply never ends, and folding one into a
//! single entry is the caller's non-terminating loop to ask for.

use std::collections::{HashMap, HashSet};
use std::fmt;
use std::rc::Rc;

use super::binder::{binds, settled};
use super::syntax::{Factor, Member, UniverseNode};
use super::window::{carve, window_of};

/// The stage a free `&` in some members reads (`None` outside any binder).
type Amp = Option<Rc<Universe>>;
/// A liveness test: whether a face is still unclaimed at its point of use.
type Live = Rc<dyn Fn(&[u32]) -> bool>;
/// A lazy stream of entries; owns its state, so it is safe over infinity.
type Entries = Box<dyn Iterator<Item = Entry>>;
/// One factor face-tuple per factor, in factor order -- the shape [`tuples`] yields.
type Combo = Vec<Vec<Vec<u32>>>;

/// Signals that membership in an unsettled closure cannot be decided.
///
/// The Python raises this as a `ValueError`; the Rust analog unwinds via
/// `panic_any`, so a caller recovers it with `catch_unwind` and `downcast_ref`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HimarkUnsettledError {
    /// A human-readable description of the undecidable query.
    pub message: String,
}

impl fmt::Display for HimarkUnsettledError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for HimarkUnsettledError {}

/// One member of a universe: the spellings that wear it, canonical face first.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Entry {
    /// The faces this entry wears, canonical (least-address) face first.
    pub faces: Vec<Vec<u32>>,
}

/// A denoted universe: a brace expression plus what its free `&` reads.
///
/// `amp` is the stage a free `&` in the members denotes (`None` outside any
/// binder). When the node is itself a binder, `stages` truncates the closure to
/// its first `stages` passes -- the stage universe `X_k` -- while `None` means
/// the full closure at omega.
#[derive(Clone)]
pub struct Universe {
    node: Rc<UniverseNode>,
    amp: Amp,
    stages: Option<usize>,
}

impl Universe {
    fn new(node: Rc<UniverseNode>, amp: Amp, stages: Option<usize>) -> Universe {
        Universe { node, amp, stages }
    }

    /// A brace expression denoted with its own `&` sealed: no outer stage reaches in.
    fn sealed(node: &UniverseNode) -> Universe {
        Universe::new(Rc::new(node.clone()), None, None)
    }

    /// Whether some entry of this universe wears `spelling`.
    ///
    /// # Panics
    ///
    /// Unwinds with a [`HimarkUnsettledError`] payload when the node is an
    /// unsettled closure and no stage up to `len(spelling) + 1` shows `spelling`:
    /// absence then has no bound.
    pub fn contains(&self, spelling: &[u32]) -> bool {
        if !binds(&self.node) {
            return walk(&self.node.members, &self.amp, spelling);
        }
        let bound = match self.stages {
            Some(stages) => stages,
            None => spelling.len() + 1,
        };
        for stage in 0..bound {
            let staged = Rc::new(Universe::new(
                self.node.clone(),
                self.amp.clone(),
                Some(stage),
            ));
            if walk(&self.node.members, &Some(staged), spelling) {
                return true;
            }
        }
        if self.stages.is_some() || settled(&self.node, &spells_empty_oracle) {
            return false;
        }
        std::panic::panic_any(HimarkUnsettledError {
            message: format!(
                "membership of {spelling:?} in an unsettled closure has no stage bound"
            ),
        })
    }

    /// Yield the entries in declaration order, lazily -- safe over infinity.
    pub fn entries(&self) -> Entries {
        if binds(&self.node) {
            closure_entries(self.node.clone(), self.amp.clone(), self.stages)
        } else {
            stream(self.node.clone(), self.amp.clone(), None)
        }
    }
}

/// Denote a universe AST node to a lazy [`Universe`].
pub fn denote(node: &UniverseNode) -> Universe {
    Universe::sealed(node)
}

/// The emptiness oracle `binder::settled` needs: does this node wear `""`?
fn spells_empty_oracle(node: &UniverseNode) -> bool {
    Universe::sealed(node).contains(&[])
}

/// The union/subtraction walk: presence after the member list, left to right.
///
/// Public because it is the member-level membership oracle: a caller asking
/// about a *slice* of a binder's members cannot re-brace the slice without
/// rebinding its free `&`, so it asks here with the binder's `amp` intact.
pub fn walk(members: &[Member], amp: &Amp, spelling: &[u32]) -> bool {
    let mut present = false;
    for member in members {
        if let Member::Subtract(inner) = member {
            present = present && !walk(&inner.members, amp, spelling);
        } else if !present {
            present = spells(member, amp, spelling);
        }
    }
    present
}

/// Whether the member's face set holds `spelling` (claims never shrink it).
fn spells(member: &Member, amp: &Amp, spelling: &[u32]) -> bool {
    match member {
        Member::Face(text) => text.as_slice() == spelling,
        Member::Range { .. } | Member::Final(_) => window_of(member)
            .expect("range or final has a window")
            .contains(spelling),
        Member::Fold(inner) => braced_spells(inner, spelling),
        Member::Closure => amp_of(amp).contains(spelling),
        Member::Product(factors) => splits(factors, amp, spelling),
        Member::Subtract(_) => unreachable!("subtraction is handled in walk"),
    }
}

/// A braced member's face set: its universe's faces, plus the fold-to-unit boundary.
///
/// A fold of the empty alphabet is the unit, so it wears the empty spelling; a
/// binder splices its closure instead. A brace that is not a subtraction operand
/// seals its own `&`, so no outer stage reaches in.
fn braced_spells(inner: &UniverseNode, spelling: &[u32]) -> bool {
    let universe = Universe::sealed(inner);
    if spelling.is_empty() && !binds(inner) {
        return universe.contains(&[]) || universe.entries().next().is_none();
    }
    universe.contains(spelling)
}

/// Whether `spelling` splits into consecutive pieces, one per factor's faces.
fn splits(factors: &[Factor], amp: &Amp, spelling: &[u32]) -> bool {
    let mut memo: HashMap<(usize, usize), bool> = HashMap::new();
    splits_rest(factors, amp, spelling, 0, 0, &mut memo)
}

/// Whether `spelling[pos..]` splits across the factors from `index` on.
fn splits_rest(
    factors: &[Factor],
    amp: &Amp,
    spelling: &[u32],
    index: usize,
    pos: usize,
    memo: &mut HashMap<(usize, usize), bool>,
) -> bool {
    if index == factors.len() {
        return pos == spelling.len();
    }
    if let Some(&cached) = memo.get(&(index, pos)) {
        return cached;
    }
    let mut result = false;
    for end in pos..=spelling.len() {
        if factor_contains(&factors[index], amp, &spelling[pos..end])
            && splits_rest(factors, amp, spelling, index + 1, end, memo)
        {
            result = true;
            break;
        }
    }
    memo.insert((index, pos), result);
    result
}

/// Whether a product factor's face set holds `piece`; a braced factor seals `&`.
fn factor_contains(factor: &Factor, amp: &Amp, piece: &[u32]) -> bool {
    match factor {
        Factor::Closure => amp_of(amp).contains(piece),
        Factor::Universe(inner) => Universe::sealed(inner).contains(piece),
    }
}

/// The universe a free `&` reads; the grammar guarantees a binder exists.
fn amp_of(amp: &Amp) -> Rc<Universe> {
    match amp {
        Some(universe) => universe.clone(),
        None => panic!("free `&` outside any binder"),
    }
}

/// Yield the member list's entries: claims to the left, strips to the right.
fn stream(node: Rc<UniverseNode>, amp: Amp, outer: Option<Live>) -> Entries {
    let count = node.members.len();
    Box::new((0..count).flat_map(move |index| -> Entries {
        let member = node.members[index].clone();
        if matches!(member, Member::Subtract(_)) {
            return Box::new(std::iter::empty());
        }
        let strips: Vec<UniverseNode> = node.members[index + 1..]
            .iter()
            .filter_map(|member| match member {
                Member::Subtract(inner) => Some(inner.clone()),
                _ => None,
            })
            .collect();
        let prefix = node.members[..index].to_vec();
        let live = make_live(prefix, amp.clone(), outer.clone());
        let entries = member_entries(member, amp.clone(), live, strips.clone());
        let amp = amp.clone();
        Box::new(entries.filter_map(move |entry| {
            let faces: Vec<Vec<u32>> = entry
                .faces
                .into_iter()
                .filter(|face| !strips.iter().any(|op| walk(&op.members, &amp, face)))
                .collect();
            if faces.is_empty() {
                None
            } else {
                Some(Entry { faces })
            }
        }))
    }))
}

/// A claim test: live means neither the members to the left nor `outer` claim it.
fn make_live(prefix: Vec<Member>, amp: Amp, outer: Option<Live>) -> Live {
    Rc::new(move |face: &[u32]| {
        if let Some(outer) = &outer {
            if !outer(face) {
                return false;
            }
        }
        !walk(&prefix, &amp, face)
    })
}

/// Yield one member's entries pre-subtraction, collisions already applied.
///
/// `strips` is advisory: window-shaped operands are carved out of a run
/// symbolically (so a fully subtracted infinite tail terminates); every strip
/// is re-checked face by face at the stream level regardless.
fn member_entries(member: Member, amp: Amp, live: Live, strips: Vec<UniverseNode>) -> Entries {
    match member {
        Member::Face(text) => {
            if live(&text) {
                Box::new(std::iter::once(Entry { faces: vec![text] }))
            } else {
                Box::new(std::iter::empty())
            }
        }
        Member::Range { .. } | Member::Final(_) => {
            let base = window_of(&member).expect("range or final has a window");
            Box::new(carve(base, &strips).into_iter().flat_map(move |window| {
                let live = live.clone();
                window.members().filter_map(move |spelling| {
                    if live(&spelling) {
                        Some(Entry {
                            faces: vec![spelling],
                        })
                    } else {
                        None
                    }
                })
            }))
        }
        Member::Fold(inner) => braced_entries(inner, live),
        Member::Closure => filtered(amp_of(&amp).entries(), live),
        Member::Product(factors) => product_entries(factors, amp, live),
        Member::Subtract(_) => Box::new(std::iter::empty()),
    }
}

/// Drop claimed faces entry-wise; an entry that loses every face drops.
fn filtered(entries: Entries, live: Live) -> Entries {
    Box::new(entries.filter_map(move |entry| {
        let faces: Vec<Vec<u32>> = entry.faces.into_iter().filter(|face| live(face)).collect();
        if faces.is_empty() {
            None
        } else {
            Some(Entry { faces })
        }
    }))
}

/// A braced member: a binder splices its closure, anything else folds to one entry.
///
/// As at membership, the brace seals its own `&`: no `amp` reaches in.
fn braced_entries(inner: UniverseNode, live: Live) -> Entries {
    let universe = Universe::sealed(&inner);
    if binds(&inner) {
        return filtered(universe.entries(), live);
    }
    let declared: Vec<Vec<u32>> = universe.entries().flat_map(|entry| entry.faces).collect();
    let source = if declared.is_empty() {
        vec![Vec::new()]
    } else {
        declared
    };
    let faces: Vec<Vec<u32>> = source.into_iter().filter(|face| live(face)).collect();
    if faces.is_empty() {
        Box::new(std::iter::empty())
    } else {
        Box::new(std::iter::once(Entry { faces }))
    }
}

/// Tuples in value order, spelled by concatenation; the least address claims.
fn product_entries(factors: Vec<Factor>, amp: Amp, live: Live) -> Entries {
    let mut seen: HashSet<Vec<u32>> = HashSet::new();
    let mut combos = tuples(factors, amp);
    Box::new(std::iter::from_fn(move || loop {
        let combo = combos.next()?;
        let mut faces: Vec<Vec<u32>> = Vec::new();
        for spelling in concat_product(&combo) {
            if !seen.contains(&spelling) && !faces.contains(&spelling) && live(&spelling) {
                faces.push(spelling);
            }
        }
        for face in &faces {
            seen.insert(face.clone());
        }
        if !faces.is_empty() {
            return Some(Entry { faces });
        }
    }))
}

/// The concatenations of one face per factor, last factor varying fastest.
fn concat_product(lists: &[Vec<Vec<u32>>]) -> Vec<Vec<u32>> {
    let mut spellings: Vec<Vec<u32>> = vec![Vec::new()];
    for list in lists {
        let mut next: Vec<Vec<u32>> = Vec::new();
        for prefix in &spellings {
            for face in list {
                let mut spelling = prefix.clone();
                spelling.extend_from_slice(face);
                next.push(spelling);
            }
        }
        spellings = next;
    }
    spellings
}

/// Factor face-tuples in value order: the most significant factor moves slowest.
fn tuples(factors: Vec<Factor>, amp: Amp) -> Box<dyn Iterator<Item = Combo>> {
    if factors.is_empty() {
        return Box::new(std::iter::once(Vec::new()));
    }
    let head = factors[0].clone();
    let rest = factors[1..].to_vec();
    Box::new(factor_entries(&head, &amp).flat_map(move |entry| {
        let head_faces = entry.faces;
        let rest = rest.clone();
        let amp = amp.clone();
        tuples(rest, amp).map(move |mut tail| {
            let mut combo: Combo = Vec::with_capacity(tail.len() + 1);
            combo.push(head_faces.clone());
            combo.append(&mut tail);
            combo
        })
    }))
}

/// A product factor's entries in declaration order; a braced factor seals `&`.
fn factor_entries(factor: &Factor, amp: &Amp) -> Entries {
    match factor {
        Factor::Closure => amp_of(amp).entries(),
        Factor::Universe(inner) => Universe::sealed(inner).entries(),
    }
}

/// Stage-major, first-appearance enumeration of a binder's closure.
fn closure_entries(node: Rc<UniverseNode>, amp: Amp, limit: Option<usize>) -> Entries {
    Box::new(ClosureEntries {
        node,
        amp,
        limit,
        stage: 0,
        current: None,
        produced: false,
        done: false,
    })
}

/// The state a closure's stage-major stream carries between pulls.
///
/// Each pass streams the body read at the previous stage, keeping only faces no
/// earlier stage spells; a pass that completes without producing is the
/// fixpoint, so the closure is finite and the stream ends.
struct ClosureEntries {
    node: Rc<UniverseNode>,
    amp: Amp,
    limit: Option<usize>,
    stage: usize,
    current: Option<Entries>,
    produced: bool,
    done: bool,
}

impl Iterator for ClosureEntries {
    type Item = Entry;

    fn next(&mut self) -> Option<Entry> {
        loop {
            if self.done {
                return None;
            }
            if self.current.is_none() {
                if matches!(self.limit, Some(limit) if self.stage >= limit) {
                    self.done = true;
                    return None;
                }
                let prev = Rc::new(Universe::new(
                    self.node.clone(),
                    self.amp.clone(),
                    Some(self.stage),
                ));
                let fresh = make_fresh(prev.clone());
                self.produced = false;
                self.current = Some(stream(self.node.clone(), Some(prev), Some(fresh)));
            }
            let Some(current) = self.current.as_mut() else {
                unreachable!("current was set above")
            };
            match current.next() {
                Some(entry) => {
                    self.produced = true;
                    return Some(entry);
                }
                None => {
                    self.current = None;
                    if !self.produced {
                        self.done = true;
                        return None;
                    }
                    self.stage += 1;
                }
            }
        }
    }
}

/// A face is fresh when no earlier stage of the same closure spells it.
fn make_fresh(prev: Rc<Universe>) -> Live {
    Rc::new(move |face: &[u32]| !prev.contains(face))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    fn node(members: Vec<Member>) -> UniverseNode {
        UniverseNode { members }
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

    /// The denoted entries as face-tuples (the first `limit` if given).
    fn faces(node: &UniverseNode, limit: Option<usize>) -> Vec<Vec<Vec<u32>>> {
        let entries = denote(node).entries();
        let collected: Vec<Entry> = match limit {
            Some(count) => entries.take(count).collect(),
            None => entries.collect(),
        };
        collected.into_iter().map(|entry| entry.faces).collect()
    }

    /// Build an expected result from face-tuples written as string slices.
    fn expected(entries: &[&[&str]]) -> Vec<Vec<Vec<u32>>> {
        entries
            .iter()
            .map(|entry| entry.iter().map(|face| cp(face)).collect())
            .collect()
    }

    /// The `{{{},0}}` fold-fill combinator that spells 0, 00, 000, ... at value.
    fn fill() -> UniverseNode {
        node(vec![Member::Fold(node(vec![
            Member::Fold(node(vec![])),
            face("0"),
        ]))])
    }

    #[test]
    fn union_is_ordered_and_deduplicates() {
        let n = node(vec![face("a"), face("b"), face("a")]);
        assert_eq!(faces(&n, None), expected(&[&["a"], &["b"]]));
    }

    #[test]
    fn range_expands_inclusively() {
        let n = node(vec![range('a', 'e')]);
        assert_eq!(
            faces(&n, None),
            expected(&[&["a"], &["b"], &["c"], &["d"], &["e"]])
        );
    }

    #[test]
    fn reversed_range_is_empty() {
        assert_eq!(faces(&node(vec![range('e', 'a')]), None), expected(&[]));
    }

    #[test]
    fn final_segment_streams_lazily_in_spelling_order() {
        let n = node(vec![Member::Final(cp("a"))]);
        assert_eq!(faces(&n, Some(3)), expected(&[&["a"], &["b"], &["c"]]));
        assert!(denote(&n).contains(&cp("zzzz")));
    }

    #[test]
    fn fold_collapses_a_nested_universe_into_one_entry() {
        let inner = node(vec![face("x"), face("y")]);
        let n = node(vec![face("a"), Member::Fold(inner)]);
        assert_eq!(faces(&n, None), expected(&[&["a"], &["x", "y"]]));
    }

    #[test]
    fn fold_of_the_empty_universe_is_the_unit() {
        let n = node(vec![Member::Fold(node(vec![]))]);
        assert_eq!(faces(&n, None), expected(&[&[""]]));
        assert!(denote(&n).contains(&cp("")));
    }

    #[test]
    fn fold_drops_faces_already_claimed() {
        let inner = node(vec![face("a"), face("x")]);
        let n = node(vec![face("a"), Member::Fold(inner)]);
        assert_eq!(faces(&n, None), expected(&[&["a"], &["x"]]));
    }

    #[test]
    fn subtraction_strips_the_named_spelling_and_renumbers() {
        let n = node(vec![
            face("a"),
            face("b"),
            face("c"),
            Member::Subtract(node(vec![face("b")])),
        ]);
        assert_eq!(faces(&n, None), expected(&[&["a"], &["c"]]));
    }

    #[test]
    fn subtraction_of_one_face_leaves_the_entry_on_its_others() {
        let folded = Member::Fold(node(vec![face("cat"), face("feline")]));
        let n = node(vec![folded, Member::Subtract(node(vec![face("feline")]))]);
        assert_eq!(faces(&n, None), expected(&[&["cat"]]));
    }

    #[test]
    fn entry_that_loses_every_face_drops() {
        let folded = Member::Fold(node(vec![face("x"), face("y")]));
        let n = node(vec![
            face("a"),
            folded,
            Member::Subtract(node(vec![face("x"), face("y")])),
        ]);
        assert_eq!(faces(&n, None), expected(&[&["a"]]));
    }

    #[test]
    fn face_can_be_reclaimed_after_subtraction() {
        let n = node(vec![
            face("a"),
            Member::Subtract(node(vec![face("a")])),
            face("a"),
        ]);
        assert_eq!(faces(&n, None), expected(&[&["a"]]));
    }

    #[test]
    fn product_member_collides_on_the_least_value() {
        let left = node(vec![face("a"), face("ab")]);
        let right = node(vec![face("c"), face("bc")]);
        let n = node(vec![Member::Product(vec![
            Factor::Universe(left),
            Factor::Universe(right),
        ])]);
        assert_eq!(faces(&n, None), expected(&[&["ac"], &["abc"], &["abbc"]]));
    }

    #[test]
    fn cross_axis_collision_can_cost_a_canonical_face() {
        let right = node(vec![face("0"), face("00")]);
        let n = node(vec![Member::Product(vec![
            Factor::Universe(fill()),
            Factor::Universe(right),
        ])]);
        assert_eq!(faces(&n, None), expected(&[&["0", "00"], &["000"]]));
    }

    #[test]
    fn closure_unfolds_stage_major() {
        let n = node(vec![
            face("a"),
            Member::Product(vec![
                Factor::Closure,
                Factor::Universe(node(vec![face("b")])),
            ]),
        ]);
        assert_eq!(
            faces(&n, Some(4)),
            expected(&[&["a"], &["ab"], &["abb"], &["abbb"]])
        );
        assert!(denote(&n).contains(&cp("abbbb")));
        assert!(!denote(&n).contains(&cp("ba")));
    }

    #[test]
    fn binder_braces_splice_rather_than_fold() {
        let body = node(vec![
            face("a"),
            Member::Product(vec![
                Factor::Closure,
                Factor::Universe(node(vec![face("b")])),
            ]),
        ]);
        let n = node(vec![face("z"), Member::Fold(body)]);
        assert_eq!(faces(&n, Some(3)), expected(&[&["z"], &["a"], &["ab"]]));
    }

    #[test]
    fn bare_self_reference_is_the_union_no_op() {
        let n = node(vec![face("a"), Member::Closure]);
        assert_eq!(faces(&n, None), expected(&[&["a"]]));
    }

    #[test]
    fn closure_of_nothing_is_empty() {
        assert_eq!(faces(&node(vec![Member::Closure]), None), expected(&[]));
    }

    #[test]
    fn unguarded_closure_still_enumerates_but_membership_raises() {
        let n = node(vec![
            face("a"),
            Member::Product(vec![Factor::Universe(fill()), Factor::Closure]),
        ]);
        assert_eq!(faces(&n, Some(3)), expected(&[&["a"], &["0a"], &["00a"]]));
        assert!(denote(&n).contains(&cp("00a")));

        let probe = n.clone();
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(|_| {}));
        let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            denote(&probe).contains(&cp("xyz"))
        }));
        std::panic::set_hook(previous);

        let payload = outcome.expect_err("membership in an unsettled closure must unwind");
        assert!(payload.downcast_ref::<HimarkUnsettledError>().is_some());
    }

    #[test]
    fn subtracted_self_reference_settles_at_stage_one() {
        let n = node(vec![
            Member::Final(cp("a")),
            Member::Subtract(node(vec![Member::Closure])),
        ]);
        assert_eq!(faces(&n, Some(3)), expected(&[&["a"], &["b"], &["c"]]));
    }
}
