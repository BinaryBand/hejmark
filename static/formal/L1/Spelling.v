(* L1 spelling order: codes, spellings, shortlex, and half-open windows.

   Mirrors Himark/core/order.py at the membership level. Code points are all
   of nat rather than a finite set, so the shortlex order here is a total
   order but not of order type omega (each length class is already infinite);
   the type-omega claim needs the finite code-point set and is deferred with
   the rest of the order axis (see README.md). One consequence is exact
   successors: the successor of the singleton [z] is [S z], with no rollover
   case, which is all the range constructor needs. *)

From Coq Require Import List Arith Bool Lia.
Import ListNotations.

Definition code : Type := nat.
Definition spelling : Type := list code.

(* ---------------------------------------------------------------- *)
(* Spelling equality.                                               *)
(* ---------------------------------------------------------------- *)

Fixpoint spelling_eqb (s t : spelling) : bool :=
  match s, t with
  | [], [] => true
  | a :: s', b :: t' => Nat.eqb a b && spelling_eqb s' t'
  | _, _ => false
  end.

Lemma spelling_eqb_eq : forall s t, spelling_eqb s t = true <-> s = t.
Proof.
  induction s as [|a s IH]; destruct t as [|b t]; simpl; split; intro H;
    try reflexivity; try discriminate.
  - apply andb_true_iff in H as [H1 H2].
    apply Nat.eqb_eq in H1. apply IH in H2. congruence.
  - injection H as H1 H2. subst.
    rewrite Nat.eqb_refl. simpl. apply IH. reflexivity.
Qed.

Lemma spelling_eqb_refl : forall s, spelling_eqb s s = true.
Proof. intro s. apply spelling_eqb_eq. reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* Lexicographic order on equal-length spellings (dictionary form). *)
(* ---------------------------------------------------------------- *)

Fixpoint lex_ltb (s t : spelling) : bool :=
  match s, t with
  | _, [] => false
  | [], _ :: _ => true
  | a :: s', b :: t' => (a <? b) || ((a =? b) && lex_ltb s' t')
  end.

Lemma lex_ltb_irrefl : forall s, lex_ltb s s = false.
Proof.
  induction s as [|a s IH]; simpl; [reflexivity|].
  rewrite Nat.ltb_irrefl, Nat.eqb_refl, IH. reflexivity.
Qed.

Lemma lex_ltb_trans :
  forall s t u, lex_ltb s t = true -> lex_ltb t u = true -> lex_ltb s u = true.
Proof.
  induction s as [|a s IH]; intros t u Hst Htu;
    destruct t as [|b t]; destruct u as [|c u]; simpl in *;
    try discriminate; try reflexivity.
  apply orb_true_iff in Hst as [Hst|Hst];
    apply orb_true_iff in Htu as [Htu|Htu].
  - apply Nat.ltb_lt in Hst, Htu. apply orb_true_iff. left.
    apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Htu as [Hbc _]. apply Nat.eqb_eq in Hbc.
    apply Nat.ltb_lt in Hst. apply orb_true_iff. left. apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Hst as [Hab _]. apply Nat.eqb_eq in Hab.
    apply Nat.ltb_lt in Htu. apply orb_true_iff. left. apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Hst as [Hab Hst].
    apply andb_true_iff in Htu as [Hbc Htu].
    apply Nat.eqb_eq in Hab, Hbc. subst.
    apply orb_true_iff. right. apply andb_true_iff.
    split; [apply Nat.eqb_refl | eapply IH; eauto].
Qed.

Lemma lex_ltb_total :
  forall s t, lex_ltb s t = true \/ s = t \/ lex_ltb t s = true.
Proof.
  induction s as [|a s IH]; destruct t as [|b t]; simpl.
  - right; left; reflexivity.
  - left; reflexivity.
  - right; right; reflexivity.
  - destruct (Nat.lt_trichotomy a b) as [H|[H|H]].
    + left. apply orb_true_iff. left. apply Nat.ltb_lt. exact H.
    + subst. destruct (IH t) as [H|[H|H]].
      * left. apply orb_true_iff. right.
        rewrite Nat.eqb_refl, H. reflexivity.
      * right; left. congruence.
      * right; right. apply orb_true_iff. right.
        rewrite Nat.eqb_refl, H. reflexivity.
    + right; right. apply orb_true_iff. left. apply Nat.ltb_lt. exact H.
Qed.

(* ---------------------------------------------------------------- *)
(* Shortlex: shorter first, ties broken lexicographically.          *)
(* ---------------------------------------------------------------- *)

Definition shortlex_ltb (s t : spelling) : bool :=
  (length s <? length t) || ((length s =? length t) && lex_ltb s t).

Definition shortlex_leb (s t : spelling) : bool :=
  shortlex_ltb s t || spelling_eqb s t.

Lemma shortlex_ltb_irrefl : forall s, shortlex_ltb s s = false.
Proof.
  intro s. unfold shortlex_ltb.
  rewrite Nat.ltb_irrefl, Nat.eqb_refl, lex_ltb_irrefl. reflexivity.
Qed.

Lemma shortlex_ltb_trans :
  forall s t u,
    shortlex_ltb s t = true -> shortlex_ltb t u = true ->
    shortlex_ltb s u = true.
Proof.
  intros s t u Hst Htu. unfold shortlex_ltb in *.
  apply orb_true_iff in Hst as [Hst|Hst];
    apply orb_true_iff in Htu as [Htu|Htu].
  - apply Nat.ltb_lt in Hst, Htu. apply orb_true_iff. left.
    apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Htu as [Hlen _]. apply Nat.eqb_eq in Hlen.
    apply Nat.ltb_lt in Hst. apply orb_true_iff. left. apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Hst as [Hlen _]. apply Nat.eqb_eq in Hlen.
    apply Nat.ltb_lt in Htu. apply orb_true_iff. left. apply Nat.ltb_lt. lia.
  - apply andb_true_iff in Hst as [Hlst Hst].
    apply andb_true_iff in Htu as [Hltu Htu].
    apply Nat.eqb_eq in Hlst, Hltu.
    apply orb_true_iff. right. apply andb_true_iff. split.
    + apply Nat.eqb_eq. congruence.
    + eapply lex_ltb_trans; eauto.
Qed.

Lemma shortlex_ltb_asym :
  forall s t, shortlex_ltb s t = true -> shortlex_ltb t s = true -> False.
Proof.
  intros s t Hst Hts.
  pose proof (shortlex_ltb_trans s t s Hst Hts) as H.
  rewrite shortlex_ltb_irrefl in H. discriminate.
Qed.

Lemma shortlex_total :
  forall s t, shortlex_ltb s t = true \/ s = t \/ shortlex_ltb t s = true.
Proof.
  intros s t. unfold shortlex_ltb.
  destruct (Nat.lt_trichotomy (length s) (length t)) as [H|[H|H]].
  - left. apply orb_true_iff. left. apply Nat.ltb_lt. exact H.
  - destruct (lex_ltb_total s t) as [Hl|[Hl|Hl]].
    + left. apply orb_true_iff. right.
      rewrite H, Nat.eqb_refl, Hl. reflexivity.
    + right; left. exact Hl.
    + right; right. apply orb_true_iff. right.
      rewrite H, Nat.eqb_refl, Hl. reflexivity.
  - right; right. apply orb_true_iff. left. apply Nat.ltb_lt. exact H.
Qed.

(* The connective identity: strictly-below is exactly not-at-or-above. *)
Lemma shortlex_ltb_negb_leb :
  forall s t, shortlex_ltb s t = negb (shortlex_leb t s).
Proof.
  intros s t. unfold shortlex_leb.
  destruct (shortlex_ltb s t) eqn:Hst.
  - destruct (shortlex_ltb t s) eqn:Hts.
    + exfalso. eapply shortlex_ltb_asym; eauto.
    + destruct (spelling_eqb t s) eqn:He; [|reflexivity].
      apply spelling_eqb_eq in He. subst.
      rewrite shortlex_ltb_irrefl in Hst. discriminate.
  - destruct (shortlex_total s t) as [H|[H|H]].
    + congruence.
    + subst. rewrite spelling_eqb_refl, orb_true_r. reflexivity.
    + rewrite H. reflexivity.
Qed.

Lemma shortlex_leb_refl : forall s, shortlex_leb s s = true.
Proof.
  intro s. unfold shortlex_leb. rewrite spelling_eqb_refl, orb_true_r.
  reflexivity.
Qed.

Lemma shortlex_leb_trans :
  forall s t u,
    shortlex_leb s t = true -> shortlex_leb t u = true ->
    shortlex_leb s u = true.
Proof.
  intros s t u Hst Htu. unfold shortlex_leb in *.
  apply orb_true_iff in Hst as [Hst|Hst];
    apply orb_true_iff in Htu as [Htu|Htu].
  - apply orb_true_iff. left. eapply shortlex_ltb_trans; eauto.
  - apply spelling_eqb_eq in Htu. subst. apply orb_true_iff. left. exact Hst.
  - apply spelling_eqb_eq in Hst. subst. apply orb_true_iff. left. exact Htu.
  - apply spelling_eqb_eq in Hst. subst. apply orb_true_iff. right. exact Htu.
Qed.

Lemma shortlex_leb_ltb_trans :
  forall s t u,
    shortlex_leb s t = true -> shortlex_ltb t u = true ->
    shortlex_ltb s u = true.
Proof.
  intros s t u Hst Htu. unfold shortlex_leb in Hst.
  apply orb_true_iff in Hst as [Hst|Hst].
  - eapply shortlex_ltb_trans; eauto.
  - apply spelling_eqb_eq in Hst. subst. exact Htu.
Qed.

(* Length dominance: a strictly shorter spelling is strictly below. *)
Lemma shortlex_ltb_length :
  forall s t, length s < length t -> shortlex_ltb s t = true.
Proof.
  intros s t H. unfold shortlex_ltb. apply orb_true_iff. left.
  apply Nat.ltb_lt. exact H.
Qed.

Lemma singleton_ltb : forall a b, a < b -> shortlex_ltb [a] [b] = true.
Proof.
  intros a b H. unfold shortlex_ltb. simpl.
  apply Nat.ltb_lt in H. rewrite H. reflexivity.
Qed.

Lemma singleton_leb : forall a b, a <= b -> shortlex_leb [a] [b] = true.
Proof.
  intros a b H. unfold shortlex_leb.
  destruct (Nat.eq_dec a b) as [->|Hne].
  - rewrite spelling_eqb_refl, orb_true_r. reflexivity.
  - rewrite singleton_ltb; [reflexivity | lia].
Qed.

Lemma singleton_ltb_iff : forall a b, shortlex_ltb [a] [b] = true <-> a < b.
Proof.
  intros a b. split; [|apply singleton_ltb].
  intro H. unfold shortlex_ltb in H. simpl in H.
  apply orb_true_iff in H as [H|H].
  - apply Nat.ltb_lt in H. exact H.
  - apply andb_true_iff in H as [_ H]. discriminate.
Qed.

Lemma singleton_leb_iff : forall a b, shortlex_leb [a] [b] = true <-> a <= b.
Proof.
  intros a b. split; [|apply singleton_leb].
  intro H. unfold shortlex_leb in H.
  apply orb_true_iff in H as [H|H].
  - apply singleton_ltb_iff in H. lia.
  - simpl in H. apply andb_true_iff in H as [H _]. apply Nat.eqb_eq in H.
    lia.
Qed.

(* ---------------------------------------------------------------- *)
(* Half-open shortlex windows [lo, hi); hi = None means unbounded.  *)
(* ---------------------------------------------------------------- *)

Record window : Type := mkwin { wlo : spelling; whi : option spelling }.

Definition winb (w : window) (s : spelling) : bool :=
  shortlex_leb (wlo w) s &&
  match whi w with
  | None => true
  | Some h => shortlex_ltb s h
  end.

(* The two window shapes the constructors denote: a final segment
   {lo..} is [lo, infinity); a range {lo..hi} over single code points
   is [[lo], successor [hi]) = [[lo], [S hi]) -- successors are exact
   because codes are all of nat. *)
Definition final_window (lo : spelling) : window := mkwin lo None.
Definition range_window (lo hi : code) : window := mkwin [lo] (Some [S hi]).

(* A bounded window is the difference of two final segments. *)
Lemma winb_final_diff :
  forall lo hi s,
    winb (mkwin lo None) s && negb (winb (mkwin hi None) s)
    = winb (mkwin lo (Some hi)) s.
Proof.
  intros lo hi s. unfold winb. simpl. rewrite !andb_true_r.
  rewrite (shortlex_ltb_negb_leb s hi). reflexivity.
Qed.

Lemma winb_range_diff :
  forall lo hi s,
    winb (final_window [lo]) s && negb (winb (final_window [S hi]) s)
    = winb (range_window lo hi) s.
Proof. intros lo hi s. apply winb_final_diff. Qed.

(* A reversed window is empty. *)
Lemma winb_empty :
  forall lo hi s,
    shortlex_leb hi lo = true -> winb (mkwin lo (Some hi)) s = false.
Proof.
  intros lo hi s Hrev. unfold winb. simpl.
  destruct (shortlex_leb lo s) eqn:Hlo; [|reflexivity].
  destruct (shortlex_ltb s hi) eqn:Hhi; [|reflexivity].
  exfalso.
  pose proof (shortlex_leb_ltb_trans lo s hi Hlo Hhi) as H1.
  pose proof (shortlex_leb_ltb_trans hi lo hi Hrev H1) as H2.
  rewrite shortlex_ltb_irrefl in H2. discriminate.
Qed.

Lemma winb_range_empty :
  forall lo hi s, hi < lo -> winb (range_window lo hi) s = false.
Proof.
  intros lo hi s Hrev. unfold range_window. apply winb_empty.
  apply singleton_leb. exact Hrev.
Qed.

(* The range window [ [lo], [S hi] ) holds exactly the singletons of
   the inclusive code interval: every longer spelling sits above the
   bound by length dominance. *)
Lemma winb_range_singleton :
  forall lo hi s,
    winb (range_window lo hi) s = true
    <-> exists c, s = [c] /\ lo <= c <= hi.
Proof.
  intros lo hi s. unfold range_window, winb. simpl.
  rewrite andb_true_iff. split.
  - intros [Hlo Hhi].
    destruct s as [|c [|d s]].
    + exfalso. unfold shortlex_leb, shortlex_ltb in Hlo. simpl in Hlo.
      discriminate.
    + exists c. split; [reflexivity|].
      apply singleton_leb_iff in Hlo. apply singleton_ltb_iff in Hhi. lia.
    + exfalso. unfold shortlex_ltb in Hhi. simpl in Hhi. discriminate.
  - intros [c [-> [Hlo Hhi]]]. split.
    + apply singleton_leb. exact Hlo.
    + apply singleton_ltb. lia.
Qed.
