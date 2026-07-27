# `CompiledQuery`

One query, lowered: a factor for each unit that was written.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `source` | string | The query as written. **Diagnostics only** -- nothing executes it |
| `factors` | list | [EagerFactor](eager-factor.md) or [LateSlot](late-slot.md), in written order |

## What it means

Match the factors in order against the text, left to right. Each factor claims a stretch of characters, and together they must cover the whole match with no gaps and nothing empty.

Matching is **leftmost and greedy**: start as early as possible, and at each factor take the longest stretch that still lets the rest succeed. If the rest fails, back off to a shorter one and try again.

## JSON

```json
{"kind": "query", "source": "{a}{$1}", "factors": [
  {"kind": "universe", "universe": {...}},
  {"kind": "slot", "slot": 0, "needs": [1]}]}
```

## Watch out

- `source` is a comment, effectively. Do not parse it; the factors are the program.
- **No zero-width matches, ever.** A factor cannot claim an empty stretch, even when its universe genuinely contains the empty spelling.
- The pieces the matcher stepped through are not always the binding the captures report -- see [Product](product.md).
