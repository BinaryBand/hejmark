# `Fold`

A nested universe used as a member. It collapses that universe into a *single* entry that wears all of its faces.

This is the shape people find surprising, and it is worth the minute.

## In source

```text
{{cat,feline}}
```

Note the doubled braces: the inner `{cat,feline}` is a universe, and wrapping it as a member of the outer group folds it.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `universe` | [UniverseNode](universe-node.md) | The group being folded |

## What it means

`{cat,feline}` is **two entries**, one wearing `cat` and one wearing `feline`.

`{{cat,feline}}` is **one entry** wearing *both* `cat` and `feline`.

The difference shows up the moment you ask for a canonical face. Match `feline` against the folded version and `$0` gives you `cat` -- the entry's first face. They are two names for one thing, so you can rewrite between them. Against the unfolded version, `feline` is simply its own entry, and `$0` is `feline`.

## JSON

```json
{"kind": "fold", "universe": {"members": [
  {"kind": "face", "text": [99, 97, 116]},
  {"kind": "face", "text": [102, 101, 108, 105, 110, 101]}]}}
```

## Watch out

- **Folding the empty universe gives you the unit** -- one entry wearing the empty spelling -- not the empty universe. `{{}}` has an entry; `{}` does not. The unit is the identity for [Product](product.md), which is why this matters.
- A group that *binds* a closure is not folded to one entry; its stages are spliced in instead. Otherwise folding would trap the `&`.
