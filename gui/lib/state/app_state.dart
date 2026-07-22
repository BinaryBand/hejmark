import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/bridge.dart';
import '../models/matcher.dart';
import '../models/project.dart';
import 'persistence.dart';

enum NavTab { rules, test, settings }

/// Which panel the desktop icon rail is holding open beside the main column.
/// Null is a legal third state: both rails toggle off and the editor takes the
/// full width.
enum DeskSidebar { projects, rules }

/// What the project shelf orders by. `manual` is the order projects were
/// created in, which drag-free reordering never disturbs.
enum ProjectSort { manual, name, date }

enum SortDir { asc, desc }

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
/// state, and every mutation the screens call.
///
/// **Saving is real.** The brief's "Saving…"→"Saved" flash is kept as the
/// visible half, but the timer behind it now writes the session to [store]
/// before it settles, so the label reports a fact. What is written is the
/// projects and the preferences — [_snapshot]; the transient UI (which panel
/// is open, which rule is being edited, the last match run) is not, because it
/// is either derivable or meaningless on the next launch.
class AppState extends ChangeNotifier {
  AppState({Bridge? bridge, Store? store})
    : bridge = bridge ?? HejmarkBridge(),
      store = store ?? const PrefsStore() {
    // Seed first, restore second: the demo set is what a first run gets, and
    // it is also what is on screen for the frame or two the load takes.
    _seedDemo();
    unawaited(_restore());
  }

  /// The language bridge that runs the real Python parser and Rust engine.
  final Bridge bridge;

  /// Where the session is kept between runs.
  final Store store;

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
  bool sheetExpanded = false;
  bool tabBarVisible = true;

  /// The Test screen's verb. Find highlights where the enabled rules hit; Run
  /// executes them, in order, as one script and shows the rewritten document.
  /// A rule that is a bare query is a one-step statement that refines and
  /// writes nothing, so a find-only project runs as an unchanged document
  /// rather than an error.
  bool runMode = false;

  // --- shell ---
  bool shelfOpen = false;
  DeskSidebar? deskSidebar = DeskSidebar.projects;
  SaveStatus saveStatus = SaveStatus.saved;

  // --- data ---
  List<String> order = <String>[];
  Map<String, Project> byId = <String, Project>{};
  String? currentProject;
  ProjectSort projectSort = ProjectSort.manual;
  SortDir sortDir = SortDir.asc;

  /// The rule whose source is open in the rules panel's inline editor, if any.
  String? editingRule;

  // --- transient overlays ---
  EditingState? editing;
  MenuState? menu;
  ConfirmState? confirm;
  SnackState? snack;

  // --- engine results (live matches from the Python+Rust bridge) ---
  List<MatchRange> matches = <MatchRange>[];
  EngineState engine = EngineState.idle;
  String? engineError;

  /// The rewritten document the last run produced, shown by the read view in
  /// run mode. Null until a run has answered for the active tab.
  String? runDocument;

  int _uid = 1;

  /// Mint an id for a new rule, tab or project.
  ///
  /// The hyphen is load-bearing: the demo seed hard-codes `r1`, `t1` and so on,
  /// and a bare counter would hand those out a second time — two list rows would
  /// then share a key, which is an error, not a cosmetic clash. Seeding again
  /// (Reset app data) does not rewind the counter, so ids stay unique for the
  /// life of the session either way.
  String _newId(String prefix) => '$prefix-${_uid++}';

  Timer? _saveTimer;
  Timer? _snackTimer;
  Timer? _matchTimer;
  int _matchReq = 0;

  /// Set by [dispose]. The store round trip is the one await here that can
  /// outlive the notifier, and notifying a disposed one is an error.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
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

  /// The shelf's list: [projectsInOrder] under the active sort. `manual` keeps
  /// creation order, so only the direction toggle moves it.
  List<Project> get projectsSorted {
    final list = projectsInOrder;
    switch (projectSort) {
      case ProjectSort.manual:
        break;
      case ProjectSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ProjectSort.date:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return sortDir == SortDir.desc ? list.reversed.toList() : list;
  }

  /// Whether the desktop rail is holding [which] open. Settings takes over the
  /// main column, so no sidebar counts as active while it is up.
  bool deskSidebarActive(DeskSidebar which) =>
      nav != NavTab.settings && deskSidebar == which;

  /// The destination the main column actually shows.
  ///
  /// Rules is a mobile-only destination — on a wide layout the rail opens it as
  /// a sidebar instead, so the column falls back to the editor. Resizing a
  /// phone-width window out to desktop is the case this covers; everything else
  /// leaves [nav] on test or settings already.
  NavTab navFor({required bool wide}) =>
      wide && nav == NavTab.rules ? NavTab.test : nav;

  bool isEditing(MenuScope scope, String id) =>
      editing != null && editing!.scope == scope && editing!.id == id;

  // ---------------------------------------------------------------------------
  // Save plumbing (debounced autosave to [store])
  // ---------------------------------------------------------------------------

  /// Record an edit to the current project: stamp it, run the mutator, then
  /// schedule both the engine pass and the save.
  void touch([void Function(Project cur)? mutator]) {
    final c = cur;
    if (mutator != null && c != null) {
      c.dirty = true;
      c.updatedAt = DateTime.now();
      mutator(c);
    }
    _scheduleMatch();
    _scheduleSave();
  }

  /// An edit to the project *list* — created, duplicated, deleted, renamed.
  /// No engine pass follows it, so it only saves.
  void _patchProjects() => _scheduleSave();

  /// Flash "Saving…", and 800ms after the last edit actually write the session
  /// out before settling back to "Saved".
  ///
  /// The debounce is why the write is cheap enough to sit on every keystroke:
  /// a burst of typing encodes the snapshot once, when it stops.
  void _scheduleSave() {
    saveStatus = SaveStatus.saving;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      await store.save(jsonEncode(_snapshot()));
      if (_disposed) return;
      saveStatus = SaveStatus.saved;
      cur?.dirty = false;
      notifyListeners();
    });
  }

  /// Everything that outlives the process: the preferences, the projects, and
  /// the id counter — the last so a restored `r-7` is never handed out twice.
  Map<String, Object?> _snapshot() => <String, Object?>{
    'version': 1,
    'uid': _uid,
    'theme': theme.name,
    'density': density.name,
    'editorFontSize': editorFontSize,
    'tabSize': tabSize,
    'showWhitespace': showWhitespace,
    'order': order,
    'currentProject': currentProject,
    'projects': <Object?>[for (final p in projectsInOrder) p.toJson()],
  };

  /// Read the last session back over the demo seed.
  ///
  /// Three ways this declines, all of them silently, all of them leaving the
  /// seed standing: nothing stored (a first run), a payload that will not
  /// decode (a store written by a version that is not this one), or an edit
  /// having already landed while the read was in flight — [_saveTimer] is the
  /// witness for that last one, and restoring over it would throw away work
  /// the user can see on screen.
  Future<void> _restore() async {
    final raw = await store.load();
    if (raw == null || _disposed || _saveTimer != null) return;
    final Map<String, Object?> json;
    try {
      json = jsonDecode(raw) as Map<String, Object?>;
      final projects = <String, Project>{
        for (final p in json['projects'] as List<Object?>? ?? const <Object?>[])
          (p! as Map<String, Object?>)['id']! as String: Project.fromJson(
            p as Map<String, Object?>,
          ),
      };
      final restored = <String>[
        for (final id in json['order'] as List<Object?>? ?? const <Object?>[])
          if (projects.containsKey(id)) id! as String,
      ];
      if (restored.isEmpty) return; // a store with no projects is no store
      order = restored;
      byId = projects;
      final current = json['currentProject'] as String?;
      currentProject = projects.containsKey(current) ? current : restored.first;
    } on Object {
      return; // an unreadable store is a first run
    }
    _uid = (json['uid'] as int?) ?? _uid;
    theme = _named(ThemeChoice.values, json['theme'], theme);
    density = _named(Density.values, json['density'], density);
    editorFontSize = ((json['editorFontSize'] as int?) ?? editorFontSize).clamp(
      12,
      18,
    );
    tabSize = (json['tabSize'] as int?) ?? tabSize;
    showWhitespace = (json['showWhitespace'] as bool?) ?? showWhitespace;
    _scheduleMatch();
    notifyListeners();
  }

  /// An enum by [Enum.name], falling back rather than throwing — a value this
  /// build does not know is a store from another build, not a crash.
  static T _named<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
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
    if (runMode) {
      if (engine == EngineState.running) return 'Running…';
      if (engine == EngineState.error) return engineError ?? 'Engine error';
      final document = runDocument;
      if (document == null) return 'Not run yet';
      if (document == (cur?.active?.content ?? '')) {
        return 'Ran — document unchanged';
      }
      return 'Ran — document rewritten '
          '(${(cur?.active?.content ?? '').runes.length} → '
          '${document.runes.length} characters)';
    }
    if (engine == EngineState.running) return 'Matching…';
    if (engine == EngineState.error) return engineError ?? 'Engine error';
    final n = matches.length;
    return n == 1 ? '1 match' : '$n matches';
  }

  /// Debounce a fresh engine pass behind the user's typing/toggling, so we
  /// spawn the compiler and engine once the edits pause rather than per
  /// keystroke. Which verb runs is [runMode]'s call.
  void _scheduleMatch() {
    _matchTimer?.cancel();
    _matchTimer = Timer(
      const Duration(milliseconds: 220),
      () => runMode ? _runScript() : _runMatch(),
    );
  }

  /// Flip the Test screen between finding and running. Turning run mode on
  /// also leaves edit mode: the point of running is to see the document.
  void toggleRunMode() {
    runMode = !runMode;
    if (runMode) editMode = false;
    engine = EngineState.idle;
    engineError = null;
    _scheduleMatch();
    notifyListeners();
  }

  /// Run the enabled rules, in order, as one script over the active test
  /// string, and publish the rewritten document. The same debounce and
  /// request-id discipline as [_runMatch].
  Future<void> _runScript() async {
    final c = cur;
    final active = c?.active;
    final req = ++_matchReq;
    if (c == null || active == null) {
      runDocument = null;
      engine = EngineState.idle;
      engineError = null;
      notifyListeners();
      return;
    }
    final sources = <String>[
      for (final rule in c.rules)
        if (c.enabled[rule.id] ?? false) rule.source,
    ];
    final content = active.content;
    if (sources.isEmpty || content.isEmpty) {
      // An empty script leaves any document alone, and no engine runs over an
      // empty one — answer without crossing.
      runDocument = content;
      engine = EngineState.ready;
      engineError = null;
      notifyListeners();
      return;
    }

    engine = EngineState.running;
    notifyListeners();

    DocumentRun run;
    try {
      run = await bridge.runScript(sources.join('\n'), content);
    } on Object catch (error) {
      run = DocumentRun(null, error: '$error');
    }
    if (req != _matchReq) return; // a newer pass started while we waited

    runDocument = run.document;
    engineError = run.error;
    engine = run.error != null ? EngineState.error : EngineState.ready;
    notifyListeners();
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
    // Only enabled rules are run, but a hit's colour comes from its rule's place
    // in the full list — so carry the original positions and map the bridge's
    // slots (indices into what it was handed) back onto them. Without this,
    // switching one rule off would recolour every rule below it.
    final rules = <Rule>[];
    final slots = <int>[];
    for (var i = 0; i < c.rules.length; i++) {
      final rule = c.rules[i];
      if (c.enabled[rule.id] ?? false) {
        rules.add(rule);
        slots.add(i);
      }
    }
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

    matches = <MatchRange>[
      for (final m in run.matches)
        MatchRange(
          m.start,
          m.end,
          m.text,
          slot: m.slot < slots.length ? slots[m.slot] : 0,
        ),
    ];
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

  /// A desktop rail press. It always returns to the workspace, then toggles the
  /// pressed panel: pressing the open one closes it and gives the width back to
  /// the editor.
  void pressRail(DeskSidebar which) {
    final wasActive = deskSidebarActive(which);
    nav = NavTab.test;
    deskSidebar = wasActive ? null : which;
    notifyListeners();
  }

  void cycleSortTarget() {
    const values = ProjectSort.values;
    projectSort = values[(projectSort.index + 1) % values.length];
    notifyListeners();
  }

  void toggleSortDir() {
    sortDir = sortDir == SortDir.asc ? SortDir.desc : SortDir.asc;
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

  /// Open [ruleId]'s source for editing in place. Row-tap still toggles the
  /// rule, so entering the editor is its own affordance (the pencil), and only
  /// one rule is open at a time.
  void startRuleEdit(String ruleId) {
    editingRule = ruleId;
    notifyListeners();
  }

  void endRuleEdit() {
    if (editingRule == null) return;
    editingRule = null;
    notifyListeners();
  }

  /// Rewrite a rule's Himark source. Goes through [touch], so it schedules the
  /// debounced engine pass and the save with every other edit.
  void setRuleSource(String ruleId, String source) {
    touch((c) {
      for (final r in c.rules) {
        if (r.id == ruleId) r.source = source;
      }
    });
  }

  void addRule() {
    final id = _newId('r');
    touch((c) {
      c.rules.add(Rule(id: id, label: 'Custom pattern', source: r'{0..9}^2'));
      c.enabled[id] = true;
    });
    // A rule you cannot read yet is a rule you meant to write: land in the
    // editor the way a new tab lands in its rename field.
    startRuleEdit(id);
  }

  void removeRule(String ruleId) {
    final c = cur;
    if (c == null) return;
    final idx = c.rules.indexWhere((r) => r.id == ruleId);
    if (idx == -1) return;
    final removed = c.rules[idx];
    final wasEnabled = c.enabled[ruleId] ?? false;
    if (editingRule == ruleId) editingRule = null;
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
    editingRule = null; // the open editor belongs to the project leaving
    _scheduleMatch();
    notifyListeners();
  }

  void addNewProject() {
    final id = _newId('p');
    final now = DateTime.now();
    byId[id] = Project(
      id: id,
      name: 'Untitled project',
      rules: <Rule>[],
      enabled: <String, bool>{},
      tabs: <TestString>[],
      createdAt: now,
      updatedAt: now,
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
          p.updatedAt = DateTime.now();
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
        byId[nid] = src.deepCopy(
          newId: nid,
          newName: '${src.name} copy',
          now: DateTime.now(),
        );
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

  // Each of these ends in [_scheduleSave], which notifies — a preference that
  // did not outlive the app would be the one setting nobody would trust.

  void setTheme(ThemeChoice value) {
    theme = value;
    _scheduleSave();
  }

  void setDensity(Density value) {
    density = value;
    _scheduleSave();
  }

  void setFontSize(int value) {
    editorFontSize = value.clamp(12, 18);
    _scheduleSave();
  }

  void setTabSize(int value) {
    tabSize = value;
    _scheduleSave();
  }

  void toggleWhitespace() {
    showWhitespace = !showWhitespace;
    _scheduleSave();
  }

  /// Put every appearance and editor preference back to its shipped value. The
  /// projects are explicitly untouched — that is [askReset]'s job.
  void askRestoreDefaults() {
    confirm = ConfirmState(
      title: 'Restore default settings?',
      detail:
          'Theme, density, font size, whitespace, and tab size will return to '
          'their defaults. Your projects and test strings are not affected.',
      label: 'Restore',
      danger: false,
      onConfirm: () {
        theme = ThemeChoice.dark;
        density = Density.compact;
        editorFontSize = 13;
        tabSize = 2;
        showWhitespace = false;
        _scheduleSave();
        showSnack('Settings restored to defaults');
      },
    );
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
        // Overwrite the store too, or the demo set would last exactly as long
        // as this session and the cleared projects would come back.
        _scheduleSave();
        showSnack('App data reset');
      },
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Seed data (verbatim from the brief's initialData)
  // ---------------------------------------------------------------------------

  void _seedDemo() {
    // The brief seeds three projects at spaced edit times so the shelf's
    // relative stamps ("2h ago", "1d ago", a short date) all show at once.
    final now = DateTime.now();
    order = <String>['demo-set', 'project-a', 'project-b'];
    byId = <String, Project>{
      'demo-set': Project(
        id: 'demo-set',
        name: 'demo-set',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 2)),
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
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(hours: 26)),
        rules: <Rule>[
          Rule(id: 'r1', label: 'IPv4 address', source: _ipv4Source),
        ],
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
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 9)),
        rules: <Rule>[],
        enabled: <String, bool>{},
        tabs: <TestString>[],
      ),
    };
    currentProject = 'demo-set';
    editingRule = null;
    unawaited(_runMatch()); // eager first pass; edits below debounce
    notifyListeners();
  }
}
