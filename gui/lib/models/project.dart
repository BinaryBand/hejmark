import '../theme/schemes.dart';

/// One pattern rule: a human [label] and the real Himark [source] the engine
/// parses and matches with. `source` is a single query expression fed verbatim
/// to `hejmark emit-fragments` (see `HejmarkBridge`).
class Rule {
  Rule({
    required this.id,
    required this.label,
    required this.source,
    this.color,
  });

  final String id;
  String label;
  String source;

  /// The swatch this rule is pinned to, or null to take the colour its position
  /// in the project gives it. Null is the norm — a pin only exists where the
  /// user overrode the cycle from the row menu.
  HighlightSwatch? color;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'source': source,
    if (color != null) 'color': color!.name,
  };

  static Rule fromJson(Map<String, Object?> json) => Rule(
    id: json['id']! as String,
    label: json['label'] as String? ?? '',
    source: json['source'] as String? ?? '',
    color: _swatch(json['color']),
  );

  /// A stored swatch name this build does not know reads as no pin, the same
  /// way an unknown enum elsewhere falls back rather than throwing.
  static HighlightSwatch? _swatch(Object? name) {
    for (final value in HighlightSwatch.values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'content': content,
  };

  static TestString fromJson(Map<String, Object?> json) => TestString(
    id: json['id']! as String,
    name: json['name'] as String? ?? 'Untitled',
    content: json['content'] as String? ?? '',
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
        .map(
          (r) =>
              Rule(id: r.id, label: r.label, source: r.source, color: r.color),
        )
        .toList(),
    enabled: Map<String, bool>.from(enabled),
    tabs: tabs.map((t) => t.copyWith()).toList(),
    activeTab: activeTab,
    createdAt: now,
    updatedAt: now,
  );

  /// The project as stored between sessions.
  ///
  /// [dirty] is deliberately absent: it means "an autosave is still in
  /// flight", which cannot outlive the process that scheduled it. Timestamps
  /// go out as ISO-8601 so the shelf's relative stamps survive a restart
  /// instead of resetting to "1m ago".
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'rules': <Object?>[for (final r in rules) r.toJson()],
    'enabled': enabled,
    'tabs': <Object?>[for (final t in tabs) t.toJson()],
    'activeTab': activeTab,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Project fromJson(Map<String, Object?> json) {
    final rules = <Rule>[
      for (final r in json['rules'] as List<Object?>? ?? const <Object?>[])
        Rule.fromJson(r! as Map<String, Object?>),
    ];
    final tabs = <TestString>[
      for (final t in json['tabs'] as List<Object?>? ?? const <Object?>[])
        TestString.fromJson(t! as Map<String, Object?>),
    ];
    final enabled = <String, bool>{
      for (final entry
          in (json['enabled'] as Map<Object?, Object?>? ??
                  const <Object?, Object?>{})
              .entries)
        entry.key! as String: entry.value == true,
    };
    final activeTab = json['activeTab'] as String?;
    return Project(
      id: json['id']! as String,
      name: json['name'] as String? ?? 'Untitled project',
      rules: rules,
      enabled: enabled,
      tabs: tabs,
      // A stored `activeTab` naming a tab that is gone would leave the Test
      // screen empty with tabs on the bar, so it is checked, not trusted.
      activeTab: tabs.any((t) => t.id == activeTab) ? activeTab : null,
      createdAt: _time(json['createdAt']),
      updatedAt: _time(json['updatedAt']),
    );
  }
}

DateTime _time(Object? value) =>
    DateTime.tryParse(value as String? ?? '') ?? DateTime.now();

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
