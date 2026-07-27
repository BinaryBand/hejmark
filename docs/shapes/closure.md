# `Closure`

The `&` token: a universe referring to itself. The only way to build something infinite.

## In source

```text
{a, b, &{a,b}}
```

## Fields

None. It is a bare token; all of its meaning comes from *where* it appears.

## What it means

`&` stands for "everything this group had at the previous stage". The group is built up in rounds:

- **Stage 0** -- take the members, treating `&` as empty. `{a,b,&{a,b}}` gives `a`, `b`.
- **Stage 1** -- take them again, with `&` meaning stage 0. Now `&{a,b}` gives `aa`, `ab`, `ba`, `bb`.
- **Stage 2** -- again, with `&` meaning stage 1. And so on.

Each round only keeps spellings no earlier round produced, so entries appear once, in first-appearance order. If a round produces nothing new, the universe is finite and complete.

A group containing a free `&` is called a **binder**. Membership is decided by building stages up to the length of the spelling being tested, plus one.

## JSON

```json
{"kind": "closure"}
```

## Watch out

- **`&` binds to the innermost enclosing group -- except a subtraction's braces, which never bind.** Inside a `!{...}` it reaches past to the outer binder. See [Subtract](subtract.md).
- Infinite universes are streamed lazily, never built. Asking for "all entries" of one simply never finishes -- that is the honest answer, not a bug.
- Membership is exact for well-behaved bodies. For a body that never settles, a "no" means "no stage up to this bound showed it", which a later stage could in principle contradict.
