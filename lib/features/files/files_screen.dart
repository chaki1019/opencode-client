import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../l10n/l10n.dart';
import '../chat/timeline_widgets.dart';
import '../live/live_widgets.dart';
import 'files_providers.dart';

/// Browses the project's folders, or searches files by name.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  /// Folder being shown, relative to the project; empty for the root.
  String _path = '';
  String _query = '';
  Timer? _debounce;

  String get _directory => widget.project.directory;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _query = value.trim()),
    );
  }

  void _open(FsEntry entry) {
    if (entry.isDirectory) {
      setState(() => _path = _stripSlash(entry.path));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerScreen(directory: _directory, entry: entry),
        ),
      );
    }
  }

  void _up() {
    final i = _path.lastIndexOf('/');
    setState(() => _path = i < 0 ? '' : _path.substring(0, i));
  }

  static String _stripSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final provider = searching
        ? fileSearchProvider((_directory, _query))
        : folderProvider((_directory, _path));
    final entries = ref.watch(provider);

    return PopScope(
      canPop: _path.isEmpty || searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.displayName),
          bottom: const LiveStatusBanner(),
          actions: [
            IconButton(
              tooltip: context.l10n.reload,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(provider),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                key: const Key('file-search'),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: context.l10n.searchFiles,
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _search,
              ),
            ),
            if (!searching && _path.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.arrow_upward),
                title: Text(_path, overflow: TextOverflow.ellipsis),
                onTap: _up,
              ),
            Expanded(
              child: entries.when(
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          searching
                              ? context.l10n.notFound
                              : context.l10n.emptyFolder,
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final entry = list[index];
                          return ListTile(
                            leading: Icon(
                              entry.isDirectory
                                  ? Icons.folder_outlined
                                  : Icons.description_outlined,
                            ),
                            title: Text(entry.name),
                            subtitle: searching
                                ? Text(
                                    entry.path,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _open(entry),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.l10n.filesLoadFailed(e)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a text file, an image, or the size of anything else.
class FileViewerScreen extends ConsumerWidget {
  const FileViewerScreen({
    super.key,
    required this.directory,
    required this.entry,
  });

  final String directory;
  final FsEntry entry;

  /// Longer text is cut so the viewer stays responsive.
  static const _maxChars = 200000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(fileContentProvider((directory, entry.path)));
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: content.when(
        data: (file) {
          if (file.isImage) {
            return InteractiveViewer(
              child: Center(
                child: Image.memory(Uint8List.fromList(file.bytes)),
              ),
            );
          }
          final text = file.text;
          if (text == null) {
            return Center(
              child: Text(context.l10n.binaryFile(file.bytes.length)),
            );
          }
          final truncated = text.length > _maxChars;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              MonospaceBlock(
                text: truncated ? text.substring(0, _maxChars) : text,
                maxLines: 1 << 30,
              ),
              if (truncated)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(context.l10n.fileTruncated),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.l10n.fileOpenFailed(e)),
        ),
      ),
    );
  }
}
