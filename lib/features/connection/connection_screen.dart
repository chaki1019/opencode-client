import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_errors.dart';
import '../../core/models/server_config.dart';
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
      setState(
        () => _error = 'このサーバーは OpenCode v2 API に対応していません。OpenCode を更新してください',
      );
    } on OpenCodeApiException catch (e) {
      setState(
        () =>
            _error = e.isUnauthorized ? 'ユーザー名またはパスワードが違います' : '接続できませんでした: $e',
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
                    decoration: const InputDecoration(
                      labelText: 'サーバー URL',
                      hintText: 'http://192.168.1.10:4096',
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'URL を入力してください'
                        : null,
                  ),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'ユーザー名'),
                    autocorrect: false,
                  ),
                  TextFormField(
                    key: const Key('password'),
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      helperText: 'OPENCODE_SERVER_PASSWORD（未設定なら空欄）',
                    ),
                    obscureText: true,
                  ),
                  TextFormField(
                    controller: _label,
                    decoration: const InputDecoration(labelText: '表示名（任意）'),
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
                        : const Text('接続'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ...saved.when(
              data: (servers) => [
                if (servers.isNotEmpty)
                  Text(
                    '保存済みサーバー',
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
                      tooltip: '削除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(savedServersProvider.notifier)
                          .forget(server.id),
                    ),
                  ),
              ],
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text('保存済みサーバーを読み込めませんでした: $e')],
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
          'OpenCode サーバーに接続',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
