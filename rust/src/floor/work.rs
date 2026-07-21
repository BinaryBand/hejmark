//! The work budget: what a run may spend before it is refused rather than waited on.
//!
//! A port of `hejmark/core/floor/work.py`. `L2.md` generalizes a rule the tree
//! already states twice -- `scan::capture::BUDGET` over a factor read, the
//! Python's `valueline.RADIX_BUDGET` over a value cut -- to the runs
//! themselves: the host holds a work budget over a match and over a
//! contracting pass exactly as it holds one over a read. Its *existence* is
//! the contract; its size is a choice.
//!
//! This sits on the floor, low enough to see the work, because that is where
//! the work is: a matcher probe is one line of Rust around one membership
//! question, and the question is what can cost seconds. The unit charged is
//! therefore one **membership question** -- one call to
//! [`super::universe::Universe::contains`], the recursion's own chokepoint,
//! memo hits included, since a run that re-asks a million answered questions
//! has spent a million questions' worth of clock.
//!
//! A budget is opened by the entry point that owns a run -- one per match, so
//! far, since [`super::super::scan::r#match`] is the only run this crate has
//! ported; a contracting pass has no Rust runner yet. Where no budget is open,
//! [`charge`] is free: the budget belongs to the caller that asked for a run,
//! not to the algebra.
//!
//! One divergence from the Python is forced by the language rather than
//! chosen: the Python raises `HimarkBudgetError` as an ordinary exception a
//! caller can catch mid-run. Rust has no such control-flow exception, so
//! [`HimarkBudgetError`] unwinds via `panic_any`, exactly as
//! [`super::universe::HimarkUnsettledError`] already does -- a caller recovers
//! it with `catch_unwind` and `downcast_ref`.

use std::cell::RefCell;
use std::fmt;

/// Raised when a run spends past the host's work budget.
///
/// Its own type rather than the reads' `HimarkScopeError` (`scan::error`),
/// because L2 separates them too: a read that outruns its budget cannot name
/// an entry, where a run past the work budget could name every one and simply
/// could not afford to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HimarkBudgetError {
    /// A human-readable description naming the run and its budget.
    pub message: String,
}

impl fmt::Display for HimarkBudgetError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for HimarkBudgetError {}

/// How many membership questions a single run may spend.
///
/// Mirrors the Python's `work.BUDGET`: around a hundred thousand questions go
/// by per second, so this is roughly a minute of work -- far above any
/// hand-written script the engine is meant to run, far below the point where a
/// wait stops being a wait.
pub const BUDGET: usize = 5_000_000;

/// One open budget: what is being run, what it may spend, what it has spent.
struct Meter {
    what: &'static str,
    budget: usize,
    spent: usize,
}

thread_local! {
    /// The open budget for this thread, at most one deep.
    ///
    /// A `RefCell<Option<Meter>>` rather than the Python's list: nested runs
    /// never push a second meter (see [`budgeted`]), so there is never more
    /// than one to hold, and the outermost run stays the one that holds.
    static OPEN: RefCell<Option<Meter>> = const { RefCell::new(None) };
}

/// A guard that closes the run's budget when dropped -- on a normal return or
/// on an unwind past it, mirroring the Python's `finally: _OPEN.clear()`.
///
/// A nested call while a budget is already open rides it instead: such a
/// guard owns nothing, so dropping it leaves the outer budget untouched.
pub struct Budget {
    owns: bool,
}

impl Drop for Budget {
    fn drop(&mut self) {
        if self.owns {
            OPEN.with(|open| *open.borrow_mut() = None);
        }
    }
}

/// Open a work budget over this run, unless an outer run already holds one.
///
/// `what` names the run for the diagnostic message. The returned [`Budget`]
/// closes the budget when it drops; hold it for exactly the run's scope, the
/// way `with budgeted(...):` does in the Python.
pub fn budgeted(what: &'static str) -> Budget {
    let owns = OPEN.with(|open| {
        let mut open = open.borrow_mut();
        if open.is_none() {
            *open = Some(Meter {
                what,
                budget: BUDGET,
                spent: 0,
            });
            true
        } else {
            false
        }
    });
    Budget { owns }
}

/// Charge `cost` questions against the open budget; a no-op where none is open.
///
/// # Panics
///
/// Panics with a [`HimarkBudgetError`] payload when the run has spent past its
/// budget. The over-budget meter stays open, so a caller that catches the
/// unwind and charges again inside the same scope is told the same thing
/// rather than granted a fresh allowance; closing it is [`Budget::drop`]'s job.
pub fn charge(cost: usize) {
    OPEN.with(|open| {
        let mut guard = open.borrow_mut();
        let Some(meter) = guard.as_mut() else {
            return;
        };
        meter.spent += cost;
        if meter.spent > meter.budget {
            let message = format!(
                "{} ran past the host's work budget of {} membership questions; \
                 the run is polynomial but not affordable here",
                meter.what, meter.budget
            );
            drop(guard);
            std::panic::panic_any(HimarkBudgetError { message });
        }
    });
}

#[cfg(test)]
mod tests {
    use super::{budgeted, charge, HimarkBudgetError, BUDGET};

    #[test]
    fn charge_is_free_with_no_open_budget() {
        charge(1_000_000_000);
    }

    #[test]
    fn a_run_within_budget_charges_without_panicking() {
        let _budget = budgeted("a test run");
        charge(10);
        charge(10);
    }

    #[test]
    fn a_run_past_budget_panics_with_the_budget_error() {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(|_| {}));
        let outcome = std::panic::catch_unwind(|| {
            let _budget = budgeted("a test run");
            charge(5);
            charge(BUDGET);
        });
        std::panic::set_hook(previous);

        let payload = outcome.expect_err("spending past the budget must unwind");
        let error = payload
            .downcast_ref::<HimarkBudgetError>()
            .expect("the panic payload must be a HimarkBudgetError");
        assert!(error.message.contains("work budget"), "{}", error.message);
    }

    #[test]
    fn a_nested_run_rides_the_outer_budget_rather_than_opening_its_own() {
        let _outer = budgeted("outer");
        charge(1);
        {
            let _inner = budgeted("inner");
            charge(1);
        }
        // The inner guard dropped without clearing the outer budget, so a
        // charge against a fresh budget of 1 would still be within it.
        charge(1);
    }
}
