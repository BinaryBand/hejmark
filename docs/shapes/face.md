# `Face`

A literal spelling. The simplest thing a universe can contain.

## In source

```text
{cat}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `text` | string | The spelling, with escapes already resolved |

## What it means

One entry, wearing exactly one face: the text itself. `{cat}` matches the spelling `cat` and nothing else.

Escapes are resolved *before* this shape exists, so a `Face` never contains a backslash unless the source really meant a backslash character. By the time an engine sees one, there is nothing left to interpret.

## JSON

```json
{"kind": "face", "text": [99, 97, 116]}
```

## Watch out

- `text` is a **code-point array**, not a JSON string. `cat` is `[99, 97, 116]`.
- The empty face (`text: []`) is a real, matchable spelling in a universe -- but a *match* never accepts it, because zero-width matching is not allowed. So an empty face can exist and still never be found by a scan.
