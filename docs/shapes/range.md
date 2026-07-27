# `Range`

An inclusive run of single characters.

## In source

```text
{a..z}
```

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `lo` | single character | First character, included |
| `hi` | single character | Last character, included |

## What it means

One entry per character from `lo` to `hi`, in order -- so `{a..c}` is three entries wearing `a`, `b`, `c`.

The order is **shortlex**: shorter spellings first, and ties broken character by character. For single characters that is just code-point order.

Ranges are never materialized. `{a..z}` is held as a symbolic interval, so `{\u0000..\U0010FFFF}` -- the entire code space -- costs nothing to represent.

## JSON

```json
{"kind": "range", "lo": 97, "hi": 122}
```

Endpoints are single code points, encoded as plain integers.

## Watch out

- **A reversed range is empty, not an error.** `{z..a}` spans nothing and matches nothing. This is deliberate: the floor answers rather than refuses.
- Both endpoints must be single characters. `{ab..z}` is not a range.
- Subtracting from a range is done symbolically where possible, so `{a..z,!{b..d}}` stays cheap instead of expanding 26 entries and filtering.
