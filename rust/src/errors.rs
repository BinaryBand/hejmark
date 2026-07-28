//! The refusal vocabulary, which is the protocol's error table.
//!
//! Five categories and nothing else, named rather than messaged -- messages are
//! deliberately unpinned, so a port agrees on *which* refusal it is and not on
//! how it reads. `Channel` is the sixth thing that can go wrong and is pointedly
//! not a refusal: a refusal is an answer, and a broken pipe is the absence of
//! one.
//!
//! `Unsettled` and `Budget` are L2's, and they part on whether a port must agree
//! with this one. Unsettled is semantic -- absence in an unguarded closure has
//! no stage bound, so answering `false` is wrong rather than lenient, and the
//! corpus pins it. The work budget's *existence* is the contract while its size
//! is the host's choice, so no case fixes a number.

use std::fmt;

/// Something the engine declines, or the conversation failing outright.
#[derive(Debug)]
pub enum Fault {
    /// The JSON did not decode. Refuse; never repair or guess.
    Payload(String),
    /// A capture read nothing anchors, or a factor read past the query.
    Scope(String),
    /// A document arrived already spelling a noncharacter (the L2 guard).
    Sentinel(String),
    /// Absence in an unguarded closure, which no stage bounds (L2).
    Unsettled(String),
    /// A run spent past this host's work budget (L2).
    Budget(String),
    /// The far side stopped speaking the protocol -- or stopped.
    Channel(String),
}

impl Fault {
    /// The wire name of this refusal, or `None` if it is not one.
    pub fn category(&self) -> Option<&'static str> {
        match self {
            Fault::Payload(_) => Some("payload"),
            Fault::Scope(_) => Some("scope"),
            Fault::Sentinel(_) => Some("sentinel"),
            Fault::Unsettled(_) => Some("unsettled"),
            Fault::Budget(_) => Some("budget"),
            Fault::Channel(_) => None,
        }
    }

    /// The refusal a category names, carrying *detail*.
    pub fn of(category: &str, detail: String) -> Self {
        match category {
            "payload" => Fault::Payload(detail),
            "scope" => Fault::Scope(detail),
            "sentinel" => Fault::Sentinel(detail),
            "unsettled" => Fault::Unsettled(detail),
            "budget" => Fault::Budget(detail),
            other => Fault::Channel(format!("unknown category {other:?}: {detail}")),
        }
    }
}

impl fmt::Display for Fault {
    fn fmt(&self, out: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Fault::Payload(detail)
            | Fault::Scope(detail)
            | Fault::Sentinel(detail)
            | Fault::Unsettled(detail)
            | Fault::Budget(detail)
            | Fault::Channel(detail) => write!(out, "{detail}"),
        }
    }
}

impl std::error::Error for Fault {}

/// What every fallible verb in the engine returns.
pub type Answer<T> = Result<T, Fault>;

/// A malformed payload, as a refusal.
pub fn payload<T>(detail: impl Into<String>) -> Answer<T> {
    Err(Fault::Payload(detail.into()))
}

/// A refused scope, as a refusal.
pub fn scope<T>(detail: impl Into<String>) -> Answer<T> {
    Err(Fault::Scope(detail.into()))
}

/// Absence with no stage bound, as a refusal.
pub fn unsettled(detail: impl Into<String>) -> Fault {
    Fault::Unsettled(detail.into())
}

/// A run past this host's work budget, as a refusal.
pub fn budget(detail: impl Into<String>) -> Fault {
    Fault::Budget(detail.into())
}
