(* L1 north-star table (docs/foundation/L1_TEMP.md), at the membership
   level. Positive rows compute through containsb_sound: sndb and
   containsb are both closed booleans, so vm_compute settles them.
   Negative and emptiness rows are proved at the Prop level (the
   evaluator is sound, not complete), mostly as corollaries of Laws.v.

   Out of scope here, with the rest of the order axis: every claim
   about entry order, values, collision ownership, and order types
   (omega, omega * 2, omega ^ 2, ...). Collision rows appear as
   membership facts only -- a claimed spelling moves owner but never
   leaves the universe. The `{{{}}, &C}` row needs the finite
   code-point set (C as a literal union) and is deferred with it.

   Toy code assignment: letters a..z are 0..25, digits 0..9 are
   100..109. *)

From Coq Require Import List Bool Arith Lia.
From L1 Require Import Spelling Syntax Semantics Laws Evaluator.
Import ListNotations.

Definition la : code := 0.   Definition lb : code := 1.
Definition lc : code := 2.   Definition ld : code := 3.
Definition le : code := 4.   Definition lf : code := 5.
Definition lg : code := 6.   Definition li : code := 8.
Definition ll : code := 11.  Definition ln : code := 13.
Definition lo : code := 14.  Definition lt : code := 19.
Definition lu : code := 20.  Definition lz : code := 25.
Definition d0 : code := 100. Definition d1 : code := 101.
Definition d5 : code := 105. Definition d9 : code := 109.

Definition cat : spelling := [lc; la; lt].
Definition dog : spelling := [ld; lo; lg].
Definition feline : spelling := [lf; le; ll; li; ln; le].

Fixpoint nlist (ms : list member) : node :=
  match ms with
  | [] => NNil
  | m :: rest => NCons m (nlist rest)
  end.

(* ---------------------------------------------------------------- *)
(* {a,b,c}                                                           *)
(* ---------------------------------------------------------------- *)

Definition abc := nlist [MFace [la]; MFace [lb]; MFace [lc]].

Lemma abc_has_b : denotes abc [lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma abc_not_d : ~ denotes abc [ld].
Proof.
  intro H. cbn in H.
  destruct H as [[[H|H]|H]|H]; solve [exact H | discriminate H].
Qed.

(* ---------------------------------------------------------------- *)
(* {a..z}: both endpoints in, the empty spelling and longer          *)
(* spellings out (a range holds singletons only).                    *)
(* ---------------------------------------------------------------- *)

Definition a_to_z := nlist [MRange la lz].

Lemma a_to_z_has_a : denotes a_to_z [la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma a_to_z_has_z : denotes a_to_z [lz].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma a_to_z_not_empty_spelling : ~ denotes a_to_z [].
Proof. intro H. cbn in H. destruct H as [H|H]; [exact H | discriminate H]. Qed.

Lemma a_to_z_not_aa : ~ denotes a_to_z [la; la].
Proof. intro H. cbn in H. destruct H as [H|H]; [exact H | discriminate H]. Qed.

(* ---------------------------------------------------------------- *)
(* {{cat,feline}}: one entry, faces cat and feline; not the unit.    *)
(* ---------------------------------------------------------------- *)

Definition cat_feline := nlist [MFold (nlist [MFace cat; MFace feline])].

Lemma cat_feline_has_cat : denotes cat_feline cat.
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma cat_feline_has_feline : denotes cat_feline feline.
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma cat_feline_not_unit : ~ denotes cat_feline [].
Proof.
  intro H. cbn in H.
  destruct H as [H|[[[H|H]|H]|[_ He]]];
    try solve [exact H | discriminate H].
  apply (He cat). left. right. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* {a..z, !{a,e,i,o,u}}: difference = subtraction.                   *)
(* ---------------------------------------------------------------- *)

Definition consonants :=
  nlist [MRange la lz;
         MSub (nlist [MFace [la]; MFace [le]; MFace [li];
                      MFace [lo]; MFace [lu]])].

Lemma consonants_has_b : denotes consonants [lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma consonants_not_a : ~ denotes consonants [la].
Proof.
  intro H. cbn in H. destruct H as [_ Hn].
  apply Hn. left. left. left. left. right. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* {{cat,feline}, !{feline}}: the subtraction strips a face; at the  *)
(* membership level cat stays and feline goes.                       *)
(* ---------------------------------------------------------------- *)

Definition cat_only :=
  nlist [MFold (nlist [MFace cat; MFace feline]);
         MSub (nlist [MFace feline])].

Lemma cat_only_has_cat : denotes cat_only cat.
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma cat_only_not_feline : ~ denotes cat_only feline.
Proof.
  intro H. cbn in H. destruct H as [_ Hn].
  apply Hn. right. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* {a..}: a final segment, unbounded above, nothing below its cut.   *)
(* ---------------------------------------------------------------- *)

Definition a_final := nlist [MFinal [la]].

Lemma a_final_has_z : denotes a_final [lz].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma a_final_has_aa : denotes a_final [la; la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma a_final_not_empty_spelling : ~ denotes a_final [].
Proof. intro H. cbn in H. destruct H as [H|H]; [exact H | discriminate H]. Qed.

(* ---------------------------------------------------------------- *)
(* {cat}{dog} = {catdog}: finite adjacency is compression, as a      *)
(* general membership identity (Laws.adjacency) and as a row.        *)
(* ---------------------------------------------------------------- *)

Definition catdog :=
  nlist [MProd (FNode (nlist [MFace cat])
                      (FNode (nlist [MFace dog]) FNil))].

Lemma catdog_row :
  forall amp s,
    spells (MProd (FNode (nlist [MFace cat]) (FNode (nlist [MFace dog]) FNil)))
      amp s
    <-> spells (MFace (cat ++ dog)) amp s.
Proof. intros amp s. apply adjacency. Qed.

Lemma catdog_has_catdog : denotes catdog (cat ++ dog).
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {a,ab}{b,c}: ab, ac, abb, abc.                                    *)
(* ---------------------------------------------------------------- *)

Definition prod_row :=
  nlist [MProd (FNode (nlist [MFace [la]; MFace [la; lb]])
                      (FNode (nlist [MFace [lb]; MFace [lc]]) FNil))].

Lemma prod_row_has_ab : denotes prod_row [la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma prod_row_has_abc : denotes prod_row [la; lb; lc].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* {a,ab}{c,bc}: the tuples (a,bc) and (ab,c) collide on abc, which
   moves ownership but never membership -- abc is simply in.          *)
Definition collision_row :=
  nlist [MProd (FNode (nlist [MFace [la]; MFace [la; lb]])
                      (FNode (nlist [MFace [lc]; MFace [lb; lc]]) FNil))].

Lemma collision_row_has_abc : denotes collision_row [la; lb; lc].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* {a..}{b}: membership samples (the omega claim is order-axis). *)
Definition final_times_b :=
  nlist [MProd (FNode (nlist [MFinal [la]])
                      (FNode (nlist [MFace [lb]]) FNil))].

Lemma final_times_b_has_ab : denotes final_times_b [la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma final_times_b_has_zb : denotes final_times_b [lz; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {a,!{a}}: the empty universe.                                     *)
(* ---------------------------------------------------------------- *)

Definition a_minus_a := nlist [MFace [la]; MSub (nlist [MFace [la]])].

Lemma a_minus_a_empty : forall s, ~ denotes a_minus_a s.
Proof. intros s H. cbn in H. tauto. Qed.

(* ---------------------------------------------------------------- *)
(* {z..a}: a reversed range is empty.                                *)
(* ---------------------------------------------------------------- *)

Definition z_to_a := nlist [MRange lz la].

Lemma z_to_a_empty : forall s, ~ denotes z_to_a s.
Proof.
  intros s H.
  destruct H as [[]|H].
  assert (Hlt : la < lz) by (unfold la, lz; lia).
  exact (range_reversed_empty lz la (fun _ => False) s Hlt H).
Qed.

(* ---------------------------------------------------------------- *)
(* {{}}: the unit -- one entry, one face, the empty spelling.        *)
(* ---------------------------------------------------------------- *)

Definition unit_row := nlist [MFold NNil].

Lemma unit_row_has_empty_spelling : denotes unit_row [].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma unit_row_not_a : ~ denotes unit_row [la].
Proof.
  intro H. destruct H as [[]|H].
  apply unit_spells in H. discriminate H.
Qed.

(* ---------------------------------------------------------------- *)
(* {{{},0}}: the fill factor -- one entry, faces `` and `0`.         *)
(* ---------------------------------------------------------------- *)

Definition fill_body := nlist [MFold NNil; MFace [d0]].
Definition fill := nlist [MFold fill_body].

Lemma fill_has_empty_spelling : denotes fill [].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma fill_has_0 : denotes fill [d0].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* {{{},0}}{0..9}: a face axis -- 5 also wears 05. *)
Definition fill_digits :=
  nlist [MProd (FNode fill (FNode (nlist [MRange d0 d9]) FNil))].

Lemma fill_digits_has_5 : denotes fill_digits [d5].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma fill_digits_has_05 : denotes fill_digits [d0; d5].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {a, &{b}}: closure -- a, ab, abb, ...; nothing else.              *)
(* ---------------------------------------------------------------- *)

Definition amp_b :=
  nlist [MFace [la];
         MProd (FAmp (FNode (nlist [MFace [lb]]) FNil))].

Lemma amp_b_has_a : denotes amp_b [la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma amp_b_has_ab : denotes amp_b [la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma amp_b_has_abb : denotes amp_b [la; lb; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* Every member of the closure starts with a, so b is out. *)
Lemma amp_b_stage_headed :
  forall k s, stage amp_b k s -> exists r, s = la :: r.
Proof.
  induction k as [|k IHk]; intros s H.
  - rewrite stage_zero in H. contradiction.
  - rewrite stage_succ in H. destruct H as [H|H]; [eauto|].
    cbn in H.
    destruct H as [[H|H]|(p & q & -> & Hp & (p' & q' & -> & [Hp'|Hp'] & Hq'))];
      try contradiction.
    + exists []. exact H.
    + destruct (IHk p Hp) as (r & ->). exists (r ++ p' ++ q').
      reflexivity.
Qed.

Lemma amp_b_not_b : ~ denotes amp_b [lb].
Proof.
  intros [k H].
  destruct (amp_b_stage_headed k [lb] H) as (r & Hr).
  discriminate Hr.
Qed.

(* ---------------------------------------------------------------- *)
(* {ab, {a}&{b}}: a^n b^n -- closure's admission witness. Membership *)
(* samples: aabb in; aab out because every stage member has even     *)
(* length.                                                           *)
(* ---------------------------------------------------------------- *)

Definition anbn :=
  nlist [MFace [la; lb];
         MProd (FNode (nlist [MFace [la]])
                      (FAmp (FNode (nlist [MFace [lb]]) FNil)))].

Lemma anbn_has_ab : denotes anbn [la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma anbn_has_aabb : denotes anbn [la; la; lb; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma anbn_stage_even :
  forall k s, stage anbn k s -> Nat.even (length s) = true.
Proof.
  induction k as [|k IHk]; intros s H.
  - rewrite stage_zero in H. contradiction.
  - rewrite stage_succ in H. destruct H as [H|H]; [eauto|].
    cbn in H.
    destruct H
      as [[H|H]
         |(p & q & -> & [Hp|Hp]
           & (p2 & q2 & -> & Hamp
              & (p3 & q3 & -> & [Hp3|Hp3] & Hq3)))];
      try contradiction.
    + subst. reflexivity.
    + subst.
      replace (length ([la] ++ p2 ++ [lb] ++ []))
        with (S (S (length p2)))
        by (rewrite !app_length; simpl; lia).
      rewrite Nat.even_succ_succ. exact (IHk p2 Hamp).
Qed.

Lemma anbn_not_aab : ~ denotes anbn [la; la; lb].
Proof.
  intros [k H].
  assert (He := anbn_stage_even k [la; la; lb] H).
  simpl in He. discriminate He.
Qed.

(* ---------------------------------------------------------------- *)
(* {0, {1..9, &{0..9}}}: canonical numerals -- membership samples    *)
(* (first-appearance order being value order is order-axis).         *)
(* ---------------------------------------------------------------- *)

Definition numerals :=
  nlist [MFace [d0];
         MFold (nlist [MRange d1 d9;
                       MProd (FAmp (FNode (nlist [MRange d0 d9]) FNil))])].

Lemma numerals_has_0 : denotes numerals [d0].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma numerals_has_1 : denotes numerals [d1].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma numerals_has_10 : denotes numerals [d1; d0].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma numerals_has_950 : denotes numerals [d9; d5; d0].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {&} is empty; {a, &} is {a}; {a.., !{&}} is {a..}: the bare-`&`   *)
(* no-op rows, as instances of Laws.v item 10.                       *)
(* ---------------------------------------------------------------- *)

Lemma bare_amp_row : forall s, ~ denotes (nsingle MAmp) s.
Proof. exact bare_amp_empty. Qed.

Lemma self_union_row :
  forall s, denotes (NCons (MFace [la]) (nsingle MAmp)) s <-> s = [la].
Proof. intro s. apply self_union_noop. Qed.

Lemma negative_amp_row :
  forall s,
    denotes (NCons (MFinal [la]) (nsingle (MSub (nsingle MAmp)))) s
    <-> winb (final_window [la]) s = true.
Proof. intro s. apply negative_amp_noop. Qed.

Lemma negative_amp_row_has_f :
  denotes (NCons (MFinal [la]) (nsingle (MSub (nsingle MAmp)))) [lf].
Proof. apply negative_amp_row. vm_compute. reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {a, {{{},0}}&}: unguarded fill -- membership samples (the         *)
(* re-spelling/collision story is order-axis).                       *)
(* ---------------------------------------------------------------- *)

Definition unguarded_fill :=
  nlist [MFace [la];
         MProd (FNode fill (FAmp FNil))].

Lemma unguarded_fill_has_a : denotes unguarded_fill [la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma unguarded_fill_has_0a : denotes unguarded_fill [d0; la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma unguarded_fill_has_00a : denotes unguarded_fill [d0; d0; la].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* {ab, &&}: nonlinear closure -- ab, abab, ababab, ...              *)
(* ---------------------------------------------------------------- *)

Definition abab := nlist [MFace [la; lb]; MProd (FAmp (FAmp FNil))].

Lemma abab_has_ab : denotes abab [la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.

Lemma abab_has_abab : denotes abab [la; lb; la; lb].
Proof. apply containsb_sound; vm_compute; reflexivity. Qed.
