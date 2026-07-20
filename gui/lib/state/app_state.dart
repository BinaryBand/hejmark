import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/project.dart';

enum NavTab { rules, test, expand, settings }

enum ThemeChoice { dark, light, system }

enum Density { compact, comfortable }

enum SaveStatus { saved, saving }

/// Which entity an inline-rename / context-menu targets.
enum MenuScope { tab, project }

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
  AppState() {
    _seedDemo();
  }

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

  // --- expand tab ---
  int expandIndex = 5; // "a.. → ω" by default, matching the hero screenshot.

  int _uid = 1;
  String _newId(String prefix) => '$prefix${_uid++}';

  Timer? _saveTimer;
  Timer? _snackTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _snackTimer?.cancel();
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
      c.rules.add(Rule(id: id, kind: RuleKind.custom));
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

  void setExpandExample(int index) {
    expandIndex = index;
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
          Rule(id: 'r1', kind: RuleKind.email),
          Rule(id: 'r2', kind: RuleKind.ipv4),
          Rule(id: 'r3', kind: RuleKind.heading),
        ],
        enabled: <String, bool>{'r1': true, 'r2': true, 'r3': false},
        activeTab: 't1',
        tabs: <TestString>[
          TestString(
            id: 't1',
            name: 'contact-log.txt',
            content:
                'Contact: alice.smith@example.com\n'
                'Server IP: 192.168.1.42\n'
                'Backup: 10.0.0.1\n\n'
                '# Release Notes\n'
                'Ticket #4821 opened by bob-jones@example.org',
          ),
          TestString(
            id: 't2',
            name: 'sample.md',
            content:
                '# Sample notes\n'
                'Reach the team at team@himark.dev\n'
                'Staging host 10.2.3.4',
          ),
          TestString(id: 't3', name: 'Untitled', content: ''),
        ],
      ),
      'project-a': Project(
        id: 'project-a',
        name: 'project-a',
        rules: <Rule>[Rule(id: 'r1', kind: RuleKind.ipv4)],
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
    notifyListeners();
  }
}
