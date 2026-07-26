# `hejmark/core/` pipeline

Source text in, result out. Spine below is `hejmark.run(source, text)` — the
one entry point that touches every stage. See `CLAUDE.md` for the layering
rules this enforces and `docs/foundation/` for the language spec itself.

## Pipeline

| # | Stage | File | Does |
| --- | --- | --- | --- |
| 0 | Entry | `hejmark/__init__.py` | Public API; binds `AntlrParser().to_ast` once, fetches std-lib text |
| 1 | Grammar | `static/grammar/*.g4` | Hand-edited ANTLR grammar |
| 2 | Codegen | `hejmark/adapters/antlr.py` | Shells out to `antlr4`; writes `hejmark/adapters/_gen/` (gitignored) |
| 3 | Std-lib fetch | `hejmark/adapters/library.py` | Reads `static/std.hmk` once, cached |
| 4 | Parse → AST | `hejmark/adapters/parser.py` + `build.py` | ANTLR tree → `ScriptNode` (`core/compiler/ast.py`). Last point any ANTLR type exists |
| 5 | Composition root | `core/driver.py` | Sequences everything below |
| 6 | Name environment | `core/compiler/{resolve,prelude,alphabet}.py` | Collect declarations, check acyclicity, seed `char`, merge std-lib → `Env` |
| 7 | Lowering | `core/compiler/{compile,expand,valueline,late}.py` | Surface → floor's 5 constructors (`core/floor/syntax.py`); back-refs go to a `SlotTable` instead → `Program` + `LateResolver` (`core/ir/program.py`) |
| 8 | L2 contract | `core/contract.py` | `apply()` (rewrite, identity today) + `check_ingest()` (refuse a document spelling a sentinel) |
| 9 | Engine | `core/engine/execute.py` + `engine/scan/{match,capture}.py` | Runs the program, denoting floor nodes via `core/floor/universe.py` |
| 10 | Output | back through `driver.run()` | Spliced document string (or a `Match`/iterator for `match`/`finditer`) |

## Where entry points diverge

| Function | Stops after | Notes |
| --- | --- | --- |
| `run` | step 10 | Only path that calls `contract.py` |
| `parse` / `match` / `finditer` | step 7, via `compile_single` | One query, not a `Program`; **skips `contract.py` entirely** |
| `emit_json` / `emit_fragments` / `emit_program` | step 7 | Serialized payload for another engine; never reaches `contract.py` or `engine/` |

## Import layering (enforced by import-linter, not convention)

- `hejmark`: `cli -> adapters -> core`, exhaustive.
- `core`: `driver -> {compiler | engine | contract} -> ir -> floor`, exhaustive.
- `compiler`, `engine`, `contract` never import each other — the one back
  edge (a back-referencing factor's late-slot resolver) crosses as a runtime
  callback value, never an import.
- `core` does no I/O — reading `.hmk`/`.g4` files lives in `adapters/`.
