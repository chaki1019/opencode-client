import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import 'composer_providers.dart';

/// Input row at the bottom of the chat, with the agent and model in use.
/// While the session is running, the send button becomes a stop button.
class Composer extends ConsumerStatefulWidget {
  const Composer({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _controller = TextEditingController();
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final ok = await ref
        .read(pendingPromptsProvider(widget.session.id).notifier)
        .send(text);
    if (!ok && mounted) {
      // Rejected: put the text back so nothing is lost.
      if (_controller.text.isEmpty) _controller.text = text;
      _showError('送信できませんでした。内容を確認してもう一度送ってください');
    }
  }

  Future<void> _stop() async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    setState(() => _stopping = true);
    try {
      await client.interrupt(widget.session.id);
    } on OpenCodeApiException catch (e) {
      _showError('中断できませんでした: $e');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(
      activeSessionsProvider.select((ids) => ids.contains(widget.session.id)),
    );
    final canSend = _controller.text.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsRow(session: widget.session),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('composer'),
                      controller: _controller,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'メッセージを入力',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (busy && !canSend)
                    IconButton.filledTonal(
                      key: const Key('stop'),
                      tooltip: '中断',
                      onPressed: _stopping ? null : _stop,
                      icon: const Icon(Icons.stop),
                    )
                  else
                    IconButton.filled(
                      key: const Key('send'),
                      tooltip: '送信',
                      onPressed: canSend ? _send : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends ConsumerWidget {
  const _SettingsRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sessionSettingsProvider(session));
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ActionChip(
            avatar: const Icon(Icons.smart_toy_outlined, size: 18),
            label: Text(settings.agent ?? 'エージェント'),
            onPressed: () => _pickAgent(context, ref),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.memory, size: 18),
            label: Text(settings.model?.label ?? 'モデル'),
            onPressed: () => _pickModel(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAgent(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AgentSheet(directory: session.location.directory),
    );
    if (picked == null) return;
    await _apply(
      messenger,
      () => ref
          .read(sessionSettingsProvider(session).notifier)
          .selectAgent(picked),
    );
  }

  Future<void> _pickModel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<ModelRef>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ModelSheet(directory: session.location.directory),
    );
    if (picked == null) return;
    await _apply(
      messenger,
      () => ref
          .read(sessionSettingsProvider(session).notifier)
          .selectModel(picked),
    );
  }

  Future<void> _apply(
    ScaffoldMessengerState messenger,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('変更できませんでした: $e')));
    }
  }
}

class _AgentSheet extends ConsumerWidget {
  const _AgentSheet({required this.directory});

  final String directory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider(directory));
    return agents.when(
      data: (list) => ListView(
        shrinkWrap: true,
        children: [
          for (final agent in list)
            ListTile(
              title: Text(agent.id),
              subtitle: agent.description == null
                  ? null
                  : Text(
                      agent.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.pop(context, agent.id),
            ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('エージェントを読み込めませんでした: $e'),
      ),
    );
  }
}

class _ModelSheet extends ConsumerStatefulWidget {
  const _ModelSheet({required this.directory});

  final String directory;

  @override
  ConsumerState<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends ConsumerState<_ModelSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelsProvider(widget.directory));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'モデルを検索',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: models.when(
              data: (list) {
                final filtered = list
                    .where(
                      (m) =>
                          _query.isEmpty ||
                          m.name.toLowerCase().contains(_query) ||
                          m.id.toLowerCase().contains(_query) ||
                          m.providerName.toLowerCase().contains(_query),
                    )
                    .toList();
                return ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ModelTile(option: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('モデルを読み込めませんでした: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.option});

  final ModelOption option;

  @override
  Widget build(BuildContext context) {
    ModelRef ref([String? variant]) => ModelRef(
      providerID: option.providerID,
      id: option.id,
      variant: variant,
    );
    return ListTile(
      title: Text(option.name),
      subtitle: Text(option.providerName),
      onTap: () => Navigator.pop(context, ref()),
      trailing: option.variants.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: 'バリアント',
              icon: const Icon(Icons.tune),
              onSelected: (v) => Navigator.pop(context, ref(v)),
              itemBuilder: (_) => [
                for (final v in option.variants)
                  PopupMenuItem(value: v, child: Text(v)),
              ],
            ),
    );
  }
}
