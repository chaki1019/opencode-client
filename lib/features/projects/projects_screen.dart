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
        // Waits for the hidden projects too, so they never flash in.
        child: switch (ref.watch(hiddenProjectsProvider).isLoading) {
          true => const Center(child: CircularProgressIndicator()),
          false => projects.when(
            data: (bootstrap) => ListView(
              // Room under the last project for the FAB.
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                _SectionHeader(title: context.l10n.projects),
                if (_visible(bootstrap.projects, hidden).isNotEmpty)
                  Card(
                    key: const Key('project-list'),
                    margin: const EdgeInsets.symmetric(horizontal: _edge),
                    clipBehavior: Clip.antiAlias,
                    shape: _listShape(Theme.of(context)),
                    child: Column(
                      children: [
                        for (final (i, project) in _sorted(
                          _visible(bootstrap.projects, hidden),
                        ).indexed) ...[
                          if (i > 0) const Divider(),
                          _ProjectTile(
                            project: project,
                            isCurrent: project.id == bootstrap.current?.id,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
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
      await ref.read(hiddenProjectsProvider.notifier).show(url, project);
      if (!context.mounted) return;
    }
    ref.invalidate(projectsProvider);
    openProject(context, ref, project);
  }

  List<Project> _visible(List<Project> projects, Set<String> hidden) => [
    for (final p in projects)
      if (!hidden.contains(p.directory)) p,
  ];

  List<Project> _sorted(List<Project> projects) {
    double updated(Project p) => p.time?.updated ?? p.time?.created ?? 0;
    return [...projects]..sort((a, b) => updated(b).compareTo(updated(a)));
  }
}

/// A project row. Swipe left or long-press to take it off the list.
class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project, required this.isCurrent});

  final Project project;
  final bool isCurrent;

  /// Takes the project off this server's list, with a way to undo it. The
  /// project itself stays on the server.
  Future<void> _hide(BuildContext context, WidgetRef ref) async {
    final url = ref.read(serverUrlProvider);
    if (url == null) return;
    final hidden = ref.read(hiddenProjectsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final panes = ref.read(paneSelectionProvider.notifier);
    if (ref.read(paneSelectionProvider).project?.id == project.id) {
      panes.clear();
    }
    await hidden.hide(url, project);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.projectHidden(project.displayName)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => hidden.show(url, project),
          ),
        ),
      );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    ref.read(hapticsProvider).play(HapticCue.longPress);
    final hide = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('project-hide'),
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(context.l10n.hideProject),
              subtitle: Text(context.l10n.hideProjectNote),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (hide != true || !context.mounted) return;
    await _hide(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dismissible(
      key: ValueKey(project.directory),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: scheme.secondaryContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.hideProject,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          ref.read(hapticsProvider).play(HapticCue.swipeThreshold);
        }
      },
      onDismissed: (_) => _hide(context, ref),
      child: _tile(context, ref, theme),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, ThemeData theme) {
    final scheme = theme.colorScheme;
    final name = project.displayName;
    return ListTile(
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
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                context.l10n.currentProject,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            )
          : null,
      onTap: () => openProject(context, ref, project),
      onLongPress: () => _menu(context, ref),
    );
  }
}

/// "Projects" label above the list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProjectsPane._edge,
        8,
        ProjectsPane._edge,
        0,
      ),
      // As tall as the add button it used to share the row with, so the
      // list doesn't move up.
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
