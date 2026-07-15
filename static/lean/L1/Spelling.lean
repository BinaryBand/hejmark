/- Port of the `singleton_ltb_iff` fragment of `static/formal/L1/Spelling.v`,
kept minimal on purpose: just enough of `lex_ltb`/`shortlex_ltb` to state and
prove the one theorem, as a Coq-vs-Lean workflow comparison rather than a
second mechanization of the order axis. -/
namespace L1

abbrev Code := Nat
abbrev Spelling := List Code

def lexLt : Spelling → Spelling → Bool
  | _, [] => false
  | [], _ :: _ => true
  | a :: s, b :: t => a < b || (a == b && lexLt s t)

def shortlexLt (s t : Spelling) : Bool :=
  s.length < t.length || (s.length == t.length && lexLt s t)

/-- Mirrors `singleton_ltb_iff` in `Spelling.v`. -/
theorem singleton_shortlexLt_iff (a b : Code) :
    shortlexLt [a] [b] = true ↔ a < b := by
  simp [shortlexLt, lexLt]

end L1
