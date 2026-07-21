//! The C ABI a non-Rust host calls: source and text in, spans out.
//!
//! `bin/find.rs` is this crate's other entry point and assumes a host that can
//! spawn processes and run the Python compiler first. An Android app can do
//! neither, so it links the crate as a `cdylib` and calls these functions
//! through Dart's FFI instead. The pipeline is the whole of this crate stacked
//! up: [`crate::surface::parse`] reads the floor subset of Himark,
//! [`crate::floor::universe`] denotes it, [`crate::scan`] matches it.
//!
//! There are **two ways in and one engine**. [`hejmark_find`] takes source and
//! parses it here, which is all a host without a compiler can do;
//! [`hejmark_find_json`] takes an already-compiled floor AST, which is what a
//! host that reached the real compiler should send -- `bin/find.rs`'s shape,
//! behind the C ABI. They meet at [`scan`]. The second is why an Android app
//! embedding CPython (`gui/`) can match every construct the language has while
//! still matching it in Rust.
//!
//! Everything crosses the boundary as one NUL-terminated UTF-8 string, because
//! that is the only shape every FFI host agrees on without a schema. A reply is
//! a status line followed by a body:
//!
//! ```text
//! ok\n                      -- then one "start\tend" line per match
//! err\n<message>            -- the rule is wrong, or the run was unaffordable
//! unported\n<message>       -- the rule is right; this engine does not compile it
//! ```
//!
//! The third status is the one worth explaining. This library parses only the
//! floor subset of Himark (see [`crate::surface::parse`]), so a pipeline or a
//! back-reference is *valid source it cannot reach* rather than a mistake. A
//! host that can also reach the full Python compiler retries there on
//! `unported` and must not retry on `err`; leaving that decision to be made by
//! reading the message would not be a boundary.
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
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::floor::json::query_from_json;
use crate::floor::syntax::QueryNode;
use crate::floor::universe::{denote_shared, HimarkUnsettledError, Universe};
use crate::floor::work::HimarkBudgetError;
use crate::scan::r#match::{finditer, Query};
use crate::surface::parse::{parse_query, ParseRefusal};

/// Matches `query` against `target`, returning the reply described above.
///
/// # Safety
///
/// Both arguments must be NUL-terminated UTF-8 strings that stay valid for the
/// duration of the call, or null. The returned pointer is owned by the caller
/// and must be released with [`hejmark_string_free`]; it is never null.
#[no_mangle]
pub unsafe extern "C" fn hejmark_find(query: *const c_char, target: *const c_char) -> *mut c_char {
    let reply = catch(|| {
        let source = borrow(query)?;
        let text = borrow(target)?;
        run(source, text)
    });
    into_c(reply)
}

/// Matches an already-compiled `query` -- floor-AST JSON, as `emit-json` writes
/// it and [`crate::floor::json`] reads it -- against `target`.
///
/// This is the entry point for a host that reached the *full* compiler: an
/// Android app with CPython embedded (`gui/`) hands the program straight here
/// rather than re-parsing source through the floor subset, so every construct
/// the Python compiler expands is matchable on the device. `bin/find.rs` has
/// always taken this shape; this only puts it behind the C ABI too.
///
/// The reply is `ok` or `err` and never `unported`: a program is already past
/// the compiler, so there is nothing left for another one to do better.
///
/// # Safety
///
/// As [`hejmark_find`].
#[no_mangle]
pub unsafe extern "C" fn hejmark_find_json(
    query: *const c_char,
    target: *const c_char,
) -> *mut c_char {
    let reply = catch(|| {
        let program = borrow(query)?;
        let text = borrow(target)?;
        let parsed = query_from_json(program)
            .map_err(|error| Reply::Error(format!("invalid query JSON: {error}")))?;
        Ok(scan(&parsed, text))
    });
    into_c(reply)
}

/// Parses `query` without matching anything, so a host can report a bad rule
/// before there is any text to run it over. Replies `ok\n` or `err\n<message>`.
///
/// # Safety
///
/// As [`hejmark_find`].
#[no_mangle]
pub unsafe extern "C" fn hejmark_check(query: *const c_char) -> *mut c_char {
    let reply = catch(|| {
        parse_query(borrow(query)?).map_err(Reply::from)?;
        Ok(String::new())
    });
    into_c(reply)
}

/// Releases a string returned by any of the entry points above.
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

/// A failed call, and which status line it earns.
enum Reply {
    Error(String),
    Unported(String),
}

impl From<ParseRefusal> for Reply {
    fn from(refusal: ParseRefusal) -> Reply {
        match refusal {
            ParseRefusal::Syntax(error) => Reply::Error(error.message),
            ParseRefusal::Unported(message) => Reply::Unported(message),
        }
    }
}

/// The reply body for a successful match run: one `start\tend` line per hit.
fn run(source: &str, text: &str) -> Result<String, Reply> {
    let parsed = parse_query(source).map_err(Reply::from)?;
    Ok(scan(&parsed, text))
}

/// Denotes a floor AST and matches it, whichever front end produced it.
///
/// The two entry points differ only in how they got here -- the floor subset
/// parser or the full compiler's JSON -- and this is where they stop differing,
/// which is the point: one engine, reachable two ways.
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
unsafe fn borrow<'a>(text: *const c_char) -> Result<&'a str, Reply> {
    if text.is_null() {
        return Err(Reply::Error("null argument".to_string()));
    }
    unsafe { CStr::from_ptr(text) }
        .to_str()
        .map_err(|_| Reply::Error("argument is not valid UTF-8".to_string()))
}

/// Runs `body`, converting both its `Err` and any panic into an `err` reply.
///
/// The two engine errors are named explicitly because their messages are worth
/// showing a user -- "this pattern costs more than the budget allows" is
/// actionable where "internal error" is not.
fn catch(body: impl FnOnce() -> Result<String, Reply>) -> String {
    let outcome = catch_unwind(AssertUnwindSafe(body));
    match outcome {
        Ok(Ok(found)) => format!("ok\n{found}"),
        Ok(Err(Reply::Error(message))) => format!("err\n{message}"),
        Ok(Err(Reply::Unported(message))) => format!("unported\n{message}"),
        Err(panic) => {
            let message = if let Some(budget) = panic.downcast_ref::<HimarkBudgetError>() {
                budget.message.clone()
            } else if let Some(unsettled) = panic.downcast_ref::<HimarkUnsettledError>() {
                unsettled.message.clone()
            } else if let Some(text) = panic.downcast_ref::<String>() {
                text.clone()
            } else if let Some(text) = panic.downcast_ref::<&str>() {
                (*text).to_string()
            } else {
                "the engine stopped unexpectedly".to_string()
            };
            format!("err\n{message}")
        }
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

    /// Calls across the boundary the way a host does, and frees the reply.
    fn call(query: &str, target: &str) -> String {
        let query = CString::new(query).expect("test input has no NUL");
        let target = CString::new(target).expect("test input has no NUL");
        unsafe {
            let reply = hejmark_find(query.as_ptr(), target.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            text
        }
    }

    /// Calls the compiled-program entry point the same way.
    fn call_json(program: &str, target: &str) -> String {
        let program = CString::new(program).expect("test input has no NUL");
        let target = CString::new(target).expect("test input has no NUL");
        unsafe {
            let reply = hejmark_find_json(program.as_ptr(), target.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            text
        }
    }

    fn check(query: &str) -> String {
        let query = CString::new(query).expect("test input has no NUL");
        unsafe {
            let reply = hejmark_check(query.as_ptr());
            let text = CStr::from_ptr(reply)
                .to_str()
                .expect("reply is UTF-8")
                .to_string();
            hejmark_string_free(reply);
            text
        }
    }

    #[test]
    fn a_seeded_rule_finds_its_hits() {
        assert_eq!(
            call(r"{0..9}^4", "id 2024 and 1999 here"),
            "ok\n3\t7\n12\t16\n"
        );
    }

    #[test]
    fn a_hex_colour_matches_through_the_std_splice() {
        assert_eq!(call(r"{\#}{@hex}^6", "bg #ff00aa;"), "ok\n3\t10\n");
    }

    #[test]
    fn no_hits_is_an_empty_ok_rather_than_an_error() {
        assert_eq!(call(r"{0..9}^4", "no digits"), "ok\n");
    }

    #[test]
    fn spans_count_code_points_not_bytes() {
        // Four astral-plane characters, then the digits: a UTF-8 host would say
        // 16, a UTF-16 host 8, and the reply says 4.
        assert_eq!(call(r"{0..9}^4", "𝄞𝄞𝄞𝄞2024"), "ok\n4\t8\n");
    }

    #[test]
    fn a_bad_rule_replies_err_and_says_why() {
        let reply = call("{a", "text");
        assert!(reply.starts_with("err\n"), "{reply}");
        assert!(reply.contains("unclosed"), "{reply}");
    }

    #[test]
    fn an_unported_construct_earns_its_own_status() {
        // A host reads the status, not the prose, to decide whether to retry
        // against the full compiler.
        let reply = call("{a}[shorter 2]", "aa");
        assert!(reply.starts_with("unported\n"), "{reply}");
        assert!(reply.contains("pipeline"), "{reply}");
        assert!(check("{$1}").starts_with("unported\n"));
        // A malformed rule is not retryable, and says so with a different status.
        assert!(check("{a,}").starts_with("err\n"));
    }

    #[test]
    fn check_validates_a_rule_with_no_text_to_run_it_over() {
        assert_eq!(check(r"{0..9}^4"), "ok\n");
        assert!(check("{@nope}").starts_with("unported\nunknown name @nope"));
    }

    /// `{0..9}[where 8..12]` as `hejmark emit-json` writes it: a value cut, so a
    /// pipeline, so exactly what `surface::parse` refuses by name. Held verbatim
    /// rather than built by hand -- the point of the fixture is that it is the
    /// compiler's real output.
    const WHERE_8_TO_12: &str = r#"{"universes": [{"members": [{"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, {"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": "face", "text": [55]}, {"kind": "face", "text": [56]}, {"kind": "face", "text": [57]}]}}]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}]}}, {"kind": "universe", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}]}}]}, {"kind": "subtract", "universe": {"members": [{"kind": "face", "text": [48]}, {"kind": "product", "factors": [{"kind": "universe", "universe": {"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, {"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": "face", "text": [55]}]}}]}]}}]}}]}]}]}"#;

    #[test]
    fn a_compiled_program_matches_what_the_parser_here_refuses() {
        // The whole reason this entry point exists, in one assertion pair: the
        // source is `unported` because a pipeline is outside the floor subset,
        // and the same rule compiled by the real compiler runs here anyway.
        assert!(call("{0..9}[where 8..12]", "7 8 9 10 11 12 13").starts_with("unported\n"));
        assert_eq!(
            call_json(WHERE_8_TO_12, "7 8 9 10 11 12 13"),
            "ok\n2\t3\n4\t5\n6\t8\n9\t11\n12\t14\n"
        );
    }

    #[test]
    fn a_compiled_program_counts_code_points_too() {
        // Same convention as the source entry point; a host converts once, for
        // both.
        let program = r#"{"universes": [{"members": [{"kind": "range", "lo": 48, "hi": 57}]}]}"#;
        assert_eq!(call_json(program, "𝄞𝄞2"), "ok\n2\t3\n");
    }

    #[test]
    fn malformed_json_is_an_err_and_never_unported() {
        // Nothing is left to retry a program against: it is already compiled.
        let reply = call_json("{\"universes\": 3}", "text");
        assert!(reply.starts_with("err\ninvalid query JSON:"), "{reply}");
    }

    #[test]
    fn a_null_argument_is_refused_rather_than_dereferenced() {
        let target = CString::new("text").expect("literal has no NUL");
        unsafe {
            let reply = hejmark_find(std::ptr::null(), target.as_ptr());
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
}
