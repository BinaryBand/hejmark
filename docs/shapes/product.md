# `Product`

Adjacency. Factors written next to each other, spelled by concatenation.

## In source

```text
{cat}{dog}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `factors` | list | Each is a [UniverseNode](universe-node.md) or a [Closure](closure.md) |

## What it means

Every combination of one entry per factor, spelled by joining their faces. `{a,b}{x,y}` gives four entries: `ax`, `ay`, `bx`, `by`.

The order is odometer order -- the **left-most factor moves slowest**, like the most significant digit of a number. So it is `ax, ay, bx, by`, not `ax, bx, ay, by`.

If a factor's entry wears several faces, the product entry wears every combination of them.

## JSON

```json
{"kind": "product", "factors": [
  {"kind": "universe", "universe": {"members": [...]}},
  {"kind": "closure"}]}
```

Each factor is tagged: a nested `universe`, or the bare `closure` token.

## Watch out

- **A spelling can split more than one way, and then the collision rule decides.** With `{a,ab}{c,bc}`, the spelling `abc` splits as `a`+`bc` or `ab`+`c`. A matcher scanning greedily will find `ab`+`c` first, but the binding is `a`+`bc` -- the lowest `<value, face>` address. Captures read the *binding*, so `$1`/`$2` can differ from the pieces the scan stepped through. If you implement an engine, this is the case to test first.
- The unit (a fold of the empty universe) is the identity: multiplying by it changes nothing.
