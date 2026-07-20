/// Kinds of pattern rule the prototype ships. Mirrors the brief's `RULE_*`
/// tables. `custom` is a user-added rule with no built-in matcher.
enum RuleKind { email, ipv4, heading, custom }

class Rule {
  Rule({required this.id, required this.kind});

  final String id;
  RuleKind kind;
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
class Project {
  Project({
    required this.id,
    required this.name,
    required this.rules,
    required this.enabled,
    required this.tabs,
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

  TestString? get active {
    if (activeTab == null) return null;
    for (final t in tabs) {
      if (t.id == activeTab) return t;
    }
    return null;
  }

  int get enabledCount => rules.where((r) => enabled[r.id] ?? false).length;

  Project deepCopy({required String newId, required String newName}) => Project(
    id: newId,
    name: newName,
    rules: rules.map((r) => Rule(id: r.id, kind: r.kind)).toList(),
    enabled: Map<String, bool>.from(enabled),
    tabs: tabs.map((t) => t.copyWith()).toList(),
    activeTab: activeTab,
  );
}
