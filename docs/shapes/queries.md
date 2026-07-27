# Queries and their factors

## `CompiledQuery`

One query, lowered: a factor for each unit that was written.

| Field | Type | Meaning |
| --- | --- | --- |
| `source` | string | The query as written. **Diagnostics only** -- nothing executes it |
| `factors` | list | One per written unit, in order |

Match the factors in order against the text, left to right. Each factor claims a
stretch of characters, and together they must cover the whole match with no gaps
and nothing empty.

Matching is **leftmost and greedy**: start as early as possible, and at each
factor take the longest stretch that still lets the rest succeed. If the rest
fails, back off to a shorter one and try again.

Factors are numbered from **1**, left to right, which is what `{{$1}}` counts.

```json
{"kind": "query", "source": "{a}{$1}", "factors": [
  {"kind": "universe", "universe": {...}},
  {"kind": "slot", "slot": 0, "needs": [1]}]}
```

## The two kinds of factor

A factor is one of exactly two things, and the difference is whether it could be
worked out ahead of time.

### Eager -- the ordinary case

A [universe](universe-node.md) that was fully lowered at compile time. Nothing
is pending: denote it, ask whether it contains a candidate spelling, move on.

```json
{"kind": "universe", "universe": {"members": [...]}}
```

### Late slot -- the one that costs you

A factor that could **not** be lowered ahead of time, because it depends on what
an earlier factor matched.

```
{a..z}{$1}
```

"A letter, followed by that same letter."

| Field | Type | Meaning |
| --- | --- | --- |
| `slot` | integer | Which deferred unit this is |
| `needs` | list of integers | Which factors it reads, **1-based**, in written order |

It cannot become a universe until its reads are bound. Since matching binds
factors left to right, by the time this factor is tried its reads *are* bound --
so it is resolved then, once per distinct combination of read faces. Resolving
means handing the bound faces back to the compiler and receiving a plain floor
universe in return: faces out, universe in.

```json
{"kind": "slot", "slot": 0, "needs": [1]}
```

## Watch out

- `source` is a comment, effectively. Do not parse it; the factors are the
  program.
- **No zero-width matches, ever.** A factor cannot claim an empty stretch, even
  when its universe genuinely contains the empty spelling.
- **A program containing a slot is not standalone.** An engine running payloads
  from elsewhere should either arrange a channel back to the compiler, or skip
  these.
- Reads must point **strictly left**. Reading the factor itself, or one to its
  right, is refused at compile time -- nothing would be bound yet.
- Memoize slot resolution on the read faces. Two attempts agreeing on the reads
  resolve to the same universe, and re-resolving is the expensive part.
- The pieces the matcher stepped through are not always the binding the captures
  report -- see [Product](product.md).
