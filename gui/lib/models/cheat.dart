/// The Himark cheat sheet's content, transcribed from the design.
///
/// This is the language's own reference, not the app's: it is the one place in
/// the editor that answers "what can I write?", which is why it ships as data
/// here rather than as a link out to `docs/foundation/`. A phone has no
/// checkout to link to.
///
/// The rows are deliberately terse — a spelling and a sentence — because the
/// sheet is read beside a half-written rule, not instead of the spec.
library;

/// One section: a heading, an optional intro line, optional [rows], an optional
/// worked [code] block, and an optional trailing [note].
class CheatSection {
  const CheatSection({
    required this.heading,
    this.intro,
    this.rows = const <CheatRow>[],
    this.code,
    this.note,
  });

  final String heading;
  final String? intro;
  final List<CheatRow> rows;
  final String? code;
  final String? note;
}

/// One row: a [code] spelling, an optional bolded [name] for it, and the
/// sentence that says what it does.
class CheatRow {
  const CheatRow(this.code, this.desc, {this.name});

  final String code;
  final String? name;
  final String desc;
}

const List<CheatSection> kCheatSheet = <CheatSection>[
  CheatSection(
    heading: 'The object',
    intro:
        'A universe is a pointed alphabet: a virtual list of entries, each '
        'wearing one or more faces (spellings), with a pointer at one entry '
        'and one face. ⟨value, face⟩ is the capture. Matching binds value; '
        'face names which spelling hit.',
  ),
  CheatSection(
    heading: 'The six constructors (L1)',
    intro: 'Denotation — nothing here rejects.',
    rows: <CheatRow>[
      CheatRow(
        '{a,b,c}',
        'entries in order, duplicates skipped (idempotent, not commutative)',
        name: 'Union',
      ),
      CheatRow(
        '!{…}',
        'strip the spelling(s) the operand claims; an entry with no face left '
            'drops',
        name: 'Subtraction',
      ),
      CheatRow(
        '{a,b} as member',
        'quotient several faces onto one entry; {{}} is the unit',
        name: 'Fold',
      ),
      CheatRow(
        '{a..}',
        'every spelling from a on, in shortlex order (unary, no upper bound)',
        name: 'Final segment',
      ),
      CheatRow(
        '{cat}{dog}',
        'tuples, spelled by concatenation, ordered by mixed-radix value',
        name: 'Product',
      ),
      CheatRow(
        '&',
        'self-reference; the closure at ω of its body',
        name: 'Closure',
      ),
    ],
    note:
        'Empty {} is legal (no entries). Unit {{}} is one entry with the empty '
        'face — the product identity, never a query match.',
  ),
  CheatSection(
    heading: 'Compression (notation only)',
    rows: <CheatRow>[
      CheatRow('{a..z}', '{a.., !{s..}}  (s = shortlex successor of z)'),
      CheatRow('{cat}{dog}', '{catdog}  (finite adjacency)'),
      CheatRow('A^n', 'A written adjacent n times; A^0 is the unit'),
      CheatRow(r'A \ B', '{…A…, !{…B…}}'),
      CheatRow('A ∩ B', r'A \ (A \ B)'),
      CheatRow('{w..}', '{{{}}, &C} \\ {predecessors of w}'),
    ],
  ),
  CheatSection(
    heading: 'Names & definitions (L1.5)',
    code:
        'uni name = {…}       // declaration; splices entry-wise\n'
        '@name                // reference; the sigil keeps a name\n'
        '                     //   from reading as a spelling\n'
        'name params := body  // definition; applied via the pipeline\n'
        'A[f x g y]           // modifier pipeline: stages left to right',
    note:
        "Acyclic — a name can't reach itself through its own declaration; & is "
        'the only self-reference. Registers read the pipeline head, not the '
        'current stage.',
  ),
  CheatSection(
    heading: 'Registers',
    intro: 'The closed inventory — four tokens, two addressed families.',
    rows: <CheatRow>[
      CheatRow('@', 'the pipeline head, as a universe (definition bodies)'),
      CheatRow(
        '@lo..hi',
        "the head's value line, cut to values lo..hi (@0 = zero entry)",
      ),
      CheatRow(r'$', 'the hit, as it hit — bound entry, bound face (templates)'),
      CheatRow(r'$0', "the hit's canonical face, face 0 (templates)"),
      CheatRow(
        r'$1..$n',
        'factor k of the hit, 1-based, spelled as it hit (templates & '
            'back-refs)',
      ),
    ],
  ),
  CheatSection(
    heading: 'Matching',
    rows: <CheatRow>[
      CheatRow('Query', 'a universe run against text; matches one entry, any '
          'face'),
      CheatRow(
        'Longest-first',
        'maximal munch — a longer face beats a prefix of it; declaration order '
            'never selects',
      ),
      CheatRow('Zero-width', "excluded — the unit's empty face never matches"),
      CheatRow(
        r'{$k}',
        'back-reference — reads factor k of the same query, strictly to its '
            'left',
      ),
      CheatRow(
        'Scope',
        'decidable only where every closure body is guarded; unguarded or '
            'negative bodies denote but matching is refused (L2)',
      ),
    ],
  ),
  CheatSection(
    heading: 'Emit — statements (L1.5)',
    intro: 'A chain of steps joined by => :  query => template => query …',
    rows: <CheatRow>[
      CheatRow(
        'query =>',
        'refines: tiles the incoming branch, one sub-branch per match; no '
            'match stops the branch',
      ),
      CheatRow(
        '=> “…”',
        r'constructs: literal text + {{…}} interpolation ($, $0, $k, '
            '{{@name}}); commits over the span',
      ),
      CheatRow(
        'q <=>[@m] t',
        'contraction — re-run the pass until nothing rewrites; @m is the '
            'measure each pass must strictly descend',
      ),
    ],
    code:
        '{{cat,feline}} => "{{\$0}}"      my feline  →  my cat\n'
        '{a,e,i,o,u} => ""              pattern    →  pttrn\n'
        '{@spellings} => "<b>{{\$}}</b>" abc        →  <b>abc</b>\n'
        '{ba} <=>[@spellings] "ab"      bbaa       →  aabb',
  ),
  CheatSection(
    heading: 'Sentinels',
    intro:
        'Declare a name for one host-allocated noncharacter (U+FDD0↑) — '
        'invisible to @C, so nothing but the name matches it.',
    code:
        'sentinel start\n'
        'sentinel end\n'
        '{@start,@end} => ""   // clean up before the boundary',
  ),
  CheatSection(
    heading: 'The std (L3)',
    rows: <CheatRow>[
      CheatRow('uni hex', '{0..9,a..f} — the hex radix'),
      CheatRow('uni spellings', '{{{}}, &@C} — every spelling, in shortlex'),
      CheatRow('numerals', 'the value line of the head radix'),
      CheatRow('where lo..hi', '{@lo..hi} — a value cut, radix-general'),
      CheatRow('pad w..w′', 'cap widths — zero-pad the short, drop the long'),
      CheatRow('padfree', 'every entry at every zero-padding'),
      CheatRow('{0..9}[where 8..12]', '→ 8, 9, 10, 11, 12'),
      CheatRow('{8,9,10,11,12}[pad 2]', '→ 88, 89, 10, 11, 12'),
    ],
  ),
  CheatSection(
    heading: 'Layers',
    rows: <CheatRow>[
      CheatRow('L1', 'What universes exist? (denotation, cemented)'),
      CheatRow(
        'L1.5',
        'What can be written? (surface; expands into the six constructors)',
      ),
      CheatRow(
        'L2',
        'What can be run? (bounded reads, decidable matching, termination)',
      ),
      CheatRow('L3', "What's in the box? (std library — pure L1.5 "
          'declarations)'),
    ],
  ),
  CheatSection(
    heading: 'CLI',
    // `emit-fragments` rather than the design's `emit-json`: the command was
    // renamed when lowering went multi-file, and this app calls the new name.
    code:
        'hejmark find query.hmk target.txt      scan; matches + count\n'
        'hejmark run script.hmk target.txt      run a script, print doc\n'
        'hejmark parse-file path.hmk            dump a parse tree\n'
        'hejmark emit-fragments query.hmk       query → floor-AST JSON\n'
        'hejmark emit-program script.hmk        script → Program JSON',
  ),
];
