import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/opencode_client.dart';
import '../connection/connection_providers.dart';

final projectsProvider = FutureProvider.autoDispose<ProjectBootstrap>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection == null) {
    return const ProjectBootstrap(projects: []);
  }
  return connection.client.loadProjects();
});
