# `Subtract`

`!{...}` -- removes faces that the inner universe spells.

## In source

```text
{a..z, !{a,e,i,o,u}}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `universe` | [UniverseNode](universe-node.md) | Whatever it spells is stripped |

## What it means

It strips **faces**, not entries. Every face contributed to its left is checked against the inner universe, and any face the inner universe spells is dropped. An entry that loses *all* of its faces disappears with them; an entry that keeps at least one survives, wearing fewer names.

Position matters: a subtraction only affects members written to its **left**.

## JSON

```json
{"kind": "subtract", "universe": {"members": [{"kind": "face", "text": [97]}]}}
```

## Watch out

- Because it works face-by-face, subtracting one face of a multi-faced entry leaves the entry in place with the remaining names. `{{cat,feline},!{feline}}` is still one entry -- now wearing only `cat`.
- **A subtraction's braces never bind `&`.** An `&` written inside one refers to the enclosing binder, not to the subtraction. This asymmetry is deliberate and is the one exception to "a brace group binds its own closure".
- Subtracting something absent is fine and changes nothing.
