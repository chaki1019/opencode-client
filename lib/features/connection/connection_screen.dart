import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('OpenCode サーバーに接続')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                for (final server in servers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(server.displayName),
                    subtitle: Text('${server.username} @ ${server.baseUrl}'),
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
