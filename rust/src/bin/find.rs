//! `find`: match a JSON-encoded query against a target file.
//!
//! The Python package parses and expands Himark source, then emits the floor
//! AST as JSON (see [`hejmark::floor::json`]); this binary reads that JSON,
//! denotes it, and prints one `start<TAB>end` line (code-point offsets) per
//! non-overlapping match -- the Rust end of the portable hand-off, and the
//! cross-check that both engines agree.

use std::env;
use std::fs;
use std::process;

use hejmark::diagnose::{caught, quiet_panics};
use hejmark::floor::json::query_from_json;
use hejmark::floor::universe::{denote_shared, Universe};
use hejmark::scan::r#match::{finditer, Query};

fn main() {
    quiet_panics();
    if let Err(message) = caught(run) {
        eprintln!("{message}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    let [_, query_path, target_path] = args.as_slice() else {
        return Err("usage: find <query.json> <target.txt>".to_string());
    };

    let query_json = fs::read_to_string(query_path)
        .map_err(|error| format!("cannot read {query_path}: {error}"))?;
    let target = fs::read_to_string(target_path)
        .map_err(|error| format!("cannot read {target_path}: {error}"))?;

    let parsed =
        query_from_json(&query_json).map_err(|error| format!("invalid query JSON: {error}"))?;
    let factors: Vec<Universe> = parsed.universes.iter().map(denote_shared).collect();
    let query = Query::new("<json>", factors);

    let text: Vec<u32> = target.chars().map(|c| c as u32).collect();
    for found in finditer(&query, &text) {
        let (start, end) = found.span;
        println!("{start}\t{end}");
    }
    Ok(())
}
