import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../chat/chat_screen.dart';
import '../projects/app_drawer.dart';
import '../projects/projects_screen.dart';
import '../sessions/sessions_screen.dart';
import 'pane_selection.dart';

/// Tablet layout: the project list, or one project's sessions, on the left
/// and the open session's chat on the right.
class TwoPaneHome extends ConsumerStatefulWidget {
  const TwoPaneHome({super.key});

  /// Width of the left pane.
  static const double listWidth = 320;

  @override
  ConsumerState<TwoPaneHome> createState() => _TwoPaneHomeState();
}

class _TwoPaneHomeState extends ConsumerState<TwoPaneHome> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(paneSelectionProvider);
    final project = selection.project;
    final session = selection.session;
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return Scaffold(
      key: _scaffold,
      // The drawer covers both panes. Nothing here swipes back, so its edge
      // swipe has the left edge to itself.
      drawer: const AppDrawer(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: TwoPaneHome.listWidth,
            child: _ListSwitcher(
              forward: project != null,
              child: project == null
                  ? ProjectsPane(
                      key: const ValueKey('projects-pane'),
                      onMenu: () => _scaffold.currentState?.openDrawer(),
                    )
                  : SessionsScreen(
                      key: ValueKey('sessions-${project.id}'),
                      project: project,
                      pane: true,
                    ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: divider),
          Expanded(
            child: session == null
                ? const _NoSession()
                : ChatScreen(
                    key: ValueKey('chat-${session.id}'),
                    session: session,
                    pane: true,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Slides the left pane sideways between the project list and a project's
/// sessions, like the pages it replaces.
class _ListSwitcher extends StatelessWidget {
  const _ListSwitcher({required this.forward, required this.child});

  /// Whether the new child goes deeper (comes in from the right).
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: instant ? Duration.zero : const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) {
          // Going deeper, the new list comes in from the right and the old
          // one leaves to the left; going back, the other way round.
          final incoming = child.key == this.child.key;
          final side = (forward ? 1.0 : -1.0) * (incoming ? 1 : -1);
          return SlideTransition(
            position: Tween(
              begin: Offset(side, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// The right pane before a session is picked.
class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.chatPaneEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
