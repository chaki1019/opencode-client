import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/project.dart';
import '../../core/models/project_tools.dart';
import '../../core/terminal/pty_connection.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import '../live/live_widgets.dart';
import 'terminal_providers.dart';

/// The project's terminals. Opening one attaches to its shell.
class TerminalsScreen extends ConsumerWidget {
  const TerminalsScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ptyListProvider(project.directory);
    final ptys = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(project.displayName),
        bottom: const LiveStatusBanner(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-terminal'),
        // Tabs share one route, so the default tag would clash.
        heroTag: null,
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newTerminal),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: ptys.when(
          data: (list) => list.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [Center(child: Text(context.l10n.terminalsEmpty))],
                )
              : ListView(
                  children: [
                    for (final pty in list)
                      ListTile(
                        leading: Icon(
                          Icons.terminal,
                          color: pty.isRunning
                              ? AppColors.of(context).running
                              : Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(pty.displayTitle),
                        subtitle: Text(
                          pty.isRunning
                              ? (pty.cwd ?? pty.command ?? '')
                              : context.l10n.terminalExited(
                                  pty.exitCode ?? '-',
                                ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: context.l10n.close,
                          icon: const Icon(Icons.close),
                          onPressed: () => _delete(context, ref, pty),
                        ),
                        onTap: () => _open(context, pty),
                      ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(context.l10n.terminalsLoadFailed(e))],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Pty pty) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TerminalScreen(directory: project.directory, pty: pty),
    ),
  );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final pty = await ref
          .read(ptyListProvider(project.directory).notifier)
          .create(l10n.terminalTitle);
      if (pty != null && context.mounted) _open(context, pty);
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.terminalOpenFailed(e.detail))),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Pty pty) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(ptyListProvider(project.directory).notifier).delete(pty);
    } on OpenCodeApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.closeFailed(e.detail))),
      );
    }
  }
}

/// A live terminal attached to [pty] over WebSocket.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, required this.directory, required this.pty});

  final String directory;
  final Pty pty;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _terminal = Terminal(maxLines: 10000);
  PtyConnection? _connection;
  PtyConnectionState _state = PtyConnectionState.connecting;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _resizeDebounce;

  @override
  void initState() {
    super.initState();
    final client = ref.read(connectionProvider)?.client;
    if (client == null) return;
    final connection = PtyConnection(
      uriFor: (cursor) => client.ptySocketUri(
        widget.pty.id,
        directory: widget.directory,
        cursor: cursor,
      ),
      headers: {
        ...client.socketHeaders,
        'x-opencode-directory': Uri.encodeComponent(widget.directory),
      },
    );
    _connection = connection;
    _subscriptions
      ..add(connection.output.listen(_terminal.write))
      ..add(
        connection.stateChanges.listen((s) {
          if (mounted) setState(() => _state = s);
        }),
      );
    _terminal
      ..onOutput = connection.send
      ..onResize = (cols, rows, _, _) {
        _resizeDebounce?.cancel();
        _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
          unawaited(
            client
                .resizePty(
                  widget.pty.id,
                  directory: widget.directory,
                  rows: rows,
                  cols: cols,
                )
                .catchError((_) {}),
          );
        });
      };
    unawaited(connection.connect());
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_connection?.dispose());
    super.dispose();
  }

  void _key(TerminalKey key) => _terminal.keyInput(key);
  void _ctrl(String letter) =>
      _terminal.charInput(letter.codeUnitAt(0), ctrl: true);

  @override
  Widget build(BuildContext context) {
    final banner = switch (_state) {
      PtyConnectionState.connecting => context.l10n.ptyConnecting,
      PtyConnectionState.failed => context.l10n.ptyFailed,
      PtyConnectionState.closed => context.l10n.ptyClosed,
      PtyConnectionState.open => null,
    };
    return Scaffold(
      backgroundColor: terminalTheme.background,
      appBar: AppBar(
        title: Text(widget.pty.displayTitle),
        bottom: banner == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(banner),
                    if (_state == PtyConnectionState.failed)
                      TextButton(
                        onPressed: () => _connection?.connect(),
                        child: Text(context.l10n.reconnect),
                      ),
                  ],
                ),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                theme: terminalTheme,
                textStyle: const TerminalStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 13,
                ),
              ),
            ),
            _ExtraKeys(onKey: _key, onCtrl: _ctrl, onText: _terminal.textInput),
          ],
        ),
      ),
    );
  }
}

/// Keys a phone keyboard lacks.
class _ExtraKeys extends StatelessWidget {
  const _ExtraKeys({
    required this.onKey,
    required this.onCtrl,
    required this.onText,
  });

  final ValueChanged<TerminalKey> onKey;
  final ValueChanged<String> onCtrl;
  final ValueChanged<String> onText;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: terminalTheme.foreground,
          side: const BorderSide(color: Color(0xFF2A3240)),
          textStyle: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13),
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
    return Material(
      color: const Color(0xFF161B22),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          children: [
            key('Esc', () => onKey(TerminalKey.escape)),
            key('Tab', () => onKey(TerminalKey.tab)),
            key('^C', () => onCtrl('c')),
            key('^D', () => onCtrl('d')),
            key('^Z', () => onCtrl('z')),
            key('^L', () => onCtrl('l')),
            key('↑', () => onKey(TerminalKey.arrowUp)),
            key('↓', () => onKey(TerminalKey.arrowDown)),
            key('←', () => onKey(TerminalKey.arrowLeft)),
            key('→', () => onKey(TerminalKey.arrowRight)),
            for (final c in const ['|', '/', '-', '~', '>'])
              key(c, () => onText(c)),
          ],
        ),
      ),
    );
  }
}

/// Graphite terminal colors, matching the app's dark theme. The terminal
/// stays dark in light mode, as most shells and prompts expect.
const terminalTheme = TerminalTheme(
  cursor: Color(0xFF7CC4FF),
  selection: Color(0x557CC4FF),
  foreground: Color(0xFFE6E9EE),
  background: Color(0xFF0F1216),
  black: Color(0xFF1F2630),
  red: Color(0xFFFF8A80),
  green: Color(0xFF6EE7A0),
  yellow: Color(0xFFF5C46B),
  blue: Color(0xFF7CC4FF),
  magenta: Color(0xFFD7A6FF),
  cyan: Color(0xFF5EEAD4),
  white: Color(0xFFC9D1DC),
  brightBlack: Color(0xFF5B6475),
  brightRed: Color(0xFFFFB0A8),
  brightGreen: Color(0xFF9AF2BF),
  brightYellow: Color(0xFFFAD898),
  brightBlue: Color(0xFFA8D7FF),
  brightMagenta: Color(0xFFE6C6FF),
  brightCyan: Color(0xFF94F1E2),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFF5C46B),
  searchHitBackgroundCurrent: Color(0xFF7CC4FF),
  searchHitForeground: Color(0xFF0F1216),
);
