// Takes the raw app screenshots for the store images. Not part of the test
// suite: copy it into test/zz_store/ and run from the repository root:
//
//   flutter test test/zz_store --name "(chat|diff|permission)\$" \
//     --dart-define=OUT=/tmp/shots --dart-define=FONT_DIR=<Noto Sans JP dir>
//   # The "connect" tests hang after their shot (discovery probes the real
//   # network), so run each one alone under a timeout:
//   timeout 45 flutter test test/zz_store --plain-name "ja/phone connect" ...
//
// FONT_DIR holds static NotoSansJP-{400,500,600,700}.ttf. Then compose the
// store images with render.mjs.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/discovery/server_discovery.dart';
import 'package:opencode_mobile/core/events/event_stream.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/core/storage/server_store.dart';
import 'package:opencode_mobile/features/connection/connection_providers.dart';
import 'package:opencode_mobile/features/git/git_screen.dart';
import 'package:opencode_mobile/features/live/live_providers.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/main.dart';

import '../support/fake_adapter.dart';
import '../support/fake_discovery.dart';

const out = String.fromEnvironment('OUT', defaultValue: '/tmp/shots');
const fontDir = String.fromEnvironment('FONT_DIR', defaultValue: 'fonts');
final flutterFonts =
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

class Device {
  const Device(this.name, this.size, this.dpr, this.top, this.bottom);
  final String name;
  final Size size; // logical
  final double dpr;
  final double top;
  final double bottom;
}

const phone = Device('phone', Size(430, 932), 3, 59, 34);
const tablet = Device('tablet', Size(1032, 1376), 2, 24, 20);

// A 7-inch tablet in portrait is narrower than the two-pane breakpoint, so
// it shows the single-page layout.
const tablet7 = Device('tablet7', Size(600, 960), 2, 24, 20);

final _boundary = GlobalKey();

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('IBMPlexSans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/IBMPlexSans-$w.ttf',
  ]);
  await load('JetBrainsMono', [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-SemiBold.ttf',
  ]);
  // Also registered as the theme's first CJK fallback: without it some
  // kanji fall through to the test font and render as boxes.
  for (final fam in ['Hiragino Sans', 'Noto Sans JP']) {
    await load(fam, [
      for (final w in [400, 500, 600, 700]) '$fontDir/NotoSansJP-$w.ttf',
    ]);
  }
  await load('MaterialIcons', ['$flutterFonts/MaterialIcons-Regular.otf']);
  await load('Roboto', ['$flutterFonts/Roboto-Regular.ttf']);
}

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  debugPrint('SHOT $name');
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void setDevice(WidgetTester tester, Device d, String lang) {
  tester.view.devicePixelRatio = d.dpr;
  tester.view.physicalSize = d.size * d.dpr;
  tester.view.padding = FakeViewPadding(
    top: d.top * d.dpr,
    bottom: d.bottom * d.dpr,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: d.top * d.dpr,
    bottom: d.bottom * d.dpr,
  );
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = [Locale(lang)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

// ---------------------------------------------------------------- data

final now = DateTime.now().millisecondsSinceEpoch.toDouble();
const dir = '/Users/me/todo-app';
const model = {'providerID': 'anthropic', 'id': 'claude-sonnet-5-5'};

class Copy {
  const Copy({
    required this.server,
    required this.sessions,
    required this.ask,
    required this.reply1,
    required this.todos,
    required this.reply2,
    required this.permAsk,
    required this.permIntro,
    required this.permDescription,
    required this.preAsk,
    required this.preReply,
  });
  final String preAsk;
  final String preReply;
  final String server;
  final List<String> sessions;
  final String ask;
  final String reply1;
  final List<String> todos;
  final String reply2;
  final String permAsk;
  final String permIntro;
  final String permDescription;
}

const ja = Copy(
  server: '自宅の Mac',
  sessions: [
    'ログインの入力チェックを修正',
    'ダークモードの切り替えを追加',
    'README の英語版を作成',
    'API クライアントのエラー処理を整理',
    '依存パッケージを更新',
  ],
  ask: 'パスワードが空でもログインできてしまうので直して。テストも追加して',
  reply1: '原因は `LoginForm` の validator が空の値を通していることでした。直します。',
  todos: ['原因を調べる', 'validator を直す', 'テストを追加', 'テストを実行'],
  reply2: 'テストが通りました。空のパスワードでは送信ボタンが押せず、次のメッセージを表示します。',
  permAsk: '依存パッケージを最新にして、テストが通るか確認して',
  permIntro: 'パッケージを更新してからテストを実行します。',
  permDescription: '依存パッケージを更新',
  preAsk: 'ログイン画面のテストってある？',
  preReply: '`test/auth/login_form_test.dart` に 3 件あります。メールアドレスの形式は確認していますが、パスワードが空のケースはまだありません。',
);

const en = Copy(
  server: 'Home Mac',
  sessions: [
    'Fix login form validation',
    'Add a dark mode toggle',
    'Write the README in Japanese',
    'Clean up API client errors',
    'Update dependencies',
  ],
  ask:
      'Login still works with an empty password. Please fix it and add a test.',
  reply1: 'The `LoginForm` validator lets empty values through. Fixing it now.',
  todos: ['Find the cause', 'Fix the validator', 'Add a test', 'Run the tests'],
  reply2: 'Tests pass. With an empty password the button stays disabled and shows this message.',
  permAsk: 'Update the dependencies and check that the tests still pass.',
  permIntro: 'I will update the packages and then run the tests.',
  permDescription: 'Update dependencies',
  preAsk: 'Do we have tests for the login screen?',
  preReply: 'There are 3 in `test/auth/login_form_test.dart`. They check the email format, but nothing covers an empty password yet.',
);

Map<String, Object?> session(int i, Copy c, {double ago = 0}) => {
  'id': 's$i',
  'projectID': 'p1',
  'title': c.sessions[i],
  'location': {'directory': dir},
  'time': {'created': now - ago - 1000, 'updated': now - ago},
  'agent': 'build',
  'model': model,
  'cost': [0.42, 1.18, 0.27, 0.86, 0.12][i],
};

Map<String, Object?> tool(
  String id,
  String name,
  Map<String, Object?> input, {
  String status = 'completed',
  String? output,
}) => {
  'type': 'tool',
  'id': id,
  'name': name,
  'state': {
    'status': status,
    'input': input,
    if (output != null)
      'content': [
        {'type': 'text', 'text': output},
      ],
  },
};

List<Map<String, Object?>> chat0(Copy c, String lang) => [
  {
    'id': 'u0',
    'type': 'user',
    'time': {'created': now - 900000},
    'text': c.preAsk,
  },
  {
    'id': 'a0',
    'type': 'assistant',
    'time': {'created': now - 890000, 'completed': now - 880000},
    'agent': 'build',
    'model': model,
    'finish': 'stop',
    'content': [
      tool('t0', 'glob', {'pattern': 'test/auth/**'}),
      {'type': 'text', 'text': c.preReply},
    ],
  },
  {
    'id': 'u1',
    'type': 'user',
    'time': {'created': now - 600000},
    'text': c.ask,
  },
  {
    'id': 'a1',
    'type': 'assistant',
    'time': {'created': now - 590000, 'completed': now - 300000},
    'agent': 'build',
    'model': model,
    'finish': 'stop',
    'content': [
      {'type': 'text', 'text': c.reply1},
      tool('t1', 'todowrite', {
        'todos': [
          for (final (i, t) in c.todos.indexed)
            {'content': t, 'status': i < 4 ? 'completed' : 'pending'},
        ],
      }),
      tool('t2', 'read', {'filePath': 'lib/auth/login_form.dart'}),
      tool('t3', 'edit', {'filePath': 'lib/auth/login_form.dart'}),
      tool('t4', 'bash', {
        'command': 'flutter test test/auth',
        'description': 'flutter test test/auth',
      }),
      {
        'type': 'text',
        'text':
            '${c.reply2}\n\n```dart\nvalidator: (v) => v == null || v.isEmpty\n    ? ${lang == 'ja' ? "'パスワードを入力してください'" : "'Enter your password'"}\n    : null,\n```',
      },
    ],
  },
];

List<Map<String, Object?>> chat1(Copy c) => [
  {
    'id': 'u2',
    'type': 'user',
    'time': {'created': now - 60000},
    'text': c.permAsk,
  },
  {
    'id': 'a2',
    'type': 'assistant',
    'time': {'created': now - 50000},
    'agent': 'build',
    'model': model,
    'content': [
      {'type': 'text', 'text': c.permIntro},
      tool('t5', 'read', {'filePath': 'pubspec.yaml'}),
      tool('t6', 'bash', {
        'command': 'flutter pub upgrade --major-versions',
        'description': c.permDescription,
      }, status: 'running'),
    ],
  },
];

const patch =
    '''diff --git a/lib/auth/login_form.dart b/lib/auth/login_form.dart
--- a/lib/auth/login_form.dart
+++ b/lib/auth/login_form.dart
@@ -18,14 +18,20 @@ class LoginForm extends StatefulWidget {
   @override
   Widget build(BuildContext context) {
     return Form(
       key: _formKey,
+      autovalidateMode: AutovalidateMode.onUserInteraction,
       child: Column(
         children: [
           TextFormField(
             controller: _email,
             decoration: const InputDecoration(labelText: 'Email'),
           ),
           TextFormField(
             controller: _password,
             obscureText: true,
-            validator: (v) => null,
+            validator: (v) => v == null || v.isEmpty
+                ? 'Enter your password'
+                : null,
           ),
           FilledButton(
-            onPressed: _submit,
+            onPressed: _canSubmit ? _submit : null,
             child: const Text('Log in'),
           ),
         ],
''';

FakeAdapter adapterFor(Copy c, String lang) => FakeAdapter({
  '/api/health': FakeRoute.json({
    'healthy': true,
    'version': '2.1.4',
    'pid': 1,
  }),
  '/api/location': FakeRoute.json({
    'directory': dir,
    'project': {'id': 'p1', 'directory': dir},
  }),
  '/api/project': FakeRoute.json([
    {'id': 'p1', 'canonical': dir, 'sandboxes': []},
    {'id': 'p2', 'canonical': '/Users/me/blog', 'sandboxes': []},
    {'id': 'p3', 'canonical': '/Users/me/dotfiles', 'sandboxes': []},
  ]),
  '/api/session': FakeRoute.json({
    'data': [
      session(1, c, ago: 30000),
      session(0, c, ago: 300000),
      session(2, c, ago: 3600000 * 3),
      session(3, c, ago: 86400000),
      session(4, c, ago: 86400000 * 2),
    ],
  }),
  '/api/session/active': FakeRoute.json({
    'data': {
      's1': {'type': 'busy'},
    },
  }),
  '/api/permission/request': FakeRoute.json({
    'data': [
      {'id': 'perm1', 'sessionID': 's1'},
    ],
  }),
  '/api/question/request': FakeRoute.json({'data': []}),
  '/api/session/s0/message': FakeRoute.json({
    'data': chat0(c, lang).reversed.toList(),
  }),
  '/api/session/s1/message': FakeRoute.json({
    'data': chat1(c).reversed.toList(),
  }),
  '/api/session/s0/permission': FakeRoute.json({'data': []}),
  '/api/session/s1/permission': FakeRoute.json({
    'data': [
      {
        'id': 'perm1',
        'sessionID': 's1',
        'action': 'bash',
        'resources': ['flutter pub upgrade --major-versions'],
        'save': ['flutter pub *'],
        'metadata': {'command': 'flutter pub upgrade --major-versions'},
        'source': {'messageID': 'a2', 'id': 't6'},
      },
    ],
  }),
  '/api/session/s0/form': FakeRoute.json({'data': []}),
  '/api/session/s1/form': FakeRoute.json({'data': []}),
  '/api/agent': FakeRoute.json({
    'data': [
      {'name': 'build', 'mode': 'primary'},
      {'name': 'plan', 'mode': 'primary'},
    ],
  }),
  '/api/provider': FakeRoute.json({
    'data': [
      {'id': 'anthropic', 'name': 'Anthropic'},
      {'id': 'openai', 'name': 'OpenAI'},
      {'id': 'opencode', 'name': 'OpenCode Zen'},
    ],
  }),
  '/api/model': FakeRoute.json({
    'data': [
      for (final m in [
        'claude-opus-5-5',
        'claude-sonnet-5-5',
        'claude-haiku-4-5',
      ])
        {
          'id': m,
          'providerID': 'anthropic',
          'name': m,
          'limit': {'context': 1000000},
        },
      for (final m in ['gpt-5.5', 'gpt-5.5-mini'])
        {'id': m, 'providerID': 'openai', 'name': m},
      {'id': 'big-pickle', 'providerID': 'opencode', 'name': 'big-pickle'},
    ],
  }),
});

class Harness {
  Harness(this.adapter, this.discovered);
  final FakeAdapter adapter;
  final List<DiscoveredServer> discovered;
}

Future<void> pumpApp(
  WidgetTester tester,
  Harness h, {
  bool connect = true,
  String serverName = '',
}) async {
  final events = StreamController<List<int>>();
  addTearDown(events.close);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: [
          serverDiscoveryProvider.overrideWithValue(
            FakeDiscovery(finished: h.discovered),
          ),
          lanScanProvider.overrideWithValue(FakeDiscovery(finished: const [])),
          serverStoreProvider.overrideWithValue(ServerStore()),
          eventStreamProvider.overrideWith((ref) {
            if (ref.watch(connectionProvider) == null) return null;
            final stream = EventStream(open: (_) async => events.stream)
              ..start();
            ref.onDispose(stream.dispose);
            return stream;
          }),
          clientFactoryProvider.overrideWithValue(
            (server, password) => OpenCodeClient(
              baseUrl: server.baseUrl,
              username: server.username,
              password: password,
              dio: fakeDio(h.adapter),
            ),
          ),
        ],
        child: const OpenCodeMobileApp(),
      ),
    ),
  );
  await settle(tester);
  if (!connect) return;
  await tester.enterText(find.byKey(const Key('url')), '192.168.1.20:4096');
  await tester.enterText(find.byKey(const Key('password')), 'pw');
  await tester.tap(find.byKey(const Key('connect')));
  await settle(tester);
  await tester.enterText(find.byKey(const Key('save-name')), serverName);
  await tester.tap(find.byKey(const Key('save')));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    WidgetsApp.debugAllowBannerOverride = false;
    await loadFonts();
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final lang in ['ja', 'en']) {
    final c = lang == 'ja' ? ja : en;
    for (final d in [phone, tablet, tablet7]) {
      final p = '$lang/${d.name}';

      testWidgets('$p connect', (tester) async {
        setDevice(tester, d, lang);
        await pumpApp(
          tester,
          Harness(adapterFor(c, lang), const [
            DiscoveredServer(
              name: 'MacBook-Pro',
              baseUrl: 'http://192.168.1.20:4096',
            ),
            DiscoveredServer(
              name: 'mac-mini',
              baseUrl: 'http://192.168.1.31:4096',
            ),
          ]),
          connect: false,
        );
        await shoot(tester, '$p-connect');
        await finish(tester);
      });

      testWidgets('$p chat', (tester) async {
        setDevice(tester, d, lang);
        final h = Harness(adapterFor(c, lang), const []);
        await pumpApp(tester, h, serverName: c.server);
        await shoot(tester, '$p-projects');
        await tapText(tester, 'todo-app');
        await shoot(tester, '$p-sessions');
        await tapText(tester, c.sessions[0]);
        await shoot(tester, '$p-chat');
        // Model picker.
        await tester.tap(find.text('claude-sonnet-5-5').last);
        await settle(tester);
        await tapText(tester, 'Anthropic');
        await shoot(tester, '$p-model');
        await finish(tester);
      });

      testWidgets('$p permission', (tester) async {
        setDevice(tester, d, lang);
        final h = Harness(adapterFor(c, lang), const []);
        await pumpApp(tester, h, serverName: c.server);
        await tapText(tester, 'todo-app');
        await tapText(tester, c.sessions[1]);
        await shoot(tester, '$p-permission');
        final missing = {
          for (final r in h.adapter.requests)
            if (!h.adapter.routes.containsKey(r.path)) r.path,
        };
        debugPrint('MISSING $missing');
        await finish(tester);
      });

      testWidgets('$p diff', (tester) async {
        setDevice(tester, d, lang);
        await tester.pumpWidget(
          RepaintBoundary(
            key: _boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const DiffScreen(
                change: FileChange(
                  file: 'lib/auth/login_form.dart',
                  additions: 6,
                  deletions: 2,
                  status: 'modified',
                  patch: patch,
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        await shoot(tester, '$p-diff');
      });
    }
  }
}
