(* L1 membership semantics: a Prop-valued structural denotation.

   Faithful to the membership walk of Himark/core/universe.py:

   - walk mirrors _walk: presence after the member list, left to right,
     threaded through the Prop accumulator P. A subtraction operand is
     walked fresh (accumulator False) with the same amp, and strips only
     what is currently present; adding members re-add what a subtraction
     to their left stripped.
   - spells mirrors _spells: a member's face set. Ranges and finals are
     shortlex windows; a range is the half-open window [[lo], [S hi]).
   - fsplit mirrors _splits: a product holds a spelling when it cuts
     into consecutive pieces, one per factor; an FAmp piece reads amp,
     an FNode piece reads the factor's full universe membership.
   - A binder (a node with a free `&`) denotes the closure at omega of
     its body: stage 0 is empty and stage (S k) re-reads the body at
     stage k, so stages are inflationary by construction. Membership in
     the closure is (exists k, stage k) -- Python decides this at stage
     length + 1 and raises on unsettled bodies; the Prop denotation is
     the total, unbounded truth it approximates.
   - A non-binder fold wears its universe's spellings, plus the fold-to-
     unit boundary: it wears the empty spelling when its universe is
     denotationally empty. A binder fold splices its closure instead,
     and an empty closure contributes nothing.
   - For a binder node the outer amp is dead (every free `&` inside
     reads the binder's own stages, the innermost binder); the model
     drops it where the Python threads it inert.

   The closure stages for nested binders (a binder used as a fold or as
   a product factor) appear as inline fixes inside the mutual Fixpoint;
   spells_fold and fsplit_fnode below restate them via the top-level
   stage/ndenote so no proof ever touches the inline form. *)

From Coq Require Import List Bool Arith.
From L1 Require Import Spelling Syntax.
Import ListNotations.

Fixpoint walk (n : node) (amp : spelling -> Prop) (P : Prop) (s : spelling)
  {struct n} : Prop :=
  match n with
  | NNil => P
  | NCons (MSub op) rest =>
      walk rest amp (P /\ ~ walk op amp False s) s
  | NCons m rest =>
      walk rest amp (P \/ spells m amp s) s
  end
with spells (m : member) (amp : spelling -> Prop) (s : spelling)
  {struct m} : Prop :=
  match m with
  | MFace t => s = t
  | MRange lo hi => winb (range_window lo hi) s = true
  | MFinal lo => winb (final_window lo) s = true
  | MAmp => amp s
  | MSub _ => False
  | MFold inner =>
      if bindsb inner
      then exists k,
             (fix st (j : nat) (t : spelling) {struct j} : Prop :=
                match j with
                | O => False
                | S j' => st j' t \/ walk inner (st j') False t
                end) k s
      else walk inner amp False s
           \/ (s = [] /\ forall t, ~ walk inner amp False t)
  | MProd fs => fsplit fs amp s
  end
with fsplit (fs : factors) (amp : spelling -> Prop) (s : spelling)
  {struct fs} : Prop :=
  match fs with
  | FNil => s = []
  | FAmp rest =>
      exists p q, s = p ++ q /\ amp p /\ fsplit rest amp q
  | FNode n rest =>
      exists p q, s = p ++ q
        /\ (if bindsb n
            then exists k,
                   (fix st (j : nat) (t : spelling) {struct j} : Prop :=
                      match j with
                      | O => False
                      | S j' => st j' t \/ walk n (st j') False t
                      end) k p
            else walk n amp False p)
        /\ fsplit rest amp q
  end.

(* The closure stages of a binder body: X_0 empty, X_{k+1} the body
   re-read at X_k, accumulated -- inflationary by construction. *)
Definition stage (n : node) : nat -> spelling -> Prop :=
  fix st (j : nat) (t : spelling) {struct j} : Prop :=
    match j with
    | O => False
    | S j' => st j' t \/ walk n (st j') False t
    end.

(* A whole universe's membership, mirroring Universe.contains: a binder
   denotes its closure at omega, anything else its walked member list. *)
Definition ndenote (n : node) (amp : spelling -> Prop) (s : spelling) : Prop :=
  if bindsb n then exists k, stage n k s else walk n amp False s.

(* Top level: a free `&` outside any binder is grammatically impossible
   (the Python raises), so it reads the faithful nothing. *)
Definition denotes (n : node) (s : spelling) : Prop :=
  ndenote n (fun _ => False) s.

(* ---------------------------------------------------------------- *)
(* Unfolding equations that hide the inline stage fixes.            *)
(* ---------------------------------------------------------------- *)

Lemma walk_cons :
  forall m rest amp P s,
    walk (NCons m rest) amp P s
    = walk rest amp (walk (nsingle m) amp P s) s.
Proof. destruct m; reflexivity. Qed.

Lemma walk_single_face :
  forall t amp P s, walk (nsingle (MFace t)) amp P s = (P \/ s = t).
Proof. reflexivity. Qed.

Lemma walk_single_range :
  forall lo hi amp P s,
    walk (nsingle (MRange lo hi)) amp P s
    = (P \/ winb (range_window lo hi) s = true).
Proof. reflexivity. Qed.

Lemma walk_single_final :
  forall lo amp P s,
    walk (nsingle (MFinal lo)) amp P s
    = (P \/ winb (final_window lo) s = true).
Proof. reflexivity. Qed.

Lemma walk_single_amp :
  forall amp P s, walk (nsingle MAmp) amp P s = (P \/ amp s).
Proof. reflexivity. Qed.

Lemma walk_single_fold :
  forall inner amp P s,
    walk (nsingle (MFold inner)) amp P s = (P \/ spells (MFold inner) amp s).
Proof. reflexivity. Qed.

Lemma walk_single_sub :
  forall op amp P s,
    walk (nsingle (MSub op)) amp P s = (P /\ ~ walk op amp False s).
Proof. reflexivity. Qed.

Lemma walk_single_prod :
  forall fs amp P s,
    walk (nsingle (MProd fs)) amp P s = (P \/ fsplit fs amp s).
Proof. reflexivity. Qed.

Lemma spells_prod :
  forall fs amp s, spells (MProd fs) amp s = fsplit fs amp s.
Proof. reflexivity. Qed.

Lemma fsplit_fnil : forall amp s, fsplit FNil amp s = (s = []).
Proof. reflexivity. Qed.

Lemma fsplit_famp :
  forall rest amp s,
    fsplit (FAmp rest) amp s
    = (exists p q, s = p ++ q /\ amp p /\ fsplit rest amp q).
Proof. reflexivity. Qed.

Lemma stage_zero : forall n s, stage n 0 s = False.
Proof. reflexivity. Qed.

Lemma stage_succ :
  forall n k s,
    stage n (S k) s = (stage n k s \/ walk n (stage n k) False s).
Proof. reflexivity. Qed.

Lemma spells_fold :
  forall inner amp s,
    spells (MFold inner) amp s
    = if bindsb inner
      then exists k, stage inner k s
      else walk inner amp False s
           \/ (s = [] /\ forall t, ~ walk inner amp False t).
Proof. intros inner amp s. simpl. destruct (bindsb inner); reflexivity. Qed.

Lemma fsplit_fnode :
  forall n rest amp s,
    fsplit (FNode n rest) amp s
    = exists p q, s = p ++ q /\ ndenote n amp p /\ fsplit rest amp q.
Proof.
  intros n rest amp s. simpl. unfold ndenote.
  destruct (bindsb n); reflexivity.
Qed.

(* ---------------------------------------------------------------- *)
(* The walk is monotone in its accumulator.                          *)
(* ---------------------------------------------------------------- *)

Lemma walk_mono :
  forall n amp s (P Q : Prop),
    (P -> Q) -> walk n amp P s -> walk n amp Q s.
Proof.
  induction n as [|m rest IH]; intros amp s P Q HPQ H; simpl in *.
  - auto.
  - destruct m; try (eapply IH; [|exact H]; tauto).
Qed.

Lemma walk_acc_iff :
  forall n amp s (P Q : Prop),
    (P <-> Q) -> (walk n amp P s <-> walk n amp Q s).
Proof.
  intros n amp s P Q H. split; apply walk_mono; tauto.
Qed.

(* A member list with no adding member walks everything back to its
   accumulator: subtractions only ever strip. *)
Lemma subs_only_walk :
  forall n amp s (P : Prop),
    addsb n = false -> walk n amp P s -> P.
Proof.
  induction n as [|m rest IH]; intros amp s P Hadds H; simpl in *.
  - exact H.
  - destruct m; try discriminate.
    apply IH in H; tauto.
Qed.

(* ---------------------------------------------------------------- *)
(* Closure stages accumulate and never retract.                      *)
(* ---------------------------------------------------------------- *)

Lemma stage_mono_succ :
  forall n k s, stage n k s -> stage n (S k) s.
Proof. intros n k s H. simpl. left. exact H. Qed.

Lemma stage_mono_le :
  forall n k m s, k <= m -> stage n k s -> stage n m s.
Proof.
  intros n k m s Hle H. induction Hle.
  - exact H.
  - apply stage_mono_succ. exact IHHle.
Qed.
