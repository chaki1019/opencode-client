import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/project.dart';
import '../features/connection/connection_providers.dart';
import '../features/connection/connection_screen.dart';
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
          GoRoute(
            path: ':projectId',
            redirect: (context, state) =>
                state.extra is Project ? null : '/projects',
            builder: (context, state) =>
                ProjectDetailScreen(project: state.extra! as Project),
          ),
        ],
      ),
    ],
  );
});
