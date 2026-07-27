# `QueryNode`

A whole query: one or more universes written next to each other.

## In source

```text
{a..z}{0..9}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `universes` | list of [UniverseNode](universe-node.md) | One per written factor, in order |

## What it means

The same concatenation rule as [Product](product.md), but at the top level of a query -- and the factors stay separately addressable, which is what lets you write `{{$1}}` and `{{$2}}` to read them individually.

Two factors is not the same as one factor containing a product: `{a}{b}` gives you two captures, `{{a}{b}}` gives you one.

## Watch out

- Factors are numbered from **1**, left to right. `$1` is the first.
- Matching binds factors left to right, which is what makes a back-reference to an earlier factor possible.
