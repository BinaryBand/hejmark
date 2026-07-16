/- L1 membership semantics: a Prop-valued structural denotation.

Port of `static/formal/L1/Semantics.v`, faithful to the membership walk of
`Himark/core/universe.py`:

- `walk` mirrors `_walk`: presence after the member list, left to right,
  threaded through the Prop accumulator `P`. A subtraction operand is walked
  fresh (accumulator `False`) with the same amp, and strips only what is
  currently present.
- `spells` mirrors `_spells`: a member's face set. Ranges and finals are
  shortlex windows; a range is the half-open window `[[lo], [hi+1])`.
- `fsplit` mirrors `_splits`: a product holds a spelling when it cuts into
  consecutive pieces, one per factor.
- A binder (a node with a free `&`) denotes the closure at omega of its body:
  `stage 0` is empty and `stage (k+1)` re-reads the body at `stage k`, so
  stages are inflationary. Membership in the closure is `∃ k, stage inner k s`.
- A non-binder fold wears its universe's spellings, plus the fold-to-unit
  boundary: it wears the empty spelling when its universe is denotationally
  empty.

Unlike the Coq port, `stage` is a member of the mutual block rather than an
inline `fix`, so `spells`/`fsplit` reference it directly and no proof ever
touches an inline stage form. The whole group is compiled by well-founded
recursion (the `stage` argument decreases on `Nat` while `walk` decreases on
the syntax), so unfolding goes through the generated equation lemmas via
`simp` rather than `rfl`. -/
import L1.Syntax

namespace L1

mutual
def walk : Node → (Spelling → Prop) → Prop → Spelling → Prop
  | .nil, _, P, _ => P
  | .cons (.sub op) rest, amp, P, s => walk rest amp (P ∧ ¬ walk op amp False s) s
  | .cons m rest, amp, P, s => walk rest amp (P ∨ spells m amp s) s
def spells : Member → (Spelling → Prop) → Spelling → Prop
  | .face t, _, s => s = t
  | .range lo hi, _, s => winb (rangeWindow lo hi) s = true
  | .final lo, _, s => winb (finalWindow lo) s = true
  | .amp, amp, s => amp s
  | .sub _, _, _ => False
  | .fold inner, amp, s =>
      if bindsb inner then (∃ k, stage inner k s)
      else walk inner amp False s ∨ (s = [] ∧ ∀ t, ¬ walk inner amp False t)
  | .prod fs, amp, s => fsplit fs amp s
def fsplit : Factors → (Spelling → Prop) → Spelling → Prop
  | .nil, _, s => s = []
  | .amp rest, amp, s => ∃ p q, s = p ++ q ∧ amp p ∧ fsplit rest amp q
  | .node n rest, amp, s =>
      ∃ p q, s = p ++ q ∧
        (if bindsb n then (∃ k, stage n k p) else walk n amp False p) ∧
        fsplit rest amp q
def stage : Node → Nat → Spelling → Prop
  | _, 0, _ => False
  | n, (k + 1), s => stage n k s ∨ walk n (stage n k) False s
end

/-- A whole universe's membership, mirroring `Universe.contains`: a binder
denotes its closure at omega, anything else its walked member list. -/
def ndenote (n : Node) (amp : Spelling → Prop) (s : Spelling) : Prop :=
  if bindsb n then (∃ k, stage n k s) else walk n amp False s

/-- Top level: a free `&` outside any binder is grammatically impossible (the
Python raises), so it reads the faithful nothing. -/
def denotes (n : Node) (s : Spelling) : Prop := ndenote n (fun _ => False) s

/- ---------------------------------------------------------------- -/
/- Unfolding equations that go through the equation lemmas.         -/
/- ---------------------------------------------------------------- -/

theorem walk_nil (amp P s) : walk .nil amp P s = P := by simp only [walk]

theorem walk_cons (m rest amp P s) :
    walk (.cons m rest) amp P s = walk rest amp (walk (nsingle m) amp P s) s := by
  cases m <;> simp [walk, nsingle]

theorem walk_single_face (t amp P s) :
    walk (nsingle (.face t)) amp P s = (P ∨ s = t) := by
  simp only [nsingle, walk, spells]

theorem walk_single_range (lo hi amp P s) :
    walk (nsingle (.range lo hi)) amp P s
      = (P ∨ winb (rangeWindow lo hi) s = true) := by
  simp only [nsingle, walk, spells]

theorem walk_single_final (lo amp P s) :
    walk (nsingle (.final lo)) amp P s
      = (P ∨ winb (finalWindow lo) s = true) := by
  simp only [nsingle, walk, spells]

theorem walk_single_amp (amp P s) :
    walk (nsingle .amp) amp P s = (P ∨ amp s) := by
  simp only [nsingle, walk, spells]

theorem walk_single_fold (inner amp P s) :
    walk (nsingle (.fold inner)) amp P s = (P ∨ spells (.fold inner) amp s) := by
  simp only [nsingle, walk]

theorem walk_single_sub (op amp P s) :
    walk (nsingle (.sub op)) amp P s = (P ∧ ¬ walk op amp False s) := by
  simp only [nsingle, walk]

theorem walk_single_prod (fs amp P s) :
    walk (nsingle (.prod fs)) amp P s = (P ∨ fsplit fs amp s) := by
  simp only [nsingle, walk, spells]

theorem spells_prod (fs amp s) : spells (.prod fs) amp s = fsplit fs amp s := by
  simp only [spells]

theorem fsplit_fnil (amp s) : fsplit .nil amp s = (s = []) := by
  simp only [fsplit]

theorem fsplit_famp (rest amp s) :
    fsplit (.amp rest) amp s
      = (∃ p q, s = p ++ q ∧ amp p ∧ fsplit rest amp q) := by
  simp only [fsplit]

theorem stage_zero (n s) : stage n 0 s = False := by simp only [stage]

theorem stage_succ (n k s) :
    stage n (k + 1) s = (stage n k s ∨ walk n (stage n k) False s) := by
  simp only [stage]

theorem spells_fold (inner amp s) :
    spells (.fold inner) amp s
      = (if bindsb inner then (∃ k, stage inner k s)
         else walk inner amp False s
              ∨ (s = [] ∧ ∀ t, ¬ walk inner amp False t)) := by
  simp only [spells]

theorem fsplit_fnode (n rest amp s) :
    fsplit (.node n rest) amp s
      = (∃ p q, s = p ++ q ∧ ndenote n amp p ∧ fsplit rest amp q) := by
  simp only [fsplit, ndenote]

/- ---------------------------------------------------------------- -/
/- The walk is monotone in its accumulator.                          -/
/- ---------------------------------------------------------------- -/

theorem walk_mono : ∀ (n : Node) (amp : Spelling → Prop) (s : Spelling) (P Q : Prop),
    (P → Q) → walk n amp P s → walk n amp Q s
  | .nil, _, _, _, _, hpq, h => by simp only [walk] at h ⊢; exact hpq h
  | .cons m rest, amp, s, P, Q, hpq, h => by
      rw [walk_cons] at h ⊢
      refine walk_mono rest amp s _ _ ?_ h
      intro hm
      cases m with
      | sub op => simp only [nsingle, walk] at hm ⊢; exact ⟨hpq hm.1, hm.2⟩
      | _ => simp only [nsingle, walk] at hm ⊢; exact hm.imp_left hpq

theorem walk_acc_iff (n amp s) (P Q : Prop) (h : P ↔ Q) :
    walk n amp P s ↔ walk n amp Q s :=
  ⟨walk_mono n amp s P Q h.mp, walk_mono n amp s Q P h.mpr⟩

/-- A member list with no adding member walks everything back to its
accumulator: subtractions only ever strip. -/
theorem subs_only_walk : ∀ (n : Node) (amp : Spelling → Prop) (s : Spelling) (P : Prop),
    addsb n = false → walk n amp P s → P
  | .nil, _, _, _, _, h => by simp only [walk] at h; exact h
  | .cons m rest, amp, s, P, hadd, h => by
      cases m with
      | sub op =>
          rw [walk_cons] at h
          have hr := subs_only_walk rest amp s _ (by simpa [addsb] using hadd) h
          simp only [nsingle, walk] at hr
          exact hr.1
      | _ => simp [addsb] at hadd

/- ---------------------------------------------------------------- -/
/- Closure stages accumulate and never retract.                      -/
/- ---------------------------------------------------------------- -/

theorem stage_mono_succ (n k s) : stage n k s → stage n (k + 1) s := by
  intro h; rw [stage_succ]; exact Or.inl h

theorem stage_mono_le (n : Node) (k m : Nat) (s : Spelling)
    (hle : k ≤ m) (h : stage n k s) : stage n m s := by
  induction hle with
  | refl => exact h
  | step _ ih => exact stage_mono_succ _ _ _ ih

end L1
