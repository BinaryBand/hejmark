# Lesson 1: The universe -- what Hejmark is about

## The wrong picture, and why it is wrong

If someone tells you "Hejmark is a pattern language," your brain immediately reaches for regular expressions. A regex like `[a-z]+` is a *predicate*: you hand it a string, it says yes or no. It is fundamentally a machine for accepting or rejecting text. Hold that picture up, look at it, and now put it down, because the mathematical floor of Hejmark -- the layer called L1 -- is not that. Nothing in L1 ever accepts or rejects anything. There is no text being matched. Matching is a real thing Hejmark does, but it lives one floor up (L1.5), and it is built *on top of* L1 the way a filesystem is built on top of a disk. L1 is the disk. It is the thing that simply *is*, before anybody asks it a question.

So what is the disk? What is the one object L1 describes?

## The one object: a pointed alphabet

L1 has exactly one kind of object, and it is called a **universe**. To build up the right picture, we need four words, and it is worth being fussy about them because the foundation document (`docs/foundation/L1.md`) is fussy about them and the whole language turns on the distinction.

- An **alphabet** is a list of abstract concepts. Not letters -- *concepts*. Think of it as an enormous virtual dictionary. Each thing in the dictionary is a distinct meaning, an idea, a semantic atom. You never see the concept directly; you only ever see how it is written down.
- An **entry** is one item in that dictionary -- one concept, one row.
- A **face** is a way of writing an entry down. This is the crucial move. One concept can have several spellings. The English word "cat" and the fancier "feline" can be two faces of a single entry: two ways to write the *same* meaning. They are not two entries that happen to be related; they are one entry wearing two masks.
- A **spelling** is a concrete string of characters -- what a face actually looks like when written out, like the four characters `c`, `a`, `t`, `s` in a row.

Here is the parable. Imagine a library where every book records one idea, and the same idea may appear on the shelf under several titles. The library is the *alphabet*. A single idea-with-its-titles is an *entry*. Each title is a *face*. And the letters printed on a particular spine are a *spelling*. Two books whose spines read differently but that record the very same idea are the same entry seen through two faces. Two books recording different ideas are different entries even if -- and this is the twist we will return to -- their spines happen to read the same.

Now the last word, the one that makes it a *universe* rather than just an alphabet:

- A **universe** is a **pointed alphabet**: the whole dictionary, plus a pointer that is currently resting on one specific entry and one specific face of that entry.

"Pointed" is a term of art from mathematics -- it just means "a set with one distinguished element singled out." A pointed alphabet is the dictionary with a finger held on one line. The finger has two coordinates: *which entry* it rests on, and *which face* of that entry it is reading. The foundation document names these two coordinates:

- **`value`** picks the entry -- which concept the finger is on. It is a position in the ordering of entries. For a small dictionary this is just a natural number ($0, 1, 2, \ldots$); for larger and stranger dictionaries it is an *ordinal*, which is lesson 3's whole topic. For now: `value` is "which row."
- **`face`** picks the spelling -- which of that entry's several faces the finger is reading. It is an index into that entry's list of faces: $0$ for the first (the **canonical** face), $1$ for the second, and so on.

The pair `<value, face>` is called the **capture**. Remember that word; when Hejmark eventually matches text and "captures" a group, this pair is literally what it captures, and it was there in the object from the very beginning, not bolted on later.

## Why bother pointing?

You might reasonably ask why the object carries a pointer at all. Why not just describe the set of entries and be done?

Because Hejmark is going to *use* these universes against text, and using them is all about the pointer. A universe as *written down on the page* leaves `value` free -- the finger is allowed to slide across every entry, so the object stands for the whole collection. When you match it against real text (that is the L1.5 story), matching pins `value` to the one entry that hit, and pins `face` to the exact spelling that appeared in the text. The written universe is a template with a sliding finger; a match freezes the finger. Building the finger into the object from the start is what lets capture be a floor-level fact rather than an add-on. It is the difference between a database schema that has a primary-key column and one where you bolt on row identifiers afterward with duct tape.

One more property of `face` worth internalizing now, because it trips people up: **`face` never changes what the object means.** Every face of an entry names the *same* concept. Reading "cat" or reading "feline" lands you on the identical row of the dictionary. So `face` "rests at 0" -- it sits on the canonical spelling by default and only moves off 0 when something specific forces it (a subtraction that strips the canonical spelling away, or a fold whose later spelling is the one that matched). The finger's row (`value`) is what ranges freely; the finger's mask (`face`) rests unless disturbed. A slogan from the foundation doc, now decodable: "face rests where value ranges."

:pencil: **Exercise.** In the library parable, describe in one sentence each: (a) a universe whose `value` ranges but whose `face` is pinned to 0, (b) what it would mean for `face` to be forced to 1. Then check yourself: (a) is any ordinary written universe -- the finger can be on any entry, but each entry is being read by its canonical title; (b) some operation removed an entry's canonical title, so the finger is now forced to read that entry by its second title instead.

## The two degenerate universes

Every good object has its zero and its one -- the empty case and the trivial case -- and getting these exactly right is where a lot of a theory's subtlety hides. L1 has both, and they are two braces apart on the page yet exact opposites in meaning. Do not skim this section; the difference between `{}` and `{{}}` is the single most common thing beginners get backwards.

### The empty universe: `{}`

The **empty universe** is the empty dictionary. No entries at all. The finger has nothing to rest on -- there is no row -- so there is no capture, no position, nothing to bind. Its "order type" (how many entries it has, counted in the ordinal sense of lesson 3) is $0$.

It is written `{}` (an empty member list) and it is also what `{a,!{a}}` comes out to (add the concept `a`, then subtract it -- you are left with nothing; we meet subtraction next lesson). It is perfectly legal and perfectly denotable. A key slogan: **emptiness is meaningless, not invalid.** L1 is happy to hand you the empty universe; it just does not *mean* anything to match against. This is the object's only form of nullability, and it is a value, not an error.

### The unit universe: `{{}}`

The **unit universe** is the sneaky one. It is *not* empty. It has exactly **one entry, wearing exactly one face, and that face is the empty spelling** -- the string of zero characters, `` (nothing between the quotes). Its order type is $1$: one entry.

Read that again. `{}` has no entry. `{{}}` has an entry that has nothing to say. The library analogy: `{}` is an empty library; `{{}}` is a library with exactly one book whose spine is blank. There is a book. You can point at it. It just has no title printed on it.

Why does this thing exist, and why is it forced rather than chosen? Because of a constructor called *fold* (next lesson), which takes a bunch of faces and quotients them onto one entry. Fold is *total* -- it never refuses -- so it has to do *something* even when you fold over nothing. What it does is yield one entry whose face is the concatenation of no characters, and the concatenation of no characters is the empty spelling. So the unit is not an axiom somebody added for convenience; it is what fold's totality *forces* at its boundary. It is also the only place the empty spelling ever comes from (you cannot type the empty spelling as a face token -- there is nothing to type), and it is the identity for the product constructor (multiplying by "one entry, no width" changes nothing), the same way $1$ is the identity for multiplication of numbers.

Here is the compact table to burn in:

| Written | Entries | Meaning | Order type |
| ------- | ------- | ------- | ---------- |
| `{}` | none | the empty universe -- nothing to point at | $0$ |
| `{{}}` | one, faced by the empty spelling | the unit -- one entry with nothing written | $1$ |

:pencil: **Exercise.** Before the next lesson, predict: what should `{{}}{cat}` denote -- the unit "times" the universe spelling `cat`? If the unit is a multiplicative identity, the answer writes itself. (It is `{cat}`. Multiplying by the unit is a no-op, exactly as multiplying a number by $1$ is. The north-star table confirms this on the `{{}}` row.)

## The one thing an entry is really about: its faces, not its spelling

We close with the idea that separates Hejmark from every string-matching tool you know, because everything downstream depends on it.

Two entries can share a spelling and stay distinct. Suppose one entry can be written `abc` (perhaps as a single face) and, in some other universe built by multiplying pieces together, another entry *also* comes out spelled `abc`. Are they the same? Not necessarily -- they are different *concepts* that happen to collide on one *string*. Something has to decide who "owns" the spelling `abc`, because you cannot have the finger ambiguously pointing at two rows when it reads those three characters. That decision is the **collision rule**, and it is settled by the capture pair: the spelling belongs to the entry with the smaller `<value, face>` address, and every later claimant simply drops that spelling from its own list of faces. If an entry loses *every* one of its faces this way, it has nothing left to be read as, and it falls out of the dictionary entirely.

You do not need to master the collision rule yet -- it gets a full treatment in lesson 3 and a whole proof file in lesson 11. Plant just this flag: **membership is about entries and their faces; a shared spelling is a collision to be adjudicated, not an identity.** The word "shortlex" you will see everywhere is simply the order used to line the spellings up so that "smaller address" has a definite meaning: shorter spellings first, and ties among equal-length spellings broken alphabetically by character code. That ordering, and why it behaves like the counting numbers $0, 1, 2, \ldots$, is the subject of the first real proof you will read (lesson 11).

## What you should now be able to say

- A Hejmark universe is a *pointed alphabet*: a dictionary of concepts (entries), each writable in one or more ways (faces), with a finger resting on one entry (`value`) and one face (`face`).
- The pair `<value, face>` is the capture, and it is native to the object.
- `value` ranges; `face` rests at 0 unless disturbed; `face` never changes meaning.
- `{}` is empty (no entry, type $0$); `{{}}` is the unit (one blank-spelled entry, type $1$); they are opposites.
- A spelling shared by two entries is a *collision*, resolved by address, not an identity.

Next: the five constructors -- the only ways to build any of this, and the single discipline they all share.
