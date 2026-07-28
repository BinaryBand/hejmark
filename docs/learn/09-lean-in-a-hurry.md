# Lesson 9: Lean in a hurry

No Hejmark in this lesson. The goal is narrow: get you from "I have never seen a proof assistant" to "I can read the proofs in `static/lean/L1/` and mostly follow what is happening." We will build the ideas in the order you need them to read those specific files.

## Why a proof assistant exists at all

You already trust your compiler to reject `let x: int = "hello"` -- that is a *type checker* enforcing a promise about your data. A proof assistant is the same machinery pushed to its limit: a type checker so expressive that the "types" can be full mathematical statements, and a "value of that type" is a *proof* of the statement. If the program type-checks, the theorem is proved -- checked mechanically, symbol by symbol, by a small trusted kernel that has no notion of "looks right to me." That is why this project bothers: a Lean proof of "membership is decidable" is not a strong argument, it is a *guarantee*, and the CI gate fails the build if any proof has a hole in it.

Lean 4 is both a programming language and this proof assistant. Mathlib is its enormous standard library of already-proved mathematics (ordinals, well-orders, lists, order isomorphisms -- everything the proofs in this tree lean on).

## The symbol legend (read this once, refer back)

The real `.lean` files use Unicode. These ASCII notes transliterate. When you open the actual files you will see the pretty forms on the right.

| ASCII here | Real Lean glyph | Means |
| ---------- | --------------- | ----- |
| `->` | the right arrow | function type, and logical "implies" |
| `forall x, P x` | the upside-down A | "for all x, P x" |
| `exists x, P x` | the backwards E | "there exists x with P x" |
| `exists! x, P x` | backwards E with bang | "there exists a *unique* x with P x" |
| `A /\ B` | the wedge | "A and B" |
| `A \/ B` | the vee | "A or B" |
| `<=`, `<` | the real symbols | order relations |
| `x-lex` | the times-with-subscript-l | *lexicographic* product of two ordered types |
| `~=r` | the tilde-equals-with-r | an *order isomorphism* between two relations |
| `Nat` | (same) | the natural numbers $0, 1, 2, \ldots$ |
| `Prop` | (same) | the type of *propositions* (statements that could be proved) |
| `Type` | (same) | the type of ordinary data types |
| the centered dot | the raised dot | a placeholder for an argument, as in `(. < .)` = "the less-than relation as a function" |

## Propositions as types: the one idea everything rests on

In Lean, a *proposition* -- a mathematical claim -- is a **type**, and a *proof* of it is a **term** (a value) of that type. This sounds abstract; it is completely concrete once you see the correspondence:

- The proposition `A -> B` ("A implies B") is the *function type* from proofs-of-`A` to proofs-of-`B`. To prove `A -> B` you write a function that, given any proof of `A`, produces a proof of `B`. Implication *is* a function.
- `A /\ B` ("A and B") is a *pair*: a proof of it is a proof of `A` bundled with a proof of `B`. You take one apart the way you destructure a tuple.
- `A \/ B` ("A or B") is a *tagged union*: a proof is either "left, here is a proof of A" or "right, here is a proof of B."
- `forall x, P x` is a *dependent function*: given any `x`, it hands back a proof of `P x`.
- `exists x, P x` is a *dependent pair*: a specific witness `x` bundled with a proof of `P x`.

So proving is programming. "Prove the theorem" means "construct a term of this type," and the kernel type-checks your term exactly as it would type-check any program. This is called the *Curry-Howard correspondence*, and if it is the only thing you take from this lesson you will still be able to read half the proofs.

Here is a tiny transliterated example -- the fact that `A and B` implies `B and A`:

```
theorem and_comm (A B : Prop) (h : A /\ B) : B /\ A :=
  And.intro h.right h.left
```

Read it as a function: it takes two propositions `A` and `B`, takes a proof `h` of `A /\ B`, and returns a proof of `B /\ A` by pairing `h`'s right half with its left half. `And.intro` is the pair constructor; `h.left` and `h.right` are the projections. That is the entire proof, and it is just data manipulation.

## Two ways to write a proof: term mode and tactic mode

The example above is *term mode*: you write the proof term directly, like an expression. It is clean for small proofs and you will see it in this tree for the one-liners (`Collision.lean`'s `value_dominates` is a single term).

For anything bigger, nobody constructs the term by hand. Instead you drop into **tactic mode** with the keyword `by`, and issue *tactics* -- commands that manipulate a *goal state*. The goal state is "here is what I still need to prove, and here are the facts I currently have." Each tactic transforms it, and when the goal is discharged, Lean assembles the underlying term for you. Reading tactic proofs is like reading a REPL session: you track how the goal shrinks.

The tactics you will meet constantly in `static/lean/L1/`:

- `intro h` -- to prove `A -> B` (or `forall x, ...`), *assume* `A` by naming its proof `h`, leaving `B` to prove. This is "move the hypothesis to the left of the turnstile."
- `exact e` -- "the term `e` is exactly a proof of the current goal." Closes the goal.
- `apply f` -- work backwards: if `f : A -> B` and the goal is `B`, reduce the goal to `A`.
- `refine e` -- like `exact` but with holes written `?_` that become new goals. You will see `refine <o, ..., ?_>` a lot: "I am building a tuple; here are some parts, prove the rest."
- `obtain <a, b, c> := h` -- destructure a hypothesis (an `exists`, an `and`) into named pieces.
- `rintro` / `rcases` -- `intro`/`cases` that destructure as they go.
- `cases h` / `induction h` -- split on the shape of a piece of data or a proof; `induction` also gives you the inductive hypothesis.
- `simp` -- the workhorse: *simplify* using a big database of known rewrite rules until the goal (hopefully) falls out. `simp only [these, lemmas]` restricts it to the listed rules, which is more predictable.
- `omega` -- a decision procedure for linear arithmetic over integers and naturals. If your goal is some true statement about `+`, `<=`, `<` on `Nat`, `omega` just closes it. The proofs in this tree offload an enormous amount of index bookkeeping to `omega`.
- `ring` -- similar, for commutative-ring identities (polynomial rearrangements like `(d+1)*p = d*p + p`).

A transliterated tactic proof, so the shape is familiar when you hit the real ones:

```
theorem le_of_lt_example (a b : Nat) (h : a < b) : a <= b := by
  omega
```

The goal starts as `a <= b` with `h : a < b` in context; `omega` recognizes this as a true arithmetic fact and closes it. Done.

## Recursion, induction, and *well-founded* recursion

To *define* a function on lists or numbers you recurse; to *prove* something about all of them you do induction, which is the same shape. Lean checks that your recursion *terminates* -- it will not accept a definition that might loop forever, because a non-terminating "proof" could prove anything.

Usual recursion shrinks a structural argument: peel one element off a list each call, and you obviously reach the empty list. But some of the proofs here recurse on something subtler -- "the value gets strictly smaller in a *well-order*" -- and that needs the key concept:

A relation is **well-founded** when there is no infinite strictly-decreasing chain -- you cannot descend forever. The naturals under `<` are well-founded: any descending sequence $n_0 > n_1 > n_2 > \cdots$ must hit $0$ and stop. This is *exactly* the property that makes ordinary induction valid, and it is the property lesson 3's ordinals were chosen to have. Lean packages it as `WellFounded r`, and Mathlib proves `wellFounded_lt` for any type whose `<` is well-founded (naturals, ordinals, and -- crucially for `Collision.lean` -- lexicographic products of well-ordered types).

The single most useful consequence, used verbatim in `Collision.lean`:

- `WellFounded.min` -- a well-founded relation has a **least element** in any nonempty set. Given a proof `wf : WellFounded r` and a nonempty set `S`, `wf.min S ne` is *the* minimal element, `wf.min_mem` proves it is in `S`, and `wf.min_le` proves everything in `S` is at least as big. This is how "the least address that spells `s`" becomes a concrete, provably-unique object: nonempty set of claimants, well-order, take the minimum.

## Order isomorphisms, and how you prove "this has order type $\omega$"

Two of the three order-axis proofs (lesson 11) work by building an **order isomorphism** -- transliterated `~=r`, Mathlib's `RelIso`. It is a bijection between two ordered sets that *preserves the order in both directions*: `x < y` on the left exactly when `f x < f y` on the right. If such a map exists, the two orders have the *same shape* -- the same order type, the same ordinal.

That is the whole strategy for proving an order-type claim. To show "shortlex over a finite alphabet has order type $\omega$," you do *not* wrestle with ordinals directly. You build an explicit order isomorphism from your ordered set onto $(\mathrm{Nat}, <)$ -- an honest function that reads each element as a number and provably respects and reflects the order -- and then invoke Mathlib's fact that $\omega$ is *by definition* the order type of $(\mathrm{Nat}, <)$. Order type is invariant under order isomorphism, so `type(your thing) = type(Nat) = omega`. The proof reduces to: define the numbering, show it is injective, show it is surjective, show it preserves `<`. That is `Order.lean` in one sentence, and `Positional.lean` does the same with `Fin (bs.prod)` -- the numbers $0$ up to a product -- on the right instead of `Nat`.

`Fin n` is worth naming: it is the type of naturals *strictly below* `n` -- a number bundled with a proof it is in range. Order isomorphism onto `Fin n` is how you say "this ordered set has exactly `n` elements in this order," i.e. order type the natural `n`.

## "Axiom-free" -- what the CI gate actually checks

You will see the phrase "honestly axiom-free" in the tree's README and its test file, and it means something specific and a little counterintuitive.

Coq (a sibling assistant) can report "this proof depends on *no* axioms at all." Lean cannot, because Lean's standard mathematics is *built on* three foundational axioms that essentially every proof touches:

- `propext` -- propositional extensionality: two propositions that imply each other are *equal*.
- `Classical.choice` -- the axiom of choice, which brings in classical logic (every proposition is true or false).
- `Quot.sound` -- the soundness of quotient types.

These three are the *trusted kernel base*. "Honestly axiom-free," in this project's sense, means: run Lean's `#print axioms theorem_name` and check that the theorem depends on *nothing beyond those three*. No `sorry` (Lean's "trust me, unproved" placeholder), no locally postulated `axiom`. The test `test_lean_headline_theorems_are_honestly_axiom_free` (`tests/infrastructure/test_lean.py`) does exactly this for every headline theorem, and a separate text scan (`test_lean_proofs_are_complete`) forbids the tokens `sorry` and `axiom` from appearing in any `.lean` file at all. There is one deliberate exception the gate excludes: proofs that use `native_decide` (which compiles a computation and trusts the compiler's answer) rest on an *extra* axiom, `Lean.ofReduceBool`, a different trust basis -- so those are kept out of the honesty gate on purpose and documented as such.

The point for you as a reader: when a theorem in this tree is on the headline list, its trustworthiness has been mechanically pinned to three well-understood axioms and nothing else. That is what all the fuss buys.

## What you should now be able to say

- A proposition is a type; a proof is a term of that type; proving is constructing that term, checked by a small kernel.
- Term mode writes the proof directly; tactic mode (`by ...`) transforms a goal state with tactics like `intro`, `exact`, `refine`, `obtain`, `simp`, `omega`, `induction`.
- A well-founded relation has no infinite descent, which validates induction and -- via `WellFounded.min` -- gives a unique least element of any nonempty set.
- You prove an order-type claim by building an order isomorphism (`~=r`) onto a known model (`Nat` for $\omega$, `Fin n` for a finite type $n$), because order type is invariant under such maps.
- "Honestly axiom-free" means the proof's axiom footprint is a subset of `{propext, Classical.choice, Quot.sound}`, with no `sorry`/`axiom` and `native_decide` proofs deliberately fenced off.

Next: with both halves in hand -- the math (Track A) and the tool (this lesson) -- we tour `static/lean/L1/` file by file and see how the mechanization is organized.
