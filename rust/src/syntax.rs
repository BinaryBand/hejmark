//! L1 as data: the five constructors, in an arena.
//!
//! The Python floor hands the same immutable node around and caches its hash,
//! because membership is memoised on `(universe, spelling)` and hashing a deep
//! tree once per question is the cost that matters. An arena reaches the same
//! place more directly: a node is a `NodeId`, so a memo key is three integers
//! and a spelling, and nothing walks a tree to hash it.
//!
//! It grows during a run rather than being sealed after decoding, because that
//! is what a late slot is -- the host answers `resolve` with a floor universe
//! that did not exist when the program was decoded. Nodes are handed out as
//! `Rc`, so a borrow of one survives the arena growing under it.
//!
//! `binds` and `reach` are both precomputed per node. Each is asked on every
//! membership query, each is a pure function of the subtree, and answering them
//! at push time turns the two hottest reads in the engine into field reads.
//! `reach` is L2's first rewrite as data (= `floor/reach.py`): the length of the
//! longest face a group can wear, or `None` for "no known bound", which is what
//! a closure and anything beside one honestly are. Over-approximating is safe --
//! a probe too many costs time -- so a shape not priced exactly is priced
//! `None`; under-approximating would drop a match.

use std::cell::RefCell;
use std::rc::Rc;

use crate::spelling::Spelling;

/// A brace group in the arena.
pub type NodeId = u32;

/// A product factor: a nested universe, or the closure token.
#[derive(Clone, Debug)]
pub enum Factor {
    /// A braced factor, which seals its own `&`.
    Universe(NodeId),
    /// `&`, reading the binder's previous stage.
    Closure,
}

/// One member of a brace group.
#[derive(Clone, Debug)]
pub enum Member {
    /// A literal spelling.
    Face(Spelling),
    /// An inclusive code-point range.
    Range(u32, u32),
    /// A nested universe used as a member: the quotient constructor.
    Fold(NodeId),
    /// `!{...}`, stripping the faces its inner universe spells.
    Subtract(NodeId),
    /// Adjacent factors as one member.
    Product(Vec<Factor>),
    /// The self-reference token.
    Closure,
}

/// A brace group: its members in declaration order, plus what it binds.
#[derive(Debug)]
pub struct Node {
    /// The members, in declaration order.
    pub members: Vec<Member>,
    /// Whether a free `&` occurs in them, so this group is a closure binder.
    pub binds: bool,
    /// The longest face the group can wear, or `None` when unbounded.
    pub reach: Option<usize>,
}

/// Every node a program mentions, plus every node resolving a slot has minted.
#[derive(Default, Debug)]
pub struct Arena {
    nodes: RefCell<Vec<Rc<Node>>>,
}

impl Arena {
    /// An empty arena.
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a brace group, working out whether it binds and how far it reaches.
    pub fn push(&self, members: Vec<Member>) -> NodeId {
        let binds = members.iter().any(|member| self.free_amp(member));
        let reach = self.group_reach(&members);
        let mut nodes = self.nodes.borrow_mut();
        let id = u32::try_from(nodes.len()).expect("arena overflow");
        nodes.push(Rc::new(Node { members, binds, reach }));
        id
    }

    /// The group at *id*.
    ///
    /// Handing back an `Rc` rather than a reference is what lets a walk hold a
    /// node while a nested `resolve` pushes new ones behind it.
    pub fn node(&self, id: NodeId) -> Rc<Node> {
        self.nodes.borrow()[id as usize].clone()
    }

    /// Whether the group at *id* is a closure binder.
    pub fn binds(&self, id: NodeId) -> bool {
        self.nodes.borrow()[id as usize].binds
    }

    /// How long a face the group at *id* can wear, or `None` when unbounded.
    pub fn reach(&self, id: NodeId) -> Option<usize> {
        self.nodes.borrow()[id as usize].reach
    }

    /// A product factor's reach; the closure token reads a stage and carries none.
    pub fn factor_reach(&self, factor: &Factor) -> Option<usize> {
        match factor {
            Factor::Closure => None,
            Factor::Universe(node) => self.reach(*node),
        }
    }

    /// The longest face a member list can wear: the greatest of its adding members.
    ///
    /// A subtraction is skipped rather than measured -- stripping faces can only
    /// shorten the set, so pricing the strip would raise the bound in exactly
    /// the wrong direction.
    fn group_reach(&self, members: &[Member]) -> Option<usize> {
        let mut longest = 0;
        for member in members {
            let far = match member {
                Member::Subtract(_) => continue,
                Member::Face(text) => Some(text.len()),
                Member::Range(lo, hi) => Some(usize::from(lo <= hi)),
                Member::Fold(inner) => self.reach(*inner),
                Member::Product(factors) => self.product_reach(factors),
                Member::Closure => None,
            };
            longest = longest.max(far?);
        }
        Some(longest)
    }

    /// A product's faces are concatenations, so its reach is the sum of its factors'.
    fn product_reach(&self, factors: &[Factor]) -> Option<usize> {
        factors.iter().try_fold(0usize, |total, factor| Some(total + self.factor_reach(factor)?))
    }

    /// How many members the group at *id* has.
    pub fn width(&self, id: NodeId) -> usize {
        self.nodes.borrow()[id as usize].members.len()
    }

    /// Whether a free `&` occurs in this member.
    ///
    /// A subtraction's braces never bind, so `&` inside one reads the *outer*
    /// binder. That asymmetry is the whole content of this function, and getting
    /// it backwards changes what `{a,&}!{&}` means.
    fn free_amp(&self, member: &Member) -> bool {
        match member {
            Member::Closure => true,
            Member::Product(factors) => {
                factors.iter().any(|factor| matches!(factor, Factor::Closure))
            }
            Member::Subtract(inner) => self.binds(*inner),
            _ => false,
        }
    }
}
