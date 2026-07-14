(* Cantor normal form ordinals below epsilon_0: omega^e_1 * c_1 + ... +
   omega^e_k * c_k, exponents strictly decreasing, coefficients positive.
   Mirrors Himark/core/ordinal.py. See docs/foundation/L1_TEMP.md,
   "Bounded transfinitude". *)

From Coq Require Import List.
Import ListNotations.

(* Each term's exponent is itself a CNF ordinal; the recursion stays finite
   because every closed term has finite nesting depth, which is exactly what
   "below epsilon_0" means. *)
Inductive ordinal : Type :=
  | CNF : list (ordinal * nat) -> ordinal.

Definition zero : ordinal := CNF [].

Definition one : ordinal := CNF [(zero, 1)].

Definition omega : ordinal := CNF [(one, 1)].

(* TODO, once well-formedness is settled:
   - wf : ordinal -> Prop (strictly decreasing exponents, positive
     coefficients on every subterm)
   - a decidable order compatible with wf
   - addition and multiplication, and their expected algebraic laws
     (n * omega = omega collapsing a left digit, etc. -- L1_TEMP.md's
     "Positional value" theorem depends on this collapse being provable,
     not assumed). *)
