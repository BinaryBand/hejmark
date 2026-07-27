# `UniverseNode`

A brace group -- `{...}` -- holding its members in the order they were written.

This is the only container in the floor. Everything else on this list is either a member of one, or a wrapper around one.

## In source

```text
{a, b, c}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `members` | list of members | In declaration order. Order is meaningful |

A member is a [Face](face.md), [Range](range.md), [Fold](fold.md), [Subtract](subtract.md), [Product](product.md) or [Closure](closure.md).

## What it means

Read the members left to right and collect what each contributes. Adding members (everything except `Subtract`) contribute entries; `Subtract` takes faces away from what came before it.

Declaration order is the **value order**, so it decides addresses -- and therefore who wins a collision. `{a, b}` and `{b, a}` hold the same two entries but assign them opposite positions.

## JSON

```json
{"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]}
```

## Watch out

- Order is not cosmetic. Reordering members can change which entry claims a contested spelling.
- An empty group `{}` is the empty universe: no entries, matches nothing. That is a legitimate answer, never an error.
- A group whose members contain a free `&` is a *binder* -- see [Closure](closure.md). Whether a group binds changes what it means, and it is decided by looking at the written members, not by denoting them.
