# `Sentinel`

One declared sentinel: a name, and the private character allocated to it.

## In source

```text
sentinel end
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | As declared |
| `face` | string | The single character allocated to it |

## What it means

A sentinel is a marker you can place in the document to anchor later rules -- "here is where the text ends", say -- and then match against.

The characters come from a block Unicode reserves as **noncharacters**: real code points that no legitimate text contains. They are handed out in declaration order, so allocation is predictable.

Two rules keep them private:

- A document arriving with one of these characters already in it is **refused** before anything runs, so a caller cannot forge or collide with them.
- Any that remain are **stripped** from the final document, so no cleanup rule has to be written and nothing internal leaks out.

## JSON

```json
{"name": "end", "face": [64976]}
```

`64976` is `U+FDD0`, the first noncharacter.

## Watch out

- The refusal on the way in and the strip on the way out are a pair. Implement one without the other and sentinels stop being private.
- Do not assume a specific character for a given name; read the table.
