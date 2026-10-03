import 'package:flutter/material.dart';

import '../../core/models/project_tools.dart';

/// A folder in a tree of changed files. [name] may span several path
/// segments when a folder holds nothing but one other folder.
class ChangeFolder {
  ChangeFolder(this.name, this.path);

  final String name;

  /// Full path from the project root; empty for the root.
  final String path;
  final folders = <ChangeFolder>[];
  final files = <FileChange>[];
}

/// Groups [changes] by folder, folders first and each level sorted by name.
ChangeFolder buildChangeTree(List<FileChange> changes) {
  final root = ChangeFolder('', '');
  for (final change in changes) {
    final parts = change.file.split('/');
    var folder = root;
    for (final part in parts.take(parts.length - 1)) {
      folder = folder.folders.firstWhere(
        (f) => f.name == part,
        orElse: () {
          final child = ChangeFolder(
            part,
            folder.path.isEmpty ? part : '${folder.path}/$part',
          );
          folder.folders.add(child);
          return child;
        },
      );
    }
    folder.files.add(change);
  }
  return _compact(root, isRoot: true);
}

ChangeFolder _compact(ChangeFolder folder, {bool isRoot = false}) {
  var current = folder;
  var name = folder.name;
  while (!isRoot && current.files.isEmpty && current.folders.length == 1) {
    current = current.folders.single;
    name = '$name/${current.name}';
  }
  final result = ChangeFolder(name, current.path)
    ..folders.addAll(
      [for (final child in current.folders) _compact(child)]
        ..sort((a, b) => a.name.compareTo(b.name)),
    )
    ..files.addAll(
      [...current.files]..sort((a, b) => _fileName(a).compareTo(_fileName(b))),
    );
  return result;
}

String _fileName(FileChange change) =>
    change.file.substring(change.file.lastIndexOf('/') + 1);

/// Changed files as a folder tree. Folders start open and collapse on tap.
class ChangeTree extends StatefulWidget {
  const ChangeTree({super.key, required this.changes, required this.fileTile});

  final List<FileChange> changes;

  /// Builds the row for one file, indented by [indent].
  final Widget Function(FileChange change, String name, double indent) fileTile;

  @override
  State<ChangeTree> createState() => _ChangeTreeState();
}

class _ChangeTreeState extends State<ChangeTree> {
  static const _step = 16.0;
  final _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(ChangeFolder folder, int depth) {
      for (final child in folder.folders) {
        final open = !_collapsed.contains(child.path);
        rows.add(
          ListTile(
            dense: true,
            minTileHeight: 40,
            contentPadding: EdgeInsets.only(
              left: 16 + depth * _step,
              right: 16,
            ),
            horizontalTitleGap: 8,
            minLeadingWidth: 0,
            leading: Icon(
              open ? Icons.expand_more : Icons.chevron_right,
              size: 20,
            ),
            title: Text(
              child.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () => setState(() {
              if (!_collapsed.remove(child.path)) _collapsed.add(child.path);
            }),
          ),
        );
        if (open) add(child, depth + 1);
      }
      for (final file in folder.files) {
        rows.add(widget.fileTile(file, _fileName(file), 16 + depth * _step));
      }
    }

    add(buildChangeTree(widget.changes), 0);
    return ListView(children: rows);
  }
}
