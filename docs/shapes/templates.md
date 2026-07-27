# Templates and their parts

## `CompiledTemplate`

The `"..."` side of a statement, already broken into parts.

```
"<b>{{$}}</b>"
```

| Field | Type | Meaning |
| --- | --- | --- |
| `parts` | list | Literal text, capture reads and sentinel splices, in order |

Render each part in order and join them. Literal text passes through; captures
and sentinels are looked up and substituted.

Every substituted part also records *where* it landed in the finished string, so
a later step in the chain can continue working inside it.

```json
{"kind": "template", "parts": [
  {"kind": "text", "text": [60, 98, 62]},
  {"kind": "capture", "capture": "$"}]}
```

Parts are fully split at compile time. There is no template syntax left to parse
at run time -- if you find yourself scanning for `{{`, something has gone wrong.

## Text

Literal text. Emit it verbatim; that is all.

| Field | Type | Meaning |
| --- | --- | --- |
| `text` | string | The characters, escapes already resolved |

```json
{"kind": "text", "text": [60, 98, 62]}
```

`text` is a **code-point array**, not a JSON string -- the same encoding
[Face](face.md) uses, and for the same reason.

## Capture

A read of what the match bound.

| Field | Type | Meaning |
| --- | --- | --- |
| `capture` | string | Exactly `"$"`, `"$0"`, or `"$"` followed by a number |

| Written | Gives you |
| --- | --- |
| `{{$}}` | The matched text, exactly as it appeared |
| `{{$0}}` | The canonical face of the entry that was matched |
| `{{$k}}` | The face bound by factor *k*, counting from 1 |

`{{$}}` is free -- it is just the text under the span. The other two need to know
*which entry* was matched, not merely that something matched, so they look the
entry up.

The difference between `{{$}}` and `{{$0}}` is the whole point of faces: match
`feline` in `{{cat,feline}}` and `{{$}}` gives `feline` while `{{$0}}` gives
`cat`. That is how you rewrite synonyms to a preferred spelling.

```json
{"kind": "capture", "capture": "$0"}
```

## Sentinel splice

Writes a declared sentinel's character into the output.

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | The declared sentinel's name |

Look the name up in the program's sentinel table (see [Program](program.md)) and
emit the character it was given. An unknown name is an error.

```json
{"kind": "sentinel", "name": "end"}
```

## Watch out

- **All three capture forms refuse alike when no match anchors them** -- for
  instance in a template that starts a statement, where nothing was matched.
  That is an error, not an empty string.
- `$k` past the number of written factors is refused.
- `$0` and `$k` agree with each other, and both may disagree with the pieces the
  matcher stepped through -- see [Product](product.md).
- Sentinels are real characters while the script runs, so later statements can
  match them; that is what makes them useful as anchors.
