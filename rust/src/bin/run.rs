//! `run`: execute a JSON-encoded program against a target file.
//!
//! The script-level companion to `find`. That one takes a single query's floor
//! AST (`hejmark emit-json`) and prints spans; this takes a whole compiled
//! script (`hejmark emit-program`, see [`hejmark::ir::wire`]) and prints the
//! spliced document, so the two binaries together answer the same two questions
//! `hejmark find` and `hejmark run` answer -- and answer them by reading data
//! the Python wrote, never Himark source.
//!
//! A program carrying a late slot is refused by name: resolving one is a call
//! back into the compiler, which lives in the process that emitted the program
//! and not in this one.

use std::env;
use std::fs;
use std::process;

use hejmark::diagnose::{caught, quiet_panics};
use hejmark::execute::run_text;
use hejmark::ir::wire::program_from_json;

fn main() {
    quiet_panics();
    if let Err(message) = caught(execute) {
        eprintln!("{message}");
        process::exit(1);
    }
}

fn execute() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    let [_, program_path, target_path] = args.as_slice() else {
        return Err("usage: run <program.json> <target.txt>".to_string());
    };

    let program_json = fs::read_to_string(program_path)
        .map_err(|error| format!("cannot read {program_path}: {error}"))?;
    let target = fs::read_to_string(target_path)
        .map_err(|error| format!("cannot read {target_path}: {error}"))?;

    let program = program_from_json(&program_json)
        .map_err(|error| format!("invalid program JSON: {error}"))?;
    let document = run_text(&program, &target).map_err(|error| error.to_string())?;
    print!("{document}");
    Ok(())
}
