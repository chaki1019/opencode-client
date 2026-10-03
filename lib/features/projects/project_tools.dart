import 'package:flutter/material.dart';

import '../../core/models/project.dart';
import '../../l10n/l10n.dart';
import '../files/files_screen.dart';
import '../git/git_screen.dart';
import '../live/live_widgets.dart';
import '../mcp/mcp_screen.dart';
import '../terminal/terminal_screen.dart';

enum _ProjectTool { git, files, mcp, terminal }

/// Header button that opens a project's Git, files, MCP servers and
/// terminals. Git, files and MCP open as bottom sheets over the session
/// list; terminals need the whole screen for the keyboard, so they open as
/// a page.
class ProjectToolsButton extends StatelessWidget {
  const ProjectToolsButton({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_ProjectTool>(
      key: const Key('project-tools'),
      tooltip: l10n.projectTools,
      icon: const Icon(Icons.more_vert),
      onSelected: (tool) => switch (tool) {
        _ProjectTool.git => _showSheet(context, GitScreen(project: project)),
        _ProjectTool.files => _showSheet(
          context,
          FilesScreen(project: project),
        ),
        _ProjectTool.mcp => _showSheet(context, McpScreen(project: project)),
        _ProjectTool.terminal => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TerminalsScreen(project: project),
          ),
        ),
      },
      itemBuilder: (context) => [
        _item(_ProjectTool.git, Icons.call_split, 'Git'),
        _item(_ProjectTool.files, Icons.folder_outlined, l10n.files),
        _item(_ProjectTool.mcp, Icons.extension_outlined, 'MCP'),
        _item(_ProjectTool.terminal, Icons.terminal, l10n.terminal),
      ],
    );
  }

  static PopupMenuItem<_ProjectTool> _item(
    _ProjectTool tool,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: tool,
    child: Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    ),
  );

  static Future<void> _showSheet(BuildContext context, Widget child) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: child),
      );
}

/// App bar for a tool shown in a project's bottom sheet: it sits under the
/// sheet's drag handle and takes the sheet's color.
AppBar toolSheetAppBar({required String title, List<Widget>? actions}) =>
    AppBar(
      title: Text(title),
      // The theme's spacing leaves room for a back button, which a sheet
      // doesn't have; line the title and actions up with the content.
      titleSpacing: 16,
      actionsPadding: const EdgeInsets.only(right: 8),
      primary: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      bottom: const LiveStatusBanner(),
      actions: actions,
    );
