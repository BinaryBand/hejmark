# Notes

- Positional value -- Because combining elements (concatenation) isn't inherently unique, the system cannot rely on raw structure alone to determine value. It uses this strict "lowest address wins" filter to purge duplicates, ensuring every valid spelling has exactly one unique mathematical owner.
- Bounded transfinitude -- In short, while combining raw patterns can theoretically cause the language's complexity to compound exponentially, the strict tie-breaker rule acts as a geometric filter. In some cases, it leaves the infinite structure intact ($\omega^2$); in highly ambiguous cases without distinct boundary markers, it aggressively flattens the structure back down to a simpler, finite-multiply sequence ($\omega \cdot k$).

## Draft: the fixpoint

<!-- Working draft: a candidate sixth constructor. Nothing above this section assumes it; the integration deltas below say what moves if it is adopted. -->

The floor has exactly one rule that runs to $\omega$: final segment, which closes the successor step over shortlex. The fixpoint generalizes it -- closure at $\omega$ of any monotone body, not just the successor -- and the special case then compresses. The motivation is recorded at the end: every generative construct the surface layers want (canonical numerals in value order, padded face families, width-driven unrollings) is one bounded or unbounded unfolding, and without this constructor each arrives as its own scoped residue.

### Statement

- Self-reference `&` -- a token legal as a product factor. It is bound to the innermost enclosing brace expression; that expression is a **fixpoint** and denotes the closure of its body, below. One anonymous `&` is the whole facility; nested fixpoints would need names, and names are L2 -- so a fixpoint inside a fixpoint's body is legal only if the inner one closes over its own `&` (the outer body sees it as a finished universe, not a binder site).
- Well-formedness, three clauses, each carrying one theorem:
  - **Positive** -- `&` never occurs inside a subtraction operand `!{...}`. Subtraction is the one anti-monotone slot; positivity makes the body a monotone map, so the least fixpoint exists.
  - **Guarded** -- every occurrence of `&` sits in a product with at least one `&`-free factor none of whose entries wears the empty spelling as a face. Each pass through `&` then lengthens every spelling, so a spelling of length $L$ settles by stage $L+1$: the unfolding is finished at $\omega$ and its order is decided at finite stages.
  - **Linear, finite escorts** -- a product contains at most one `&`, and its `&`-free factors are finite. This is the clause that keeps bounded transfinitude (below); base members -- members without `&` -- may be anything the floor denotes, infinite included.
- Semantics -- stages: $X_0$ is the empty universe, $X_{k+1}$ is the body with `&` read as $X_k$. Positivity makes the chain increasing; the fixpoint denotes its closure at $\omega$. Declaration order is **first appearance**: stage-$(k+1)$ newcomers append after everything already placed, in the order the stage-$(k+1)$ body gives them. This is not a new rule -- it is the union no-op read at $\omega$: a spelling derived again at a later stage keeps its first position and the later derivation contributes nothing, exactly as a re-declared member always has. The collision rule is likewise untouched: least `<value, face>` claims each spelling, values now assigned by first-appearance order, and every later claimant drops.

### Theorems, checked

- **Existence and productivity.** Positivity gives the increasing chain; guardedness bounds every spelling's arrival stage by its length, so $X_\omega$ is already closed under the body and is the least fixpoint. Membership stays decidable stage-free: to test a spelling, unfold to one stage past its length. (The matching consequence is L1.5's, as ever.)
- **Bounded transfinitude survives.** Let $u < \omega^m$ bound the base members' types. Linearity with finite escorts makes each stage's type at most $u \cdot c_k$ for finite $c_k$ -- a product with one `&` and finite escorts multiplies the previous stage's type by a finite on the right, and finitely many members sum -- so the first-appearance order has type at most $u \cdot \omega \le \omega^{m+1} < \omega^\omega$. The clause is load-bearing, not cautious: two `&`s in one product over an infinite base member square the stage type each unfolding ($\omega, \omega^2, \omega^4, \ldots$), and the supremum is exactly $\omega^\omega$; escorts of type $\omega$ do the same one power at a time. Relaxing linearity is not a small edit -- it is a new bound (the closure climbs toward $\epsilon_0$), and nothing below asks for it.
- **Refusal to compress -- the admission witness.** Every universe of the five-constructor floor has a regular set of faces: final segments are regular (all spellings longer than the cut, plus the same-length tail above it), fold only re-groups spellings, and union, subtraction, and product preserve regularity. `{ab, {a}&{b}}` denotes $a^n b^n$ -- ab, aabb, aaabbb, ... -- which no regular set contains, so no arrangement of the five reaches it. By the re-admission test the fixpoint enters as an axiom or not at all.

### Integration deltas, if adopted

- **Final segment demotes to compression.** Let `C` be the code-point set as a universe, one entry per code point in code-point order -- finite, so writable as a literal union in principle, which breaks the circularity of writing it as a range. Then `{{{}}, &C}` is **every spelling, in shortlex**: stage $k$ contributes the length-$(k-1)$ spellings, and within a stage, product order is code-point order digit by digit -- shorter first, ties code point by code point. The spelling order stops being a definition the object leans on and becomes the unfolding order of one fixpoint. A final segment `{w..}` is that universe minus the finitely many spellings before `w` -- a subtraction with a finite operand -- so final segment moves to the compression list, next to the bounded range it once carried. The axiom-side constructors are then fixpoint and product; the count stays at five (union, subtraction, fold, product, fixpoint).
- **Product stays axiomatic.** A linear fixpoint over finite base members has type at most $\omega$, so reaching $\omega^2$ -- `{b}{a..}{b}{a..}` -- still needs an infinite factor under product. Whether product-over-an-infinite-factor is fully independent of the fixpoint (no fixpoint-plus-finite-products expression reaches every such order) is left open below; nothing here needs the answer.
- **What the surface buys** (recorded here so the axiom's cost is priced against its work; the definitions belong to L1.5/L2):
  - Canonical numerals over any radix `D` with zero digit `z`, **in value order**: `{z, {D', &D}}` with `D'` the nonzero digits -- stage $k$ is the width-$k$ numerals, and within a width, product order most-significant-first *is* value order. This is the value line of type $\omega$ over multi-character digits too, where no shortlex carve can exist (value order and shortlex disagree there); the residue closes by generation, not by carving.
  - Width-driven unrollings (padding families, per-width window products) become bounded unfoldings of one body instead of literal-driven expansion schemes, which is what lets a later layer take widths from variables without inventing iteration of its own.

### North-star, draft rows

| Expression | Denotes |
| --- | --- |
| `{a, &{b}}` | a, ab, abb, abbb, ...  (type $\omega$; the simplest fixpoint) |
| `{{{}}, &C}` | ``, a, b, ..., aa, ab, ...  (every spelling, in shortlex: the spelling order, generated) |
| `{ab, {a}&{b}}` | ab, aabb, aaabbb, ...  (no regular face set: the admission witness) |
| `{0, {{1..9}, &{0..9}}}` | 0, 1, ..., 9, 10, ..., 99, 100, ...  (canonical decimal numerals, value order = unfolding order) |
| `{a, &}` | ill-formed  (unguarded: `&` outside any product) |
| `{a, {{{},0}}&}` | ill-formed  (the fill factor wears the empty face: no guard) |
| `{a.., !{&}}` | ill-formed  (negative occurrence) |
| `{ab, &&}` | ill-formed  (two `&` in one product) |

### Open

- Nested fixpoints -- one anonymous `&` binds to the innermost brace expression; mutually or lexically nested recursion waits for L2's names, and may never be needed.
- Relaxing linearity or finite escorts -- raises the transfinitude bound past $\omega^\omega$; scoped out until a construct asks, and none does.
- Independence of product -- believed independent (the $\omega^2$ argument above), not proven; a proof or a counterexample would settle whether the axiom side is minimal.
