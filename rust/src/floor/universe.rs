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
//! - Where the Python memoizes `_contains` on an `lru_cache` keyed by a
//!   `Universe`'s structural hash, this keys on a `Key`: the shared node's
//!   identity, its `amp`'s key, its stage limit. Identity implies equality, so
//!   the memo is sound; it is also strictly cheaper than the Python's remembered
//!   node hash, which exists only because Python has no node identity to key on.
//!   The trade is that two structurally equal but separately built nodes miss
//!   each other -- a miss, never a wrong answer.
//!
//! Laziness is the one discipline: nothing here materializes an infinite object,
//! so iterating an infinite universe simply never ends, and folding one into a
//! single entry is the caller's non-terminating loop to ask for.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::fmt;
use std::rc::Rc;

use super::binder::{binds, settled};
use super::reach::{cuts, suffixes};
use super::syntax::{Factor, Member, NodeId, UniverseNode};
use super::window::{carve, window_of};

/// The stage a free `&` in some members reads (`None` outside any binder).
///
/// Public because the scan layer (measure, capture) reads and threads it, the
/// way the Python's public `Universe.amp` field is read.
pub type Amp = Option<Rc<Universe>>;
/// A liveness test: whether a face is still unclaimed at its point of use.
type Live = Rc<dyn Fn(&[u32]) -> bool>;
/// A lazy stream of entries; owns its state, so it is safe over infinity.
type Entries = Box<dyn Iterator<Item = Entry>>;
/// One factor face-tuple per factor, in factor order -- the shape [`tuples`] yields.
type Combo = Vec<Vec<Vec<u32>>>;

/// A universe's memo identity: its node, its `amp`'s key, its stage limit.
///
/// The recursion through `amp` is what makes this useful rather than merely
/// sound. A stage universe is built fresh on every pass of [`Universe::contains`],
/// so a node alone would never match twice; `(node, stage)` distinguishes the
/// stages exactly the way the Python's structural hash does, and the chain stays
/// short because a brace seals its own `&`.
#[derive(Clone, PartialEq, Eq, Hash)]
struct Key {
    /// The shared node this universe denotes, identified by address.
    node: NodeId,
    /// The key of the stage a free `&` reads, if there is one.
    amp: Option<Box<Key>>,
    /// The closure truncation, if this is a stage universe.
    stages: Option<usize>,
}

/// Membership answers, spelling-major under each universe identity.
///
/// Nested rather than keyed on one `(Key, spelling)` pair so that a *hit* costs
/// no allocation: a `Vec<u32>` borrows as a `[u32]`, so the inner lookup takes
/// the spelling as it stands, where a flat key would have to copy it first. On a
/// long target that copy is the whole cost -- it is paid per probe, and a probe's
/// spelling is as long as the text.
type Memo = HashMap<Key, HashMap<Vec<u32>, bool>>;

thread_local! {
    /// The membership memo for this thread.
    ///
    /// Membership is a pure function of universe and spelling, so the memo
    /// changes no denotation -- it collapses the sub-questions a closure re-asks
    /// at every stage, which is where the recursion's cost actually sits.
    ///
    /// **Unbounded, on purpose, and this is the one place the port knowingly
    /// differs in kind rather than in detail.** The Python caps the same cache
    /// at 65536 with an LRU and can afford to, because it also carries
    /// `core/floor/work.py`: a run that outgrows its memo hits the work budget
    /// and is *refused*, with a `HimarkBudgetError` naming the reason. The port
    /// has no work budget yet, so a cap here would bound the wrong thing -- it
    /// would leave the run going and silently make it exponential again, which
    /// is the one outcome the budget exists to prevent.
    ///
    /// Both alternatives were measured on `{a, &{a}}`, and both cliff hard.
    /// Clearing wholesale at 65536 answers took a 400-character target from
    /// 8.5 s to past 90 s; filling and then holding did the same, because past
    /// the cap the closure recursion is simply un-memoized. Unbounded, the curve
    /// is smooth -- 0.7 s at 200 characters, 8.5 s at 400, 70 s at 700 -- and
    /// memory tracks the work rather than the input: 14 MB, 92 MB, 470 MB.
    ///
    /// So the memo grows with the run, and bounding the *run* is the fix. Porting
    /// `work.py` is the item that closes this, and `docs/TODO.md` ranks it.
    static CONTAINS: RefCell<Memo> = RefCell::new(Memo::new());
}

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
    ///
    /// A refcount bump, not a copy: the node is shared, which is what lets this
    /// stand in the split search's inner loop without paying for the subtree.
    fn sealed(node: &Rc<UniverseNode>) -> Universe {
        Universe::new(node.clone(), None, None)
    }

    /// This universe's memo identity -- see [`Key`].
    fn key(&self) -> Key {
        Key {
            node: NodeId(self.node.clone()),
            amp: self.amp.as_ref().map(|amp| Box::new(amp.key())),
            stages: self.stages,
        }
    }

    /// The AST node this universe denotes.
    ///
    /// These three accessors and [`Universe::at_stage`] mirror the Python's
    /// public `node` / `amp` / `stages` fields: the scan layer reads them to
    /// walk a universe's structure and to build its stage universes `X_k`.
    pub fn node(&self) -> &UniverseNode {
        &self.node
    }

    /// The AST node as it is shared, for a caller that keys on its identity.
    ///
    /// [`super::reach`] memoizes per node, so it wants the node the rest of the
    /// run holds rather than a fresh copy of it.
    pub fn shared_node(&self) -> &Rc<UniverseNode> {
        &self.node
    }

    /// The stage a free `&` in the members reads (`None` outside any binder).
    pub fn amp(&self) -> &Amp {
        &self.amp
    }

    /// The closure truncation, if this is a stage universe `X_k` (`None` at omega).
    pub fn stage_limit(&self) -> Option<usize> {
        self.stages
    }

    /// This universe truncated to its first `stage` closure passes, reusing node and amp.
    pub fn at_stage(&self, stage: usize) -> Universe {
        Universe::new(self.node.clone(), self.amp.clone(), Some(stage))
    }

    /// Whether some entry of this universe wears `spelling`.
    ///
    /// # Panics
    ///
    /// Unwinds with a [`HimarkUnsettledError`] payload when the node is an
    /// unsettled closure and no stage up to `len(spelling) + 1` shows `spelling`:
    /// absence then has no bound.
    pub fn contains(&self, spelling: &[u32]) -> bool {
        if !self.worth_remembering() {
            return self.decide(spelling);
        }
        let key = self.key();
        let remembered = CONTAINS.with(|memo| {
            memo.borrow()
                .get(&key)
                .and_then(|answers| answers.get(spelling))
                .copied()
        });
        if let Some(answer) = remembered {
            return answer;
        }
        // The borrow is dropped before deciding: this function re-enters itself
        // through every constructor below, and a live borrow would panic.
        let answer = self.decide(spelling);
        CONTAINS.with(|memo| {
            memo.borrow_mut()
                .entry(key)
                .or_default()
                .insert(spelling.to_vec(), answer);
        });
        answer
    }

    /// Whether this universe's questions can recur, so remembering them can pay.
    ///
    /// The Python memoizes unconditionally, and can afford to: an interpreted
    /// call dwarfs a hash lookup there, so a memo never loses. Here the base
    /// operation is a slice comparison, and remembering one costs more than
    /// recomputing it unless the same question genuinely comes back.
    ///
    /// It comes back under a closure and nowhere else. A binder re-walks its
    /// whole member list once per stage, asking each member about the same
    /// pieces; every question raised *inside* that walk carries the stage as its
    /// `amp`, so those recur too. A closure-free universe answers each question
    /// once per asker and remembering it is pure overhead -- measurably so: on a
    /// long target the memo cost 78x before this gate, while the closure row it
    /// exists for got 58x faster.
    fn worth_remembering(&self) -> bool {
        self.amp.is_some() || binds(&self.node)
    }

    /// Answer the shorter prefixes before the whole, so the descent stays shallow.
    ///
    /// A closure decides a length-`L` spelling by asking its body about strictly
    /// shorter ones, so the recursion is naturally as deep as the spelling is
    /// long -- and a document long enough exhausts the stack. In the Python that
    /// surfaces as a `RecursionError`; here it is a hard abort, so the warming
    /// matters more rather than less. Walking the prefixes upward first puts each
    /// answer the descent will want in the memo, so the descent finds it there
    /// rather than a frame deeper.
    ///
    /// It is the narrowed cut range that makes this necessary: bounding a split
    /// search moves the *longest* sub-question to the front, so the first thing
    /// asked is the deepest. Pure warming -- no answer changes, only where it is
    /// computed. An unsettled body has none to warm with, and saying so is the
    /// real question's job rather than a prefix's, so the walk stops instead of
    /// naming the wrong spelling. Tactic, not rule: a host whose stack is its
    /// memory conforms without it.
    ///
    /// The Python warms until a prefix raises; here an unsettled body is skipped
    /// up front instead. Unwinding is both costly and loud in Rust, and the two
    /// come to the same thing -- an unsettled body has no bound to warm toward,
    /// and saying so is the real question's job rather than a prefix's.
    fn warm_prefixes(&self, spelling: &[u32]) {
        if spelling.len() < 2 || !settled(&self.node, &spells_empty_oracle) {
            return;
        }
        for end in 1..spelling.len() {
            self.contains(&spelling[..end]);
        }
    }

    /// Decide membership from the structure, with no memo consulted.
    fn decide(&self, spelling: &[u32]) -> bool {
        if !binds(&self.node) {
            return walk(&self.node.members, &self.amp, spelling);
        }
        if self.stages.is_none() {
            self.warm_prefixes(spelling);
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
///
/// Takes an unshared node and shares it, which is the entry point for a caller
/// holding a tree it built itself. A caller already holding the shared node the
/// AST stores -- which is every caller inside this crate -- wants
/// [`denote_shared`], so that the denotation keys on the node the rest of the
/// run keys on.
pub fn denote(node: &UniverseNode) -> Universe {
    denote_shared(&Rc::new(node.clone()))
}

/// Denote an already-shared node, bumping its refcount rather than copying it.
pub fn denote_shared(node: &Rc<UniverseNode>) -> Universe {
    Universe::sealed(node)
}

/// The emptiness oracle `binder::settled` needs: does this node wear `""`?
fn spells_empty_oracle(node: &Rc<UniverseNode>) -> bool {
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
fn braced_spells(inner: &Rc<UniverseNode>, spelling: &[u32]) -> bool {
    let universe = Universe::sealed(inner);
    if spelling.is_empty() && !binds(inner) {
        return universe.contains(&[]) || universe.entries().next().is_none();
    }
    universe.contains(spelling)
}

/// Whether `spelling` splits into consecutive pieces, one per factor's faces.
fn splits(factors: &[Factor], amp: &Amp, spelling: &[u32]) -> bool {
    let mut memo: HashMap<(usize, usize), bool> = HashMap::new();
    let tails = suffixes(factors);
    splits_rest(factors, &tails, amp, spelling, 0, 0, &mut memo)
}

/// Whether `spelling[pos..]` splits across the factors from `index` on.
///
/// The candidate cuts come off the expression rather than off the text: see
/// [`cuts`], whose two ends are this search's whole cost curve.
fn splits_rest(
    factors: &[Factor],
    tails: &[Option<usize>],
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
    for end in cuts(&factors[index], tails[index + 1], pos, spelling.len()) {
        if factor_contains(&factors[index], amp, &spelling[pos..end])
            && splits_rest(factors, tails, amp, spelling, index + 1, end, memo)
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
        let strips: Vec<Rc<UniverseNode>> = node.members[index + 1..]
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
fn member_entries(member: Member, amp: Amp, live: Live, strips: Vec<Rc<UniverseNode>>) -> Entries {
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
fn braced_entries(inner: Rc<UniverseNode>, live: Live) -> Entries {
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
    fn fill() -> Rc<UniverseNode> {
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
    fn a_recycled_node_address_does_not_answer_for_its_successor() {
        // The memo keys on node identity, and an address only identifies a node
        // while the node is alive. Denote and drop enough short-lived trees that
        // the allocator hands an address back, and check the answers still track
        // the tree that was asked about rather than the one that used to be there.
        for index in 0..64 {
            let text = format!("face{index}");
            let n = node(vec![face(&text)]);
            assert!(denote(&n).contains(&cp(&text)));
            assert!(!denote(&n).contains(&cp("face-absent")));
        }
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
