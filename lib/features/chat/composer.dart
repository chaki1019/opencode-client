import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/models/attachment.dart';
import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../connection/connection_providers.dart';
import '../live/live_providers.dart';
import 'agent_labels.dart';
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
  List<PromptFile> _files = const [];
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
    final files = _files;
    if (text.isEmpty && files.isEmpty) return;
    _controller.clear();
    setState(() => _files = const []);
    final ok = await ref
        .read(pendingPromptsProvider(widget.session.id).notifier)
        .send(text, files: files);
    if (!ok && mounted) {
      // Rejected: put the text and attachments back so nothing is lost.
      if (_controller.text.isEmpty) _controller.text = text;
      if (_files.isEmpty) setState(() => _files = files);
      _showError('送信できませんでした。内容を確認してもう一度送ってください');
    }
  }

  Future<void> _attach() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('attach-library'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('写真を選ぶ'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('写真を撮る'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final List<PromptFile> picked;
    try {
      picked = await ref.read(pickImagesProvider)(camera: camera);
    } catch (e) {
      _showError('画像を読み込めませんでした: $e');
      return;
    }
    if (picked.isEmpty || !mounted) return;
    final problem = PromptFile.checkLimits(_files, picked);
    if (problem != null) {
      _showError(problem);
      return;
    }
    setState(() => _files = [..._files, ...picked]);
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
    final canSend = _controller.text.trim().isNotEmpty || _files.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_files.isNotEmpty)
                  _AttachmentStrip(
                    files: _files,
                    onRemove: (i) =>
                        setState(() => _files = [..._files]..removeAt(i)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      key: const Key('attach'),
                      tooltip: '画像を添付',
                      onPressed: _attach,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('composer'),
                        controller: _controller,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'メッセージを入力',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (busy && !canSend)
                      IconButton.filledTonal(
                        key: const Key('stop'),
                        tooltip: '中断',
                        style: _buttonStyle,
                        onPressed: _stopping ? null : _stop,
                        icon: const Icon(Icons.stop_rounded),
                      )
                    else
                      IconButton.filled(
                        key: const Key('send'),
                        tooltip: '送信',
                        style: _buttonStyle,
                        onPressed: canSend ? _send : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                  ],
                ),
                _SettingsRow(session: widget.session),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _buttonStyle = IconButton.styleFrom(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

/// Thumbnails of the images about to be sent, each with a remove button.
class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.files, required this.onRemove});

  final List<PromptFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Stack(
          key: Key('attachment-$index'),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: files[index].isImage
                  ? Image.memory(
                      files[index].bytes,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                tooltip: '添付を外す',
                iconSize: 18,
                onPressed: () => onRemove(index),
                icon: const Icon(Icons.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    width: 64,
    height: 64,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.insert_drive_file_outlined),
  );
}

class _SettingsRow extends ConsumerWidget {
  const _SettingsRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sessionSettingsProvider(session));
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          ActionChip(
            avatar: Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: scheme.primary,
            ),
            label: Text(
              settings.agent == null
                  ? 'エージェント'
                  : agentDisplayName(settings.agent!),
              style: TextStyle(color: scheme.primary),
            ),
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            visualDensity: VisualDensity.compact,
            onPressed: () => _pickAgent(context, ref),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.memory, size: 16),
            label: Text(settings.model?.label ?? 'モデル'),
            visualDensity: VisualDensity.compact,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'エージェント',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final agent in list) _agentTile(context, agent),
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

  Widget _agentTile(BuildContext context, AgentInfo agent) {
    final description = agentDescription(agent.id, agent.description);
    return ListTile(
      title: Text(agentDisplayName(agent.id)),
      subtitle: description == null
          ? null
          : Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.pop(context, agent.id),
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
