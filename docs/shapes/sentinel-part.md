# `SentinelPart`

`{{@name}}` -- writes a declared sentinel character into the output.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | The declared sentinel's name |

## What it means

Look the name up in the program's sentinel table and emit the character it was given. Unknown name is an error.

## JSON

```json
{"kind": "sentinel", "name": "end"}
```

## Watch out

Sentinels are real characters while the script runs, so later statements can match them -- that is what makes them useful as anchors. They are stripped at the very end. See [Sentinel](sentinel.md).
