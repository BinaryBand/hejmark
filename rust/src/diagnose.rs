//! Recover an engine panic as a message worth showing a user.
//!
//! Two of this crate's refusals are not `Result`s and cannot be. The Python
//! raises `HimarkBudgetError` and `HimarkUnsettledError` as ordinary exceptions
//! from deep inside the membership recursion; Rust has no catchable exception
//! type, so both ride `panic_any` (see [`crate::floor::work`]). Every entry
//! point therefore has the same last step -- run the body inside `catch_unwind`
//! and turn a panic back into a sentence -- and that step lives here rather than
//! three times over.
//!
//! The two engine errors are named explicitly because their messages are
//! actionable: "this pattern costs more than the budget allows" tells an author
//! what to do, where "the engine stopped unexpectedly" does not.

use std::any::Any;
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::floor::universe::HimarkUnsettledError;
use crate::floor::work::HimarkBudgetError;

/// Run `body`, flattening its `Err` and any panic into one error message.
///
/// # Errors
///
/// Returns the body's own error, or the description of whatever it panicked
/// with. A panic never escapes -- which is a correctness requirement across a C
/// ABI and merely good manners for a binary.
pub fn caught<T>(body: impl FnOnce() -> Result<T, String>) -> Result<T, String> {
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(outcome) => outcome,
        Err(panic) => Err(describe(panic.as_ref())),
    }
}

/// Silence the default panic hook, so a caught refusal prints once.
///
/// Without this a budget refusal reaches a user twice: the hook's "thread 'main'
/// panicked at ... Box<dyn Any>" on the way up, and the real sentence from
/// [`caught`] on the way out. The first is noise for an outcome the engine
/// intends, so a **binary** turns it off -- unless `RUST_BACKTRACE` is set,
/// which is the request for the noisy version and is honored.
///
/// A library must not: [`crate::ffi`] runs inside a host process whose own panic
/// reporting is not this crate's to change. It relies on `caught` alone.
pub fn quiet_panics() {
    if std::env::var_os("RUST_BACKTRACE").is_some() {
        return;
    }
    std::panic::set_hook(Box::new(|_| {}));
}

/// Describe a caught panic: the two engine refusals by name, anything else by
/// whatever string it carried.
fn describe(panic: &(dyn Any + Send)) -> String {
    if let Some(budget) = panic.downcast_ref::<HimarkBudgetError>() {
        budget.message.clone()
    } else if let Some(unsettled) = panic.downcast_ref::<HimarkUnsettledError>() {
        unsettled.message.clone()
    } else if let Some(text) = panic.downcast_ref::<String>() {
        text.clone()
    } else if let Some(text) = panic.downcast_ref::<&str>() {
        (*text).to_string()
    } else {
        "the engine stopped unexpectedly".to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::caught;
    use crate::floor::work::{budgeted, charge, BUDGET};

    #[test]
    fn a_body_that_returns_passes_its_value_through() {
        assert_eq!(caught(|| Ok::<_, String>(7)).unwrap(), 7);
    }

    #[test]
    fn a_body_that_errors_keeps_its_own_message() {
        let error = caught(|| Err::<(), _>("refused".to_string())).unwrap_err();
        assert_eq!(error, "refused");
    }

    #[test]
    fn a_budget_refusal_comes_back_as_its_own_sentence() {
        let error = caught(|| {
            let _budget = budgeted("a test run");
            charge(BUDGET + 1);
            Ok::<(), String>(())
        })
        .unwrap_err();
        assert!(error.contains("a test run"), "{error}");
    }

    #[test]
    fn an_ordinary_panic_still_becomes_a_message_rather_than_an_abort() {
        let error = caught(|| -> Result<(), String> { panic!("something gave way") }).unwrap_err();
        assert_eq!(error, "something gave way");
    }
}
