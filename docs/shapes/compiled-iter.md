# `CompiledIter`

The contracting statement: `<=>`. Run a rewrite over and over until the document stops changing.

## In source

```text
{b}{a} <=> "{{$2}}{{$1}}"
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `query` | [CompiledQuery](compiled-query.md) | What to find |
| `template` | [CompiledTemplate](compiled-template.md) | What to write |

## What it means

Do exactly what the equivalent `=>` statement would do, then look at the result. If the document changed, do it again. Stop when a pass produces a document identical to the one it started with.

This is how sorting works: swap any out-of-order neighbours, repeat, and stop when there is nothing left to swap.

## JSON

```json
{"kind": "iter", "query": {...}, "template": {...}}
```

## Watch out

- **The stopping condition is "the document did not change" -- nothing else.** A rewrite that keeps shuffling the document forever will loop forever. Nothing detects this in advance, and that is a deliberate choice: the alternative is guessing.
- A rewrite that reproduces exactly what it matched settles on the first pass.
