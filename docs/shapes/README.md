# Shapes

Plain-language drafts of every data shape hejmark passes around. Two families:

- **Floor shapes** -- the five constructors and their carriers. This is what a *universe* is made of, and it is all that survives compilation.
- **Program shapes** -- what a whole compiled script looks like, so an engine can run it without seeing a line of source.

Together these are exactly what crosses the wire, so this doubles as the reading list for anyone implementing an engine in another language. The normative specs are in `docs/foundation/`; these pages are the friendly version.

## Vocabulary

Five words do all the work. Learn these and the rest reads easily.

| Word | Meaning |
| --- | --- |
| **spelling** | A string of characters. Just text -- `cat`, `a`, \`\` (empty) |
| **face** | A spelling *worn by* an entry. The same entry can wear several |
| **entry** | One member of a universe. It has an identity, and one or more faces |
| **universe** | An ordered collection of entries. A `{...}` group |
| **value order** | The order entries are declared in. Position 0, 1, 2... |

The distinction that matters most: an **entry** is a thing; a **face** is a name that thing answers to. `{{cat,feline}}` is *one* entry with *two* faces. So matching `cat` and matching `feline` find the same entry -- which is why `$0` can rewrite one into the other.

An entry's address is `<value, face>`: which entry (declaration order), and which of its faces. When two entries could claim the same spelling, the **lowest address wins**. That single rule is the collision rule, and it explains most surprises.

## Floor shapes

**Five constructors and two leaves.** The constructors are *union* -- which is
simply what a group does to its members -- plus *subtraction*, *fold*, *product*
and *closure*. [Face](face.md) and [Range](range.md) are the leaves they combine.

That is the whole floor. There is deliberately nothing else, and everything the
surface language offers expands into exactly these before it can run.

| Shape | One line |
| --- | --- |
| [UniverseNode](universe-node.md) | A `{...}` group: members in declaration order |
| [Face](face.md) | A literal spelling |
| [Range](range.md) | An inclusive character range, `{a..z}` |
| [Fold](fold.md) | A nested universe used as a member -- collapses it to one entry |
| [Subtract](subtract.md) | `!{...}` -- strips faces the inner universe spells |
| [Product](product.md) | Adjacency -- factors concatenated |
| [Closure](closure.md) | `&` -- self-reference, the only source of infinity |

## Program shapes

Four pages, nesting outward to inward: a program holds statements, statements
hold queries and templates.

| Page | Covers |
| --- | --- |
| [Program](program.md) | The compiled script, and the faces to strip on exit |
| [Statements](statements.md) | `=>` chains, and `<=>` repeat-to-a-fixpoint |
| [Queries](queries.md) | A query's factors: eager ones, and late slots |
| [Templates](templates.md) | The `"..."` side: literal text and capture reads |

## A note on JSON

Payload JSON writes spellings as **code-point arrays**, not strings: `cat` is `[99, 97, 116]`. That is not decoration -- it lets a face hold a lone surrogate, which no JSON string can carry. Names and capture spellings stay plain strings.
