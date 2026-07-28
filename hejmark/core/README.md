# `hejmark/core/` pipeline

Source text in, result out. Spine below is `hejmark.run(source, text)` -- the one entry point that touches every stage. See `CLAUDE.md` for the layering rules this enforces and `docs/foundation/` for the language spec itself.

## Pipeline

| # | Stage | File | Does |
| --- | --- | --- | --- |
| 0 | Entry | `hejmark/__init__.py` | Public API; binds `AntlrParser().to_ast` once, fetches std-lib text |
| 1 | Grammar | `static/grammar/*.g4` | Hand-edited ANTLR grammar |
| 2 | Codegen | `hejmark/adapters/antlr.py` | Shells out to `antlr4`; writes `hejmark/adapters/_gen/` (gitignored) |
| 3 | Std-lib fetch | `hejmark/adapters/library.py` | Reads `static/std.hmk` once, cached |
| 4 | Parse -> AST | `hejmark/adapters/parser.py` + `build.py` | ANTLR tree -> `ScriptNode` (`core/compiler/ast.py`). Last point any ANTLR type exists |
| 5 | Composition root | `core/driver.py` | Sequences everything below |
| 6 | Name environment | `core/compiler/{resolve,prelude,alphabet}.py` | Collect declarations, check acyclicity, seed `char`, merge std-lib -> `Env` |
| 7 | Lowering | `core/compiler/{compile,expand,valueline,late}.py` | Surface -> floor's 5 constructors (`core/floor/syntax.py`); back-refs go to a `SlotTable` instead -> `Program` + `LateResolver` (`core/ir/program.py`) |
| 8 | L2 contract | `core/contract.py` | `apply()` (the value-cut collapse, as a `Program -> Program` rewrite) + `check_ingest()` (refuse a document spelling a sentinel) |
| 9 | Engine | `core/engine/execute.py` + `engine/scan/{match,capture}.py` | Runs the program, denoting floor nodes via `core/engine/denote/universe.py` |
| 10 | Output | back through `driver.run()` | Spliced document string (or a `Match`/iterator for `match`/`finditer`) |

## Data flow

Types crossing each boundary, `run`'s path:

```text
str (source)
  -> [adapters.parser.to_ast]           ScriptNode
  -> [resolve.collect + prelude.prelude_env + resolve.merge]
                                         (ScriptNode, Env)
  -> [compile.compile_script(ToFaces)]  (Program, LateResolver)
  -> [contract.apply]                   Program            (rewritten, same denotation)
  -> [contract.check_ingest]            str (document)     (checked, not transformed)
  -> [engine.execute.run]               str (spliced document)
```

| Type | Defined in | Carries |
| --- | --- | --- |
| `ScriptNode` | `core/compiler/ast.py` | Faithful surface AST: lines, in source order. Nothing resolved yet |
| `Env` | `core/compiler/resolve.py` | Name -> declaration bindings, `uni`/`def` merged with the prelude, already acyclicity-checked |
| `Program` | `core/ir/program.py` | Plain-data compiled script: statements, templates, and the faces to strip on exit. Fully serializable |
| `LateResolver` | `core/ir/program.py` | `Callable[[int, tuple[str, ...]], UniverseNode]` -- one of the **two** non-data values in the pipeline; a back-reference slot's resolver, kept out of `Program` on purpose so the wire format stays pure data. Compiler-implemented, engine-called, at match time |
| `ToFaces` | `core/ir/program.py` | `Callable[[UniverseNode], Iterator[str]]` -- the other one, pointing the other way: `engine/denote/universe.py`'s `canonical_faces`, injected by `driver.py` so expansion can read a denotation (`@0`, value cuts) without importing one. Engine-implemented, compiler-called, at expansion time |
| `Query` | `core/engine/scan/match.py` | `parse`/`match`/`finditer`'s payload -- one compiled+loaded query, the `compile_single` sibling of `Program` |
| `Match` | `core/engine/scan/match.py` | One scan hit: span + captures, yielded by `match`/`finditer` |

Two payloads never mix: a `Program` (whole script, `run`) and a `Query` (one expression, `parse`/`match`/`finditer`) are built by different `compile.py` functions (`compile_script` vs `compile_single`) and consumed by different engine entry points -- `execute.run` vs `scan/match.py`'s `match`/`finditer`.

## Where entry points diverge

| Function | Stops after | Notes |
| --- | --- | --- |
| `run` | step 10 | Only path that calls `contract.py` |
| `parse` / `match` / `finditer` | step 7, via `compile_single` | One query, not a `Program`; **skips `contract.py` entirely** |
| `emit_json` / `emit_fragments` / `emit_program` | step 7 | Serialized payload for another engine. `emit_program` crosses `contract.py` (so a port receives the rewritten program); the query-level two do not, and never reach `engine/` |

## Import layering (enforced by import-linter, not convention)

- `hejmark`: `cli -> adapters -> core`, exhaustive.
- `core`: `driver -> {compiler | engine | contract} -> ir -> floor`, exhaustive.
- `engine`: `service -> execute -> scan -> denote -> budget`, exhaustive; `engine.denote`: `universe -> split -> window -> order`, exhaustive. `budget` is at the bottom because L2's work meter is charged at the membership question -- denotation's own chokepoint -- while the runs that *open* one are up in `scan` and `execute`.
- `compiler`, `engine`, `contract` never import each other -- the two edges between them (`LateResolver` and `ToFaces`) cross as callback values injected by `driver.py`, never as imports.
- `contract.py` is L2's *seam*, not the whole of L2. An obligation that cannot be expressed as a `Program -> Program` step lands where it is enforceable -- reach on the floor, the budgets with the runs they meter -- and is identified as L2's by the error class it raises. See CLAUDE.md's table.
- `core/floor/` is L1 as **data** only -- `syntax` (the five constructors), `binder` (where a closure binds, and whether it settles) and `reach` (how long a face an expression can wear). Denoting one of those trees is what it takes to execute it, so denotation lives under `engine/denote/`.
- `core` does no I/O -- reading `.hmk`/`.g4` files lives in `adapters/`.
