import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/analytics/session_replay.dart';
import '../core/models/project.dart';
import '../core/models/session.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/connection/connection_providers.dart';
import '../features/connection/connection_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/push/push_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_providers.dart';
import '../features/sessions/sessions_screen.dart';

/// go_router 18 only recognizes `material_ui`'s MaterialApp and otherwise
/// falls back to pages without any transition, so every route builds its
/// [MaterialPage] itself to get the theme's slide. The page is named after
/// its route pattern (`/sessions/:sessionId`), which usage analytics and
/// session replay report as the screen, so no IDs leave the device.
Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, name: state.fullPath, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the connection changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(connectionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final analyticsObserver = ref.read(usageAnalyticsProvider).observer;
  final replayObserver = ref.read(sessionReplayProvider).observer;
  return GoRouter(
    initialLocation: '/',
    observers: [?analyticsObserver, ?replayObserver],
    refreshListenable: refresh,
    redirect: (context, state) {
      final connected = ref.read(connectionProvider) != null;
      final atConnect = state.matchedLocation == '/';
      // App settings do not need a server.
      if (state.matchedLocation == '/settings') return null;
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
                  SessionsScreen(project: state.extra! as Project),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/add-server',
        pageBuilder: (context, state) =>
            _page(state, const ConnectionScreen(adding: true)),
      ),
      GoRoute(
        path: '/settings',
        // Only the app's own text is shown here, so session recordings may
        // show it in full.
        pageBuilder: (context, state) =>
            _page(state, const SessionReplayUnmask(child: SettingsScreen())),
      ),
      GoRoute(
        path: '/diagnostics',
        pageBuilder: (context, state) =>
            _page(state, const DiagnosticsScreen()),
      ),
      GoRoute(
        path: '/push',
        pageBuilder: (context, state) =>
            _page(state, const PushSettingsScreen()),
      ),
      GoRoute(
        path: '/push/:serverId',
        pageBuilder: (context, state) => _page(
          state,
          PushSettingsScreen(serverId: state.pathParameters['serverId']),
        ),
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
