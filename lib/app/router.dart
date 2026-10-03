import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/project.dart';
import '../core/models/session.dart';
import '../features/chat/chat_screen.dart';
import '../features/connection/connection_providers.dart';
import '../features/connection/connection_screen.dart';
import '../features/projects/project_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/push/push_settings_screen.dart';

/// go_router 18 only recognizes `material_ui`'s MaterialApp and otherwise
/// falls back to pages without any transition, so every route builds its
/// [MaterialPage] itself to get the theme's slide.
Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the connection changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(connectionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final connected = ref.read(connectionProvider) != null;
      final atConnect = state.matchedLocation == '/';
      if (!connected && !atConnect) return '/';
      if (connected && atConnect) return '/projects';
      return null;
    },
    routes: [
      // The project list stacks on top of the connect screen, so connecting
      // pushes it in and disconnecting pops it back out instead of sliding
      // the connect screen in as a new page.
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _page(state, const ConnectionScreen()),
        routes: [
          GoRoute(
            path: 'projects',
            pageBuilder: (context, state) =>
                _page(state, const ProjectsScreen()),
            routes: [
              // Screens receive their model through `extra`; deep links without
              // it fall back to the project list.
              GoRoute(
                path: ':projectId',
                redirect: (context, state) =>
                    state.extra is Project ? null : '/projects',
                pageBuilder: (context, state) => _page(
                  state,
                  ProjectScreen(project: state.extra! as Project),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/push',
        pageBuilder: (context, state) =>
            _page(state, const PushSettingsScreen()),
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        redirect: (context, state) =>
            state.extra is Session ? null : '/projects',
        pageBuilder: (context, state) =>
            _page(state, ChatScreen(session: state.extra! as Session)),
      ),
    ],
  );
});
