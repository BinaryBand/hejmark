//! A hejmark engine: `docs/protocol.md`, spoken over a pipe.
//!
//! The engine half of the boundary and nothing else. It receives a lowered
//! payload -- floor universes, a compiled program -- denotes it, matches with
//! it, executes it, and hands back a document. It has no parser, no compiler
//! and no idea what `.hmk` source looks like, which is the property the whole
//! partition exists to buy.
//!
//! Two things are worth knowing before reading further.
//!
//! **A spelling is a `Vec` of code points, never a `String`.** L1 fixes the
//! spelling order as shortlex over the entire code space and lets surrogates
//! ride along unspecialised, and `char` cannot hold one. See [`spelling`].
//!
//! **The protocol is re-entrant, and this end is where that is discovered.**
//! Executing a late slot calls the host back from inside the `run` this engine
//! is still answering, and the host will ask this engine for denotations before
//! it replies. See [`channel`].
//!
//! `static/conformance/` is the specification this is written against;
//! `tests/integration/test_transport.py` with `HEJMARK_ENGINE` set runs it.

pub mod channel;
pub mod denote;
pub mod errors;
pub mod execute;
pub mod scan;
pub mod serve;
pub mod spelling;
pub mod syntax;
pub mod wire;
