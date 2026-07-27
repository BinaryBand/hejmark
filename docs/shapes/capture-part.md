# `CapturePart`

A read of what the match bound: `{{$}}`, `{{$0}}` or `{{$k}}`.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `capture` | string | Exactly `"$"`, `"$0"`, or `"$"` followed by a number |

## What it means

| Written | Gives you |
| --- | --- |
| `{{$}}` | The matched text, exactly as it appeared |
| `{{$0}}` | The canonical face of the entry that was matched |
| `{{$k}}` | The face bound by factor *k*, counting from 1 |

`{{$}}` is free -- it is just the text under the span. The other two need to know *which entry* was matched, not merely that something matched, so they look the entry up.

The difference between `{{$}}` and `{{$0}}` is the whole point of faces: match `feline` in `{{cat,feline}}` and `{{$}}` gives `feline` while `{{$0}}` gives `cat`. That is how you rewrite synonyms to a preferred spelling.

## JSON

```json
{"kind": "capture", "capture": "$0"}
```

## Watch out

- **All three refuse alike when no match anchors them** -- for instance in a template that starts a statement, where nothing was matched. That is an error, not an empty string.
- `$k` past the number of written factors is refused.
- `$0` and `$k` agree with each other, and both may disagree with the pieces the matcher stepped through -- see [Product](product.md).
