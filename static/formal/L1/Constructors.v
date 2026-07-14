(* The object and the constructor floor. See docs/foundation/L1_TEMP.md,
   "The object" and "The constructors". *)

From L1 Require Import Ordinal.

(* Alphabet is left abstract: formalizing "virtual, never materialized,
   possibly infinite" faithfully wants a coinductive or symbolic encoding
   (mirrors Himark/core/universe.py's lazy `Universe`), which is future work
   once that representation is settled. *)
Parameter alphabet : Type.

(* The object: a pointed alphabet <alphabet, value, face>. *)
Record universe : Type := {
  uAlphabet : alphabet;
  uValue : ordinal;  (* below epsilon_0; mixed radix over a product's factors *)
  uFace : nat;        (* index into the entry's faces; rests at 0, canonical *)
}.

(* Six total constructors; nothing rejects. *)
Inductive constructor : Type :=
  | CUnion
  | CSubtraction
  | CFold
  | CFinalSegment
  | CProduct
  | CClosure.

(* TODO, once `alphabet` and a `denote` function are concrete:
   - positional value: a spelling is claimed by the least <value, face>
     address that spells it (L1_TEMP.md, "Positional value")
   - bounded transfinitude: uValue stays below epsilon_0, below omega^omega
     on the linear fragment (L1_TEMP.md, "Bounded transfinitude")
   - fixpoint on settled (guarded) closure bodies: membership decided by
     stage length + 1 (L1_TEMP.md, "Fixpoint on settled bodies"). *)
