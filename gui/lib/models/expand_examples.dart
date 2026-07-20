/// One face (spelling) of an entry. [primary] is the canonical face, drawn as
/// an outlined chip; non-primary faces are drawn muted.
class ExpandFace {
  const ExpandFace(this.text, {this.primary = true});
  final String text;
  final bool primary;
}

/// One entry (value) of a denoted universe, carrying its shortlex index and the
/// face(s) it wears.
class ExpandEntry {
  const ExpandEntry(this.index, this.faces);
  final int index;
  final List<ExpandFace> faces;
}

/// A canned denotation, curated to match the Expand screenshots. The prototype
/// has no live engine, so the Expand tab is driven by this library: each entry
/// in the example strip selects one of these.
class ExpandExample {
  const ExpandExample({
    required this.chipLabel,
    required this.expression,
    required this.title,
    required this.orderType,
    required this.description,
    required this.entries,
    this.infinite = false,
  });

  /// Short label shown in the horizontal example strip.
  final String chipLabel;

  /// The Himark expression, shown in the editor field.
  final String expression;

  /// Card heading, e.g. "Final segment".
  final String title;

  /// Order-type badge value, e.g. "26" or "ω".
  final String orderType;

  final String description;
  final List<ExpandEntry> entries;

  /// When true the entry list is a finite prefix of an unbounded universe and a
  /// trailing "…" is drawn.
  final bool infinite;
}

const List<ExpandExample> kExpandExamples = <ExpandExample>[
  ExpandExample(
    chipLabel: 'a, b, c',
    expression: '{a, b, c}',
    title: 'Union',
    orderType: '3',
    description:
        'A comma is a union: three members in shortlex, side by side. The '
        'simplest finite universe.',
    entries: <ExpandEntry>[
      ExpandEntry(0, <ExpandFace>[ExpandFace('a')]),
      ExpandEntry(1, <ExpandFace>[ExpandFace('b')]),
      ExpandEntry(2, <ExpandFace>[ExpandFace('c')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'a..z',
    expression: '{a..z}',
    title: 'Finite range',
    orderType: '26',
    description:
        'A range is compression, not a new axiom: {a..z} = {a.., !{s..}} with '
        's the shortlex successor of z.',
    entries: [
      ExpandEntry(0, [ExpandFace('a')]),
      ExpandEntry(1, [ExpandFace('b')]),
      ExpandEntry(2, [ExpandFace('c')]),
      ExpandEntry(3, [ExpandFace('d')]),
      ExpandEntry(4, [ExpandFace('e')]),
      ExpandEntry(5, [ExpandFace('f')]),
      ExpandEntry(6, [ExpandFace('g')]),
      ExpandEntry(7, [ExpandFace('h')]),
      ExpandEntry(8, [ExpandFace('i')]),
      ExpandEntry(9, [ExpandFace('j')]),
      ExpandEntry(10, [ExpandFace('k')]),
      ExpandEntry(11, [ExpandFace('l')]),
      ExpandEntry(12, [ExpandFace('m')]),
      ExpandEntry(13, [ExpandFace('n')]),
      ExpandEntry(14, [ExpandFace('o')]),
      ExpandEntry(15, [ExpandFace('p')]),
      ExpandEntry(16, [ExpandFace('q')]),
      ExpandEntry(17, [ExpandFace('r')]),
      ExpandEntry(18, [ExpandFace('s')]),
      ExpandEntry(19, [ExpandFace('t')]),
      ExpandEntry(20, [ExpandFace('u')]),
      ExpandEntry(21, [ExpandFace('v')]),
      ExpandEntry(22, [ExpandFace('w')]),
      ExpandEntry(23, [ExpandFace('x')]),
      ExpandEntry(24, [ExpandFace('y')]),
      ExpandEntry(25, [ExpandFace('z')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'consonants',
    expression: '{a..z, !{a, e, i, o, u}}',
    title: 'Subtraction',
    orderType: '21',
    description:
        'Subtraction removes the five vowels from the letters; the survivors '
        'keep shortlex order and renumber to close the gaps.',
    entries: [
      ExpandEntry(0, [ExpandFace('b')]),
      ExpandEntry(1, [ExpandFace('c')]),
      ExpandEntry(2, [ExpandFace('d')]),
      ExpandEntry(3, [ExpandFace('f')]),
      ExpandEntry(4, [ExpandFace('g')]),
      ExpandEntry(5, [ExpandFace('h')]),
      ExpandEntry(6, [ExpandFace('j')]),
      ExpandEntry(7, [ExpandFace('k')]),
      ExpandEntry(8, [ExpandFace('l')]),
      ExpandEntry(9, [ExpandFace('m')]),
      ExpandEntry(10, [ExpandFace('n')]),
      ExpandEntry(11, [ExpandFace('p')]),
      ExpandEntry(12, [ExpandFace('q')]),
      ExpandEntry(13, [ExpandFace('r')]),
      ExpandEntry(14, [ExpandFace('s')]),
      ExpandEntry(15, [ExpandFace('t')]),
      ExpandEntry(16, [ExpandFace('v')]),
      ExpandEntry(17, [ExpandFace('w')]),
      ExpandEntry(18, [ExpandFace('x')]),
      ExpandEntry(19, [ExpandFace('y')]),
      ExpandEntry(20, [ExpandFace('z')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'synonyms',
    expression: '{gray, grey}',
    title: 'One value, two faces',
    orderType: '1',
    description:
        'Both spellings name the same entry, so the universe holds one value '
        'wearing two faces. Value order is unchanged; only the face set grows.',
    entries: <ExpandEntry>[
      ExpandEntry(0, <ExpandFace>[
        ExpandFace('gray'),
        ExpandFace('grey', primary: false),
      ]),
    ],
  ),
  ExpandExample(
    chipLabel: 'face cut',
    expression: '{0..9}[numerals]',
    title: 'Face cut',
    orderType: '10',
    description:
        'A face cut chooses which spelling each entry wears without touching '
        'the value order — here every entry takes its canonical numeral.',
    entries: [
      ExpandEntry(0, [ExpandFace('0')]),
      ExpandEntry(1, [ExpandFace('1')]),
      ExpandEntry(2, [ExpandFace('2')]),
      ExpandEntry(3, [ExpandFace('3')]),
      ExpandEntry(4, [ExpandFace('4')]),
      ExpandEntry(5, [ExpandFace('5')]),
      ExpandEntry(6, [ExpandFace('6')]),
      ExpandEntry(7, [ExpandFace('7')]),
      ExpandEntry(8, [ExpandFace('8')]),
      ExpandEntry(9, [ExpandFace('9')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'a.. → ω',
    expression: '{a..}',
    title: 'Final segment',
    orderType: 'ω',
    description:
        'Every spelling from a onward in shortlex. One cut, no right endpoint '
        '— unboundedness is the missing second cut.',
    infinite: true,
    entries: [
      ExpandEntry(0, [ExpandFace('a')]),
      ExpandEntry(1, [ExpandFace('b')]),
      ExpandEntry(2, [ExpandFace('c')]),
      ExpandEntry(3, [ExpandFace('d')]),
      ExpandEntry(4, [ExpandFace('e')]),
      ExpandEntry(5, [ExpandFace('f')]),
      ExpandEntry(6, [ExpandFace('g')]),
      ExpandEntry(7, [ExpandFace('h')]),
      ExpandEntry(8, [ExpandFace('i')]),
      ExpandEntry(9, [ExpandFace('j')]),
      ExpandEntry(10, [ExpandFace('k')]),
      ExpandEntry(11, [ExpandFace('l')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'product',
    expression: '{a, b}{0, 1}',
    title: 'Product',
    orderType: '4',
    description:
        'Adjacency is a product: every left face followed by every right face, '
        'leftmost slowest. Two by two gives four entries.',
    entries: <ExpandEntry>[
      ExpandEntry(0, <ExpandFace>[ExpandFace('a0')]),
      ExpandEntry(1, <ExpandFace>[ExpandFace('a1')]),
      ExpandEntry(2, <ExpandFace>[ExpandFace('b0')]),
      ExpandEntry(3, <ExpandFace>[ExpandFace('b1')]),
    ],
  ),
  ExpandExample(
    chipLabel: 'collision',
    expression: '{{{}, 0}}{0, 00}',
    title: 'Cross-axis collision',
    orderType: '2',
    description:
        '00 is claimed by the lower value, so the higher entry loses its '
        'canonical face and is left spelled 000. Surviving faces renumber.',
    entries: <ExpandEntry>[
      ExpandEntry(0, <ExpandFace>[
        ExpandFace('0'),
        ExpandFace('00', primary: false),
      ]),
      ExpandEntry(1, <ExpandFace>[ExpandFace('000')]),
    ],
  ),
];
