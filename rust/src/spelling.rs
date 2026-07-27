//! Spellings, the spelling order, and half-open windows of it.
//!
//! A spelling is a sequence of **code points**, not a Rust `String`. That is not
//! a style choice: L1 fixes the spelling order as shortlex over the whole
//! Unicode code space and lets surrogates ride along unspecialised, so `D800`
//! is an ordinary spelling with an ordinary successor. `char` cannot hold one,
//! and a `String`-based engine would quietly skip the surrogate block when
//! stepping a range -- disagreeing with the reference engine on `{\u{d7ff}..\u{e000}}`
//! and on every window that spans it. The wire carries code-point arrays for the
//! same reason; this is that decision followed all the way in.

use std::rc::Rc;

/// One code point. Every value `0..=0x10FFFF` is legal, surrogates included.
pub type Point = u32;

/// A spelling: shared, because faces are copied far more often than built.
pub type Spelling = Rc<[Point]>;

/// The greatest code point: the one character with no in-length successor.
const MAX: Point = 0x0010_FFFF;

/// Build a spelling from code points.
pub fn spelling(points: &[Point]) -> Spelling {
    Rc::from(points)
}

/// The empty spelling, which a fold of the empty alphabet wears.
pub fn empty() -> Spelling {
    spelling(&[])
}

/// Shortlex: shorter first, ties code point by code point.
///
/// A well-order of type omega over the code space, which is what lets a range
/// denote as an interval and a window be walked one step at a time.
pub fn compare(left: &[Point], right: &[Point]) -> std::cmp::Ordering {
    left.len().cmp(&right.len()).then_with(|| left.cmp(right))
}

/// The unique next spelling after *points*.
///
/// Increments the last non-maximal code point and zeroes everything after it;
/// an all-maximal string rolls over to one `\0` longer. Total, so the order is
/// walked rather than searched.
pub fn successor(points: &[Point]) -> Spelling {
    let mut next = points.to_vec();
    for index in (0..next.len()).rev() {
        if next[index] != MAX {
            next[index] += 1;
            next[index + 1..].fill(0);
            return Rc::from(next);
        }
    }
    Rc::from(vec![0; points.len() + 1])
}

/// A half-open shortlex window `[lo, hi)`.
///
/// A reversed window is simply empty rather than an error: `contains` finds no
/// member and the walk yields nothing.
#[derive(Clone, Debug)]
pub struct Window {
    /// The least spelling in the window.
    pub lo: Spelling,
    /// The first spelling past it.
    pub hi: Spelling,
}

impl Window {
    /// A window over a single spelling.
    pub fn at(point: &[Point]) -> Self {
        Self { lo: spelling(point), hi: successor(point) }
    }

    /// The window an inclusive range `lo..hi` denotes.
    pub fn inclusive(lo: Point, hi: Point) -> Self {
        Self { lo: spelling(&[lo]), hi: successor(&[hi]) }
    }

    /// Whether the window has no member.
    pub fn is_empty(&self) -> bool {
        compare(&self.hi, &self.lo) != std::cmp::Ordering::Greater
    }

    /// Whether *point* falls inside the window.
    pub fn contains(&self, point: &[Point]) -> bool {
        compare(&self.lo, point) != std::cmp::Ordering::Greater
            && compare(point, &self.hi) == std::cmp::Ordering::Less
    }

    /// What is left of the window after removing *cut*: zero, one, or two pieces.
    pub fn minus(&self, cut: &Window) -> Vec<Window> {
        let left = Window { lo: self.lo.clone(), hi: least(&self.hi, &cut.lo) };
        let right = Window { lo: greatest(&self.lo, &cut.hi), hi: self.hi.clone() };
        [left, right].into_iter().filter(|piece| !piece.is_empty()).collect()
    }

    /// Walk the members in spelling order, stopping when *visit* says to.
    pub fn walk(&self, visit: &mut dyn FnMut(&Spelling) -> Flow) -> Flow {
        let mut at = self.lo.clone();
        while compare(&at, &self.hi) == std::cmp::Ordering::Less {
            visit(&at)?;
            at = successor(&at);
        }
        GO
    }
}

fn least(left: &Spelling, right: &Spelling) -> Spelling {
    if compare(left, right) == std::cmp::Ordering::Greater {
        right.clone()
    } else {
        left.clone()
    }
}

fn greatest(left: &Spelling, right: &Spelling) -> Spelling {
    if compare(left, right) == std::cmp::Ordering::Less {
        right.clone()
    } else {
        left.clone()
    }
}

/// Whether a lazy walk should carry on.
///
/// Streams here are callbacks rather than iterators, because a universe may
/// denote unboundedly many entries and every consumer either takes a fixed
/// number or searches for one. [`STOP`] is what makes "read the zero entry"
/// cost one entry on an infinite universe instead of not returning, and `?`
/// propagates it through the recursion the way `return` ends a Python generator.
pub type Flow = std::ops::ControlFlow<()>;

/// Keep streaming.
pub const GO: Flow = std::ops::ControlFlow::Continue(());

/// The consumer has what it needs; unwind without producing more.
pub const STOP: Flow = std::ops::ControlFlow::Break(());
