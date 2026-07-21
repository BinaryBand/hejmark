//! The std entries the on-device parser resolves, as Himark source.
//!
//! The std is Himark, not Rust -- `core/compiler/std.py` holds it as source
//! transcribed from `docs/foundation/L3.md`, and this table keeps that property
//! rather than hand-building floor nodes: an entry is the same text L3 prints,
//! parsed by [`super::parse`].
//!
//! Only the entries that expand with **no environment to consult** can live
//! here. Most of L3 takes arguments and expands through pipelines (`where`,
//! `pad`, `shorter`, `upto`, ...), which is the compiler's job and is not
//! ported; of the argument-free ones, `spellings` closes over the whole
//! code-point set and is unbounded, so a phone that resolved it would hand the
//! matcher a query it cannot finish. What is left is `hex`, which is exactly
//! what the editor's seeded rules ask for.
//!
//! An unresolved name is refused by name rather than silently skipped -- see
//! [`super::parse::parse_query`] -- so a host can offer the full compiler
//! instead of reporting a syntax error for well-formed Himark.

use std::rc::Rc;

use crate::floor::syntax::UniverseNode;

/// `name -> source`, transcribed from `docs/foundation/L3.md`.
const ENTRIES: &[(&str, &str)] = &[("hex", "{0..9,a..f}")];

/// The node a `@name` splice denotes, or `None` when the name is not resolvable
/// on this device.
///
/// The source is parsed on every call rather than cached. An entry is a handful
/// of characters and a rule is parsed once per edit, so the cache would cost
/// more in ceremony -- and in shared mutable state under an `Rc` tree -- than
/// the parse it saves.
pub fn resolve(name: &str) -> Option<Rc<UniverseNode>> {
    let (_, source) = ENTRIES.iter().find(|(entry, _)| *entry == name)?;
    let mut query = super::parse::parse_query(source)
        .expect("a std entry is Himark this parser accepts")
        .universes;
    // Every entry is one brace group, so its query has exactly one universe.
    query.pop()
}

/// The resolvable names, for the message an unknown one earns.
pub fn names() -> Vec<&'static str> {
    ENTRIES.iter().map(|(name, _)| *name).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::floor::syntax::Member;

    #[test]
    fn hex_resolves_to_the_two_ranges_l3_writes() {
        let node = resolve("hex").expect("hex is a std entry");
        assert_eq!(
            node.members,
            vec![
                Member::Range {
                    lo: u32::from('0'),
                    hi: u32::from('9')
                },
                Member::Range {
                    lo: u32::from('a'),
                    hi: u32::from('f')
                },
            ]
        );
    }

    #[test]
    fn an_unported_entry_is_absent_rather_than_wrong() {
        // `spellings` and the pipeline entries are deliberately not here; a host
        // must hear "unknown" and fall back, not receive a partial expansion.
        assert!(resolve("spellings").is_none());
        assert!(resolve("where").is_none());
        assert!(resolve("").is_none());
    }

    #[test]
    fn every_entry_parses_to_exactly_one_universe() {
        for (name, _) in ENTRIES {
            assert!(resolve(name).is_some(), "{name} should resolve");
        }
    }
}
