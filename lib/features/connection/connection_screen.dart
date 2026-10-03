import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/discovery/server_discovery.dart';
import '../../core/models/server_config.dart';
import '../../l10n/l10n.dart';
import '../push/push_providers.dart';
import 'connection_providers.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _username = TextEditingController(text: 'opencode');
  final _password = TextEditingController();
  final _label = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _label.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on UnsupportedServerException {
      setState(() => _error = context.l10n.connectUnsupported);
    } on OpenCodeApiException catch (e) {
      setState(
        () => _error = e.isUnauthorized
            ? context.l10n.connectWrongCredentials
            : context.l10n.connectFailed(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The server described by the form, reusing the id of a saved server
  /// with the same URL and username. Null when the form is invalid.
  Future<ServerConfig?> _serverFromForm() async {
    if (!_formKey.currentState!.validate()) return null;
    final baseUrl = ServerConfig.normalizeBaseUrl(_url.text);
    final username = _username.text.trim().isEmpty
        ? 'opencode'
        : _username.text.trim();
    final existing = await ref
        .read(savedServersProvider.notifier)
        .find(baseUrl, username);
    return ServerConfig(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      baseUrl: baseUrl,
      username: username,
      label: _label.text.trim().isEmpty ? existing?.label : _label.text.trim(),
    );
  }

  Future<void> _connectNew() async {
    final server = await _serverFromForm();
    if (server == null) return;
    await _run(
      () =>
          ref.read(connectionProvider.notifier).connect(server, _password.text),
    );
  }

  /// Saves the form as a server without connecting to it.
  Future<void> _saveNew() async {
    final server = await _serverFromForm();
    if (server == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await ref
        .read(savedServersProvider.notifier)
        .remember(server, _password.text);
    _url.clear();
    _password.clear();
    _label.clear();
    _username.text = 'opencode';
    setState(() => _error = null);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.serverSaved(server.displayName))),
    );
  }

  Future<void> _forget(ServerConfig server) async {
    await forgetPush(ref, server.id);
    await ref.read(savedServersProvider.notifier).forget(server.id);
  }

  Future<void> _editSaved(ServerConfig server) async {
    final password = await ref
        .read(serverStoreProvider)
        .readPassword(server.id);
    if (!mounted) return;
    final edited = await showDialog<(ServerConfig, String)>(
      context: context,
      builder: (_) => _EditServerDialog(server: server, password: password),
    );
    if (edited == null) return;
    await ref.read(savedServersProvider.notifier).edit(edited.$1, edited.$2);
  }

  /// Fills the form with a server found on the network; the user still
  /// enters the password and connects.
  void _pickDiscovered(DiscoveredServer server) {
    _url.text = server.baseUrl;
    setState(() => _error = null);
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedServersProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            const _Brand(),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  TextFormField(
                    key: const Key('url'),
                    controller: _url,
                    decoration: InputDecoration(
                      labelText: context.l10n.serverUrl,
                      hintText: 'http://192.168.1.10:4096',
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.serverUrlRequired
                        : null,
                  ),
                  TextFormField(
                    controller: _username,
                    decoration: InputDecoration(
                      labelText: context.l10n.username,
                    ),
                    autocorrect: false,
                  ),
                  TextFormField(
                    key: const Key('password'),
                    controller: _password,
                    focusNode: _passwordFocus,
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      helperText: context.l10n.passwordHelper,
                    ),
                    obscureText: true,
                  ),
                  TextFormField(
                    controller: _label,
                    decoration: InputDecoration(
                      labelText: context.l10n.displayNameOptional,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('save'),
                          onPressed: _busy ? null : _saveNew,
                          child: Text(context.l10n.saveServer),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const Key('connect'),
                          onPressed: _busy ? null : _connectNew,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.l10n.connect),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ...saved.when(
              data: (servers) => [
                if (servers.isNotEmpty)
                  Text(
                    context.l10n.savedServers,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                for (final server in servers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(server.displayName),
                    subtitle: Text(
                      '${server.username} @ ${server.baseUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(connectionProvider.notifier)
                                .connectSaved(server),
                          ),
                    trailing: PopupMenuButton<_ServerAction>(
                      key: Key('server-menu-${server.id}'),
                      onSelected: (action) => switch (action) {
                        _ServerAction.edit => _editSaved(server),
                        _ServerAction.delete => _forget(server),
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _ServerAction.edit,
                          child: Text(context.l10n.editServer),
                        ),
                        PopupMenuItem(
                          value: _ServerAction.delete,
                          child: Text(context.l10n.delete),
                        ),
                      ],
                    ),
                  ),
              ],
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text(context.l10n.savedServersLoadFailed(e))],
            ),
            const SizedBox(height: 24),
            _DiscoveredServers(
              saved: saved.value ?? const [],
              onPick: _busy ? null : _pickDiscovered,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ServerAction { edit, delete }

/// Servers found on the network (mDNS or a LAN scan) that are not saved
/// yet. Tapping one fills the form.
class _DiscoveredServers extends ConsumerWidget {
  const _DiscoveredServers({required this.saved, required this.onPick});

  final List<ServerConfig> saved;
  final void Function(DiscoveredServer server)? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final snapshot = ref.watch(discoveredServersProvider).value;
    final scanning = snapshot?.scanning ?? true;
    final savedUrls = {for (final s in saved) s.baseUrl};
    final found = [
      for (final server in snapshot?.servers ?? const <DiscoveredServer>[])
        if (!savedUrls.contains(server.baseUrl)) server,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.discoveredServers,
                style: theme.textTheme.labelLarge?.copyWith(color: muted),
              ),
            ),
            if (scanning)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                key: const Key('rescan'),
                tooltip: context.l10n.rescanNetwork,
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(discoveredServersProvider),
              ),
          ],
        ),
        if (found.isEmpty) ...[
          Text(
            scanning
                ? context.l10n.discoveringServers
                : context.l10n.discoveryNoneFound,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.discoveryHint,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
        for (final server in found)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wifi_tethering),
            title: Text(server.name),
            subtitle: Text(
              server.baseUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: AppFonts.mono,
                color: muted,
              ),
            ),
            onTap: onPick == null ? null : () => onPick!(server),
          ),
      ],
    );
  }
}

class _EditServerDialog extends StatefulWidget {
  const _EditServerDialog({required this.server, required this.password});

  final ServerConfig server;
  final String password;

  @override
  State<_EditServerDialog> createState() => _EditServerDialogState();
}

class _EditServerDialogState extends State<_EditServerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.server.label ?? '');
  late final _url = TextEditingController(text: widget.server.baseUrl);
  late final _username = TextEditingController(text: widget.server.username);
  late final _password = TextEditingController(text: widget.password);

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final label = _label.text.trim();
    final username = _username.text.trim();
    Navigator.of(context).pop((
      widget.server.copyWith(
        label: label.isEmpty ? null : label,
        baseUrl: ServerConfig.normalizeBaseUrl(_url.text),
        username: username.isEmpty ? 'opencode' : username,
      ),
      _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.editServerTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              TextFormField(
                key: const Key('edit-name'),
                controller: _label,
                decoration: InputDecoration(
                  labelText: context.l10n.serverName,
                  hintText: widget.server.host,
                ),
                autofocus: true,
              ),
              TextFormField(
                key: const Key('edit-url'),
                controller: _url,
                decoration: InputDecoration(labelText: context.l10n.serverUrl),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.serverUrlRequired
                    : null,
              ),
              TextFormField(
                controller: _username,
                decoration: InputDecoration(labelText: context.l10n.username),
                autocorrect: false,
              ),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(labelText: context.l10n.password),
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('edit-save'),
          onPressed: _save,
          child: Text(context.l10n.saveServer),
        ),
      ],
    );
  }
}

/// The app's mark and name at the top of the connect screen.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: Text(
            '>_',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'OpenCode Mobile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.connectTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
