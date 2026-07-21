//! The shortlex-window view of a member, and symbolic carving.
//!
//! A port of `hejmark/core/floor/window.py`. A range or a final segment is an
//! interval in shortlex order, so it has a [`Window`] -- and a run of them can
//! have subtractions cut out of it *without* enumerating either side. That is
//! what makes `{a..}![b..]` terminate: the infinite tail is carved symbolically
//! rather than filtered face by face forever.
//!
//! The carving is deliberately partial. [`carve`] only cuts operands that are
//! plainly window-shaped; anything else is left alone here and re-checked face
//! by face by the caller, so a missed carve costs termination on infinite runs
//! but never correctness.
//!
//! Leaf module: reads [`super::order`] and the AST, and nothing above it. No
//! universe is denoted to answer these questions.

use std::rc::Rc;

use super::order::{successor, Window};
use super::syntax::{Member, UniverseNode};

/// The shortlex window a range or final segment denotes; `None` for any other member.
pub fn window_of(member: &Member) -> Option<Window> {
    match member {
        Member::Range { lo, hi } => Some(Window {
            lo: vec![*lo],
            hi: Some(successor(&[*hi])),
        }),
        Member::Final(lo) => Some(Window {
            lo: lo.clone(),
            hi: None,
        }),
        _ => None,
    }
}

/// Cut the window-shaped strips out of a run's window, symbolically.
///
/// Operands that are not plainly window-shaped carve nothing here; they are
/// still applied face by face downstream.
pub fn carve(window: Window, strips: &[Rc<UniverseNode>]) -> Vec<Window> {
    let mut pieces = vec![window];
    for operand in strips {
        let Some(cuts) = windows_of(operand) else {
            continue;
        };
        for cut in &cuts {
            pieces = pieces.iter().flat_map(|piece| piece.minus(cut)).collect();
        }
    }
    pieces
}

/// The node's face set as windows when every member is one, else `None`.
pub fn windows_of(node: &UniverseNode) -> Option<Vec<Window>> {
    node.members.iter().map(as_window).collect()
}

/// One member as a window: a face is a single-point window, a range or final its
/// interval; any other member has no window, which collapses [`windows_of`] to `None`.
fn as_window(member: &Member) -> Option<Window> {
    if let Member::Face(text) = member {
        return Some(Window {
            lo: text.clone(),
            hi: Some(successor(text)),
        });
    }
    window_of(member)
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

    fn range(lo: char, hi: char) -> Member {
        Member::Range {
            lo: lo as u32,
            hi: hi as u32,
        }
    }

    #[test]
    fn a_range_becomes_a_half_open_window_over_its_inclusive_endpoint() {
        let window = window_of(&range('a', 'c')).unwrap();
        let hits: Vec<bool> = "abcd"
            .chars()
            .map(|c| window.contains(&[c as u32]))
            .collect();
        assert_eq!(hits, vec![true, true, true, false]);
    }

    #[test]
    fn a_final_segment_becomes_an_unbounded_window() {
        let window = window_of(&Member::Final(cp("y"))).unwrap();
        assert!(window.hi.is_none());
        assert!(window.contains(&cp("y")));
        assert!(window.contains(&cp("zzzz")));
        assert!(!window.contains(&cp("x")));
    }

    #[test]
    fn windows_of_reads_a_face_as_a_single_point_window() {
        let windows = carve(
            Window {
                lo: cp("a"),
                hi: None,
            },
            &[node(vec![Member::Face(cp("b"))])],
        );
        let spellings: Vec<Vec<u32>> = windows.iter().flat_map(|w| w.members().take(4)).collect();
        assert!(!spellings.contains(&cp("b")));
        assert_eq!(spellings[..3].to_vec(), vec![cp("a"), cp("c"), cp("d")]);
    }

    #[test]
    fn carving_splits_a_run_in_two_and_drops_the_empty_piece() {
        assert_eq!(
            carve(
                Window {
                    lo: cp("a"),
                    hi: Some(cp("f")),
                },
                &[node(vec![range('c', 'd')])],
            ),
            vec![
                Window {
                    lo: cp("a"),
                    hi: Some(cp("c")),
                },
                Window {
                    lo: cp("e"),
                    hi: Some(cp("f")),
                },
            ]
        );
        assert_eq!(
            carve(
                Window {
                    lo: cp("a"),
                    hi: Some(cp("d")),
                },
                &[node(vec![range('a', 'z')])],
            ),
            Vec::<Window>::new()
        );
    }

    #[test]
    fn carving_an_infinite_tail_leaves_a_finite_prefix() {
        // The point of carving symbolically: {a..}![c..] terminates.
        assert_eq!(
            carve(
                Window {
                    lo: cp("a"),
                    hi: None,
                },
                &[node(vec![Member::Final(cp("c"))])],
            ),
            vec![Window {
                lo: cp("a"),
                hi: Some(cp("c")),
            }]
        );
    }

    #[test]
    fn a_non_window_shaped_operand_carves_nothing() {
        // A fold is not plainly window-shaped, so nothing is cut here; the
        // stream level re-checks it face by face, which is why this is safe.
        let window = Window {
            lo: cp("a"),
            hi: Some(cp("f")),
        };
        let fold = node(vec![Member::Fold(node(vec![Member::Face(cp("c"))]))]);
        assert_eq!(carve(window.clone(), &[fold]), vec![window]);
    }

    #[test]
    fn strips_compose_left_to_right() {
        assert_eq!(
            carve(
                Window {
                    lo: cp("a"),
                    hi: Some(cp("h")),
                },
                &[node(vec![range('b', 'b')]), node(vec![range('e', 'f')])],
            ),
            vec![
                Window {
                    lo: cp("a"),
                    hi: Some(cp("b")),
                },
                Window {
                    lo: cp("c"),
                    hi: Some(cp("e")),
                },
                Window {
                    lo: cp("g"),
                    hi: Some(cp("h")),
                },
            ]
        );
    }
}
