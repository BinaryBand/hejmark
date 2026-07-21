/// One pattern rule: a human [label] and the real Himark [source] the engine
/// parses and matches with. `source` is a single query expression fed verbatim
/// to `hejmark emit-json` (see `HejmarkBridge`).
class Rule {
  Rule({required this.id, required this.label, required this.source});

  final String id;
  String label;
  String source;
}

/// A single test string ("tab" in the brief).
class TestString {
  TestString({required this.id, required this.name, required this.content});

  final String id;
  String name;
  String content;

  TestString copyWith({String? id, String? name, String? content}) =>
      TestString(
        id: id ?? this.id,
        name: name ?? this.name,
        content: content ?? this.content,
      );
}

/// A project bundles an ordered list of rules (with an on/off map) and its
/// test strings, tracking which one is active.
///
/// [createdAt] and [updatedAt] exist for the shelf: it sorts by either, and
/// prints [updatedAt] through [formatEdited] under each project's name.
class Project {
  Project({
    required this.id,
    required this.name,
    required this.rules,
    required this.enabled,
    required this.tabs,
    required this.createdAt,
    required this.updatedAt,
    this.activeTab,
    this.dirty = false,
  });

  final String id;
  String name;
  bool dirty;
  List<Rule> rules;
  Map<String, bool> enabled;
  String? activeTab;
  List<TestString> tabs;
  DateTime createdAt;
  DateTime updatedAt;

  TestString? get active {
    if (activeTab == null) return null;
    for (final t in tabs) {
      if (t.id == activeTab) return t;
    }
    return null;
  }

  int get enabledCount => rules.where((r) => enabled[r.id] ?? false).length;

  Project deepCopy({
    required String newId,
    required String newName,
    required DateTime now,
  }) => Project(
    id: newId,
    name: newName,
    rules: rules
        .map((r) => Rule(id: r.id, label: r.label, source: r.source))
        .toList(),
    enabled: Map<String, bool>.from(enabled),
    tabs: tabs.map((t) => t.copyWith()).toList(),
    activeTab: activeTab,
    createdAt: now,
    updatedAt: now,
  );
}

/// The shelf's relative timestamp: minutes within the hour, hours within the
/// day, days within the week, then an absolute short date. A port of the brief's
/// `formatEdited`, with [now] injected so the result is testable.
String formatEdited(DateTime updatedAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(updatedAt);
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return 'Edited ${minutes}m ago';
  }
  if (diff.inDays < 1) return 'Edited ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Edited ${diff.inDays}d ago';
  return 'Edited ${_months[updatedAt.month - 1]} ${updatedAt.day}';
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
