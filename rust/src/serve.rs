//! The three verbs, answered.
//!
//! The mirror of `hejmark/adapters/serve.py`, from the other end. Each request
//! decodes into the arguments the engine already takes, the engine runs, and the
//! answer encodes back.
//!
//! `run` is where the protocol earns its shape. A late slot cannot be lowered
//! before its reads bind, so executing one calls the host back -- from inside
//! the `run` this is still answering -- and the expansion the host performs will
//! ask this engine for denotations before it replies. The channel it borrows is
//! the same one, which is why it is handed through a [`RefCell`] rather than
//! captured: the resolver is an ordinary `Fn`, and only the outstanding call
//! holds the borrow.

use std::cell::RefCell;
use std::rc::Rc;

use serde_json::{json, Value};

use crate::channel::{Channel, Dispatch};
use crate::denote::Denoter;
use crate::errors::{payload, Answer, Fault};
use crate::scan::Engine;
use crate::spelling::{Spelling, GO, STOP};
use crate::syntax::{Arena, NodeId};
use crate::wire;

/// This package's engine, presented as the protocol's three verbs.
#[derive(Default)]
pub struct Verbs;

impl Dispatch for Verbs {
    fn answer(&self, channel: &mut Channel, verb: &str, params: &Value) -> Answer<Value> {
        match verb {
            "run" => self.run(channel, params),
            "zero" => zero(params),
            "digits" => digits(params),
            other => payload(format!("unknown verb {other:?}")),
        }
    }
}

impl Verbs {
    /// Execute a whole program, answering `resolve` back to the host as it goes.
    ///
    /// The arena is shared rather than sealed after decoding: a resolved slot is
    /// a floor universe that did not exist when the program arrived, and it has
    /// to land in the same arena the denotation is reading.
    fn run(&self, channel: &mut Channel, params: &Value) -> Answer<Value> {
        let arena = Rc::new(Arena::new());
        let program = wire::program(field(params, "program", "run")?, &arena)?;
        let document = wire::spelling(field(params, "document", "run")?)?;
        let borrowed = RefCell::new(channel);
        let resolve = |slot: u32, faces: &[Spelling]| -> Answer<NodeId> {
            let asked = json!({
                "slot": slot,
                "faces": faces.iter().map(|face| wire::points(face)).collect::<Vec<Value>>(),
            });
            let answered = borrowed.borrow_mut().call(self, "resolve", asked)?;
            wire::universe(field(&answered, "universe", "resolve")?, &arena)
        };
        let engine = Engine { den: Denoter::new(arena.clone()), resolve: &resolve };
        let spliced = engine.run(&program, &document)?;
        Ok(json!({"document": wire::points(&spliced)}))
    }
}

/// The head's zero entry: one face, or null for an empty universe.
///
/// One face, and the stream stops there. That is what makes `@0` on an
/// unbounded universe an answer rather than a hang -- the difference between
/// reading a universe's zero and enumerating it.
fn zero(params: &Value) -> Answer<Value> {
    let arena = Rc::new(Arena::new());
    let node = wire::universe(field(params, "universe", "zero")?, &arena)?;
    let denoter = Denoter::new(arena);
    let universe = denoter.denote(node);
    let mut first = None;
    let _drained = denoter.canonical_faces(universe, &mut |face| {
        first = Some(face.clone());
        STOP
    });
    Ok(json!({"face": first.map(|face| wire::points(&face))}))
}

/// Every canonical face, in value order: what a value cut reads.
///
/// On an unbounded universe this does not return, deliberately -- the floor
/// answers or diverges, and inventing a truncated radix would be worse than
/// hanging.
fn digits(params: &Value) -> Answer<Value> {
    let arena = Rc::new(Arena::new());
    let node = wire::universe(field(params, "universe", "digits")?, &arena)?;
    let denoter = Denoter::new(arena);
    let universe = denoter.denote(node);
    let mut faces = Vec::new();
    let _drained = denoter.canonical_faces(universe, &mut |face| {
        faces.push(wire::points(face));
        GO
    });
    Ok(json!({"faces": faces}))
}

/// Read *key* from a request's parameters, refusing anything else.
fn field<'a>(params: &'a Value, key: &str, what: &str) -> Answer<&'a Value> {
    params
        .get(key)
        .map_or_else(|| Err(Fault::Payload(format!("malformed {what}: missing {key:?}"))), Ok)
}
