import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import 'project_providers.dart';
import 'server_path.dart';

/// Browses the server's folders in a bottom sheet and opens the chosen one
/// as a project. Moving between folders swaps the sheet's contents instead
/// of pushing pages, so dismissing the sheet always returns to where it was
/// opened.
class FolderPickerSheet extends ConsumerStatefulWidget {
  const FolderPickerSheet({super.key});

  /// Resolves to the opened project, or null when the sheet is dismissed.
  static Future<Project?> show(BuildContext context) =>
      showModalBottomSheet<Project>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.94,
          child: FolderPickerSheet(),
        ),
      );

  @override
  ConsumerState<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<FolderPickerSheet> {
  /// Folder being shown; null until the server's directory is known.
  String? _directory;
  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _showHidden = false;
  bool _opening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _go(String directory) => setState(() {
    _directory = directory;
    _debounce?.cancel();
    _search.clear();
    _query = '';
  });

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _query = value.trim()),
    );
  }

  Future<void> _enterPath(String directory) async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => _PathDialog(initial: directory),
    );
    if (path != null) _go(path);
  }

  Future<void> _open(String directory) async {
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _opening = true);
    try {
      final project = await client.openProject(directory);
      if (mounted) Navigator.of(context).pop(project);
    } on OpenCodeApiException catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.projectOpenFailed(e.detail))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = ref.watch(serverDirectoryProvider);
    final directory = _directory ?? start.value;
    final l10n = context.l10n;

    // Its own messenger keeps snack bars inside the sheet, above the
    // project list it covers.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chooseFolder,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    key: const Key('toggle-hidden'),
                    tooltip: _showHidden
                        ? l10n.hideHiddenFolders
                        : l10n.showHiddenFolders,
                    icon: Icon(
                      _showHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _showHidden = !_showHidden),
                  ),
                  IconButton(
                    key: const Key('enter-path'),
                    tooltip: l10n.enterFolderPath,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: directory == null
                        ? null
                        : () => _enterPath(directory),
                  ),
                  IconButton(
                    key: const Key('close-folder-picker'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (directory == null)
              Expanded(
                child: start.hasError
                    ? _Message(
                        text: l10n.foldersLoadFailed(_detail(start.error)),
                        onRetry: () => ref.invalidate(serverDirectoryProvider),
                      )
                    : const Center(child: CircularProgressIndicator()),
              )
            else ...[
              _PathBar(path: directory, onGo: _go),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  key: const Key('folder-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchFolders,
                    isDense: true,
                  ),
                  onChanged: _onSearch,
                ),
              ),
              Expanded(child: _folderList(directory)),
            ],
          ],
        ),
        bottomNavigationBar: directory == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const Key('open-folder'),
                    onPressed: _opening ? null : () => _open(directory),
                    icon: _opening
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(l10n.openThisFolder),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _folderList(String directory) {
    final searching = _query.isNotEmpty;
    final provider = searching
        ? folderSearchProvider((directory, _query))
        : subfoldersProvider(directory);
    return ref
        .watch(provider)
        .when(
          data: (entries) {
            final visible = [
              for (final e in entries)
                if (_showHidden || !_isHidden(e)) e,
            ];
            if (visible.isEmpty) {
              return _Message(
                text: searching
                    ? context.l10n.notFound
                    : context.l10n.noSubfolders,
              );
            }
            return ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final entry = visible[index];
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(ServerPath.name(entry.path)),
                  subtitle: searching
                      ? Text(
                          ServerPath.normalize(entry.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _go(ServerPath.join(directory, entry.path)),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            text: context.l10n.foldersLoadFailed(_detail(e)),
            onRetry: () => ref.invalidate(provider),
          ),
        );
  }

  static bool _isHidden(FsEntry entry) =>
      ServerPath.name(entry.path).startsWith('.');

  static Object _detail(Object? error) =>
      error is OpenCodeApiException ? error.detail : error ?? '';
}

/// The parent-folder button and the current folder as tappable segments
/// from the root, scrolled so the deepest one stays visible.
class _PathBar extends StatelessWidget {
  const _PathBar({required this.path, required this.onGo});

  final String path;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final crumbs = ServerPath.crumbs(path);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: AppFonts.mono,
    );
    final parent = ServerPath.parent(path);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            key: const Key('folder-up'),
            tooltip: context.l10n.parentFolder,
            icon: const Icon(Icons.arrow_upward),
            onPressed: parent == null ? null : () => onGo(parent),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const Key('breadcrumbs'),
                scrollDirection: Axis.horizontal,
                reverse: true,
                padding: const EdgeInsets.only(right: 12),
                // Short paths stay left-aligned despite the reversed scroll.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth - 12,
                  ),
                  child: Row(
                    children: [
                      for (final (i, (label, crumbPath)) in crumbs.indexed) ...[
                        if (i > 0)
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: i == crumbs.length - 1
                              ? null
                              : () => onGo(crumbPath),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              label,
                              style: i == crumbs.length - 1
                                  ? style?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    )
                                  : style?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(context.l10n.reload),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for an absolute folder path to jump to.
class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.initial});

  final String initial;

  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final path = ServerPath.normalize(_controller.text);
    if (!ServerPath.isAbsolute(path)) {
      setState(() => _error = context.l10n.projectFolderMustBeAbsolute);
      return;
    }
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.enterFolderPath),
      content: TextField(
        key: const Key('folder-path'),
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontFamily: AppFonts.mono),
        decoration: InputDecoration(
          labelText: context.l10n.projectFolderLabel,
          hintText: context.l10n.projectFolderHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-folder-path'),
          onPressed: _submit,
          child: Text(context.l10n.goToFolder),
        ),
      ],
    );
  }
}
