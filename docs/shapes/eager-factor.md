# `EagerFactor`

A factor that was fully lowered at compile time. The ordinary case.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `node` | [UniverseNode](universe-node.md) | The floor form, ready to use |

## What it means

Nothing is pending. Denote the node, ask it whether it contains a candidate spelling, and move on. Every factor is one of these unless it back-references another factor.

## JSON

```json
{"kind": "universe", "universe": {"members": [...]}}
```

## Watch out

Nothing surprising. This is the shape you want; [LateSlot](late-slot.md) is the one that costs you.
