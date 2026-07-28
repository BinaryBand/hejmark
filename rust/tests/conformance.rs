//! The conformance corpus, run natively.
//!
//! `static/conformance/*.json` is the language-neutral contract between engine
//! implementations, and this is this engine meeting it. It reads the checked-in
//! payloads directly -- no compiler, no wire, no Python -- which is exactly the
//! claim the corpus exists to make checkable.
//!
//! This is the gate that matters, and the transport suite is not a substitute
//! for it. The protocol has verbs for `run`, `zero` and `digits` and none for
//! entries or membership, so the `denote` and `match` suites are simply not
//! reachable over a pipe. An engine that reported the matcher's greedy split
//! instead of the floor's least-address binding passes every case a wire can
//! carry and fails `{a,ab}{c,bc}` here.
//!
//! Faces arrive as JSON strings rather than code-point arrays in this file, so
//! a case can only mention spellings Python's `json` can emit; the payloads
//! themselves still carry code points and still round-trip a lone surrogate.

use std::rc::Rc;

use serde_json::Value;

use hejmark_engine::denote::Denoter;
use hejmark_engine::errors::{Answer, Fault};
use hejmark_engine::scan::{Engine, Query};
use hejmark_engine::spelling::{Point, Spelling, GO, STOP};
use hejmark_engine::syntax::{Arena, NodeId};
use hejmark_engine::wire::{self, WireFactor};

/// The corpus, beside the checkout this crate sits in.
fn corpus(suite: &str) -> Vec<Value> {
    let path = format!("{}/../static/conformance/{suite}.json", env!("CARGO_MANIFEST_DIR"));
    let text = std::fs::read_to_string(&path).unwrap_or_else(|_| panic!("cannot read {path}"));
    let loaded: Value = serde_json::from_str(&text).expect("corpus is not JSON");
    loaded["cases"].as_array().expect("corpus has no cases").clone()
}

/// A JSON string as the code points it spells.
fn text_of(value: &Value) -> Vec<Point> {
    value.as_str().expect("not a string").chars().map(|point| point as Point).collect()
}

/// A spelling as the string a corpus case compares against.
fn shown(face: &[Point]) -> String {
    face.iter().map(|point| char::from_u32(*point).expect("no lone surrogate here")).collect()
}

/// The resolver a standalone payload must never reach for.
fn no_resolver(_slot: u32, _faces: &[Spelling]) -> Answer<NodeId> {
    panic!("a slot-free payload must not need a late resolver")
}

#[test]
fn denote_cases() {
    for case in corpus("denote") {
        let name = case["name"].as_str().expect("named");
        let arena = Rc::new(Arena::new());
        let node = wire::universe(&case["universe"], &arena).expect("payload decodes");
        let denoter = Denoter::new(arena);
        let universe = denoter.denote(node);

        if let Some(expected) = case["entries"].as_array() {
            let limit = case["limit"].as_u64();
            let mut seen: Vec<Vec<String>> = Vec::new();
            let _drained = denoter.entries(universe, &mut |entry| {
                if limit.is_some_and(|cap| seen.len() as u64 >= cap) {
                    return STOP;
                }
                seen.push(entry.faces.iter().map(|face| shown(face)).collect());
                if limit.is_some_and(|cap| seen.len() as u64 >= cap) {
                    STOP
                } else {
                    GO
                }
            });
            let expected: Vec<Vec<String>> = expected
                .iter()
                .map(|entry| {
                    entry
                        .as_array()
                        .expect("entry")
                        .iter()
                        .map(|f| f.as_str().unwrap().into())
                        .collect()
                })
                .collect();
            assert_eq!(seen, expected, "{name}: entries");
        }

        for (spelling, expected) in case["contains"].as_object().expect("contains") {
            let face: Spelling =
                Rc::from(spelling.chars().map(|point| point as Point).collect::<Vec<Point>>());
            // Three outcomes, not two: absence in an unguarded closure has no
            // stage bound, so L2 refuses instead of answering. A port that says
            // `false` there is wrong rather than lenient, and this is where that
            // is caught -- the protocol has no verb to ask membership over.
            let answer = denoter.contains(universe, &face);
            let seen: Value = match denoter.take_fault() {
                Some(fault) => Value::from(fault.category().expect("a refusal, not a fault")),
                None => Value::from(answer),
            };
            assert_eq!(&seen, expected, "{name}: contains {spelling:?}");
        }
    }
}

#[test]
fn match_cases() {
    for case in corpus("match") {
        let name = case["name"].as_str().expect("named");
        let arena = Rc::new(Arena::new());
        let factors: Vec<WireFactor> = case["query"]
            .as_array()
            .expect("query")
            .iter()
            .map(|universe| {
                WireFactor::Universe(wire::universe(universe, &arena).expect("payload decodes"))
            })
            .collect();
        let denoter = Denoter::new(arena);
        let query = Query::load(&denoter, String::new(), factors);
        let engine = Engine { den: denoter, resolve: &no_resolver };
        let text = text_of(&case["text"]);

        let found = engine.find(&query, &text, 0).expect("no slot to resolve");
        let Some(expected) = case["match"].as_object() else {
            assert!(found.is_none(), "{name}: expected no match");
            continue;
        };
        let found = found.unwrap_or_else(|| panic!("{name}: expected a match"));

        let span: Vec<u64> =
            expected["span"].as_array().unwrap().iter().map(|n| n.as_u64().unwrap()).collect();
        assert_eq!(vec![found.span.0 as u64, found.span.1 as u64], span, "{name}: span");

        let parts: Vec<(Vec<u64>, String)> = expected["parts"]
            .as_array()
            .unwrap()
            .iter()
            .map(|part| {
                (
                    part["span"].as_array().unwrap().iter().map(|n| n.as_u64().unwrap()).collect(),
                    part["face"].as_str().unwrap().to_owned(),
                )
            })
            .collect();
        let seen: Vec<(Vec<u64>, String)> = found
            .parts
            .iter()
            .map(|part| (vec![part.span.0 as u64, part.span.1 as u64], shown(&part.face)))
            .collect();
        assert_eq!(seen, parts, "{name}: parts");

        let canonical = engine.canonical_face(&query, &found).expect("canonical");
        assert_eq!(shown(&canonical), expected["canonical"].as_str().unwrap(), "{name}: $0");

        let factors = engine.factor_faces(&query, &found).expect("factors");
        let expected_factors: Vec<String> = expected["factors"]
            .as_array()
            .unwrap()
            .iter()
            .map(|f| f.as_str().unwrap().into())
            .collect();
        let seen: Vec<String> = factors.iter().map(|face| shown(face)).collect();
        assert_eq!(seen, expected_factors, "{name}: $k");
    }
}

#[test]
fn run_cases() {
    for case in corpus("run") {
        let name = case["name"].as_str().expect("named");
        if !case["requires"].as_array().expect("requires").is_empty() {
            // Needs the compiler's late resolver, which no standalone engine has.
            continue;
        }
        let arena = Rc::new(Arena::new());
        let program = wire::program(&case["program"], &arena).expect("payload decodes");
        let engine = Engine { den: Denoter::new(arena), resolve: &no_resolver };
        let document = text_of(&case["document"]);
        let spliced = engine.run(&program, &document).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(shown(&spliced), case["output"].as_str().unwrap(), "{name}");
    }
}

#[test]
fn refuse_cases() {
    for case in corpus("refuse") {
        let name = case["name"].as_str().expect("named");
        let expected = case["error"].as_str().expect("error");
        let arena = Rc::new(Arena::new());

        if case["case"] == "payload" {
            let fault = wire::program(&case["program"], &arena)
                .err()
                .unwrap_or_else(|| panic!("{name}: expected a refusal"));
            assert_eq!(fault.category(), Some(expected), "{name}");
            continue;
        }
        if case["stage"] == "ingest" {
            // The L2 ingest guard runs on the host, before `run` is ever called.
            continue;
        }
        let program = wire::program(&case["program"], &arena).expect("payload decodes");
        let engine = Engine { den: Denoter::new(arena), resolve: &no_resolver };
        let fault: Fault = engine
            .run(&program, &text_of(&case["document"]))
            .err()
            .unwrap_or_else(|| panic!("{name}: expected a refusal"));
        assert_eq!(fault.category(), Some(expected), "{name}");
    }
}
