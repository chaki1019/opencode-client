import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../l10n/l10n.dart';
import '../ads/ad_widgets.dart';
import '../connection/connection_providers.dart';
import '../home/pane_selection.dart';
import '../home/two_pane_home.dart';
import '../live/live_widgets.dart';
import '../settings/haptics.dart';
import 'app_drawer.dart';
import 'folder_picker_sheet.dart';
import 'project_providers.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

/// The root screen once connected: the project list on a phone, or the
/// list and a chat side by side on a tablet.
class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool? _twoPane;

  /// Moves the open project and session across when the window changes
  /// between one and two panes (turning a device, resizing a split-screen
  /// window).
  void _relayout(bool twoPane) {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final panes = ref.read(paneSelectionProvider.notifier);
    final selection = ref.read(paneSelectionProvider);
    // The top page, including ones pushed over the location.
    final location = router.state.matchedLocation;
    if (twoPane) {
      // The pages open for a project and a chat become the panes' content.
      // Settings and other pages on top stay where they are.
      if (location != '/projects' &&
          !location.startsWith('/projects/') &&
          !location.startsWith('/sessions/')) {
        return;
      }
      Project? project;
      Session? session;
      for (final match in router.routerDelegate.currentConfiguration.matches) {
        if (match is! ImperativeRouteMatch) continue;
        switch (match.matches.extra) {
          case final Project p:
            project = p;
          case final Session s:
            session = s;
        }
      }
      panes.clear();
      if (project != null) panes.showProject(project);
      if (session != null) panes.showSession(session);
      if (location != '/projects') router.go('/projects');
    } else if (location == '/projects') {
      if (selection.project case final project?) {
        router.push(projectLocation(project), extra: project);
      }
      if (selection.session case final session?) {
        router.push(sessionLocation(session), extra: session);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final twoPane = useTwoPane(context);
    if (_twoPane != null && _twoPane != twoPane) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _relayout(twoPane));
    }
    _twoPane = twoPane;

    // The connect screen sits underneath only so disconnecting can pop this
    // page; going back there is what the disconnect button is for, so back
    // leaves the app as it does on a root screen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: twoPane ? const TwoPaneHome() : const ProjectsPane(),
    );
  }
}

/// The project list with the server in its header. On its own it is a
/// phone's root page with the drawer; in two panes it is the left pane and
/// [onMenu] opens the drawer over both.
class ProjectsPane extends ConsumerWidget {
  const ProjectsPane({super.key, this.onMenu});

  final VoidCallback? onMenu;

  /// Leading edge shared by the section header and the project list card.
  static const double _edge = 16;

  /// Where the title starts after the menu button (its default width plus
  /// the theme's title spacing), so the version line sits under it.
  static const double _titleStart = kToolbarHeight + 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final projects = ref.watch(projectsProvider);
    final hidden = ref.watch(hiddenOnServerProvider);
    final pinned = ref.watch(pinnedOnServerProvider);
    final showAll = ref.watch(showAllProjectsProvider);
    final health = connection?.health;

    return Scaffold(
      // Only this root screen has the drawer, so its edge swipe never
      // competes with the iOS swipe back on the screens above it.
      drawer: onMenu == null ? const AppDrawer() : null,
      bottomNavigationBar: const AdBanner(),
      // Same round "+" as the session list, so adding reads the same on
      // both lists.
      floatingActionButton: FloatingActionButton(
        key: const Key('add-project'),
        // In two panes the session list slides in over this one with a FAB
        // of its own; without a tag they don't fly between the lists.
        heroTag: null,
        tooltip: context.l10n.addProject,
        onPressed: () => _addProject(context, ref),
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        // The connect screen sits underneath, so AppBar would otherwise
        // add a back button that the PopScope below swallows.
        leading: Builder(
          builder: (context) => IconButton(
            key: const Key('open-drawer'),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            icon: const Icon(Icons.menu),
            onPressed: onMenu ?? () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(connection?.server.displayName ?? context.l10n.projects),
        actions: [
          // Diagnoses the server this list belongs to.
          IconButton(
            key: const Key('diagnostics'),
            tooltip: context.l10n.diagnosticsTitle,
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => context.push('/diagnostics'),
          ),
          IconButton(
            tooltip: context.l10n.disconnect,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          ),
        ],
        bottom: health == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_titleStart, 0, 16, 6),
                  child: Row(
                    children: [
                      LiveDot(
                        size: 6,
                        color: AppColors.of(context).success,
                        pulse: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OpenCode ${health.version}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        // Waits for the hidden and pinned projects too, so rows never
        // flash in or jump.
        child: switch (ref.watch(hiddenProjectsProvider).isLoading ||
            ref.watch(pinnedProjectsProvider).isLoading) {
          true => const Center(child: CircularProgressIndicator()),
          false => projects.when(
            data: (bootstrap) {
              final sorted = _sorted(bootstrap.projects, pinned);
              return ListView(
                // Room under the last project for the FAB.
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _SectionHeader(
                    title: context.l10n.projects,
                    trailing: _ShowAllButton(
                      showAll: showAll,
                      hiddenCount: bootstrap.projects
                          .where((p) => hidden.contains(p.directory))
                          .length,
                    ),
                  ),
                  if (_anyListed(bootstrap.projects, hidden, showAll))
                    Card(
                      key: const Key('project-list'),
                      margin: const EdgeInsets.symmetric(horizontal: _edge),
                      clipBehavior: Clip.antiAlias,
                      shape: _listShape(Theme.of(context)),
                      // Hidden projects stay in the column, folded away, so
                      // showing all unfolds them in place.
                      child: Column(
                        children: [
                          for (final (i, project) in sorted.indexed)
                            _ProjectTile(
                              key: ValueKey(project.directory),
                              project: project,
                              pinned: pinned.contains(project.directory),
                              hidden: hidden.contains(project.directory),
                              showAll: showAll,
                              divider: _anyListed(
                                sorted.take(i),
                                hidden,
                                showAll,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [Text(context.l10n.projectsLoadFailed(e))],
            ),
          ),
        },
      ),
    );
  }

  /// The theme's hairline almost vanishes against the dark background, so
  /// the list frame uses the stronger outline there.
  static ShapeBorder? _listShape(ThemeData theme) {
    if (theme.brightness != Brightness.dark) return null;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }

  Future<void> _addProject(BuildContext context, WidgetRef ref) async {
    final project = await FolderPickerSheet.show(context);
    if (project == null || !context.mounted) return;
    // Opening a project again puts it back on the list.
    if (ref.read(serverUrlProvider) case final url?) {
      await ref.read(hiddenProjectsProvider.notifier).remove(url, project);
      if (!context.mounted) return;
    }
    ref.invalidate(projectsProvider);
    openProject(context, ref, project);
  }

  /// Whether any of [projects] is on the list: all of them while showing
  /// all, otherwise the ones not hidden.
  bool _anyListed(
    Iterable<Project> projects,
    Set<String> hidden,
    bool showAll,
  ) => projects.any((p) => showAll || !hidden.contains(p.directory));

  /// Pinned projects first, each group by most recent update.
  List<Project> _sorted(List<Project> projects, Set<String> pinned) {
    double updated(Project p) => p.time?.updated ?? p.time?.created ?? 0;
    int pin(Project p) => pinned.contains(p.directory) ? 0 : 1;
    return [...projects]..sort(
      (a, b) => switch (pin(a).compareTo(pin(b))) {
        0 => updated(b).compareTo(updated(a)),
        final byPin => byPin,
      },
    );
  }
}

/// Switches the list between the projects on it and every project, hidden
/// ones included. The badge counts the hidden ones.
class _ShowAllButton extends ConsumerWidget {
  const _ShowAllButton({required this.showAll, required this.hiddenCount});

  final bool showAll;
  final int hiddenCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('show-all-projects'),
      isSelected: showAll,
      tooltip: showAll
          ? context.l10n.showListedProjects
          : context.l10n.showAllProjects,
      icon: Badge(
        isLabelVisible: hiddenCount > 0,
        label: Text('$hiddenCount'),
        child: const Icon(Icons.visibility_outlined),
      ),
      selectedIcon: const Icon(Icons.visibility),
      onPressed: () => ref.read(showAllProjectsProvider.notifier).toggle(),
    );
  }
}

/// A project row. Swipe left or long-press to take it off the list, swipe
/// right to pin it. While the list shows all projects, the eye on the right
/// hides or shows it. A hidden row stays in the list folded away, so it
/// unfolds when all projects are shown.
class _ProjectTile extends ConsumerStatefulWidget {
  const _ProjectTile({
    super.key,
    required this.project,
    required this.pinned,
    required this.hidden,
    required this.showAll,
    required this.divider,
  });

  final Project project;
  final bool pinned;
  final bool hidden;
  final bool showAll;

  /// Whether a listed row sits above this one.
  final bool divider;

  bool get listed => showAll || !hidden;

  @override
  ConsumerState<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends ConsumerState<_ProjectTile>
    with SingleTickerProviderStateMixin {
  late final _fold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.listed ? 1 : 0,
  );
  late final _foldCurve = CurvedAnimation(
    parent: _fold,
    curve: Curves.easeInOut,
  );

  /// Set when a swipe took the row off: the swipe already shrank it, so it
  /// folds away at once rather than coming back to fold.
  bool _swiped = false;

  Project get project => widget.project;

  @override
  void didUpdateWidget(_ProjectTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listed == oldWidget.listed) return;
    final target = widget.listed ? 1.0 : 0.0;
    if (_swiped && !widget.listed) {
      _fold.value = target;
    } else {
      _fold.animateTo(target);
    }
    if (widget.listed) _swiped = false;
  }

  @override
  void dispose() {
    _foldCurve.dispose();
    _fold.dispose();
    super.dispose();
  }

  /// Takes the project off this server's list, with a way to undo it. The
  /// project itself stays on the server.
  Future<void> _hide() async {
    final url = ref.read(serverUrlProvider);
    if (url == null) return;
    final hidden = ref.read(hiddenProjectsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final panes = ref.read(paneSelectionProvider.notifier);
    if (ref.read(paneSelectionProvider).project?.id == project.id) {
      panes.clear();
    }
    await hidden.add(url, project);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.projectHidden(project.displayName)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => hidden.remove(url, project),
          ),
        ),
      );
  }

  /// Puts a hidden project back on the list, or hides a listed one, from
  /// the list of every project. No undo: the eye switches it back.
  Future<void> _toggleHidden() async {
    final url = ref.read(serverUrlProvider);
    if (url == null) return;
    final notifier = ref.read(hiddenProjectsProvider.notifier);
    if (widget.hidden) {
      await notifier.remove(url, project);
    } else {
      if (ref.read(paneSelectionProvider).project?.id == project.id) {
        ref.read(paneSelectionProvider.notifier).clear();
      }
      await notifier.add(url, project);
    }
  }

  Future<void> _togglePinned() async {
    final url = ref.read(serverUrlProvider);
    if (url == null) return;
    final notifier = ref.read(pinnedProjectsProvider.notifier);
    await (widget.pinned
        ? notifier.remove(url, project)
        : notifier.add(url, project));
  }

  Future<void> _menu() async {
    ref.read(hapticsProvider).play(HapticCue.longPress);
    final pinned = widget.pinned;
    final hidden = widget.hidden;
    final action = await showModalBottomSheet<_ProjectAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('project-pin'),
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(
                pinned ? context.l10n.unpinProject : context.l10n.pinProject,
              ),
              onTap: () => Navigator.pop(context, _ProjectAction.pin),
            ),
            if (hidden)
              ListTile(
                key: const Key('project-unhide'),
                leading: const Icon(Icons.visibility_outlined),
                title: Text(context.l10n.unhideProject),
                onTap: () => Navigator.pop(context, _ProjectAction.hide),
              )
            else
              ListTile(
                key: const Key('project-hide'),
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(context.l10n.hideProject),
                subtitle: Text(context.l10n.hideProjectNote),
                onTap: () => Navigator.pop(context, _ProjectAction.hide),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _ProjectAction.pin:
        await _togglePinned();
      case _ProjectAction.hide when widget.hidden || widget.showAll:
        await _toggleHidden();
      case _ProjectAction.hide:
        await _hide();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizeTransition(
      sizeFactor: _foldCurve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _foldCurve,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.divider) const Divider(),
            // A folded row can't be swiped; after a swipe to hide, the
            // dismissed row also has to leave the tree.
            if (widget.listed)
              _swipeable(context, theme)
            else
              ExcludeFocus(child: _tile(context, theme)),
          ],
        ),
      ),
    );
  }

  /// Swipe right pins or unpins; swipe left hides, except while all
  /// projects are shown, where the eye does that.
  Widget _swipeable(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final pin = _SwipeBackground(
      alignment: AlignmentDirectional.centerStart,
      color: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      icon: widget.pinned ? Icons.push_pin_outlined : Icons.push_pin,
      label: widget.pinned
          ? context.l10n.unpinProject
          : context.l10n.pinProject,
    );
    final hide = _SwipeBackground(
      alignment: AlignmentDirectional.centerEnd,
      color: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      icon: Icons.visibility_off_outlined,
      label: context.l10n.hideProject,
    );
    return Dismissible(
      key: ValueKey(project.directory),
      direction: widget.showAll
          ? DismissDirection.startToEnd
          : DismissDirection.horizontal,
      background: pin,
      secondaryBackground: hide,
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          ref.read(hapticsProvider).play(HapticCue.swipeThreshold);
        }
      },
      // Pinning keeps the row, so it slides back into place.
      confirmDismiss: (direction) async {
        if (direction != DismissDirection.startToEnd) return true;
        await _togglePinned();
        return false;
      },
      onDismissed: (_) {
        _swiped = true;
        _hide();
      },
      child: _tile(context, theme),
    );
  }

  Widget _tile(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final name = project.displayName;
    final hidden = widget.hidden;
    final tile = ListTile(
      // While showing all, the eye button's own padding stands in for the
      // row's end padding, so it sits as far in as the badge on the left.
      contentPadding: widget.showAll
          ? const EdgeInsetsDirectional.only(start: 16, end: 4)
          : null,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          name.isEmpty ? '/' : name.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: scheme.primary,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        project.directory,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: AppFonts.mono,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pinned)
            Icon(
              Icons.push_pin,
              key: const Key('project-pinned'),
              size: 18,
              color: scheme.primary,
              semanticLabel: context.l10n.pinnedProject,
            ),
          if (widget.showAll)
            IconButton(
              key: const Key('project-visibility'),
              tooltip: hidden
                  ? context.l10n.unhideProject
                  : context.l10n.hideProject,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(hidden),
                  color: hidden ? scheme.onSurfaceVariant : scheme.primary,
                ),
              ),
              onPressed: _toggleHidden,
            ),
        ],
      ),
      onTap: () => openProject(context, ref, project),
      onLongPress: _menu,
    );
    // Hidden rows, listed only while showing all, read as switched off.
    return AnimatedOpacity(
      opacity: hidden ? 0.5 : 1,
      duration: const Duration(milliseconds: 200),
      child: tile,
    );
  }
}

/// What shows under a row as it is swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final AlignmentDirectional alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProjectAction { pin, hide }

/// "Projects" label above the list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // The trailing button's own padding lines its icon up with the
      // list's right edge.
      padding: EdgeInsetsDirectional.fromSTEB(
        ProjectsPane._edge,
        8,
        trailing == null ? ProjectsPane._edge : 4,
        0,
      ),
      // As tall as a button, so the list sits at the same height with or
      // without one.
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
