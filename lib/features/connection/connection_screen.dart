import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/discovery/server_discovery.dart';
import '../../core/models/server_config.dart';
import '../../l10n/l10n.dart';
import '../push/push_providers.dart';
import '../settings/support_section.dart';
import 'connection_providers.dart';
import 'opencode_logo.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key, this.adding = false});

  /// Opened from the drawer while connected: it gets a back button and
  /// closes itself once the new server is connected.
  final bool adding;

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _username = TextEditingController(text: 'opencode');
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = l10n.connectError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectNew() async {
    if (!_formKey.currentState!.validate()) return;
    final baseUrl = ServerConfig.normalizeBaseUrl(_url.text);
    final username = _username.text.trim().isEmpty
        ? 'opencode'
        : _username.text.trim();
    final password = _password.text;
    final saved = ref.read(savedServersProvider.notifier);
    final existing = await saved.find(baseUrl, username);
    final server =
        existing ??
        ServerConfig(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          baseUrl: baseUrl,
          username: username,
        );
    final connections = ref.read(connectionProvider.notifier);
    ActiveConnection? connection;
    await _run(() async {
      connection = await connections.probe(server, password);
    });
    final probed = connection;
    if (probed == null || !mounted) return;
    // Asked outside _run so the button is not spinning behind the sheet.
    if (existing == null && !await saved.isDeclined(baseUrl, username)) {
      if (!mounted) return;
      await _offerToSave(server, password);
    }
    await connections.open(probed, password);
  }

  /// Asks once, after a successful connect, whether to keep this server.
  /// Dismissing the sheet decides nothing, so it is asked again next time.
  Future<void> _offerToSave(ServerConfig server, String password) async {
    final choice = await showModalBottomSheet<_SaveChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SaveServerSheet(server: server),
    );
    final saved = ref.read(savedServersProvider.notifier);
    switch (choice) {
      case _Save(:final name):
        await saved.remember(
          server.copyWith(label: name.isEmpty ? null : name),
          password,
        );
      case _Decline():
        await saved.decline(server.baseUrl, server.username);
      case null:
        break;
    }
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
    if (widget.adding) {
      ref.listen(connectionProvider, (previous, next) {
        if (next == null || next == previous) return;
        // The router re-runs its redirect for the same change; popping
        // before that finishes would be undone by it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      });
    }
    return Scaffold(
      appBar: widget.adding
          ? AppBar(title: Text(context.l10n.addServer))
          : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            readableSide(context, min: 20),
            32,
            readableSide(context, min: 20),
            24,
          ),
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
                        : ServerConfig.isValidBaseUrl(v)
                        ? null
                        : context.l10n.serverUrlInvalid,
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
                  FilledButton(
                    key: const Key('connect'),
                    onPressed: _busy ? null : _connectNew,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.connect),
                  ),
                  if (ref
                          .watch(supportConfigProvider)
                          .connectGuide(
                            Localizations.localeOf(context).languageCode,
                          )
                      case final guide?)
                    TextButton.icon(
                      key: const Key('connect-guide'),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: Text(context.l10n.connectGuide),
                      onPressed: () => launchUrl(
                        guide,
                        mode: LaunchMode.externalApplication,
                      ),
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
                    onLongPress: () => _editSaved(server),
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

sealed class _SaveChoice {
  const _SaveChoice();
}

class _Save extends _SaveChoice {
  const _Save(this.name);

  final String name;
}

class _Decline extends _SaveChoice {
  const _Decline();
}

/// "Save this server?" with a name field that starts as the host.
class _SaveServerSheet extends StatefulWidget {
  const _SaveServerSheet({required this.server});

  final ServerConfig server;

  @override
  State<_SaveServerSheet> createState() => _SaveServerSheetState();
}

class _SaveServerSheetState extends State<_SaveServerSheet> {
  late final _name = TextEditingController(text: widget.server.host);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_Save(_name.text.trim()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            context.l10n.saveServerTitle,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            '${widget.server.username} @ ${widget.server.baseUrl}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: AppFonts.mono,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextField(
            key: const Key('save-name'),
            controller: _name,
            decoration: InputDecoration(labelText: context.l10n.serverName),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 4),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('dont-save'),
                  onPressed: () => Navigator.of(context).pop(const _Decline()),
                  child: Text(context.l10n.dontSave),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const Key('save'),
                  onPressed: _save,
                  child: Text(context.l10n.saveServer),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
                    : ServerConfig.isValidBaseUrl(v)
                    ? null
                    : context.l10n.serverUrlInvalid,
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
    return Row(
      children: [
        const OpenCodeLogo(height: 52),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenCode Mobile',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.connectTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
