//! The C ABI a non-Rust host calls: a compiled program and text in, an answer out.
//!
//! `bin/find.rs` and `bin/run.rs` are this crate's other entry points and assume
//! a host that can spawn processes. An Android app cannot, so it links the crate
//! as a `cdylib` and calls [`hejmark_find_json`] or [`hejmark_run_json`] instead
//! -- the same shapes those binaries read, the same decoders reading them,
//! behind a C ABI rather than a pipe.
//!
//! **The program is compiled before it arrives.** This crate parses no Himark
//! and never has to: the host runs the real compiler and sends floor-AST JSON,
//! whether that compiler is a subprocess on a desktop or a CPython embedded in
//! the app (`gui/`). One way in, so nothing the language can spell is out of
//! reach here -- what a host cannot compile it also cannot send, and that is a
//! fact about the host and not about this engine.
//!
//! Everything crosses the boundary as one NUL-terminated UTF-8 string, because
//! that is the only shape every FFI host agrees on without a schema. A reply is
//! a status line followed by a body:
//!
//! ```text
//! ok\n<body>                -- the body is what the entry point produces
//! err\n<message>            -- the program is malformed, or the run was unaffordable
//! ```
//!
//! There are two entry points and they differ only in what a program is and
//! what an `ok` body holds. [`hejmark_find_json`] takes one query's floor AST
//! and its body is one `start\tend` line per match; [`hejmark_run_json`] takes a
//! whole compiled script ([`crate::ir::wire`]) and its body is the spliced
//! document. `find` and `run`, the language's two verbs, over one reply shape.
//!
//! Spans are **code-point** offsets, exactly as `find` prints them. A host whose
//! strings are UTF-16 (Dart, Java, JavaScript) must convert, or astral-plane text
//! misplaces every highlight after it.
//!
//! Panics never cross the boundary. The engine reports an unaffordable run and
//! an unsettled closure by unwinding with [`crate::floor::work::HimarkBudgetError`]
//! and [`crate::floor::universe::HimarkUnsettledError`] -- Rust has no catchable
//! exception type, so those ride `panic_any` -- and unwinding into the caller's
//! frames would be undefined behavior. [`catch`] turns each into an `err` reply.

use std::ffi::{c_char, CStr, CString};

use crate::diagnose::caught;
use crate::execute::run_text;
use crate::floor::json::query_from_json;
use crate::floor::syntax::QueryNode;
use crate::floor::universe::{denote_shared, Universe};
use crate::ir::wire::program_from_json;
use crate::scan::r#match::{finditer, Query};

/// Matches an already-compiled `query` -- floor-AST JSON, as `emit-json` writes
/// it and [`crate::floor::json`] reads it -- against `target`.
///
/// One of two, and the narrower: a single query, and the answer is where it
/// hits. `bin/find.rs` has always taken this shape, and this puts it behind the
/// C ABI too, for a host that can link a library but not spawn a process.
///
/// # Safety
///
/// Both arguments must be NUL-terminated UTF-8 strings that stay valid for the
/// duration of the call, or null. The returned pointer is owned by the caller
/// and must be released with [`hejmark_string_free`]; it is never null.
#[no_mangle]
pub unsafe extern "C" fn hejmark_find_json(
    query: *const c_char,
    target: *const c_char,
) -> *mut c_char {
    let reply = catch(|| {
        let program = borrow(query)?;
        let text = borrow(target)?;
        let parsed =
            query_from_json(program).map_err(|error| format!("invalid query JSON: {error}"))?;
        Ok(scan(&parsed, text))
    });
    into_c(reply)
}

/// Runs an already-compiled `program` -- the Program JSON `emit-program` writes
/// and [`crate::ir::wire`] reads -- over `document`, returning the spliced
/// result.
///
/// The other verb. Where [`hejmark_find_json`] reports where a query hits, this
/// executes a whole script: statements in order, templates spliced, contracting
/// statements run to settlement. A program carrying a late slot comes back as an
/// `err` naming what it needs, because resolving one is a call into the compiler
/// that emitted it and this library is not that compiler.
///
/// # Safety
///
/// Both arguments must be NUL-terminated UTF-8 strings that stay valid for the
/// duration of the call, or null. The returned pointer is owned by the caller
/// and must be released with [`hejmark_string_free`]; it is never null.
#[no_mangle]
pub unsafe extern "C" fn hejmark_run_json(
    program: *const c_char,
    document: *const c_char,
) -> *mut c_char {
    let reply = catch(|| {
        let source = borrow(program)?;
        let text = borrow(document)?;
        let parsed =
            program_from_json(source).map_err(|error| format!("invalid program JSON: {error}"))?;
        run_text(&parsed, text).map_err(|error| error.to_string())
    });
    into_c(reply)
}

/// Releases a string returned by either entry point above.
///
/// # Safety
///
/// `text` must be a pointer this library returned and has not already freed.
/// Passing null is allowed and does nothing.
#[no_mangle]
pub unsafe extern "C" fn hejmark_string_free(text: *mut c_char) {
    if !text.is_null() {
        drop(unsafe { CString::from_raw(text) });
    }
}

/// Denotes a floor AST and matches it: the reply body for a successful run, one
/// `start\tend` line per hit.
fn scan(parsed: &QueryNode, text: &str) -> String {
    let factors: Vec<Universe> = parsed.universes.iter().map(denote_shared).collect();
    let query = Query::new("<ffi>", factors);
    let points: Vec<u32> = text.chars().map(u32::from).collect();
    let mut body = String::new();
    for found in finditer(&query, &points) {
        let (start, end) = found.span;
        body.push_str(&format!("{start}\t{end}\n"));
    }
    body
}

/// Reads a borrowed C string, refusing null and invalid UTF-8 rather than
/// reaching for `from_utf8_unchecked`: the host controls this memory.
unsafe fn borrow<'a>(text: *const c_char) -> Result<&'a str, String> {
    if text.is_null() {
        return Err("null argument".to_string());
    }
    unsafe { CStr::from_ptr(text) }
        .to_str()
        .map_err(|_| "argument is not valid UTF-8".to_string())
}

/// Runs `body`, converting both its `Err` and any panic into an `err` reply.
///
/// The flattening is [`crate::diagnose::caught`], shared with the two binaries;
/// what is this module's own is that the result must never unwind past here --
/// crossing a C ABI mid-unwind is undefined behavior, where a binary would
/// merely print badly.
fn catch(body: impl FnOnce() -> Result<String, String>) -> String {
    match caught(body) {
        Ok(found) => format!("ok\n{found}"),
        Err(message) => format!("err\n{message}"),
    }
}

/// Hands a reply to the caller. A NUL inside the string would truncate it at the
/// boundary, so any is stripped first -- only an error message could carry one.
fn into_c(reply: String) -> *mut c_char {
    let clean = reply.replace('\0', " ");
    CString::new(clean)
        .unwrap_or_else(|_| {
            CString::new("err\nthe engine produced an unreadable reply")
                .expect("literal has no NUL")
        })
        .into_raw()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The shape of both entry points, so one helper drives either.
    type Entry = unsafe extern "C" fn(*const c_char, *const c_char) -> *mut c_char;

    /// Calls across the boundary the way a host does, and frees the reply.
    fn cross(entry: Entry, program: &str, target: &str) -> String {
        let program = CString::new(program).expect("test input has no NUL");
        let target = CString::new(target).expect("test input has no NUL");
        unsafe {
            let reply = entry(program.as_ptr(), target.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            text
        }
    }

    fn call(program: &str, target: &str) -> String {
        cross(hejmark_find_json, program, target)
    }

    fn run(program: &str, document: &str) -> String {
        cross(hejmark_run_json, program, document)
    }

    /// `{0..9}^4` as `hejmark emit-json` writes it. The fixtures here are all
    /// verbatim compiler output rather than hand-built JSON, which is the only
    /// way this file tests the boundary a host actually crosses.
    const FOUR_DIGITS: &str = r#"{"universes": [{"members": [{"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "range", "lo": 48, "hi": 57}]}}, {"kind": "universe", "universe": {"members": [{"kind": "range", "lo": 48, "hi": 57}]}}, {"kind": "universe", "universe": {"members": [{"kind": "range", "lo": 48, "hi": 57}]}}, {"kind": "universe", "universe": {"members": [{"kind": "range", "lo": 48, "hi": 57}]}}]}]}]}"#;

    /// `{0..9}[where 8..12]` -- a value cut, so a pipeline, so a construct no
    /// front end this crate ever had could reach. Compiled, it is just a
    /// universe, which is the argument for having deleted that front end.
    const WHERE_8_TO_12: &str = r#"{"universes": [{"members": [{"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, {"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": "face", "text": [55]}, {"kind": "face", "text": [56]}, {"kind": "face", "text": [57]}]}}]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}]}}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}]}}]}, {"kind": "subtract", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, {"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": "face", "text": [55]}]}}]}]}}]}}]}]}]}"#;

    #[test]
    fn a_compiled_rule_finds_its_hits() {
        assert_eq!(
            call(FOUR_DIGITS, "id 2024 and 1999 here"),
            "ok\n3\t7\n12\t16\n"
        );
    }

    #[test]
    fn no_hits_is_an_empty_ok_rather_than_an_error() {
        assert_eq!(call(FOUR_DIGITS, "no digits"), "ok\n");
    }

    #[test]
    fn spans_count_code_points_not_bytes() {
        // Four astral-plane characters, then the digits: a UTF-8 host would say
        // 16, a UTF-16 host 8, and the reply says 4.
        assert_eq!(
            call(FOUR_DIGITS, "\u{1d11e}\u{1d11e}\u{1d11e}\u{1d11e}2024"),
            "ok\n4\t8\n"
        );
    }

    #[test]
    fn a_pipeline_arrives_already_expanded() {
        // The whole reason there is no parser here. `where` is a pipeline, and
        // the compiler that expanded it -- subprocess or embedded CPython --
        // hands over something this crate needs no surface layer to read.
        assert_eq!(
            call(WHERE_8_TO_12, "7 8 9 10 11 12 13"),
            "ok\n2\t3\n4\t5\n6\t8\n9\t11\n12\t14\n"
        );
    }

    #[test]
    fn a_malformed_program_is_an_err_and_says_why() {
        let reply = call("{\"universes\": 3}", "text");
        assert!(reply.starts_with("err\ninvalid query JSON:"), "{reply}");
    }

    #[test]
    fn source_is_not_a_program_and_is_refused_as_one() {
        // A host that sends unexpanded source has skipped the compiler, and
        // there is no status for that beyond `err`: nothing downstream of this
        // library could do better, because this library is the downstream.
        let reply = call("{0..9}^4", "id 2024");
        assert!(reply.starts_with("err\ninvalid query JSON:"), "{reply}");
    }

    #[test]
    fn a_null_argument_is_refused_rather_than_dereferenced() {
        let target = CString::new("text").expect("literal has no NUL");
        unsafe {
            let reply = hejmark_find_json(std::ptr::null(), target.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            assert_eq!(text, "err\nnull argument");
        }
    }

    #[test]
    fn freeing_null_is_a_no_op() {
        unsafe { hejmark_string_free(std::ptr::null_mut()) };
    }

    /// `uni m = {a, b, &{a,b}}` then `{b}{a} <=>[@m] "{{$2}}{{$1}}"`, verbatim
    /// from `hejmark emit-program`: a two-letter bubble sort, which is a query,
    /// a template, a measure and a settlement loop in one program.
    const BUBBLE: &str = r#"{"format": "hejmark-program", "version": 1, "sentinels": [], "statements": [{"kind": "iter", "query": {"kind": "query", "source": "", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [98]}]}}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}]}}]}, "measure_name": "m", "measure": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}, {"kind": "product", "factors": [{"kind": "closure"}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]}}]}]}, "template": {"kind": "template", "parts": [{"kind": "capture", "capture": "$2"}, {"kind": "capture", "capture": "$1"}]}}]}"#;

    #[test]
    fn a_whole_script_runs_and_the_body_is_the_document() {
        assert_eq!(run(BUBBLE, "bbaa"), "ok\naabb");
    }

    #[test]
    fn a_program_is_not_a_query_and_the_two_entry_points_say_so_differently() {
        // Each refuses the other's payload by name, which is the whole reason
        // they are two symbols rather than one that guesses.
        assert!(call(BUBBLE, "bbaa").starts_with("err\ninvalid query JSON:"));
        assert!(run(FOUR_DIGITS, "id 2024").starts_with("err\ninvalid program JSON:"));
    }

    #[test]
    fn a_null_argument_is_refused_by_the_run_entry_point_too() {
        let document = CString::new("text").expect("literal has no NUL");
        unsafe {
            let reply = hejmark_run_json(std::ptr::null(), document.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            assert_eq!(text, "err\nnull argument");
        }
    }
}
