/- L1 abstract syntax: the six constructors as one mutual inductive.

Port of `static/formal/L1/Syntax.v`, mirroring `Himark/core/syntax.py`,
except that the Python list spines (`UniverseNode.members`, `Product.factors`)
are rolled into the mutual inductive itself (`Node`, `Factors`) so structural
recursion on the spine is available to the denotation. `Range` carries single
code points; `face` carries a whole spelling. `amp` is the closure token
`&`; `sub` is the subtraction member `!{...}`; `fold` is a nested universe used
as a member; `prod` is a run of adjacent factors, each either a brace
expression (`Factors.node`) or a bare `&` (`Factors.amp`). -/
import L1.Membership.Spelling

namespace L1

mutual
inductive Member : Type where
  | face  (text : Spelling)
  | range (lo hi : Code)
  | amp
  | fold (inner : Node)
  | sub  (inner : Node)
  | prod (fs : Factors)
inductive Node : Type where
  | nil
  | cons (m : Member) (rest : Node)
inductive Factors : Type where
  | nil
  | amp  (rest : Factors)
  | node (n : Node) (rest : Factors)
end

/-- A one-member node: the building block for stating member-level laws. -/
def nsingle (m : Member) : Node := .cons m .nil

/-- Union of member lists: node append. -/
def napp : Node → Node → Node
  | .nil, n2 => n2
  | .cons m rest, n2 => .cons m (napp rest n2)

/-- Union associativity in its strongest form: structural equality. -/
theorem napp_assoc : ∀ (a b c : Node), napp (napp a b) c = napp a (napp b c)
  | .nil, _, _ => rfl
  | .cons m rest, b, c => by simp [napp, napp_assoc rest b c]

/- ---------------------------------------------------------------- -/
/- Binder detection, mirroring universe.py's _binds/_free_amp: a     -/
/- free `&` is the token itself or a literal `&` factor; it recurses -/
/- through subtraction operands but never through folds (the fold's  -/
/- own braces are the innermost binder site), and a brace factor     -/
/- with a free `&` inside binds itself.                              -/
/- ---------------------------------------------------------------- -/

def hasAmpb : Factors → Bool
  | .nil => false
  | .amp _ => true
  | .node _ rest => hasAmpb rest

mutual
def freeAmpb : Member → Bool
  | .amp => true
  | .prod fs => hasAmpb fs
  | .sub inner => bindsb inner
  | _ => false
def bindsb : Node → Bool
  | .nil => false
  | .cons m rest => freeAmpb m || bindsb rest
end

theorem bindsb_napp : ∀ (n1 n2 : Node),
    bindsb (napp n1 n2) = (bindsb n1 || bindsb n2)
  | .nil, _ => rfl
  | .cons m rest, n2 => by
      simp [napp, bindsb, bindsb_napp rest n2, Bool.or_assoc]

/- ---------------------------------------------------------------- -/
/- Top-level member-list shape predicates.                          -/
/- ---------------------------------------------------------------- -/

/-- Whether some member of the list adds faces (is not a subtraction). The
evaluator uses its negation as a sound emptiness surrogate. -/
def addsb : Node → Bool
  | .nil => false
  | .cons (.sub _) rest => addsb rest
  | .cons _ _ => true

/-- Whether the member list is subtraction-free at the top level. -/
def subfreeb : Node → Bool
  | .nil => true
  | .cons (.sub _) _ => false
  | .cons _ rest => subfreeb rest

theorem subfreeb_napp : ∀ (n1 n2 : Node),
    subfreeb n1 = true → subfreeb n2 = true → subfreeb (napp n1 n2) = true
  | .nil, _, _, h2 => h2
  | .cons m rest, n2, h1, h2 => by
      have ih := subfreeb_napp rest n2
      cases m <;> simp_all [napp, subfreeb]

end L1
