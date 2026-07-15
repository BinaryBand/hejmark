(* L1 membership laws: the compression laws and constructor identities
   of docs/foundation/L1_TEMP.md, proved at the membership level.

   Everything here is about which spellings a universe wears. The order
   axis (entry order, collision ownership, positional value) is out of
   scope -- see README.md. In particular the doc's "union is not
   commutative" is a statement about entry order; at the membership
   level union is a commutative, idempotent, associative join, and that
   is what items 2a-2c say. *)

From Coq Require Import List Bool Arith.
From L1 Require Import Spelling Syntax Semantics.
Import ListNotations.

(* ---------------------------------------------------------------- *)
(* 1. Walk decomposition: the walk is a left fold, so union composes *)
(*    accumulators.                                                  *)
(* ---------------------------------------------------------------- *)

Lemma walk_app :
  forall n1 n2 amp P s,
    walk (napp n1 n2) amp P s = walk n2 amp (walk n1 amp P s) s.
Proof.
  induction n1 as [|m rest IH]; intros n2 amp P s.
  - reflexivity.
  - simpl napp. rewrite walk_cons, IH, (walk_cons m rest). reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* 2. Union: associative (napp_assoc, structural equality), and on   *)
(*    subtraction-free member lists idempotent and commutative at    *)
(*    the membership level.                                          *)
(* ---------------------------------------------------------------- *)

(* The spellings some member of a subtraction-free list wears. *)
Fixpoint anyspell (n : node) (amp : spelling -> Prop) (s : spelling) : Prop :=
  match n with
  | NNil => False
  | NCons m rest => spells m amp s \/ anyspell rest amp s
  end.

Lemma walk_adds :
  forall n amp P s,
    subfreeb n = true -> (walk n amp P s <-> P \/ anyspell n amp s).
Proof.
  induction n as [|m rest IH]; intros amp P s Hsf; simpl in *.
  - tauto.
  - destruct m; try discriminate;
      rewrite (IH amp _ s Hsf); tauto.
Qed.

Lemma union_idem :
  forall n amp P s,
    subfreeb n = true -> (walk (napp n n) amp P s <-> walk n amp P s).
Proof.
  intros n amp P s Hsf. rewrite walk_app.
  rewrite !(walk_adds _ _ _ _ Hsf). tauto.
Qed.

Lemma union_comm :
  forall n1 n2 amp P s,
    subfreeb n1 = true -> subfreeb n2 = true ->
    (walk (napp n1 n2) amp P s <-> walk (napp n2 n1) amp P s).
Proof.
  intros n1 n2 amp P s H1 H2. rewrite !walk_app.
  rewrite (walk_adds n2 _ _ _ H2), (walk_adds n1 _ _ _ H1),
          (walk_adds n1 _ _ _ H1), (walk_adds n2 _ _ _ H2).
  tauto.
Qed.

Lemma denotes_union_idem :
  forall n s,
    subfreeb n = true -> bindsb n = false ->
    (denotes (napp n n) s <-> denotes n s).
Proof.
  intros n s Hsf Hb. unfold denotes, ndenote.
  rewrite bindsb_napp, Hb. simpl.
  apply union_idem. exact Hsf.
Qed.

(* ---------------------------------------------------------------- *)
(* 3. Difference: appending a subtraction is set difference.         *)
(* ---------------------------------------------------------------- *)

Lemma difference :
  forall A B amp P s,
    walk (napp A (nsingle (MSub B))) amp P s
    <-> walk A amp P s /\ ~ walk B amp False s.
Proof.
  intros A B amp P s. rewrite walk_app. simpl. tauto.
Qed.

(* ---------------------------------------------------------------- *)
(* 4. Intersection: A /\ B = A \ (A \ B). Stated with an explicit    *)
(*    decidability hypothesis on B's membership rather than classical *)
(*    logic; the hypothesis holds on the settled fragment, and the    *)
(*    doc's set-theoretic reading is classical anyway.                *)
(* ---------------------------------------------------------------- *)

Lemma intersection :
  forall A B amp s,
    (walk B amp False s \/ ~ walk B amp False s) ->
    (walk (napp A (nsingle (MSub (napp A (nsingle (MSub B)))))) amp False s
     <-> walk A amp False s /\ walk B amp False s).
Proof.
  intros A B amp s Hdec.
  rewrite difference. rewrite (difference A B). tauto.
Qed.

(* ---------------------------------------------------------------- *)
(* 5. Bounded ranges are compression: {lo..hi} = {lo.., !{succ hi..}}. *)
(*    A reversed range is empty.                                      *)
(* ---------------------------------------------------------------- *)

Lemma range_compression :
  forall lo hi amp s,
    walk (NCons (MFinal [lo]) (nsingle (MSub (nsingle (MFinal [S hi]))))) amp
      False s
    <-> spells (MRange lo hi) amp s.
Proof.
  intros lo hi amp s.
  change (NCons (MFinal [lo]) (nsingle (MSub (nsingle (MFinal [S hi])))))
    with (napp (nsingle (MFinal [lo]))
               (nsingle (MSub (nsingle (MFinal [S hi]))))).
  rewrite difference. cbn [walk spells nsingle].
  rewrite <- (winb_range_diff lo hi s).
  rewrite andb_true_iff, negb_true_iff.
  split.
  - intros [[H|Hlo] Hnot]; [contradiction|].
    split; [exact Hlo|].
    destruct (winb (final_window [S hi]) s) eqn:E; [|reflexivity].
    exfalso. apply Hnot. right. reflexivity.
  - intros [Hlo Hhi]. split; [right; exact Hlo|].
    intros [H|H]; [exact H|]. rewrite Hhi in H. discriminate.
Qed.

Lemma range_reversed_empty :
  forall lo hi amp s, hi < lo -> ~ spells (MRange lo hi) amp s.
Proof.
  intros lo hi amp s Hrev H. simpl in H.
  rewrite winb_range_empty in H; [discriminate | exact Hrev].
Qed.

(* ---------------------------------------------------------------- *)
(* 6. Finite adjacency: {t1}{t2} = {t1 ++ t2}.                        *)
(* ---------------------------------------------------------------- *)

Lemma adjacency :
  forall t1 t2 amp s,
    spells
      (MProd (FNode (nsingle (MFace t1)) (FNode (nsingle (MFace t2)) FNil)))
      amp s
    <-> spells (MFace (t1 ++ t2)) amp s.
Proof.
  intros t1 t2 amp s. simpl. split.
  - intros (p & q & -> & [Hp|Hp] & (p' & q' & -> & [Hp'|Hp'] & Hq'));
      try contradiction. subst. rewrite app_nil_r. reflexivity.
  - intro H. simpl in H. subst.
    exists t1, (t2 ++ []). rewrite app_nil_r. split; [reflexivity|].
    split; [right; reflexivity|].
    exists t2, []. rewrite app_nil_r.
    repeat split. right; reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* 7. The empty universe and the unit.                                *)
(* ---------------------------------------------------------------- *)

Lemma empty_denotes : forall s, ~ denotes NNil s.
Proof. intros s H. exact H. Qed.

Lemma unit_spells : forall amp s, spells (MFold NNil) amp s <-> s = [].
Proof.
  intros amp s. simpl. split.
  - intros [H|[H _]]; [contradiction|exact H].
  - intro H. right. split; [exact H|]. intros t Ht. exact Ht.
Qed.

Definition unit_node : node := nsingle (MFold NNil).

Lemma unit_ndenote : forall amp p, ndenote unit_node amp p <-> p = [].
Proof.
  intros amp p. unfold ndenote. simpl. split.
  - intros [H|[H|[Hp _]]]; try contradiction. exact Hp.
  - intro H. right; right. split; [exact H|]. intros t Ht. exact Ht.
Qed.

Lemma product_unit_l :
  forall A amp s,
    bindsb A = false ->
    (spells (MProd (FNode unit_node (FNode A FNil))) amp s
     <-> walk A amp False s).
Proof.
  intros A amp s Hb.
  rewrite spells_prod, (fsplit_fnode unit_node). split.
  - intros (p & q & -> & Hp & Hq).
    apply unit_ndenote in Hp. subst p. simpl.
    rewrite fsplit_fnode in Hq.
    destruct Hq as (p' & q' & -> & Hp' & Hq').
    simpl in Hq'. subst q'.
    unfold ndenote in Hp'. rewrite Hb in Hp'.
    rewrite app_nil_r. exact Hp'.
  - intro H. exists [], s. split; [reflexivity|]. split.
    + apply unit_ndenote. reflexivity.
    + rewrite fsplit_fnode. exists s, []. rewrite app_nil_r.
      split; [reflexivity|]. split; [|reflexivity].
      unfold ndenote. rewrite Hb. exact H.
Qed.

Lemma product_unit_r :
  forall A amp s,
    bindsb A = false ->
    (spells (MProd (FNode A (FNode unit_node FNil))) amp s
     <-> walk A amp False s).
Proof.
  intros A amp s Hb.
  rewrite spells_prod, (fsplit_fnode A). split.
  - intros (p & q & -> & Hp & Hq).
    rewrite fsplit_fnode in Hq.
    destruct Hq as (p' & q' & -> & Hp' & Hq').
    simpl in Hq'. subst q'.
    apply unit_ndenote in Hp'. subst p'.
    unfold ndenote in Hp. rewrite Hb in Hp.
    rewrite !app_nil_r. exact Hp.
  - intro H. exists s, []. rewrite app_nil_r. split; [reflexivity|]. split.
    + unfold ndenote. rewrite Hb. exact H.
    + rewrite fsplit_fnode. exists [], []. simpl.
      split; [reflexivity|]. split; [|reflexivity].
      apply unit_ndenote. reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* 8. Fold membership, and depth flattening on the doc's shapes.      *)
(* ---------------------------------------------------------------- *)

Lemma fold_membership :
  forall inner amp s,
    bindsb inner = false ->
    (spells (MFold inner) amp s
     <-> walk inner amp False s
         \/ (s = [] /\ forall t, ~ walk inner amp False t)).
Proof.
  intros inner amp s Hb. rewrite spells_fold, Hb. tauto.
Qed.

(* A fold of a fold splices: {{X}} wears what {X} wears, for a
   non-binder X. (For a binder X the two can differ: the fold of an
   empty closure is empty, while the fold of THAT fold is the unit.) *)
Lemma fold_flatten :
  forall inner amp s,
    bindsb inner = false ->
    (spells (MFold (nsingle (MFold inner))) amp s
     <-> spells (MFold inner) amp s).
Proof.
  intros inner amp s Hb.
  assert (Houter : bindsb (nsingle (MFold inner)) = false) by reflexivity.
  rewrite (fold_membership (nsingle (MFold inner)) amp s Houter).
  split.
  - intros [H|[_ Hempty]].
    + rewrite walk_single_fold in H. destruct H as [H|H];
        [contradiction | exact H].
    + exfalso.
      assert (Hnil : ~ walk (nsingle (MFold inner)) amp False [])
        by apply Hempty.
      rewrite walk_single_fold in Hnil.
      apply Hnil. right.
      rewrite (fold_membership inner amp [] Hb).
      right. split; [reflexivity|].
      intros t Ht.
      apply (Hempty t). rewrite walk_single_fold. right.
      rewrite (fold_membership inner amp t Hb). left. exact Ht.
  - intro H. left. rewrite walk_single_fold. right. exact H.
Qed.

(* Items 9 (stage monotonicity) live in Semantics.v: stage_mono_succ
   and stage_mono_le say accumulation never retracts.                *)

(* ---------------------------------------------------------------- *)
(* 10. Bare-`&` no-ops, as general equivalences.                      *)
(* ---------------------------------------------------------------- *)

(* {&}: a bare self-reference builds nothing. *)
Lemma bare_amp_empty : forall s, ~ denotes (nsingle MAmp) s.
Proof.
  assert (Hstage : forall k s, ~ stage (nsingle MAmp) k s).
  { induction k; intros s H; simpl in H.
    - exact H.
    - destruct H as [H|[H|H]]; [eapply IHk; eauto | exact H | eapply IHk; eauto]. }
  intros s [k H]. eapply Hstage; eauto.
Qed.

(* {a, &}: self-union no-ops, as union always has. *)
Lemma self_union_noop :
  forall t s, denotes (NCons (MFace t) (nsingle MAmp)) s <-> s = t.
Proof.
  intro t.
  set (n := NCons (MFace t) (nsingle MAmp)).
  assert (Hstage : forall k s, stage n k s -> s = t).
  { induction k; intros s H; simpl in H.
    - contradiction.
    - destruct H as [H|[[H|H]|H]];
        solve [apply IHk; exact H | contradiction | exact H]. }
  intro s. split.
  - intros [k H]. eapply Hstage; eauto.
  - intro H. exists 1. simpl. right. left. right. exact H.
Qed.

(* {lo.., !{&}}: stage 1 places the whole final segment, every later
   body is empty -- no oscillation, and the closure is just {lo..}. *)
Lemma negative_amp_noop :
  forall lo s,
    denotes (NCons (MFinal lo) (nsingle (MSub (nsingle MAmp)))) s
    <-> winb (final_window lo) s = true.
Proof.
  intro lo.
  set (n := NCons (MFinal lo) (nsingle (MSub (nsingle MAmp)))).
  assert (Hstage : forall k s, stage n k s -> winb (final_window lo) s = true).
  { induction k; intros s H; simpl in H.
    - contradiction.
    - destruct H as [H|[[H|H] _]];
        solve [apply IHk; exact H | contradiction | exact H]. }
  intro s. split.
  - intros [k H]. eapply Hstage; eauto.
  - intro H. exists 1. simpl. right. split; [right; exact H|]. tauto.
Qed.
