import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/server_config.dart';
import '../../l10n/l10n.dart';
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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _label.dispose();
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

  Future<void> _connectNew() async {
    if (!_formKey.currentState!.validate()) return;
    final baseUrl = ServerConfig.normalizeBaseUrl(_url.text);
    final username = _username.text.trim().isEmpty
        ? 'opencode'
        : _username.text.trim();
    final existing = await ref
        .read(savedServersProvider.notifier)
        .find(baseUrl, username);
    final server = ServerConfig(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      baseUrl: baseUrl,
      username: username,
      label: _label.text.trim().isEmpty ? existing?.label : _label.text.trim(),
    );
    await _run(
      () =>
          ref.read(connectionProvider.notifier).connect(server, _password.text),
    );
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
                    trailing: IconButton(
                      tooltip: context.l10n.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(savedServersProvider.notifier)
                          .forget(server.id),
                    ),
                  ),
              ],
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text(context.l10n.savedServersLoadFailed(e))],
            ),
          ],
        ),
      ),
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
