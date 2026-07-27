# Statements

A program is a list of these. There are two kinds: one that runs once, and one that runs until nothing changes.

## `CompiledStatement` -- steps joined by `=>`

```text
{a..z} => "X"
```

| Field | Type | Meaning |
| --- | --- | --- |
| `steps` | list | Each is a [query](queries.md) or a [template](templates.md) |

Steps chain left to right, and each kind does one thing:

- A **query** step narrows: it finds every match in what it was given, and each match continues down the chain separately.
- A **template** step builds: it produces a string that replaces what it was given, and anything interpolated into it continues down the chain.

So `{a..z} => "X"` finds each letter and replaces it with `X`. Adding a third step `=> "{{$}}"` would then work *inside* each `X` just written.

```json
{"kind": "statement", "steps": [{"kind": "query", ...}, {"kind": "template", ...}]}
```

## `CompiledIter` -- `<=>`, repeat to a fixpoint

```text
{b}{a} <=> "{{$2}}{{$1}}"
```

| Field | Type | Meaning |
| --- | --- | --- |
| `query` | [query](queries.md) | What to find |
| `template` | [template](templates.md) | What to write |

Do exactly what the equivalent `=>` statement would do, then look at the result. If the document changed, do it again. Stop when a pass produces a document identical to the one it started with.

This is how sorting works: swap any out-of-order neighbours, repeat, stop when there is nothing left to swap.

```json
{"kind": "iter", "query": {...}, "template": {...}}
```

## Watch out

- A statement that **starts** with a template is detached: it computes a string and throws it away, leaving the document untouched. That is intentional -- there is no match to anchor it to, so it cannot commit anywhere.
- A query that matches nothing leaves its input unchanged, so a query step doubles as a guard.
- **`<=>` stops on "the document did not change" -- nothing else.** A rewrite that keeps shuffling the document forever will loop forever. Nothing detects this in advance, and that is deliberate: the alternative is guessing.
