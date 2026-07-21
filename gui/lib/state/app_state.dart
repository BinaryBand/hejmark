import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bridge.dart';
import '../models/matcher.dart';
import '../models/project.dart';

enum NavTab { rules, test, settings }

/// Lifecycle of the current match run, surfaced in the Test output sheet.
enum EngineState { idle, running, ready, error }

enum ThemeChoice { dark, light, system }

enum Density { compact, comfortable }

enum SaveStatus { saved, saving }

/// Which entity an inline-rename / context-menu targets.
enum MenuScope { tab, project }

/// A single IPv4 octet: 1–3 decimal digits, longest alternative first so
/// maximal munch takes the whole octet.
const String _octet = r'{{0..9}^3,{0..9}^2,{0..9}}';

// Real, engine-checked Himark spellings for the seeded rules. Each is one query
// expression the Rust matcher terminates on — bounded exponents, ranges and the
// `@hex` splice. (An unbounded `{X,&X}` closure would hang the port's maximal
// munch, so the seeds stay bounded and the bridge time-budgets the rest.)
const String _ipv4Source = '$_octet{\\.}$_octet{\\.}$_octet{\\.}$_octet';
const String _hexColorSource = r'{\#}{@hex}^6';
const String _numberSource = r'{0..9}^4';

class EditingState {
  EditingState(this.scope, this.id, this.value);
  final MenuScope scope;
  final String id;
  String value;
}

class MenuState {
  const MenuState(this.scope, this.id, this.name);
  final MenuScope scope;
  final String id;
  final String name;
}

class ConfirmState {
  const ConfirmState({
    required this.title,
    required this.detail,
    required this.label,
    required this.danger,
    required this.onConfirm,
  });
  final String title;
  final String detail;
  final String label;
  final bool danger;
  final VoidCallback onConfirm;
}

class SnackState {
  const SnackState(this.message, {this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// The whole application model. A single [ChangeNotifier] that mirrors the
/// design brief's `Component`: it owns the project data, the per-session UI
/// state, and every mutation the screens call. Persistence is cosmetic
/// (a "Saving…"→"Saved" flash), exactly as in the brief.
class AppState extends ChangeNotifier {
  AppState({Bridge? bridge}) : bridge = bridge ?? HejmarkBridge() {
    _seedDemo();
  }

  /// The language bridge that runs the real Python parser and Rust engine.
  final Bridge bridge;

  // --- navigation / screen ---
  NavTab nav = NavTab.test;

  // --- appearance / editor settings ---
  ThemeChoice theme = ThemeChoice.dark;
  Density density = Density.compact;
  int editorFontSize = 13;
  int tabSize = 2;
  bool showWhitespace = false;

  // --- test screen ui ---
  bool editMode = true;
  bool sheetExpanded = true;
  bool tabBarVisible = true;

  // --- shell ---
  bool shelfOpen = false;
  SaveStatus saveStatus = SaveStatus.saved;

  // --- data ---
  List<String> order = <String>[];
  Map<String, Project> byId = <String, Project>{};
  String? currentProject;

  // --- transient overlays ---
  EditingState? editing;
  MenuState? menu;
  ConfirmState? confirm;
  SnackState? snack;

  // --- engine results (live matches from the Python+Rust bridge) ---
  List<MatchRange> matches = <MatchRange>[];
  EngineState engine = EngineState.idle;
  String? engineError;

  int _uid = 1;
  String _newId(String prefix) => '$prefix${_uid++}';

  Timer? _saveTimer;
  Timer? _snackTimer;
  Timer? _matchTimer;
  int _matchReq = 0;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _snackTimer?.cancel();
    _matchTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Derived
  // ---------------------------------------------------------------------------

  Project? get cur => currentProject == null ? null : byId[currentProject];

  TestString? _tabById(Project c, String id) {
    for (final t in c.tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  String get currentProjectName => cur?.name ?? '—';
  bool get isSaving => saveStatus == SaveStatus.saving;
  String get saveText => isSaving ? 'Saving…' : 'Saved';

  List<Project> get projectsInOrder =>
      order.map((id) => byId[id]).whereType<Project>().toList();

  bool isEditing(MenuScope scope, String id) =>
      editing != null && editing!.scope == scope && editing!.id == id;

  // ---------------------------------------------------------------------------
  // Save plumbing (cosmetic autosave)
  // ---------------------------------------------------------------------------

  void touch([void Function(Project cur)? mutator]) {
    final c = cur;
    if (mutator != null && c != null) {
      c.dirty = true;
      mutator(c);
    }
    saveStatus = SaveStatus.saving;
    _scheduleMatch();
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      saveStatus = SaveStatus.saved;
      cur?.dirty = false;
      notifyListeners();
    });
  }

  void _patchProjects() {
    saveStatus = SaveStatus.saving;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      saveStatus = SaveStatus.saved;
      notifyListeners();
    });
  }

  void showSnack(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _snackTimer?.cancel();
    snack = SnackState(message, actionLabel: actionLabel, onAction: onAction);
    notifyListeners();
    _snackTimer = Timer(const Duration(milliseconds: 4500), () {
      snack = null;
      notifyListeners();
    });
  }

  void dismissSnack() {
    _snackTimer?.cancel();
    snack = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Matching (the live Python parser + Rust engine bridge)
  // ---------------------------------------------------------------------------

  /// One-line status for the output sheet header.
  String get matchSummary {
    if (engine == EngineState.running) return 'Matching…';
    if (engine == EngineState.error) return engineError ?? 'Engine error';
    final n = matches.length;
    return n == 1 ? '1 match' : '$n matches';
  }

  /// Debounce a fresh match run behind the user's typing/toggling, so we spawn
  /// the parser and engine once the edits pause rather than per keystroke.
  void _scheduleMatch() {
    _matchTimer?.cancel();
    _matchTimer = Timer(const Duration(milliseconds: 220), _runMatch);
  }

  /// Run the enabled rules over the active test string through the bridge. A
  /// monotonic request id drops results from a superseded run.
  Future<void> _runMatch() async {
    final c = cur;
    final active = c?.active;
    final req = ++_matchReq;
    if (c == null || active == null) {
      matches = <MatchRange>[];
      engine = EngineState.idle;
      engineError = null;
      notifyListeners();
      return;
    }
    final rules = c.rules
        .where((r) => c.enabled[r.id] ?? false)
        .toList(growable: false);
    final content = active.content;

    engine = EngineState.running;
    notifyListeners();

    MatchRun run;
    try {
      run = await bridge.matchAll(rules, content);
    } on Object catch (error) {
      run = MatchRun(const <MatchRange>[], error: '$error');
    }
    if (req != _matchReq) return; // a newer run started while we waited

    matches = run.matches;
    engineError = run.error;
    engine = run.error != null ? EngineState.error : EngineState.ready;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigation & shell
  // ---------------------------------------------------------------------------

  void goTo(NavTab tab) {
    nav = tab;
    notifyListeners();
  }

  void toggleShelf() {
    shelfOpen = !shelfOpen;
    notifyListeners();
  }

  void toggleEditMode() {
    editMode = !editMode;
    notifyListeners();
  }

  void toggleTabBar() {
    tabBarVisible = !tabBarVisible;
    notifyListeners();
  }

  void toggleSheet() {
    sheetExpanded = !sheetExpanded;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  void toggleRule(String ruleId) {
    touch((c) => c.enabled[ruleId] = !(c.enabled[ruleId] ?? false));
  }

  void addRule() {
    final id = _newId('r');
    touch((c) {
      c.rules.add(
        Rule(id: id, label: 'Custom pattern', source: r'{0..9}^2'),
      );
      c.enabled[id] = true;
    });
  }

  void removeRule(String ruleId) {
    final c = cur;
    if (c == null) return;
    final idx = c.rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final removed = c.rules[idx];
    final wasEnabled = c.enabled[ruleId] ?? false;
    touch((p) {
      p.rules.removeAt(idx);
      p.enabled.remove(ruleId);
    });
    showSnack(
      'Rule removed',
      actionLabel: 'Undo',
      onAction: () {
        touch((p) {
          p.rules.insert(idx.clamp(0, p.rules.length), removed);
          p.enabled[ruleId] = wasEnabled;
        });
        dismissSnack();
      },
    );
  }

  /// Reorder using [ReorderableListView.onReorderItem] semantics: [newIndex] is
  /// already adjusted for the item removed at [oldIndex], so it is a direct
  /// remove-then-insert.
  void reorderRule(int oldIndex, int newIndex) {
    touch((c) {
      final moved = c.rules.removeAt(oldIndex);
      c.rules.insert(newIndex, moved);
    });
  }

  // ---------------------------------------------------------------------------
  // Test strings (tabs)
  // ---------------------------------------------------------------------------

  void selectTab(String id) => touch((c) => c.activeTab = id);

  void addTab() {
    final id = _newId('t');
    touch((c) {
      c.tabs.add(TestString(id: id, name: 'Untitled', content: ''));
      c.activeTab = id;
    });
    Timer(
      const Duration(milliseconds: 30),
      () => startRename(MenuScope.tab, id),
    );
  }

  void setActiveContent(String value) {
    touch((c) {
      final t = c.active;
      if (t != null) t.content = value;
    });
  }

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------

  void selectProject(String id) {
    currentProject = id;
    shelfOpen = false;
    _scheduleMatch();
    notifyListeners();
  }

  void addNewProject() {
    final id = _newId('p');
    byId[id] = Project(
      id: id,
      name: 'Untitled project',
      rules: <Rule>[],
      enabled: <String, bool>{},
      tabs: <TestString>[],
    );
    order.add(id);
    currentProject = id;
    _patchProjects();
    Timer(
      const Duration(milliseconds: 30),
      () => startRename(MenuScope.project, id),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline rename
  // ---------------------------------------------------------------------------

  void startRename(MenuScope scope, String id) {
    var name = '';
    if (scope == MenuScope.tab) {
      final c = cur;
      final t = c == null ? null : _tabById(c, id);
      name = t?.name ?? '';
    } else {
      name = byId[id]?.name ?? '';
    }
    editing = EditingState(scope, id, name);
    menu = null;
    notifyListeners();
  }

  void setEditingValue(String value) {
    if (editing != null) editing!.value = value;
    // No notify: the TextField owns its own text; renaming commits on submit.
  }

  void commitRename() {
    final ed = editing;
    if (ed == null) return;
    final value = ed.value.trim();
    if (value.isNotEmpty) {
      if (ed.scope == MenuScope.tab) {
        touch((c) {
          final t = _tabById(c, ed.id);
          if (t != null) t.name = value;
        });
      } else {
        final p = byId[ed.id];
        if (p != null) {
          p.name = value;
          p.dirty = false;
          _patchProjects();
        }
      }
    }
    editing = null;
    notifyListeners();
  }

  void cancelRename() {
    editing = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Context menu / duplicate / delete
  // ---------------------------------------------------------------------------

  void openMenu(MenuScope scope, String id, String name) {
    menu = MenuState(scope, id, name);
    notifyListeners();
  }

  void closeMenu() {
    menu = null;
    notifyListeners();
  }

  void duplicate(MenuScope scope, String id) {
    if (scope == MenuScope.tab) {
      touch((c) {
        final idx = c.tabs.indexWhere((x) => x.id == id);
        if (idx == -1) return;
        final src = c.tabs[idx];
        final nid = _newId('t');
        c.tabs.insert(
          idx + 1,
          TestString(id: nid, name: '${src.name} copy', content: src.content),
        );
        c.activeTab = nid;
      });
    } else {
      final src = byId[id];
      if (src != null) {
        final nid = _newId('p');
        byId[nid] = src.deepCopy(newId: nid, newName: '${src.name} copy');
        order.insert(order.indexOf(id) + 1, nid);
        currentProject = nid;
        _patchProjects();
      }
    }
    menu = null;
    notifyListeners();
  }

  void requestDelete(MenuScope scope, String id) {
    menu = null;
    if (scope == MenuScope.tab) {
      final c = cur;
      if (c == null) return;
      final idx = c.tabs.indexWhere((x) => x.id == id);
      if (idx == -1) return;
      final removed = c.tabs[idx];
      String? nextActive = c.activeTab;
      if (c.activeTab == id) {
        final after = idx + 1 < c.tabs.length ? c.tabs[idx + 1] : null;
        final before = idx - 1 >= 0 ? c.tabs[idx - 1] : null;
        nextActive = (after ?? before)?.id;
      }
      touch((p) {
        p.tabs.removeWhere((x) => x.id == id);
        p.activeTab =
            nextActive ?? (p.tabs.isNotEmpty ? p.tabs.first.id : null);
      });
      showSnack(
        'Test string deleted',
        actionLabel: 'Undo',
        onAction: () {
          touch((p) {
            p.tabs.insert(idx.clamp(0, p.tabs.length), removed);
            p.activeTab = removed.id;
          });
          dismissSnack();
        },
      );
    } else {
      final p = byId[id];
      if (p == null) return;
      confirm = ConfirmState(
        title: 'Delete “${p.name}”?',
        detail:
            'This project and all its rules and test strings will be '
            'permanently deleted.',
        label: 'Delete',
        danger: true,
        onConfirm: () {
          order.remove(id);
          byId.remove(id);
          if (currentProject == id) {
            currentProject = order.isNotEmpty ? order.first : null;
          }
          _patchProjects();
          showSnack('Project deleted');
        },
      );
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Confirm dialog
  // ---------------------------------------------------------------------------

  void cancelConfirm() {
    confirm = null;
    notifyListeners();
  }

  void runConfirm() {
    final fn = confirm?.onConfirm;
    confirm = null;
    notifyListeners();
    fn?.call();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  void setTheme(ThemeChoice value) {
    theme = value;
    notifyListeners();
  }

  void setDensity(Density value) {
    density = value;
    notifyListeners();
  }

  void setFontSize(int value) {
    editorFontSize = value.clamp(12, 18);
    notifyListeners();
  }

  void setTabSize(int value) {
    tabSize = value;
    notifyListeners();
  }

  void toggleWhitespace() {
    showWhitespace = !showWhitespace;
    notifyListeners();
  }

  void askReset() {
    confirm = ConfirmState(
      title: 'Reset app data?',
      detail:
          'This clears all projects, rules, and test strings and restores the '
          'demo set. This cannot be undone.',
      label: 'Reset',
      danger: true,
      onConfirm: () {
        _seedDemo();
        nav = NavTab.test;
        showSnack('App data reset');
      },
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Seed data (verbatim from the brief's initialData)
  // ---------------------------------------------------------------------------

  void _seedDemo() {
    order = <String>['demo-set', 'project-a', 'project-b'];
    byId = <String, Project>{
      'demo-set': Project(
        id: 'demo-set',
        name: 'demo-set',
        rules: <Rule>[
          Rule(id: 'r1', label: 'IPv4 address', source: _ipv4Source),
          Rule(id: 'r2', label: 'Hex colour', source: _hexColorSource),
          Rule(id: 'r3', label: '4-digit number', source: _numberSource),
        ],
        enabled: <String, bool>{'r1': true, 'r2': true, 'r3': false},
        activeTab: 't1',
        tabs: <TestString>[
          TestString(
            id: 't1',
            name: 'infra-log.txt',
            content:
                'Server IP 192.168.1.42, backup 10.0.0.1\n'
                'Theme colours #ff8800 and #1e90ff\n'
                'Ticket 4821 filed for review',
          ),
          TestString(
            id: 't2',
            name: 'sample.md',
            content:
                'Staging host 10.2.3.4\n'
                'Accent colour #00ffcc\n'
                'Change 2048 shipped',
          ),
          TestString(id: 't3', name: 'Untitled', content: ''),
        ],
      ),
      'project-a': Project(
        id: 'project-a',
        name: 'project-a',
        rules: <Rule>[Rule(id: 'r1', label: 'IPv4 address', source: _ipv4Source)],
        enabled: <String, bool>{'r1': true},
        activeTab: 't1',
        tabs: <TestString>[
          TestString(
            id: 't1',
            name: 'hosts.conf',
            content: '10.0.0.1\n10.0.0.2\nlocalhost',
          ),
        ],
      ),
      'project-b': Project(
        id: 'project-b',
        name: 'project-b',
        rules: <Rule>[],
        enabled: <String, bool>{},
        tabs: <TestString>[],
      ),
    };
    currentProject = 'demo-set';
    unawaited(_runMatch()); // eager first pass; edits below debounce
    notifyListeners();
  }
}
