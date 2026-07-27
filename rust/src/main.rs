//! Serve the engine protocol on stdin and stdout.
//!
//! Nothing here is for a human to read: the output is `docs/protocol.md`, one
//! JSON object per line, so this is a command a host spawns rather than one
//! anybody types.
//!
//! The work runs on a spawned thread with a large stack, deliberately. Deciding
//! whether a closure spells a length-`L` face descends about `L` frames, so a
//! long document is a deep recursion rather than a wide one -- the Python
//! engine meets the same wall and warms its memo shorter-prefix-first to stay
//! shallow. This engine does that too; the stack is the belt to that braces.

use std::io::{stdin, stdout, BufReader, BufWriter};
use std::process::ExitCode;
use std::thread;

use hejmark_engine::channel::Channel;
use hejmark_engine::serve::Verbs;

/// Room for a deep membership descent, not for deep protocol nesting.
const STACK_BYTES: usize = 256 * 1024 * 1024;

fn main() -> ExitCode {
    let started = thread::Builder::new().stack_size(STACK_BYTES).spawn(serve);
    let served = match started {
        Ok(handle) => handle.join().unwrap_or_else(|_| Err("the engine panicked".to_owned())),
        Err(error) => Err(format!("cannot start the engine thread: {error}")),
    };
    match served {
        Ok(()) => ExitCode::SUCCESS,
        Err(complaint) => {
            eprintln!("hejmark-engine: {complaint}");
            ExitCode::FAILURE
        }
    }
}

/// Answer verbs until the host hangs up.
fn serve() -> Result<(), String> {
    let reader = Box::new(BufReader::new(stdin()));
    let writer = Box::new(BufWriter::new(stdout()));
    Channel::new(reader, writer).serve(&Verbs).map_err(|fault| fault.to_string())
}
