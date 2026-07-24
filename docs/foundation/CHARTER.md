# Himark foundation -- Charter

The normative specs (`L1`, `L1_5`, `L2`, `L3`) are one denotation seen at four depths. This charter is the law they are written under: what each may contain, and what each must cede. It binds the specs, not the language -- amend it when the layering changes, never to fit a sentence.

## Jurisdictions

Each layer denotes one stratum and documents only it. A reader of one spec needs the specs below it, never the ones above.

- **L1 -- the floor.** The five constructors and their denotation: order, reach, ceiling, collision. Total, timeless, rejects nothing.
- **L1.5 -- the surface.** The syntax that expands into the floor, its registers, and the derivations and ground-truth that show each surface form dissolving into L1. It owns matching's scope only far enough to name where it stops.
- **L2 -- the contract.** Finite execution: every operational refusal -- budget, unguarded matcher, non-settling contraction, boundary noncharacter. The only layer that says *refused*.
- **L3 -- the std.** In-language declarations over the surface: an inventory, not a derivation. The "why" is L1.5's.

Roadmap, open decisions, and history are not a layer. They live in `ROADMAP.md` (the index) and `docs/.TODO.md`. No spec cites its own future.

## Rules

1. **Denote your own stratum.** A layer explains its concern and no other. If a sentence would only make sense to a reader who has read a layer above, it is in the wrong file.

2. **Cede, don't leak.** When a concern belongs to another layer, hand it off by name -- "(L2)", "L1.5's residue" -- and stop. Ceding is a pointer, never a re-explanation and never a pre-emption of what the owning layer will say. The seam between layers is a citation, not a stretch of duplicated prose.

3. **One definition, one home.** A construct is defined in exactly one layer -- constructors in L1, declarations in L3 -- and referenced by name everywhere else. No layer restates a definition it could cite.

4. **No meta.** No roadmap, decision, deferral, or version talk in a spec: no "planned," "deferred," "today," "still moving," "re-addition," "removed," "used to." A spec is timeless; what is provisional lives in `.TODO.md`.

5. **Don't document absence.** Never tell the reader a thing is not there unless something already written in-layer would lead them to expect it. "There is no separate `numerals`" answers a question the reader never asked -- the gorilla rule: no one wondered where the `gorilla` constructor went, so no spec need say it is missing.

6. **Earn the sentence.** Prefer the derivation to the enumeration, the example to the restatement, the cited concern to the re-argued one. A sentence that only repeats a cross-reference is cut. Concision is the house style, not a later pass.

## Amending

The charter changes when the layering changes -- a stratum splits, a concern moves homes -- and under the scrutiny L1 gets, not a spec's convenience. A rule the specs keep wanting to break is a rule to reconsider here, never to violate there.
