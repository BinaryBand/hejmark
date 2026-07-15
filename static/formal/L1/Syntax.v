(* L1 abstract syntax: the six constructors as one mutual inductive.

   Mirrors Himark/core/syntax.py, except that the Python list spines
   (UniverseNode.members, Product.factors) are rolled into the mutual
   inductive itself (node, factors) so Coq generates usable mutual
   induction schemes and the guard checker never sees a nested list.

   MRange carries single code points, as syntax.Range does; MFinal and
   MFace carry whole spellings. MAmp is the closure token `&`; MSub is
   the subtraction member `!{...}`; MFold is a nested universe used as
   a member; MProd is a run of adjacent factors, each either a brace
   expression (FNode) or a bare `&` (FAmp). *)

From Coq Require Import List Bool Arith.
From L1 Require Import Spelling.
Import ListNotations.

Inductive member : Type :=
  | MFace  (text : spelling)
  | MRange (lo hi : code)
  | MFinal (lo : spelling)
  | MAmp
  | MFold (inner : node)
  | MSub  (inner : node)
  | MProd (fs : factors)
with node : Type :=
  | NNil
  | NCons (m : member) (rest : node)
with factors : Type :=
  | FNil
  | FAmp  (rest : factors)
  | FNode (n : node) (rest : factors).

Scheme member_mut := Induction for member Sort Prop
  with node_mut := Induction for node Sort Prop
  with factors_mut := Induction for factors Sort Prop.
Combined Scheme syntax_mutind from member_mut, node_mut, factors_mut.

(* A one-member node: the building block for stating member-level laws. *)
Definition nsingle (m : member) : node := NCons m NNil.

(* Union of member lists: node append. *)
Fixpoint napp (n1 n2 : node) : node :=
  match n1 with
  | NNil => n2
  | NCons m rest => NCons m (napp rest n2)
  end.

(* Union associativity in its strongest form: structural equality. *)
Lemma napp_assoc : forall a b c, napp (napp a b) c = napp a (napp b c).
Proof. induction a; simpl; congruence. Qed.

Lemma napp_nnil_r : forall n, napp n NNil = n.
Proof. induction n; simpl; congruence. Qed.

(* ---------------------------------------------------------------- *)
(* Binder detection, mirroring universe.py's _binds/_free_amp: a    *)
(* free `&` is the token itself or a literal `&` factor; it recurses *)
(* through subtraction operands but never through folds (the fold's  *)
(* own braces are the innermost binder site), and a brace factor     *)
(* with a free `&` inside binds itself.                              *)
(* ---------------------------------------------------------------- *)

Fixpoint has_ampb (fs : factors) : bool :=
  match fs with
  | FNil => false
  | FAmp _ => true
  | FNode _ rest => has_ampb rest
  end.

Fixpoint free_ampb (m : member) : bool :=
  match m with
  | MAmp => true
  | MProd fs => has_ampb fs
  | MSub inner => bindsb inner
  | _ => false
  end
with bindsb (n : node) : bool :=
  match n with
  | NNil => false
  | NCons m rest => free_ampb m || bindsb rest
  end.

Lemma bindsb_napp :
  forall n1 n2, bindsb (napp n1 n2) = bindsb n1 || bindsb n2.
Proof.
  induction n1 as [|m rest IH]; intro n2; simpl.
  - reflexivity.
  - rewrite IH, orb_assoc. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* Top-level member-list shape predicates.                          *)
(* ---------------------------------------------------------------- *)

(* Whether some member of the list adds faces (is not a subtraction).
   The evaluator uses its negation as a sound emptiness surrogate. *)
Fixpoint addsb (n : node) : bool :=
  match n with
  | NNil => false
  | NCons (MSub _) rest => addsb rest
  | NCons _ _ => true
  end.

(* Whether the member list is subtraction-free at the top level. *)
Fixpoint subfreeb (n : node) : bool :=
  match n with
  | NNil => true
  | NCons (MSub _) _ => false
  | NCons _ rest => subfreeb rest
  end.

Lemma subfreeb_napp :
  forall n1 n2,
    subfreeb n1 = true -> subfreeb n2 = true ->
    subfreeb (napp n1 n2) = true.
Proof.
  induction n1 as [|m rest IH]; intros n2 H1 H2; simpl in *.
  - exact H2.
  - destruct m; try (apply IH; assumption). discriminate.
Qed.
