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
//! `binds` is precomputed per node. It is asked on every membership query, it is
//! a pure function of the subtree, and answering it at push time turns the
//! hottest predicate in the engine into a field read.

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

    /// Add a brace group, working out whether it binds.
    pub fn push(&self, members: Vec<Member>) -> NodeId {
        let binds = members.iter().any(|member| self.free_amp(member));
        let mut nodes = self.nodes.borrow_mut();
        let id = u32::try_from(nodes.len()).expect("arena overflow");
        nodes.push(Rc::new(Node { members, binds }));
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
