# `CompiledTemplate`

The `"..."` side of a statement, broken into parts.

## In source

```text
"<b>{{$}}</b>"
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `parts` | list | [TextPart](text-part.md), [CapturePart](capture-part.md) or [SentinelPart](sentinel-part.md), in order |

## What it means

Render each part in order and join them. Literal text passes through; captures and sentinels are looked up and substituted.

Every substituted part also records *where* it landed in the finished string, so a later step in the chain can continue working inside it.

## JSON

```json
{"kind": "template", "parts": [
  {"kind": "text", "text": [60, 98, 62]},
  {"kind": "capture", "capture": "$"}]}
```

## Watch out

- Parts are already fully split at compile time. There is no template syntax left to parse at run time -- if you find yourself scanning for `{{`, something has gone wrong.
