# `Program`

A whole compiled script. This is the top-level payload an engine receives, and
the only shape that is not contained in something else.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `statements` | list | [Statements](statements.md), in source order |
| `sentinels` | list of `Sentinel` | The script's declared sentinels and their characters |

## What it means

Run the statements in order, threading the document through: each one takes the
document and returns a possibly-rewritten document, which the next receives.

At the very end, strip every sentinel character from the result, so nothing
engine-private escapes to the caller.

## JSON

```json
{"format": "hejmark-program", "version": 3,
 "sentinels": [{"name": "end", "face": [64976]}],
 "statements": [{"kind": "statement", "steps": [...]}]}
```

The `format` and `version` tags are checked on decode. A payload that does not
decode is refused outright rather than repaired.

## `Sentinel`

One declared sentinel: a name, and the private character allocated to it.

```
sentinel end
```

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | As declared |
| `face` | string | The single character allocated to it |

A sentinel is a marker you can place in the document to anchor later rules --
"here is where the text ends", say -- and then match against.

The characters come from a block Unicode reserves as **noncharacters**: real
code points that no legitimate text contains. They are handed out in declaration
order, so allocation is predictable. `64976` is `U+FDD0`, the first one.

Two rules keep them private, and they are a **pair**:

- A document arriving with one of these characters already in it is **refused**
  before anything runs, so a caller cannot forge or collide with them.
- Any that remain are **stripped** from the final document, so no cleanup rule
  has to be written and nothing internal leaks out.

Implement one without the other and sentinels stop being private.

## Watch out

- A program is **pure data with one exception**: if any factor is a late slot
  (see [Queries](queries.md)), running it requires calling back into the
  compiler that produced it. Everything else is standalone.
- Statements are independent of each other; nothing is shared but the document.
- Do not assume a specific character for a given sentinel name; read the table.
