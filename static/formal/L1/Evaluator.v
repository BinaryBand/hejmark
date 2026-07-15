(* L1 boolean evaluator: the same algorithm as universe.py's _contains,
   plus its soundness against the Prop denotation.

   containsb mirrors Universe.contains: closure membership is decided at
   stage (length s + 1), exactly the Python bound. Two deliberate,
   documented approximations against the Prop spec:

   - Unsettled closures: where the Python raises HimarkUnsettledError,
     the bool simply answers false at the stage bound, so containsb
     under-approximates on unsettled bodies (exactness on settled bodies
     is the deferred fixpoint theorem, see README.md).
   - The fold-to-unit boundary: denotational emptiness of a fold's body
     is not boolean-decidable (with subtraction it is a language
     difference emptiness problem), so the evaluator uses the sound
     surrogate "no adding member" (addsb = false). Sound because a node
     with only subtraction members walks every spelling to False; but
     {{a, !{a}}} is the unit in the Prop spec and in Python while
     containsb misses its empty face. This is the one gap between the
     evaluator and the spec, and it is why soundness (containsb_sound)
     carries the sndb side condition: a subtraction operand must sit in
     the exact fragment (exactb: no fold, no `&`), because under a
     subtraction the under-approximations would flip into unsoundness.

   The north-star rows all live inside sndb, so positive membership rows
   compute by vm_compute through containsb_sound. Completeness is
   deliberately not attempted: it is false on unsettled bodies and
   blocked by the addsb surrogate on emptied folds. *)

From Coq Require Import List Bool Arith Lia.
From L1 Require Import Spelling Syntax Semantics.
Import ListNotations.

Definition is_nilb (s : spelling) : bool :=
  match s with [] => true | _ => false end.

Lemma is_nilb_true_iff : forall s, is_nilb s = true <-> s = [].
Proof. destruct s; simpl; split; intro H; congruence. Qed.

(* ---------------------------------------------------------------- *)
(* The evaluator: walkb/spellsb/fsplitb mirror walk/spells/fsplit    *)
(* with bool connectives, a bounded stage search for closures, and a *)
(* bounded cut search for products (the memoless _splits).           *)
(* ---------------------------------------------------------------- *)

Fixpoint walkb (n : node) (ampb : spelling -> bool) (Pb : bool) (s : spelling)
  {struct n} : bool :=
  match n with
  | NNil => Pb
  | NCons (MSub op) rest =>
      walkb rest ampb (Pb && negb (walkb op ampb false s)) s
  | NCons m rest =>
      walkb rest ampb (Pb || spellsb m ampb s) s
  end
with spellsb (m : member) (ampb : spelling -> bool) (s : spelling)
  {struct m} : bool :=
  match m with
  | MFace t => spelling_eqb s t
  | MRange lo hi => winb (range_window lo hi) s
  | MFinal lo => winb (final_window lo) s
  | MAmp => ampb s
  | MSub _ => false
  | MFold inner =>
      if bindsb inner
      then (fix st (j : nat) (t : spelling) {struct j} : bool :=
              match j with
              | O => false
              | S j' => st j' t || walkb inner (st j') false t
              end) (S (length s)) s
      else walkb inner ampb false s || (is_nilb s && negb (addsb inner))
  | MProd fs => fsplitb fs ampb s
  end
with fsplitb (fs : factors) (ampb : spelling -> bool) (s : spelling)
  {struct fs} : bool :=
  match fs with
  | FNil => is_nilb s
  | FAmp rest =>
      existsb
        (fun k => ampb (firstn k s) && fsplitb rest ampb (skipn k s))
        (seq 0 (S (length s)))
  | FNode n rest =>
      existsb
        (fun k =>
           (if bindsb n
            then (fix st (j : nat) (t : spelling) {struct j} : bool :=
                    match j with
                    | O => false
                    | S j' => st j' t || walkb n (st j') false t
                    end) (S (length (firstn k s))) (firstn k s)
            else walkb n ampb false (firstn k s))
           && fsplitb rest ampb (skipn k s))
        (seq 0 (S (length s)))
  end.

(* The bounded closure stages, mirroring stage with bool. *)
Definition stageb (n : node) : nat -> spelling -> bool :=
  fix st (j : nat) (t : spelling) {struct j} : bool :=
    match j with
    | O => false
    | S j' => st j' t || walkb n (st j') false t
    end.

(* A product factor's membership, mirroring _factor_contains. *)
Definition fcontainsb (n : node) (ampb : spelling -> bool) (p : spelling)
  : bool :=
  if bindsb n then stageb n (S (length p)) p else walkb n ampb false p.

(* Top-level membership, mirroring Universe.contains with amp = None:
   a binder is decided at stage (length s + 1). *)
Definition containsb (n : node) (s : spelling) : bool :=
  if bindsb n then stageb n (S (length s)) s
  else walkb n (fun _ => false) false s.

(* ---------------------------------------------------------------- *)
(* Unfolding equations (all definitional).                           *)
(* ---------------------------------------------------------------- *)

Lemma walkb_cons :
  forall m rest ampb Pb s,
    walkb (NCons m rest) ampb Pb s
    = walkb rest ampb (walkb (nsingle m) ampb Pb s) s.
Proof. destruct m; reflexivity. Qed.

Lemma walkb_single_face :
  forall t ampb Pb s,
    walkb (nsingle (MFace t)) ampb Pb s = (Pb || spelling_eqb s t).
Proof. reflexivity. Qed.

Lemma walkb_single_range :
  forall lo hi ampb Pb s,
    walkb (nsingle (MRange lo hi)) ampb Pb s
    = (Pb || winb (range_window lo hi) s).
Proof. reflexivity. Qed.

Lemma walkb_single_final :
  forall lo ampb Pb s,
    walkb (nsingle (MFinal lo)) ampb Pb s
    = (Pb || winb (final_window lo) s).
Proof. reflexivity. Qed.

Lemma walkb_single_amp :
  forall ampb Pb s, walkb (nsingle MAmp) ampb Pb s = (Pb || ampb s).
Proof. reflexivity. Qed.

Lemma walkb_single_fold :
  forall inner ampb Pb s,
    walkb (nsingle (MFold inner)) ampb Pb s
    = (Pb || spellsb (MFold inner) ampb s).
Proof. reflexivity. Qed.

Lemma walkb_single_sub :
  forall op ampb Pb s,
    walkb (nsingle (MSub op)) ampb Pb s
    = (Pb && negb (walkb op ampb false s)).
Proof. reflexivity. Qed.

Lemma walkb_single_prod :
  forall fs ampb Pb s,
    walkb (nsingle (MProd fs)) ampb Pb s = (Pb || fsplitb fs ampb s).
Proof. reflexivity. Qed.

Lemma spellsb_fold :
  forall inner ampb s,
    spellsb (MFold inner) ampb s
    = if bindsb inner
      then stageb inner (S (length s)) s
      else walkb inner ampb false s || (is_nilb s && negb (addsb inner)).
Proof.
  intros inner ampb s. destruct (bindsb inner) eqn:E; simpl; rewrite E;
    reflexivity.
Qed.

Lemma fsplitb_fnil : forall ampb s, fsplitb FNil ampb s = is_nilb s.
Proof. reflexivity. Qed.

Lemma fsplitb_famp :
  forall rest ampb s,
    fsplitb (FAmp rest) ampb s
    = existsb
        (fun k => ampb (firstn k s) && fsplitb rest ampb (skipn k s))
        (seq 0 (S (length s))).
Proof. reflexivity. Qed.

Lemma fsplitb_fnode :
  forall n rest ampb s,
    fsplitb (FNode n rest) ampb s
    = existsb
        (fun k =>
           fcontainsb n ampb (firstn k s) && fsplitb rest ampb (skipn k s))
        (seq 0 (S (length s))).
Proof. intros n rest ampb s. unfold fcontainsb. reflexivity. Qed.

Lemma stageb_zero : forall n s, stageb n 0 s = false.
Proof. reflexivity. Qed.

Lemma stageb_succ :
  forall n k s,
    stageb n (S k) s = (stageb n k s || walkb n (stageb n k) false s).
Proof. reflexivity. Qed.

(* ---------------------------------------------------------------- *)
(* Cut search: the bounded split enumeration is exactly the claim    *)
(* that some decomposition s = p ++ q exists.                                        *)
(* ---------------------------------------------------------------- *)

Lemma firstn_app_len :
  forall (p q : spelling), firstn (length p) (p ++ q) = p.
Proof. induction p; intros q; simpl; congruence. Qed.

Lemma skipn_app_len :
  forall (p q : spelling), skipn (length p) (p ++ q) = q.
Proof. induction p; intros q; simpl; auto. Qed.

Lemma cuts_true_iff :
  forall (pb qb : spelling -> bool) s,
    existsb (fun k => pb (firstn k s) && qb (skipn k s))
      (seq 0 (S (length s))) = true
    <-> exists p q, s = p ++ q /\ pb p = true /\ qb q = true.
Proof.
  intros pb qb s. rewrite existsb_exists. split.
  - intros (k & _ & H). apply andb_true_iff in H as [H1 H2].
    exists (firstn k s), (skipn k s). rewrite firstn_skipn. auto.
  - intros (p & q & -> & H1 & H2).
    exists (length p). split.
    + apply in_seq. split; [lia|]. rewrite app_length. simpl. lia.
    + rewrite firstn_app_len, skipn_app_len, H1, H2. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* The exact fragment: no `&`, no fold, no binder factor. On it the  *)
(* evaluator is two-sided, which is what a subtraction operand needs *)
(* (a subtraction flips soundness into completeness).                *)
(* ---------------------------------------------------------------- *)

Fixpoint exactmb (m : member) : bool :=
  match m with
  | MFace _ => true
  | MRange _ _ => true
  | MFinal _ => true
  | MAmp => false
  | MFold _ => false
  | MSub op => exactb op
  | MProd fs => exactfb fs
  end
with exactb (n : node) : bool :=
  match n with
  | NNil => true
  | NCons m rest => exactmb m && exactb rest
  end
with exactfb (fs : factors) : bool :=
  match fs with
  | FNil => true
  | FAmp _ => false
  | FNode n rest => (exactb n && negb (bindsb n)) && exactfb rest
  end.

(* The sound fragment: `&` reads and closures are fine (soundness of a
   stage bound only needs the sound direction), folds are fine, but
   every subtraction operand must be exact.                           *)
Fixpoint sndmb (m : member) : bool :=
  match m with
  | MFace _ => true
  | MRange _ _ => true
  | MFinal _ => true
  | MAmp => true
  | MFold inner => sndb inner
  | MSub op => exactb op
  | MProd fs => sndfb fs
  end
with sndb (n : node) : bool :=
  match n with
  | NNil => true
  | NCons m rest => sndmb m && sndb rest
  end
with sndfb (fs : factors) : bool :=
  match fs with
  | FNil => true
  | FAmp rest => sndfb rest
  | FNode n rest => sndb n && sndfb rest
  end.

(* ---------------------------------------------------------------- *)
(* Two-sided correctness on the exact fragment. The amp pair is      *)
(* unconstrained because the fragment never consults it.             *)
(* ---------------------------------------------------------------- *)

Definition exact_member_stmt (m : member) : Prop :=
  exactmb m = true ->
  forall ampb amp (Pb : bool) (P : Prop) s,
    (Pb = true <-> P) ->
    (walkb (nsingle m) ampb Pb s = true <-> walk (nsingle m) amp P s).

Definition exact_node_stmt (n : node) : Prop :=
  exactb n = true ->
  forall ampb amp (Pb : bool) (P : Prop) s,
    (Pb = true <-> P) ->
    (walkb n ampb Pb s = true <-> walk n amp P s).

Definition exact_factors_stmt (fs : factors) : Prop :=
  exactfb fs = true ->
  forall ampb amp s,
    (fsplitb fs ampb s = true <-> fsplit fs amp s).

Lemma false_acc : false = true <-> False.
Proof. split; [discriminate | intros []]. Qed.

Lemma exact_correct :
  (forall m, exact_member_stmt m)
  /\ (forall n, exact_node_stmt n)
  /\ (forall fs, exact_factors_stmt fs).
Proof.
  apply syntax_mutind;
    unfold exact_member_stmt, exact_node_stmt, exact_factors_stmt.
  - (* MFace *)
    intros t _ ampb amp Pb P s Hacc.
    rewrite walkb_single_face, walk_single_face, orb_true_iff, Hacc,
      spelling_eqb_eq.
    tauto.
  - (* MRange *)
    intros lo hi _ ampb amp Pb P s Hacc.
    rewrite walkb_single_range, walk_single_range, orb_true_iff, Hacc.
    tauto.
  - (* MFinal *)
    intros lo _ ampb amp Pb P s Hacc.
    rewrite walkb_single_final, walk_single_final, orb_true_iff, Hacc.
    tauto.
  - (* MAmp *)
    intros H. discriminate.
  - (* MFold *)
    intros inner _ H. discriminate.
  - (* MSub *)
    intros op IHop Hx ampb amp Pb P s Hacc. simpl in Hx.
    rewrite walkb_single_sub, walk_single_sub, andb_true_iff,
      negb_true_iff, Hacc.
    assert (Hop := IHop Hx ampb amp false False s false_acc).
    split.
    + intros [HP Hf]. split; [exact HP|]. intro Hw.
      apply Hop in Hw. congruence.
    + intros [HP Hw]. split; [exact HP|].
      destruct (walkb op ampb false s) eqn:E; [|reflexivity].
      exfalso. apply Hw. apply Hop. reflexivity.
  - (* MProd *)
    intros fs IHfs Hx ampb amp Pb P s Hacc. simpl in Hx.
    rewrite walkb_single_prod, walk_single_prod, orb_true_iff, Hacc,
      (IHfs Hx ampb amp s).
    tauto.
  - (* NNil *)
    intros _ ampb amp Pb P s Hacc. simpl. exact Hacc.
  - (* NCons *)
    intros m IHm rest IHrest Hx ampb amp Pb P s Hacc.
    simpl in Hx. apply andb_true_iff in Hx as [Hm Hr].
    rewrite walkb_cons, walk_cons.
    exact (IHrest Hr ampb amp _ _ s (IHm Hm ampb amp Pb P s Hacc)).
  - (* FNil *)
    intros _ ampb amp s. rewrite fsplitb_fnil, fsplit_fnil,
      is_nilb_true_iff. tauto.
  - (* FAmp *)
    intros rest _ H. discriminate.
  - (* FNode *)
    intros n IHn fs IHfs Hx ampb amp s.
    simpl in Hx. apply andb_true_iff in Hx as [Hnb Hf].
    apply andb_true_iff in Hnb as [Hn Hb].
    apply negb_true_iff in Hb.
    rewrite fsplitb_fnode, cuts_true_iff, fsplit_fnode.
    split.
    + intros (p & q & Heq & H1 & H2). exists p, q. split; [exact Heq|].
      unfold fcontainsb in H1. rewrite Hb in H1.
      unfold ndenote. rewrite Hb.
      split.
      * exact (proj1 (IHn Hn ampb amp false False p false_acc) H1).
      * exact (proj1 (IHfs Hf ampb amp q) H2).
    + intros (p & q & Heq & H1 & H2). exists p, q. split; [exact Heq|].
      unfold ndenote in H1. rewrite Hb in H1.
      unfold fcontainsb. rewrite Hb.
      split.
      * exact (proj2 (IHn Hn ampb amp false False p false_acc) H1).
      * exact (proj2 (IHfs Hf ampb amp q) H2).
Qed.

(* ---------------------------------------------------------------- *)
(* Soundness on the sndb fragment.                                    *)
(* ---------------------------------------------------------------- *)

Definition sound_hyp (n : node) : Prop :=
  forall ampb amp (Pb : bool) (P : Prop) s,
    (forall t, ampb t = true -> amp t) ->
    (Pb = true -> P) ->
    walkb n ampb Pb s = true -> walk n amp P s.

(* Stage soundness follows from body soundness alone: stage k's amp is
   stage k-1, whose soundness is the induction hypothesis.            *)
Lemma stage_sound_of :
  forall n, sound_hyp n ->
  forall k s, stageb n k s = true -> stage n k s.
Proof.
  intros n Hw. induction k as [|k IHk]; intros t H.
  - rewrite stageb_zero in H. discriminate.
  - rewrite stageb_succ in H. apply orb_true_iff in H as [H|H];
      rewrite stage_succ.
    + left. apply IHk. exact H.
    + right. eapply Hw; [| |exact H].
      * intros u Hu. apply IHk. exact Hu.
      * intro Hc. discriminate.
Qed.

Definition snd_member_stmt (m : member) : Prop :=
  sndmb m = true ->
  forall ampb amp (Pb : bool) (P : Prop) s,
    (forall t, ampb t = true -> amp t) ->
    (Pb = true -> P) ->
    walkb (nsingle m) ampb Pb s = true -> walk (nsingle m) amp P s.

Definition snd_node_stmt (n : node) : Prop :=
  sndb n = true -> sound_hyp n.

Definition snd_factors_stmt (fs : factors) : Prop :=
  sndfb fs = true ->
  forall ampb amp s,
    (forall t, ampb t = true -> amp t) ->
    fsplitb fs ampb s = true -> fsplit fs amp s.

Lemma sound_correct :
  (forall m, snd_member_stmt m)
  /\ (forall n, snd_node_stmt n)
  /\ (forall fs, snd_factors_stmt fs).
Proof.
  apply syntax_mutind;
    unfold snd_member_stmt, snd_node_stmt, snd_factors_stmt, sound_hyp.
  - (* MFace *)
    intros t _ ampb amp Pb P s _ Hacc H.
    rewrite walkb_single_face in H. rewrite walk_single_face.
    apply orb_true_iff in H as [H|H]; [left; auto|].
    right. apply spelling_eqb_eq. exact H.
  - (* MRange *)
    intros lo hi _ ampb amp Pb P s _ Hacc H.
    rewrite walkb_single_range in H. rewrite walk_single_range.
    apply orb_true_iff in H as [H|H]; [left; auto | right; exact H].
  - (* MFinal *)
    intros lo _ ampb amp Pb P s _ Hacc H.
    rewrite walkb_single_final in H. rewrite walk_single_final.
    apply orb_true_iff in H as [H|H]; [left; auto | right; exact H].
  - (* MAmp *)
    intros _ ampb amp Pb P s Hamp Hacc H.
    rewrite walkb_single_amp in H. rewrite walk_single_amp.
    apply orb_true_iff in H as [H|H]; [left; auto | right; auto].
  - (* MFold *)
    intros inner IHinner Hx ampb amp Pb P s Hamp Hacc H. simpl in Hx.
    rewrite walkb_single_fold, spellsb_fold in H.
    rewrite walk_single_fold, spells_fold.
    apply orb_true_iff in H as [H|H]; [left; auto|].
    right. destruct (bindsb inner) eqn:E.
    + exists (S (length s)).
      apply (stage_sound_of inner (IHinner Hx)). exact H.
    + apply orb_true_iff in H as [H|H].
      * left. eapply (IHinner Hx); [exact Hamp | |exact H].
        intro Hc. discriminate.
      * apply andb_true_iff in H as [H1 H2].
        apply is_nilb_true_iff in H1. apply negb_true_iff in H2.
        right. split; [exact H1|].
        intros t Ht. exact (subs_only_walk inner amp t False H2 Ht).
  - (* MSub *)
    intros op _ Hx ampb amp Pb P s Hamp Hacc H. simpl in Hx.
    rewrite walkb_single_sub in H. rewrite walk_single_sub.
    apply andb_true_iff in H as [H1 H2]. apply negb_true_iff in H2.
    split; [auto|].
    intro Hw.
    destruct exact_correct as (_ & Hexact & _).
    apply (proj2 (Hexact op Hx ampb amp false False s false_acc)) in Hw.
    congruence.
  - (* MProd *)
    intros fs IHfs Hx ampb amp Pb P s Hamp Hacc H. simpl in Hx.
    rewrite walkb_single_prod in H. rewrite walk_single_prod.
    apply orb_true_iff in H as [H|H]; [left; auto|].
    right. eapply IHfs; eauto.
  - (* NNil *)
    intros _ ampb amp Pb P s _ Hacc H. simpl in H. simpl. auto.
  - (* NCons *)
    intros m IHm rest IHrest Hx ampb amp Pb P s Hamp Hacc H.
    simpl in Hx. apply andb_true_iff in Hx as [Hm Hr].
    rewrite walkb_cons in H. rewrite walk_cons.
    eapply (IHrest Hr); [exact Hamp | | exact H].
    intro Hw. eapply (IHm Hm); eauto.
  - (* FNil *)
    intros _ ampb amp s _ H.
    rewrite fsplitb_fnil in H. rewrite fsplit_fnil.
    apply is_nilb_true_iff. exact H.
  - (* FAmp *)
    intros rest IHrest Hx ampb amp s Hamp H. simpl in Hx.
    rewrite fsplitb_famp, cuts_true_iff in H. rewrite fsplit_famp.
    destruct H as (p & q & Heq & H1 & H2).
    exists p, q. split; [exact Heq|]. split; [auto|].
    eapply IHrest; eauto.
  - (* FNode *)
    intros n IHn fs IHfs Hx ampb amp s Hamp H.
    simpl in Hx. apply andb_true_iff in Hx as [Hn Hf].
    rewrite fsplitb_fnode, cuts_true_iff in H. rewrite fsplit_fnode.
    destruct H as (p & q & Heq & H1 & H2).
    exists p, q. split; [exact Heq|]. split.
    + unfold fcontainsb in H1. unfold ndenote.
      destruct (bindsb n) eqn:E.
      * exists (S (length p)).
        apply (stage_sound_of n (IHn Hn)). exact H1.
      * eapply (IHn Hn); [exact Hamp | | exact H1].
        intro Hc. discriminate.
    + eapply IHfs; eauto.
Qed.

(* ---------------------------------------------------------------- *)
(* The headline theorem: on the sound fragment, whatever containsb    *)
(* asserts, the universe denotationally wears.                        *)
(* ---------------------------------------------------------------- *)

Theorem containsb_sound :
  forall n s, sndb n = true -> containsb n s = true -> denotes n s.
Proof.
  intros n s Hs H. unfold containsb in H. unfold denotes, ndenote.
  destruct sound_correct as (_ & Hsound & _).
  destruct (bindsb n) eqn:E.
  - exists (S (length s)).
    apply (stage_sound_of n (Hsound n Hs)). exact H.
  - eapply (Hsound n Hs); [| |exact H].
    + intros t Ht. discriminate.
    + intro Hc. discriminate.
Qed.

(* ---------------------------------------------------------------- *)
(* Settledness, mirroring _settled/_settled_member/_guards: every     *)
(* free `&` is guarded by a factor with no empty face, so membership  *)
(* settles by stage (length + 1). Defined here (it needs containsb    *)
(* for the guard test) only to state the deferred fixpoint theorem;   *)
(* see README.md.                                                     *)
(* ---------------------------------------------------------------- *)

Fixpoint guarded_factorb (fs : factors) : bool :=
  match fs with
  | FNil => false
  | FAmp rest => guarded_factorb rest
  | FNode n rest => negb (containsb n []) || guarded_factorb rest
  end.

Fixpoint settled_memberb (m : member) : bool :=
  match m with
  | MAmp => false
  | MProd fs => if has_ampb fs then guarded_factorb fs else true
  | MSub inner => settledb inner
  | _ => true
  end
with settledb (n : node) : bool :=
  match n with
  | NNil => true
  | NCons m rest => settled_memberb m && settledb rest
  end.
