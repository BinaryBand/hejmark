//! Universe algebra: denote the floor AST to lazy, computational universes.
//!
//! A port of `hejmark/core/engine/denote/universe.py`, kept deliberately
//! function-for-function against it. This is a *reference* engine: where a
//! tidier Rust shape would have drifted from the Python, the Python's shape
//! won, so the two can be diffed by eye when the corpus disagrees.
//!
//! Two questions, both computed structurally rather than from a table.
//! `contains` is pure set algebra over the five constructors, because collision
//! never changes it -- a claimed spelling merely moves owner. `entries` streams
//! in declaration order with the collision rule applied: a spelling is claimed
//! by the least `<value, face>` address, later claimants drop it, and an entry
//! that loses every face drops with them.
//!
//! Streaming is callbacks rather than iterators. Python gets laziness free from
//! generators; here [`Flow`] carries the same discipline explicitly, and it has
//! to, because nothing may materialise an infinite universe.
//!
//! L2's refusals arrive here as a **latch** rather than as `Result` on every
//! signature, and that is a deliberate reading of the porting rule. Python
//! raises, and raising unwinds a whole recursion from wherever it happens;
//! threading `Answer` through `contains`, `walk`, `spells`, both split searches
//! and every streaming callback would rewrite each of those bodies and leave
//! nothing diffable against its counterpart. [`Denoter::refuse`] records the
//! refusal instead, every entry point short-circuits on it, and the boundary in
//! `scan.rs` and `execute.rs` -- which already returns [`Answer`] -- turns it
//! back into one. Same effect as unwinding: the run is abandoned and the caller
//! is told which refusal it was.
//!
//! Two of them can land: absence in an unguarded closure, which no stage bounds,
//! and a run past this host's work budget. The first is semantic and the corpus
//! pins it; the second's size is this host's choice.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;

use crate::errors::{budget, unsettled, Fault};
use crate::spelling::{compare, empty, spelling, Flow, Spelling, Window, GO, STOP};
use crate::syntax::{Arena, Factor, Member, NodeId};

/// How many membership questions one run may spend (= `engine/budget.py`).
///
/// Its existence is L2's contract; the number is this host's choice, so no
/// conformance case fixes it. Far above any hand-written script and far below
/// the point where a wait stops being a wait.
pub const BUDGET: u64 = 5_000_000;

/// A denoted universe: a brace group plus what its free `&` reads.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct Univ(u32);

/// One member of a universe: the spellings that wear it, canonical face first.
#[derive(Clone, Debug)]
pub struct Entry {
    /// The faces, canonical first.
    pub faces: Vec<Spelling>,
}

/// What a universe is: its node, the stage a free `&` reads, and its own truncation.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
struct Key {
    node: NodeId,
    amp: Option<Univ>,
    stages: Option<u32>,
}

/// A liveness test: whether a face is still unclaimed at its point of use.
type Live<'a> = &'a dyn Fn(&Spelling) -> bool;

/// Where a stream delivers its entries.
type Sink<'a> = &'a mut dyn FnMut(Entry) -> Flow;

/// What a universe was asked about a spelling.
type ContainsMemo = RefCell<HashMap<(Univ, Spelling), bool>>;

/// What one member of one node, under one stage, was asked about a spelling.
type SpellsMemo = RefCell<HashMap<(NodeId, u32, Option<Univ>, Spelling), bool>>;

/// The engine's denotation, with the memos every query shares.
///
/// Everything takes `&self` and the memos sit behind [`RefCell`]. That mirrors
/// the Python, where `lru_cache` is likewise invisible to the callers, and it is
/// what lets a liveness test be an ordinary closure over `self` while the walk
/// it guards recurses back through the same tables.
pub struct Denoter {
    /// Every node the loaded program mentions, shared with whatever mints more.
    pub arena: Rc<Arena>,
    keys: RefCell<Vec<Key>>,
    interned: RefCell<HashMap<Key, Univ>>,
    contains_memo: ContainsMemo,
    spells_memo: SpellsMemo,
    /// The refusal a walk hit, standing in for Python's raise.
    fault: RefCell<Option<Fault>>,
    /// The open run's meter: what it may spend, and what it has spent.
    meter: RefCell<Option<(u64, u64)>>,
}

impl Denoter {
    /// A denoter over *arena*, which a late resolver may still be growing.
    pub fn new(arena: Rc<Arena>) -> Self {
        Self {
            arena,
            keys: RefCell::new(Vec::new()),
            interned: RefCell::new(HashMap::new()),
            contains_memo: RefCell::new(HashMap::new()),
            spells_memo: RefCell::new(HashMap::new()),
            fault: RefCell::new(None),
            meter: RefCell::new(None),
        }
    }

    /// Open a work budget over this run, unless an outer run already holds one.
    ///
    /// Runs nest -- a contracting pass is made of matches -- and the outermost
    /// is the one that holds, so a pass is priced whole rather than per match
    /// inside it. Answers whether this call opened it, which is what the caller
    /// must hand back to [`Denoter::close_run`].
    pub fn open_run(&self) -> bool {
        let mut meter = self.meter.borrow_mut();
        if meter.is_some() {
            return false;
        }
        *meter = Some((BUDGET, 0));
        true
    }

    /// Close a budget this caller opened, clearing the latch with it.
    pub fn close_run(&self, opened: bool) {
        if opened {
            *self.meter.borrow_mut() = None;
            *self.fault.borrow_mut() = None;
        }
    }

    /// Charge one membership question against the open budget; free where none is.
    fn charge(&self) {
        let mut held = self.meter.borrow_mut();
        let Some((budgeted, spent)) = held.as_mut() else { return };
        *spent += 1;
        if *spent > *budgeted {
            let cost = *budgeted;
            drop(held);
            self.refuse(budget(format!(
                "a run spent past this host's work budget of {cost} membership questions"
            )));
        }
    }

    /// Record a refusal, keeping the first: the run ended where it first could not go.
    fn refuse(&self, fault: Fault) {
        let mut held = self.fault.borrow_mut();
        if held.is_none() {
            *held = Some(fault);
        }
    }

    /// Whether a refusal is standing, so every walk should unwind rather than answer.
    pub fn faulted(&self) -> bool {
        self.fault.borrow().is_some()
    }

    /// The standing refusal, taken -- so a caller reads it once and turns it into an `Err`.
    pub fn take_fault(&self) -> Option<Fault> {
        self.fault.borrow_mut().take()
    }

    /// Denote a node: the universe it is, read outside any binder.
    pub fn denote(&self, node: NodeId) -> Univ {
        self.univ(node, None, None)
    }

    /// Intern one universe, so a memo key is three integers rather than a tree.
    fn univ(&self, node: NodeId, amp: Option<Univ>, stages: Option<u32>) -> Univ {
        let key = Key { node, amp, stages };
        if let Some(&found) = self.interned.borrow().get(&key) {
            return found;
        }
        let mut keys = self.keys.borrow_mut();
        let made = Univ(u32::try_from(keys.len()).expect("universe overflow"));
        keys.push(key);
        drop(keys);
        self.interned.borrow_mut().insert(key, made);
        made
    }

    fn key(&self, universe: Univ) -> Key {
        self.keys.borrow()[universe.0 as usize]
    }

    /// How long a face this universe can wear, or `None` when unbounded.
    ///
    /// The interned universe's own reach, which is its node's: truncating a
    /// closure to a stage cannot lengthen a face, so the node's bound holds for
    /// every stage universe over it too.
    pub fn univ_reach(&self, universe: Univ) -> Option<usize> {
        self.arena.reach(self.key(universe).node)
    }

    /// Whether some entry of *universe* wears *face*.
    ///
    /// The one place the work budget is charged, this being the question a run
    /// asks over and over, and deliberately outside the memo: an answer served
    /// from it still cost the clock it took to ask for. Also the one place the
    /// latch is read, so a standing refusal unwinds the recursion rather than
    /// letting it grind on to an answer nobody will use.
    pub fn contains(&self, universe: Univ, face: &Spelling) -> bool {
        if self.faulted() {
            return false;
        }
        self.charge();
        let memo_key = (universe, face.clone());
        if let Some(&found) = self.contains_memo.borrow().get(&memo_key) {
            return found;
        }
        let answer = self.contains_fresh(universe, face);
        if !self.faulted() {
            self.contains_memo.borrow_mut().insert(memo_key, answer);
        }
        answer
    }

    fn contains_fresh(&self, universe: Univ, face: &Spelling) -> bool {
        let Key { node, amp, stages } = self.key(universe);
        if !self.arena.binds(node) {
            return self.walk(node, self.arena.width(node), amp, face);
        }
        if stages.is_none() {
            self.shorter_first(universe, face);
        }
        // A guarded body settles by `len + 1` and a truncated stage universe was
        // only ever asked about that stage, so a miss is a decided absence in
        // both. Only the closure at omega over an unguarded body has a miss
        // meaning nothing, and that one refuses.
        let bound =
            stages.unwrap_or_else(|| u32::try_from(face.len()).expect("spelling too long") + 1);
        let shown = (0..bound).any(|stage| {
            let prev = self.univ(node, amp, Some(stage));
            self.walk(node, self.arena.width(node), Some(prev), face)
        });
        if shown || stages.is_some() || self.settled(node) {
            return shown;
        }
        self.refuse(unsettled(format!(
            "membership of {face:?} in an unguarded closure has no stage bound"
        )));
        false
    }

    /// Whether every free `&` is guarded, so each pass lengthens and stage
    /// `len + 1` is exact (= `floor/binder.py`'s `settled`).
    ///
    /// A bare `&` is unguarded: the pass can reproduce itself. A `&` in a product
    /// is guarded when some sibling factor cannot spell the empty face -- which
    /// is the one clause here that is not syntactic, and the reason this sits in
    /// the denoter rather than in the arena beside `binds`.
    fn settled(&self, node: NodeId) -> bool {
        let group = self.arena.node(node);
        group.members.iter().all(|member| match member {
            Member::Closure => false,
            Member::Product(factors) if factors.iter().any(|f| matches!(f, Factor::Closure)) => {
                factors.iter().any(|factor| match factor {
                    Factor::Universe(inner) => !self.spells_empty(*inner),
                    Factor::Closure => false,
                })
            }
            Member::Subtract(inner) => self.settled(*inner),
            _ => true,
        })
    }

    /// The emptiness oracle `settled` needs: does this group wear the empty face?
    ///
    /// A factor guards by *failing* to spell the empty face, so an oracle that
    /// cannot answer must not report one. An undecidable answer therefore reads
    /// as "spells it", leaving the refusal conservative -- able to decline a
    /// closure a deeper analysis would settle, never to accept one it cannot.
    fn spells_empty(&self, node: NodeId) -> bool {
        let answer = self.contains(self.denote(node), &empty());
        if self.clear_unsettled() {
            return true;
        }
        answer
    }

    /// Drop a standing *unsettled* refusal, reporting whether there was one.
    ///
    /// Only that one: a budget refusal is the run ending, and a question asked
    /// inside it has no more right to carry on than the run does. Python says
    /// the same thing by catching one exception class and not the other.
    fn clear_unsettled(&self) -> bool {
        let mut held = self.fault.borrow_mut();
        if matches!(*held, Some(Fault::Unsettled(_))) {
            *held = None;
            return true;
        }
        false
    }

    /// Answer the shorter prefixes before the whole, so the descent stays shallow.
    ///
    /// A closure decides a length-`L` face by asking its body about strictly
    /// shorter ones, so the recursion is naturally as deep as the face is long.
    /// Walking the prefixes upward first puts each answer the descent will want
    /// in the memo, so the descent finds it there rather than a frame deeper.
    ///
    /// Pure warming: no answer changes, only where it is computed. An unguarded
    /// body has none to warm with, and naming that refusal is the real
    /// question's job rather than a prefix's, so the walk stops rather than
    /// refuse under the wrong spelling.
    fn shorter_first(&self, universe: Univ, face: &Spelling) {
        for end in 1..face.len() {
            self.contains(universe, &spelling(&face[..end]));
            if self.clear_unsettled() || self.faulted() {
                return;
            }
        }
    }

    /// The union/subtraction walk over `members[..upto]`, left to right.
    ///
    /// Taking a prefix width rather than a slice is what lets a liveness test
    /// ask about the members to a position's left without re-bracing them --
    /// re-bracing would rebind their free `&`.
    fn walk(&self, node: NodeId, upto: usize, amp: Option<Univ>, face: &Spelling) -> bool {
        let mut present = false;
        for index in 0..upto {
            let group = self.arena.node(node);
            match &group.members[index] {
                Member::Subtract(inner) => {
                    present = present && !self.walk(*inner, self.arena.width(*inner), amp, face);
                }
                _ if !present => {
                    present = self.spells(node, index, amp, face);
                }
                _ => {}
            }
        }
        present
    }

    /// Whether one adding member's face set holds *face* (claims never shrink it).
    fn spells(&self, node: NodeId, index: usize, amp: Option<Univ>, face: &Spelling) -> bool {
        let slot = u32::try_from(index).expect("member overflow");
        let memo_key = (node, slot, amp, face.clone());
        if let Some(&found) = self.spells_memo.borrow().get(&memo_key) {
            return found;
        }
        let answer = self.spells_fresh(node, index, amp, face);
        self.spells_memo.borrow_mut().insert(memo_key, answer);
        answer
    }

    fn spells_fresh(&self, node: NodeId, index: usize, amp: Option<Univ>, face: &Spelling) -> bool {
        let group = self.arena.node(node);
        match &group.members[index] {
            Member::Face(text) => **text == **face,
            Member::Range(lo, hi) => Window::inclusive(*lo, *hi).contains(face),
            Member::Fold(inner) => self.braced_spells(*inner, face),
            Member::Closure => self.contains(amp_of(amp), face),
            Member::Product(factors) => self.splits(factors, amp, face),
            Member::Subtract(_) => unreachable!("walk handles subtraction"),
        }
    }

    /// A braced member's face set: its universe's faces, plus the fold-to-unit boundary.
    ///
    /// A fold of the empty alphabet is the unit, so it wears the empty spelling;
    /// a binder splices its closure instead, and an empty closure contributes
    /// nothing. The brace seals its own `&`, so no outer stage reaches in.
    fn braced_spells(&self, inner: NodeId, face: &Spelling) -> bool {
        let universe = self.denote(inner);
        if face.is_empty() && !self.arena.binds(inner) {
            return self.contains(universe, &empty()) || self.is_barren(universe);
        }
        self.contains(universe, face)
    }

    /// Whether a universe has no entry at all -- one entry taken, then stopped.
    fn is_barren(&self, universe: Univ) -> bool {
        let mut any = false;
        let _drained = self.entries(universe, &mut |_entry| {
            any = true;
            STOP
        });
        !any
    }

    /// Whether *face* splits into consecutive pieces, one per factor's faces.
    ///
    /// Cut where reach allows, at both ends (= `denote/split.py`): no factor is
    /// offered a piece longer than it can wear, nor a cut leaving the factors
    /// after it more text than they could ever cover. `tails[i]` bounds
    /// `factors[i..]`, `None` propagating leftward from the first unbounded
    /// factor. Both bounds come off the expression, so the splits are unchanged.
    fn splits(&self, factors: &[Factor], amp: Option<Univ>, face: &Spelling) -> bool {
        let length = face.len();
        let mut tails: Vec<Option<usize>> = vec![Some(0)];
        for factor in factors.iter().rev() {
            let far = self.arena.factor_reach(factor);
            let tail = *tails.last().expect("seeded with the empty tail");
            tails.push(match (far, tail) {
                (Some(far), Some(tail)) => Some(far + tail),
                _ => None,
            });
        }
        tails.reverse();
        let mut memo: HashMap<(usize, usize), bool> = HashMap::new();
        self.rest(factors, amp, face, length, 0, 0, &tails, &mut memo)
    }

    #[allow(clippy::too_many_arguments)]
    fn rest(
        &self,
        factors: &[Factor],
        amp: Option<Univ>,
        face: &Spelling,
        length: usize,
        index: usize,
        pos: usize,
        tails: &[Option<usize>],
        memo: &mut HashMap<(usize, usize), bool>,
    ) -> bool {
        if index == factors.len() {
            return pos == length;
        }
        if let Some(&found) = memo.get(&(index, pos)) {
            return found;
        }
        let stop = match self.arena.factor_reach(&factors[index]) {
            Some(far) => length.min(pos + far),
            None => length,
        };
        let start = match tails[index + 1] {
            Some(tail) => pos.max(length.saturating_sub(tail)),
            None => pos,
        };
        let mut answer = false;
        for end in start..=stop {
            if self.factor_contains(&factors[index], amp, &spelling(&face[pos..end]))
                && self.rest(factors, amp, face, length, index + 1, end, tails, memo)
            {
                answer = true;
                break;
            }
        }
        memo.insert((index, pos), answer);
        answer
    }

    /// Whether a product factor's face set holds *piece*; a braced factor seals `&`.
    fn factor_contains(&self, factor: &Factor, amp: Option<Univ>, piece: &Spelling) -> bool {
        match factor {
            Factor::Closure => self.contains(amp_of(amp), piece),
            Factor::Universe(node) => self.contains(self.denote(*node), piece),
        }
    }

    /// Stream the entries in declaration order, lazily -- safe over infinity.
    ///
    /// Unwinds on a standing refusal, so a stream begun before one landed does
    /// not go on producing entries the caller will discard.
    pub fn entries(&self, universe: Univ, sink: Sink) -> Flow {
        if self.faulted() {
            return STOP;
        }
        let Key { node, amp, stages } = self.key(universe);
        if self.arena.binds(node) {
            return self.closure_entries(node, amp, stages, sink);
        }
        self.stream(node, amp, None, sink)
    }

    /// The canonical face of each entry, which is the whole of what expansion asks.
    pub fn canonical_faces(&self, universe: Univ, sink: &mut dyn FnMut(&Spelling) -> Flow) -> Flow {
        self.entries(universe, &mut |entry| sink(&entry.faces[0]))
    }

    /// A member list's entries: claims to the left, strips to the right.
    fn stream(&self, node: NodeId, amp: Option<Univ>, outer: Option<Live>, sink: Sink) -> Flow {
        let width = self.arena.width(node);
        let group = self.arena.node(node);
        for index in 0..width {
            if matches!(group.members[index], Member::Subtract(_)) {
                continue;
            }
            let strips: Vec<NodeId> = (index + 1..width)
                .filter_map(|later| match group.members[later] {
                    Member::Subtract(inner) => Some(inner),
                    _ => None,
                })
                .collect();
            let live = |face: &Spelling| -> bool {
                if let Some(outer) = outer {
                    if !outer(face) {
                        return false;
                    }
                }
                !self.walk(node, index, amp, face)
            };
            self.member_entries(node, index, amp, &live, &strips, &mut |entry| {
                let faces: Vec<Spelling> = entry
                    .faces
                    .into_iter()
                    .filter(|face| {
                        !strips.iter().any(|op| self.walk(*op, self.arena.width(*op), amp, face))
                    })
                    .collect();
                if faces.is_empty() {
                    GO
                } else {
                    sink(Entry { faces })
                }
            })?;
        }
        GO
    }

    /// One member's entries pre-subtraction, collisions already applied.
    ///
    /// *strips* is advisory: window-shaped operands are carved out of a run
    /// symbolically, so a fully subtracted infinite tail terminates; every strip
    /// is re-checked face by face at the stream level regardless.
    fn member_entries(
        &self,
        node: NodeId,
        index: usize,
        amp: Option<Univ>,
        live: Live,
        strips: &[NodeId],
        sink: Sink,
    ) -> Flow {
        let group = self.arena.node(node);
        match &group.members[index] {
            Member::Face(text) => {
                if live(text) {
                    sink(Entry { faces: vec![text.clone()] })?;
                }
                GO
            }
            Member::Range(lo, hi) => {
                for window in self.carve(&Window::inclusive(*lo, *hi), strips) {
                    window.walk(&mut |face| {
                        if live(face) {
                            sink(Entry { faces: vec![face.clone()] })?;
                        }
                        GO
                    })?;
                }
                GO
            }
            Member::Fold(inner) => self.braced_entries(*inner, live, sink),
            Member::Closure => self.filtered(amp_of(amp), live, sink),
            Member::Product(factors) => self.product_entries(factors, amp, live, sink),
            Member::Subtract(_) => GO,
        }
    }

    /// Drop claimed faces entry-wise; an entry that loses every face drops.
    fn filtered(&self, universe: Univ, live: Live, sink: Sink) -> Flow {
        self.entries(universe, &mut |entry| {
            let faces: Vec<Spelling> = entry.faces.into_iter().filter(|face| live(face)).collect();
            if faces.is_empty() {
                GO
            } else {
                sink(Entry { faces })
            }
        })
    }

    /// A braced member: a binder splices its closure, anything else folds to one entry.
    fn braced_entries(&self, inner: NodeId, live: Live, sink: Sink) -> Flow {
        let universe = self.denote(inner);
        if self.arena.binds(inner) {
            return self.filtered(universe, live, sink);
        }
        let mut declared: Vec<Spelling> = Vec::new();
        let _drained = self.entries(universe, &mut |entry| {
            declared.extend(entry.faces);
            GO
        });
        if declared.is_empty() {
            declared.push(empty());
        }
        let faces: Vec<Spelling> = declared.into_iter().filter(|face| live(face)).collect();
        if faces.is_empty() {
            GO
        } else {
            sink(Entry { faces })
        }
    }

    /// Tuples in value order, spelled by concatenation; the least address claims.
    fn product_entries(
        &self,
        factors: &[Factor],
        amp: Option<Univ>,
        live: Live,
        sink: Sink,
    ) -> Flow {
        let mut seen: HashSet<Spelling> = HashSet::new();
        self.tuples(factors, amp, 0, &mut Vec::new(), &mut |combo| {
            let mut faces: Vec<Spelling> = Vec::new();
            for pieces in cartesian(combo) {
                let joined: Spelling = Rc::from(pieces.concat());
                if !seen.contains(&joined) && !faces.contains(&joined) && live(&joined) {
                    faces.push(joined);
                }
            }
            seen.extend(faces.iter().cloned());
            if faces.is_empty() {
                GO
            } else {
                sink(Entry { faces })
            }
        })
    }

    /// Factor face-tuples in value order: the most significant factor moves slowest.
    fn tuples(
        &self,
        factors: &[Factor],
        amp: Option<Univ>,
        depth: usize,
        chosen: &mut Vec<Vec<Spelling>>,
        sink: &mut dyn FnMut(&[Vec<Spelling>]) -> Flow,
    ) -> Flow {
        if depth == factors.len() {
            return sink(chosen);
        }
        let source = match &factors[depth] {
            Factor::Closure => amp_of(amp),
            Factor::Universe(node) => self.denote(*node),
        };
        self.entries(source, &mut |entry| {
            chosen.push(entry.faces);
            let flow = self.tuples(factors, amp, depth + 1, chosen, sink);
            chosen.pop();
            flow
        })
    }

    /// Stage-major, first-appearance enumeration of a binder's closure.
    ///
    /// Each pass streams the body read at the previous stage, keeping only faces
    /// no earlier stage spells; a pass that completes without producing is the
    /// fixpoint, so the closure is finite and the stream ends.
    fn closure_entries(
        &self,
        node: NodeId,
        amp: Option<Univ>,
        limit: Option<u32>,
        sink: Sink,
    ) -> Flow {
        let mut stage = 0u32;
        while limit.is_none_or(|cap| stage < cap) {
            let prev = self.univ(node, amp, Some(stage));
            let fresh = |face: &Spelling| !self.contains(prev, face);
            let mut produced = false;
            self.stream(node, Some(prev), Some(&fresh), &mut |entry| {
                produced = true;
                sink(entry)
            })?;
            if !produced {
                return GO;
            }
            stage += 1;
        }
        GO
    }

    /// Cut the window-shaped strips out of a run's window, symbolically.
    ///
    /// Deliberately partial: operands that are not plainly window-shaped carve
    /// nothing here and are still applied face by face downstream, so a missed
    /// carve costs a wider enumeration but never correctness.
    fn carve(&self, window: &Window, strips: &[NodeId]) -> Vec<Window> {
        let mut pieces = vec![window.clone()];
        for operand in strips {
            let Some(cuts) = self.windows_of(*operand) else { continue };
            for cut in cuts {
                pieces = pieces.iter().flat_map(|piece| piece.minus(&cut)).collect();
            }
        }
        pieces
    }

    /// The node's face set as windows when every member is one, else `None`.
    fn windows_of(&self, node: NodeId) -> Option<Vec<Window>> {
        self.arena
            .node(node)
            .members
            .iter()
            .map(|member| match member {
                Member::Face(text) => Some(Window::at(text)),
                Member::Range(lo, hi) => Some(Window::inclusive(*lo, *hi)),
                _ => None,
            })
            .collect()
    }
}

/// The universe a free `&` reads; the grammar guarantees a binder exists.
fn amp_of(amp: Option<Univ>) -> Univ {
    amp.expect("free `&` outside any binder")
}

/// Every combination taking one face from each factor, last factor moving fastest.
fn cartesian(combo: &[Vec<Spelling>]) -> Vec<Vec<Spelling>> {
    let mut rows: Vec<Vec<Spelling>> = vec![Vec::new()];
    for choices in combo {
        rows = rows
            .into_iter()
            .flat_map(|row| {
                choices.iter().map(move |face| {
                    let mut next = row.clone();
                    next.push(face.clone());
                    next
                })
            })
            .collect();
    }
    rows
}

/// Shortlex order over spellings, for callers outside this module.
pub fn shortlex(left: &Spelling, right: &Spelling) -> std::cmp::Ordering {
    compare(left, right)
}
