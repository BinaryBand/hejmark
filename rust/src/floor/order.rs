//! The spelling order: shortlex over spellings, and symbolic windows of it.
//!
//! A faithful port of `hejmark/core/floor/order.py`. L1 fixes the spelling
//! order as shortlex (shorter first, ties by code point) -- a well-order of
//! type omega over the whole Unicode code space, surrogates riding along by
//! design, nothing special-cased. This module realizes just what the
//! constructors need:
//!
//! - [`shortlex_cmp`] compares spellings in shortlex.
//! - [`successor`] steps to the unique next spelling, which turns an inclusive
//!   range endpoint into a half-open bound and walks a window lazily.
//! - [`Window`] is a half-open shortlex interval `[lo, hi)`; a range or a final
//!   segment denotes as one window, never materialized. An unbounded window
//!   (`hi` is `None`) still answers `contains` in finite time.
//!
//! One representational note: a Python `str` is a sequence of code points, and
//! the order deliberately ranges over lone surrogates (U+D800..=U+DFFF), which
//! Rust's `char`/`String` cannot hold. So a spelling here is a `[u32]` of code
//! points in `0..=0x10FFFF`, not a `String`. That is the only difference from
//! the Python; the order it induces is identical.

use std::cmp::Ordering;

/// The greatest code point: the one code unit with no in-length successor.
pub const MAX: u32 = 0x10FFFF;

/// Compare two spellings in shortlex: shorter first, ties by code point.
pub fn shortlex_cmp(a: &[u32], b: &[u32]) -> Ordering {
    a.len().cmp(&b.len()).then_with(|| a.cmp(b))
}

/// Return the shortlex successor: the unique next spelling after `s`.
///
/// Increments the last non-maximal code point and zeroes everything after it;
/// an all-maximal spelling rolls over to `s.len() + 1` zeros. The order is
/// total, so every spelling has a successor and the order is walked one step
/// at a time.
pub fn successor(s: &[u32]) -> Vec<u32> {
    let mut codes = s.to_vec();
    for i in (0..codes.len()).rev() {
        if codes[i] != MAX {
            codes[i] += 1;
            for code in codes.iter_mut().skip(i + 1) {
                *code = 0;
            }
            return codes;
        }
    }
    vec![0; s.len() + 1]
}

/// Return whichever spelling is greater in shortlex; ties return `a`.
fn shortlex_max<'a>(a: &'a [u32], b: &'a [u32]) -> &'a [u32] {
    if shortlex_cmp(a, b) == Ordering::Less {
        b
    } else {
        a
    }
}

/// A half-open shortlex window `[lo, hi)`; `hi` is `None` when unbounded.
///
/// A reversed window (`hi` at or below `lo`) is simply empty: [`contains`] finds
/// no member and [`members`] yields nothing.
///
/// [`contains`]: Window::contains
/// [`members`]: Window::members
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Window {
    /// Inclusive lower bound.
    pub lo: Vec<u32>,
    /// Exclusive upper bound, or `None` when the window is unbounded.
    pub hi: Option<Vec<u32>>,
}

impl Window {
    /// Whether the window has no member.
    pub fn is_empty(&self) -> bool {
        match &self.hi {
            Some(hi) => shortlex_cmp(hi, &self.lo) != Ordering::Greater,
            None => false,
        }
    }

    /// Whether `s` falls inside the window.
    pub fn contains(&self, s: &[u32]) -> bool {
        if shortlex_cmp(s, &self.lo) == Ordering::Less {
            return false;
        }
        match &self.hi {
            Some(hi) => shortlex_cmp(s, hi) == Ordering::Less,
            None => true,
        }
    }

    /// The parts of the window left after removing `cut` -- zero, one, or two.
    pub fn minus(&self, cut: &Window) -> Vec<Window> {
        let left_hi = match &self.hi {
            // cut.lo sits at or past hi: nothing to trim on the left, keep hi.
            Some(hi) if shortlex_cmp(&cut.lo, hi) != Ordering::Less => Some(hi.clone()),
            // hi is None, or cut.lo lands inside: the left piece ends at cut.lo.
            _ => Some(cut.lo.clone()),
        };
        let mut pieces = vec![Window {
            lo: self.lo.clone(),
            hi: left_hi,
        }];
        if let Some(cut_hi) = &cut.hi {
            pieces.push(Window {
                lo: shortlex_max(&self.lo, cut_hi).to_vec(),
                hi: self.hi.clone(),
            });
        }
        pieces
            .into_iter()
            .filter(|piece| !piece.is_empty())
            .collect()
    }

    /// Iterate the members in spelling order (lazy; an unbounded window is infinite).
    pub fn members(&self) -> Members {
        Members {
            next: self.lo.clone(),
            hi: self.hi.clone(),
        }
    }
}

/// A lazy iterator over a [`Window`]'s members in spelling order.
///
/// It owns its bound rather than borrowing the window, so it can be moved into
/// and composed by the denotation streams in [`super::universe`] without tying
/// their lifetime to a window that has since gone out of scope.
pub struct Members {
    next: Vec<u32>,
    hi: Option<Vec<u32>>,
}

impl Iterator for Members {
    type Item = Vec<u32>;

    fn next(&mut self) -> Option<Vec<u32>> {
        if let Some(hi) = &self.hi {
            if shortlex_cmp(&self.next, hi) != Ordering::Less {
                return None;
            }
        }
        let current = self.next.clone();
        self.next = successor(&self.next);
        Some(current)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A spelling as code points, mirroring how the tests write Python `str`s.
    fn cp(s: &str) -> Vec<u32> {
        s.chars().map(|c| c as u32).collect()
    }

    /// Every spelling of length <= 3 over a tiny alphabet, in shortlex order --
    /// small enough to check window operations exhaustively.
    fn universe_of_spellings() -> Vec<Vec<u32>> {
        let alphabet = [b'a' as u32, b'b' as u32, b'c' as u32];
        let mut spellings: Vec<Vec<u32>> = vec![vec![]];
        for &a in &alphabet {
            spellings.push(vec![a]);
        }
        for &a in &alphabet {
            for &b in &alphabet {
                spellings.push(vec![a, b]);
            }
        }
        for &a in &alphabet {
            for &b in &alphabet {
                for &c in &alphabet {
                    spellings.push(vec![a, b, c]);
                }
            }
        }
        spellings.sort_by(|x, y| shortlex_cmp(x, y));
        spellings
    }

    #[test]
    fn shortlex_sorts_shorter_first_then_by_code_point() {
        let mut spellings = vec![cp("ba"), cp("b"), cp("a"), cp(""), cp("ab")];
        spellings.sort_by(|x, y| shortlex_cmp(x, y));
        assert_eq!(
            spellings,
            vec![cp(""), cp("a"), cp("b"), cp("ab"), cp("ba")]
        );
    }

    #[test]
    fn successor_is_strictly_next() {
        for s in universe_of_spellings() {
            assert_eq!(shortlex_cmp(&s, &successor(&s)), Ordering::Less);
        }
        // The rollover cases the tiny universe never reaches.
        for s in [vec![], vec![MAX], vec![MAX, MAX]] {
            assert_eq!(shortlex_cmp(&s, &successor(&s)), Ordering::Less);
        }
    }

    #[test]
    fn successor_steps_within_a_length_then_rolls_over() {
        assert_eq!(successor(&cp("")), cp("\u{0}"));
        assert_eq!(successor(&cp("a")), cp("b"));
        assert_eq!(successor(&cp("az")), cp("a{"));
        assert_eq!(successor(&cp("ab\u{10ffff}")), cp("ac\u{0}"));
    }

    #[test]
    fn all_maximal_spelling_rolls_to_a_longer_zero_spelling() {
        assert_eq!(successor(&[MAX]), vec![0, 0]);
        assert_eq!(successor(&[MAX, MAX]), vec![0, 0, 0]);
    }

    #[test]
    fn bounded_window_iterates_in_spelling_order() {
        let window = Window {
            lo: cp("a"),
            hi: Some(successor(&cp("e"))),
        };
        let members: Vec<Vec<u32>> = window.members().collect();
        assert_eq!(members, vec![cp("a"), cp("b"), cp("c"), cp("d"), cp("e")]);
    }

    #[test]
    fn window_contains_matches_brute_force() {
        let window = Window {
            lo: cp("b"),
            hi: Some(cp("bb")),
        };
        for s in universe_of_spellings() {
            let expected = shortlex_cmp(&cp("b"), &s) != Ordering::Greater
                && shortlex_cmp(&s, &cp("bb")) == Ordering::Less;
            assert_eq!(window.contains(&s), expected, "spelling {s:?}");
        }
    }

    #[test]
    fn unbounded_window_is_infinite() {
        let tail = Window {
            lo: cp("a"),
            hi: None,
        };
        assert!(tail.contains(&cp("a")));
        assert!(tail.contains(&cp("zzzz")));
        assert!(!tail.contains(&cp("\u{0}"))); // below "a" in shortlex
        let first_three: Vec<Vec<u32>> = tail.members().take(3).collect();
        assert_eq!(first_three, vec![cp("a"), cp("b"), cp("c")]);
    }

    #[test]
    fn reversed_window_is_empty() {
        let window = Window {
            lo: cp("e"),
            hi: Some(cp("a")),
        };
        assert!(window.is_empty());
        assert!(!window.contains(&cp("e")));
        assert!(window.members().next().is_none());
    }

    #[test]
    fn minus_matches_brute_force() {
        let universe = universe_of_spellings();
        let windows = [
            Window {
                lo: cp("a"),
                hi: Some(cp("cc")),
            },
            Window {
                lo: cp("b"),
                hi: None,
            },
        ];
        let cuts = [
            Window {
                lo: cp("b"),
                hi: Some(cp("bc")),
            },
            Window {
                lo: cp("aa"),
                hi: Some(cp("ca")),
            },
            Window {
                lo: cp("e"),
                hi: Some(cp("a")), // an empty cut removes nothing
            },
        ];
        for window in &windows {
            for cut in &cuts {
                let pieces = window.minus(cut);
                for s in &universe {
                    let in_pieces = pieces.iter().any(|piece| piece.contains(s));
                    let expected = window.contains(s) && !cut.contains(s);
                    assert_eq!(
                        in_pieces, expected,
                        "window {window:?} minus {cut:?} at {s:?}"
                    );
                }
            }
        }
    }
}
