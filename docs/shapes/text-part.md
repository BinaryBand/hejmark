# `TextPart`

Literal text inside a template.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `text` | string | The characters, escapes already resolved |

## What it means

Emit it verbatim. That is all.

## JSON

```json
{"kind": "text", "text": [60, 98, 62]}
```

## Watch out

`text` is a **code-point array**, not a JSON string -- the same encoding [Face](face.md) uses, and for the same reason.
