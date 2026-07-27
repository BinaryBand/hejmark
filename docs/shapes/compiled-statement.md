# `CompiledStatement`

One statement: steps joined by `=>`.

## In source

```text
{a..z} => "X"
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `steps` | list | Each is a [CompiledQuery](compiled-query.md) or a [CompiledTemplate](compiled-template.md) |

## What it means

Steps chain left to right, and each kind does one thing:

- A **query** step narrows: it finds every match in what it was given, and each match continues down the chain separately.
- A **template** step builds: it produces a string that replaces what it was given, and anything interpolated into it continues down the chain.

So `{a..z} => "X"` finds each letter and replaces it with `X`. Adding a third step `=> "{{$}}"` would then work *inside* each `X` that was just written.

## JSON

```json
{"kind": "statement", "steps": [{"kind": "query", ...}, {"kind": "template", ...}]}
```

## Watch out

- A statement that **starts** with a template is detached: it computes a string and throws it away, leaving the document untouched. That is intentional, not a no-op bug -- there is no match to anchor it to, so it cannot commit anywhere.
- A query that matches nothing leaves its input unchanged, so a query step doubles as a guard.
