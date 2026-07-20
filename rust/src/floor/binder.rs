//! Where a closure binds, and whether it settles.
//!
//! A port of `hejmark/core/floor/binder.py`. Two structural questions about a
//! brace expression, both answered by reading the AST rather than by denoting
//! anything:
//!
//! - [`binds`] -- does a free `&` occur in these members? A subtraction's braces
//!   never bind, so `&` inside one reads the *outer* binder; that asymmetry is
//!   the whole content of [`free_amp`].
//! - [`settled`] -- is every free `&` guarded, so that each closure pass strictly
//!   lengthens and membership settles at stage `len(spelling) + 1`? A bare `&`
//!   is unguarded (the pass can repeat itself); a `&` in a product is guarded
//!   when some sibling factor cannot spell the empty face.
//!
//! That last clause is the one thing here that is not purely syntactic, so it
//! arrives as a parameter: `spells_empty` decides whether a factor's face set
//! holds the empty spelling. Threading it in (rather than denoting a universe
//! here) is what keeps this a leaf, and states the real shape of the property --
//! settledness is syntactic *modulo* an emptiness oracle.

use super::syntax::{Factor, Member, UniverseNode};

/// Whether this brace expression is a closure binder: a free `&` in its members.
pub fn binds(node: &UniverseNode) -> bool {
    node.members.iter().any(free_amp)
}

/// Whether a free `&` occurs in this member (subtraction braces never bind).
pub fn free_amp(member: &Member) -> bool {
    match member {
        Member::Closure => true,
        Member::Product(factors) => factors
            .iter()
            .any(|factor| matches!(factor, Factor::Closure)),
        Member::Subtract(inner) => binds(inner),
        _ => false,
    }
}

/// Whether every free `&` is guarded, so membership settles by stage len + 1.
///
/// `spells_empty` decides whether a factor's face set holds the empty spelling.
pub fn settled(node: &UniverseNode, spells_empty: &dyn Fn(&UniverseNode) -> bool) -> bool {
    node.members
        .iter()
        .all(|member| settled_member(member, spells_empty))
}

/// Whether this member's free `&` occurrences (if any) are guarded.
fn settled_member(member: &Member, spells_empty: &dyn Fn(&UniverseNode) -> bool) -> bool {
    match member {
        Member::Closure => false,
        Member::Product(factors) if factors.iter().any(|f| matches!(f, Factor::Closure)) => factors
            .iter()
            .filter_map(|factor| match factor {
                Factor::Universe(inner) => Some(inner),
                Factor::Closure => None,
            })
            .any(|inner| guards(inner, spells_empty)),
        Member::Subtract(inner) => settled(inner, spells_empty),
        _ => true,
    }
}

/// Whether a factor guards its product: no empty face, so every pass lengthens.
fn guards(factor: &UniverseNode, spells_empty: &dyn Fn(&UniverseNode) -> bool) -> bool {
    !spells_empty(factor)
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

    /// A stand-in oracle: a node spells "" exactly when it holds an empty face.
    fn spells_empty(node: &UniverseNode) -> bool {
        node.members
            .iter()
            .any(|member| matches!(member, Member::Face(text) if text.is_empty()))
    }

    #[test]
    fn a_bare_amp_binds_its_enclosing_braces() {
        assert!(binds(&node(vec![Member::Face(cp("a")), Member::Closure])));
        assert!(!binds(&node(vec![
            Member::Face(cp("a")),
            Member::Face(cp("b"))
        ])));
    }

    #[test]
    fn an_amp_inside_a_product_still_binds() {
        let product = Member::Product(vec![
            Factor::Universe(node(vec![Member::Face(cp("a"))])),
            Factor::Closure,
        ]);
        assert!(binds(&node(vec![product])));
    }

    #[test]
    fn a_subtractions_braces_never_bind_so_the_amp_reads_the_outer_binder() {
        // `&` inside `!{...}` is free in the subtraction but bound outside it:
        // the subtraction reports the amp upward rather than capturing it.
        let inner = node(vec![Member::Closure]);
        assert!(free_amp(&Member::Subtract(inner.clone())));
        assert!(binds(&node(vec![
            Member::Face(cp("a")),
            Member::Subtract(inner)
        ])));
    }

    #[test]
    fn a_fold_does_capture_its_own_amp() {
        // Unlike a subtraction, a fold is a binder in its own right, so the amp
        // is not free in the enclosing expression.
        let fold = Member::Fold(node(vec![Member::Closure]));
        assert!(!binds(&node(vec![Member::Face(cp("a")), fold])));
    }

    #[test]
    fn a_bare_amp_is_unsettled() {
        let n = node(vec![Member::Face(cp("a")), Member::Closure]);
        assert!(!settled(&n, &spells_empty));
    }

    #[test]
    fn an_amp_guarded_by_a_non_empty_factor_settles() {
        let guarded = node(vec![Member::Product(vec![
            Factor::Universe(node(vec![Member::Face(cp("a"))])),
            Factor::Closure,
        ])]);
        assert!(settled(&guarded, &spells_empty));
    }

    #[test]
    fn an_amp_whose_only_sibling_can_be_empty_does_not_settle() {
        // Nothing forces the pass to lengthen, so there is no stage bound.
        let unguarded = node(vec![Member::Product(vec![
            Factor::Universe(node(vec![Member::Face(cp(""))])),
            Factor::Closure,
        ])]);
        assert!(!settled(&unguarded, &spells_empty));
    }

    #[test]
    fn one_guarding_factor_is_enough() {
        let mixed = node(vec![Member::Product(vec![
            Factor::Universe(node(vec![Member::Face(cp(""))])),
            Factor::Universe(node(vec![Member::Face(cp("b"))])),
            Factor::Closure,
        ])]);
        assert!(settled(&mixed, &spells_empty));
    }

    #[test]
    fn settledness_reaches_through_a_subtraction() {
        let n = node(vec![
            Member::Face(cp("a")),
            Member::Subtract(node(vec![Member::Closure])),
        ]);
        assert!(!settled(&n, &spells_empty));
    }

    #[test]
    fn members_with_no_amp_at_all_are_vacuously_settled() {
        let n = node(vec![
            Member::Face(cp("a")),
            Member::Range {
                lo: 'a' as u32,
                hi: 'z' as u32,
            },
        ]);
        assert!(settled(&n, &spells_empty));
    }
}
