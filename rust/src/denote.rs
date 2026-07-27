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

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;

use crate::spelling::{compare, empty, spelling, Flow, Spelling, Window, GO, STOP};
use crate::syntax::{Arena, Factor, Member, NodeId};

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
    contains_memo: RefCell<HashMap<(Univ, Spelling), bool>>,
    spells_memo: RefCell<HashMap<(NodeId, u32, Option<Univ>, Spelling), bool>>,
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
        }
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

    /// Whether some entry of *universe* wears *face*.
    pub fn contains(&self, universe: Univ, face: &Spelling) -> bool {
        let memo_key = (universe, face.clone());
        if let Some(&found) = self.contains_memo.borrow().get(&memo_key) {
            return found;
        }
        let answer = self.contains_fresh(universe, face);
        self.contains_memo.borrow_mut().insert(memo_key, answer);
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
        // A guarded body settles by `len + 1`, so this is exact; an unguarded one
        // only semi-decides, and a face no stage up to the bound shows reads as
        // absent -- which a later stage of an unsettled body could contradict.
        let bound = stages
            .unwrap_or_else(|| u32::try_from(face.len()).expect("spelling too long") + 1);
        (0..bound).any(|stage| {
            let prev = self.univ(node, amp, Some(stage));
            self.walk(node, self.arena.width(node), Some(prev), face)
        })
    }

    /// Answer the shorter prefixes before the whole, so the descent stays shallow.
    ///
    /// A closure decides a length-`L` face by asking its body about strictly
    /// shorter ones, so the recursion is naturally as deep as the face is long.
    /// Walking the prefixes upward first puts each answer the descent will want
    /// in the memo, so the descent finds it there rather than a frame deeper.
    /// Pure warming: no answer changes, only where it is computed.
    fn shorter_first(&self, universe: Univ, face: &Spelling) {
        for end in 1..face.len() {
            self.contains(universe, &spelling(&face[..end]));
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
                    present =
                        present && !self.walk(*inner, self.arena.width(*inner), amp, face);
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
            Member::Closure => self.contains(self.amp(amp), face),
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
    fn splits(&self, factors: &[Factor], amp: Option<Univ>, face: &Spelling) -> bool {
        let length = face.len();
        let mut memo: HashMap<(usize, usize), bool> = HashMap::new();
        self.rest(factors, amp, face, length, 0, 0, &mut memo)
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
        memo: &mut HashMap<(usize, usize), bool>,
    ) -> bool {
        if index == factors.len() {
            return pos == length;
        }
        if let Some(&found) = memo.get(&(index, pos)) {
            return found;
        }
        let mut answer = false;
        for end in pos..=length {
            if self.factor_contains(&factors[index], amp, &spelling(&face[pos..end]))
                && self.rest(factors, amp, face, length, index + 1, end, memo)
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
            Factor::Closure => self.contains(self.amp(amp), piece),
            Factor::Universe(node) => self.contains(self.denote(*node), piece),
        }
    }

    /// The universe a free `&` reads; the grammar guarantees a binder exists.
    fn amp(&self, amp: Option<Univ>) -> Univ {
        amp.expect("free `&` outside any binder")
    }

    /// Stream the entries in declaration order, lazily -- safe over infinity.
    pub fn entries(&self, universe: Univ, sink: Sink) -> Flow {
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
            Member::Closure => self.filtered(self.amp(amp), live, sink),
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
            Factor::Closure => self.amp(amp),
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
