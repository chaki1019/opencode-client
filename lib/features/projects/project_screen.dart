import 'package:flutter/material.dart';

import '../../core/models/project.dart';
import '../files/files_screen.dart';
import '../git/git_screen.dart';
import '../mcp/mcp_screen.dart';
import '../sessions/sessions_screen.dart';

/// A project's sessions, Git changes, files and MCP servers as tabs. A tab is
/// built the first time it is opened and then kept alive.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  int _index = 0;
  final _opened = <int>{0};

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget Function()>[
      () => SessionsScreen(project: widget.project),
      () => GitScreen(project: widget.project),
      () => FilesScreen(project: widget.project),
      () => McpScreen(project: widget.project),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _opened.contains(i) ? tabs[i]() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _opened.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'セッション',
          ),
          NavigationDestination(icon: Icon(Icons.call_split), label: 'Git'),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'ファイル',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            label: 'MCP',
          ),
        ],
      ),
    );
  }
}
