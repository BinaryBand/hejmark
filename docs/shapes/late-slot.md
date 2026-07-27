# `LateSlot`

A factor that could **not** be lowered ahead of time, because it depends on what an earlier factor matched.

## In source

```text
{a..z}{$1}
```

"A letter, followed by that same letter."

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `slot` | integer | Which deferred unit this is |
| `needs` | list of integers | Which factors it reads, **1-based**, in written order |

## What it means

The factor cannot become a universe until its reads are bound. Since matching binds factors left to right, by the time this factor is tried its reads *are* bound -- so it is resolved then, once per distinct combination of read faces.

Resolving means handing the bound faces back to the compiler and receiving a plain floor universe in return. From the engine's side: faces out, universe in.

## JSON

```json
{"kind": "slot", "slot": 0, "needs": [1]}
```

## Watch out

- **A program containing a slot is not standalone.** Everything else in a program is data an engine can run alone; this one needs the compiler that emitted it. An engine running payloads from elsewhere should either arrange a channel back, or skip these.
- Reads must point **strictly left**. Reading the factor itself, or one to its right, is refused at compile time -- there would be nothing bound yet.
- Memoize on the read faces. Two attempts that agree on the reads resolve to the same universe, and re-resolving is the expensive part.
