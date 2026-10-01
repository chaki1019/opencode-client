import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/opencode_client.dart';
import '../../core/events/server_event.dart';
import '../../core/models/form.dart';
import '../../core/models/prompts.dart';
import '../../core/models/session.dart';
import '../../core/models/timeline.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import 'chat_providers.dart';

/// Requests from one session that wait on the user, loaded once and then
/// kept current by "asked" and "settled" events. Events that arrive during
/// the load are applied to its result; a reconnect reloads.
abstract class PendingRequestsNotifier<T> extends AsyncNotifier<List<T>> {
  PendingRequestsNotifier(this.sessionId);

  final String sessionId;
  List<ServerEvent>? _buffer;

  Future<List<T>> fetch(OpenCodeClient client);
  String idOf(T item);

  /// The request [event] announces, if any.
  T? added(ServerEvent event);

  /// The ID of the request [event] settles, if any.
  String? settled(ServerEvent event);

  @override
  Future<List<T>> build() async {
    final client = ref.watch(connectionProvider)?.client;
    if (client == null) return const [];
    _buffer = [];
    listenToServerEvents(ref, onEvent: _onEvent, onResync: _reload);
    try {
      var items = await fetch(client);
      for (final event in _buffer ?? const <ServerEvent>[]) {
        items = _apply(items, event);
      }
      return items;
    } finally {
      _buffer = null;
    }
  }

  /// Drops [id] without waiting for the server's event.
  void remove(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => idOf(r) != id).toList());
  }

  void _onEvent(ServerEvent event) {
    if (event.sessionId != sessionId) return;
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(event);
      return;
    }
    final current = state.value;
    if (current == null) return;
    final next = _apply(current, event);
    if (!identical(next, current)) state = AsyncData(next);
  }

  List<T> _apply(List<T> items, ServerEvent event) {
    final item = added(event);
    if (item != null) {
      final id = idOf(item);
      final index = items.indexWhere((r) => idOf(r) == id);
      return index < 0 ? [...items, item] : ([...items]..[index] = item);
    }
    final id = settled(event);
    if (id != null && items.any((r) => idOf(r) == id)) {
      return items.where((r) => idOf(r) != id).toList();
    }
    return items;
  }

  Future<void> _reload() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    try {
      final items = await fetch(client);
      if (ref.mounted) state = AsyncData(items);
    } on OpenCodeApiException {
      // Keep what we have; the next reconnect or event tries again.
    }
  }

  /// Runs [action] for request [id]. When the server says the request is
  /// already gone (answered elsewhere), it is dropped instead of failing.
  Future<void> settle(String id, Future<void> Function() action) async {
    try {
      await action();
    } on OpenCodeApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 409) rethrow;
    }
    if (ref.mounted) remove(id);
  }
}

class PermissionsNotifier extends PendingRequestsNotifier<PermissionRequest> {
  PermissionsNotifier(super.sessionId);

  @override
  Future<List<PermissionRequest>> fetch(OpenCodeClient client) =>
      client.listPermissions(sessionId);

  @override
  String idOf(PermissionRequest item) => item.id;

  @override
  PermissionRequest? added(ServerEvent event) =>
      event.type == 'permission.asked'
      ? PermissionRequest.tryParse(event.data)
      : null;

  @override
  String? settled(ServerEvent event) => event.type == 'permission.replied'
      ? (event.data['requestID'] ?? event.data['id']) as String?
      : null;

  Future<void> reply(PermissionRequest request, PermissionDecision decision) {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return Future.value();
    return settle(request.id, () => client.replyPermission(request, decision));
  }
}

final permissionsProvider = AsyncNotifierProvider.autoDispose
    .family<PermissionsNotifier, List<PermissionRequest>, String>(
      PermissionsNotifier.new,
    );

class FormsNotifier extends PendingRequestsNotifier<FormRequest> {
  FormsNotifier(this.session) : super(session.id);

  final Session session;

  String get _directory => session.location.directory;

  @override
  Future<List<FormRequest>> fetch(OpenCodeClient client) =>
      client.listForms(sessionId, directory: _directory);

  @override
  String idOf(FormRequest item) => item.id;

  @override
  FormRequest? added(ServerEvent event) => event.type == 'form.created'
      ? FormRequest.tryParse(event.data['form'])
      : null;

  @override
  String? settled(ServerEvent event) =>
      event.type == 'form.replied' || event.type == 'form.cancelled'
      ? event.data['id'] as String?
      : null;

  Future<void> submit(FormRequest form, Map<String, Object> answer) {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return Future.value();
    return settle(
      form.id,
      () => client.replyForm(form, directory: _directory, answer: answer),
    );
  }

  Future<void> cancel(FormRequest form) {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return Future.value();
    return settle(
      form.id,
      () => client.cancelForm(form, directory: _directory),
    );
  }
}

final formsProvider = AsyncNotifierProvider.autoDispose
    .family<FormsNotifier, List<FormRequest>, Session>(FormsNotifier.new);

/// The agent's current todo list: the input of the latest todo-writing tool
/// call in the loaded transcript. Null when there is none.
final todosProvider = Provider.autoDispose.family<List<TodoItem>?, String>((
  ref,
  sessionId,
) {
  final entries =
      ref.watch(timelineProvider(sessionId)).value?.items ?? const [];
  for (final entry in entries.reversed) {
    if (entry is! AssistantEntry) continue;
    for (final content in entry.content.reversed) {
      if (content is ToolContent && TodoItem.isTodoTool(content.name)) {
        final todos = TodoItem.fromToolInput(content.input);
        if (todos != null) return todos;
      }
    }
  }
  return null;
});
