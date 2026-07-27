//! The re-entrant line, this side of it.
//!
//! A port of `hejmark/adapters/channel.py`, and symmetric for the same reason:
//! [`Channel::call`] and [`Channel::serve`] are one loop with different stopping
//! conditions. That matters here more than on the host side, because this end is
//! the one that discovers it: answering `run` can require asking the host to
//! expand a late slot, and the host will ask *this* engine for a denotation
//! before it replies. An engine that stopped reading while its own call was
//! outstanding would deadlock against a host that is behaving correctly.
//!
//! One JSON object per line, flushed every time. Ids are per-direction, so this
//! end numbers its own calls and never confuses the host's.

use std::io::{BufRead, Write};

use serde_json::{json, Value};

use crate::errors::{Answer, Fault};

/// What answers inbound requests.
///
/// The channel is handed back so an inbound request can issue outbound ones of
/// its own -- which is exactly what `run` does when it hits a late slot.
pub trait Dispatch {
    /// Answer one request, or refuse it.
    fn answer(&self, channel: &mut Channel, verb: &str, params: &Value) -> Answer<Value>;
}

/// One end of a bidirectional request/response line.
pub struct Channel {
    reader: Box<dyn BufRead>,
    writer: Box<dyn Write>,
    next: u64,
}

impl Channel {
    /// A channel over *reader* and *writer*.
    pub fn new(reader: Box<dyn BufRead>, writer: Box<dyn Write>) -> Self {
        Self { reader, writer, next: 1 }
    }

    /// Ask the far side for *verb*, servicing its requests until it answers.
    pub fn call<D: Dispatch>(&mut self, dispatch: &D, verb: &str, params: Value) -> Answer<Value> {
        let id = self.next;
        self.next += 1;
        // Built by hand so *params* moves. A `json!` interpolation re-serialises
        // it, which on `run` means deep-copying a whole program payload.
        let mut request = serde_json::Map::new();
        request.insert("id".into(), Value::from(id));
        request.insert("verb".into(), Value::from(verb));
        request.insert("params".into(), params);
        self.send(&Value::Object(request))?;
        self.pump(dispatch, Some(id))
    }

    /// Answer inbound requests until the far side hangs up.
    pub fn serve<D: Dispatch>(&mut self, dispatch: &D) -> Answer<()> {
        self.pump(dispatch, None).map(|_| ())
    }

    /// Read messages, answering requests, until call *awaiting* is answered.
    fn pump<D: Dispatch>(&mut self, dispatch: &D, awaiting: Option<u64>) -> Answer<Value> {
        loop {
            let Some(message) = self.receive()? else {
                return match awaiting {
                    None => Ok(Value::Null),
                    Some(id) => Err(Fault::Channel(format!(
                        "the far side hung up while call {id} was outstanding"
                    ))),
                };
            };
            if message.get("verb").is_some() {
                self.reply(dispatch, &message)?;
            } else if let Some(id) = awaiting {
                return result(&message, id);
            } else {
                return Err(Fault::Channel("unsolicited answer".into()));
            }
        }
    }

    /// Dispatch one inbound request and send back its answer or its refusal.
    fn reply<D: Dispatch>(&mut self, dispatch: &D, message: &Value) -> Answer<()> {
        let id = message.get("id").cloned().unwrap_or(Value::Null);
        let verb = message
            .get("verb")
            .and_then(Value::as_str)
            .ok_or_else(|| Fault::Channel("malformed request".into()))?
            .to_owned();
        let params = message.get("params").cloned().unwrap_or_else(|| json!({}));
        let answered = dispatch.answer(self, &verb, &params);
        match answered {
            Ok(value) => self.send(&json!({"id": id, "ok": value})),
            Err(fault) => match fault.category() {
                // A refusal is an answer: the far side is never left waiting.
                Some(category) => self.send(&json!({
                    "id": id,
                    "error": {"category": category, "message": fault.to_string()},
                })),
                // The conversation itself is broken; there is nothing to reply on.
                None => Err(fault),
            },
        }
    }

    /// Write one message and flush it: a line the far side can act on now.
    fn send(&mut self, message: &Value) -> Answer<()> {
        writeln!(self.writer, "{message}")
            .and_then(|()| self.writer.flush())
            .map_err(|error| Fault::Channel(format!("cannot write: {error}")))
    }

    /// Read one message, or `None` at end of input.
    fn receive(&mut self) -> Answer<Option<Value>> {
        let mut line = String::new();
        let read = self
            .reader
            .read_line(&mut line)
            .map_err(|error| Fault::Channel(format!("cannot read: {error}")))?;
        if read == 0 {
            return Ok(None);
        }
        match serde_json::from_str::<Value>(&line) {
            Ok(value) if value.is_object() => Ok(Some(value)),
            _ => Err(Fault::Channel(format!("not a protocol message: {line:?}"))),
        }
    }
}

/// The value an answer carries, or the refusal it carries instead.
fn result(message: &Value, awaiting: u64) -> Answer<Value> {
    if message.get("id").and_then(Value::as_u64) != Some(awaiting) {
        return Err(Fault::Channel(format!("answer to another call while awaiting {awaiting}")));
    }
    if let Some(error) = message.get("error") {
        let category = error.get("category").and_then(Value::as_str).unwrap_or("");
        let detail = error.get("message").and_then(Value::as_str).unwrap_or("");
        return Err(Fault::of(category, detail.to_owned()));
    }
    message
        .get("ok")
        .cloned()
        .ok_or_else(|| Fault::Channel(format!("answer to call {awaiting} carries nothing")))
}
