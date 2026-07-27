# `Program`

A whole compiled script. This is the top-level payload an engine receives.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `statements` | list | [CompiledStatement](compiled-statement.md) or [CompiledIter](compiled-iter.md), in source order |
| `sentinels` | list of [Sentinel](sentinel.md) | The script's declared sentinels and their characters |

## What it means

Run the statements in order, threading the document through: each one takes the document and returns a possibly-rewritten document, which the next one receives.

At the very end, every sentinel character is stripped from the result, so nothing engine-private escapes to the caller.

## JSON

```json
{"format": "hejmark-program", "version": 3,
 "sentinels": [{"name": "end", "face": [64976]}],
 "statements": [{"kind": "statement", "steps": [...]}]}
```

The `format` and `version` tags are checked on decode. A payload that does not decode is refused outright rather than repaired.

## Watch out

- A program is **pure data with one exception**: if any factor is a [LateSlot](late-slot.md), running it requires calling back into the compiler that produced it. Everything else is standalone.
- Statements are independent of each other; nothing is shared but the document.
