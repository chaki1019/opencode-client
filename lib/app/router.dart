import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/project.dart';
import '../core/models/session.dart';
import '../features/chat/chat_screen.dart';
import '../features/connection/connection_providers.dart';
import '../features/connection/connection_screen.dart';
import '../features/projects/project_screen.dart';
import '../features/projects/projects_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the connection changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(connectionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/connect',
    refreshListenable: refresh,
    redirect: (context, state) {
      final connected = ref.read(connectionProvider) != null;
      final atConnect = state.matchedLocation == '/connect';
      if (!connected && !atConnect) return '/connect';
      if (connected && atConnect) return '/projects';
      return null;
    },
    routes: [
      GoRoute(
        path: '/connect',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsScreen(),
        routes: [
          // Screens receive their model through `extra`; deep links without
          // it fall back to the project list.
          GoRoute(
            path: ':projectId',
            redirect: (context, state) =>
                state.extra is Project ? null : '/projects',
            builder: (context, state) =>
                ProjectScreen(project: state.extra! as Project),
          ),
        ],
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        redirect: (context, state) =>
            state.extra is Session ? null : '/projects',
        builder: (context, state) =>
            ChatScreen(session: state.extra! as Session),
      ),
    ],
  );
});
