import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import '../projects/project_providers.dart';

/// Windows at least this wide show the session list and the chat side by
/// side. Every iPad qualifies in both orientations; narrow split-screen
/// windows keep one page at a time.
const double twoPaneMinWidth = 700;

/// Phones turned sideways are wide too, but too short for two panes; this
/// keeps them on single pages.
const double _tabletShortestSide = 600;

bool useTwoPane(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= twoPaneMinWidth &&
      size.shortestSide >= _tabletShortestSide;
}

/// The project and session open in two panes. With one pane the pushed
/// pages are what is open; turning the device or resizing the window moves
/// between the two without losing place.
@immutable
class PaneSelection {
  const PaneSelection({this.project, this.session});

  final Project? project;
  final Session? session;
}

class PaneSelectionNotifier extends Notifier<PaneSelection> {
  @override
  PaneSelection build() {
    // Another server has other projects.
    ref.listen(
      connectionProvider.select((c) => c?.server.id),
      (_, _) => state = const PaneSelection(),
    );
    return const PaneSelection();
  }

  /// Back to the project list. An open chat stays open beside it.
  void clear() => state = const PaneSelection();

  void showProjects() => state = PaneSelection(session: state.session);

  void showProject(Project project) => state = PaneSelection(project: project);

  /// Opens [session], moving to its project when it belongs to another one.
  void showSession(Session session) {
    var project = state.project;
    if (project?.id != session.projectID) {
      final known = ref.read(projectsProvider).value?.projects;
      project =
          known?.where((p) => p.id == session.projectID).firstOrNull ??
          Project(id: session.projectID, directory: session.location.directory);
    }
    state = PaneSelection(project: project, session: session);
  }

  void closeSession() => state = PaneSelection(project: state.project);

  /// Keeps an open session current after it was renamed, or closes it
  /// after it was deleted.
  void updated(Session session) {
    if (state.session?.id == session.id) {
      state = PaneSelection(project: state.project, session: session);
    }
  }

  void removed(String sessionId) {
    if (state.session?.id == sessionId) closeSession();
  }
}

final paneSelectionProvider =
    NotifierProvider<PaneSelectionNotifier, PaneSelection>(
      PaneSelectionNotifier.new,
    );

String projectLocation(Project project) =>
    '/projects/${Uri.encodeComponent(project.id)}';

String sessionLocation(Session session) =>
    '/sessions/${Uri.encodeComponent(session.id)}';

/// Opens [project]'s sessions: in the left pane, or as a page.
void openProject(BuildContext context, WidgetRef ref, Project project) {
  ref.read(paneSelectionProvider.notifier).showProject(project);
  if (!useTwoPane(context)) {
    context.push(projectLocation(project), extra: project);
  }
}

/// Opens [session]'s chat: in the right pane, or as a page.
void openSession(
  GoRouter router,
  PaneSelectionNotifier panes,
  Session session,
) {
  panes.showSession(session);
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null || !useTwoPane(context)) {
    router.push(sessionLocation(session), extra: session);
  }
}
