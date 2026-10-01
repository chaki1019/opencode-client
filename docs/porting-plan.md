# OpenClient (iOS / Swift) → Flutter 移植計画

対象: https://github.com/ntoporcov/openclient （2026-10-01 時点の main を shallow clone して調査）

> **決定事項 (2026-10-01)**: 新規リポジトリ chaki1019/opencode-client で、iOS と Android を対象に作る。対象サーバーは **OpenCode v2 HttpAPI のみ**で、legacy API には対応しない。Swift のコードは仕様の参考にとどめ、Dart で新しく書く。

## 0. 最初に確認したい重要事項

- **ライセンスが PolyForm Noncommercial 1.0.0** です。個人・非商用利用での改変・移植は可能ですが、有償配布や商用利用は不可です。Flutter 版を配布・販売する予定があるなら、コードを流用せず「OpenCode サーバー API に対する独自クライアント」としてゼロから書く方針が安全です（以下の計画はその前提で、Swift 版は仕様書・参考として使います）。
- 規模は Swift 約 17 万行（テスト含む）。UI テスト・スクショ自動化・課金・ミニゲーム等を含むため、**全機能パリティではなく、コア機能から段階的に移植**することを推奨します。

## 1. 元アプリの概要

OpenClient はセルフホストした OpenCode サーバーにつなぐ iPhone/iPad/Mac 用コンパニオンアプリ。

### 主な画面（`OpenCodeIOSClient/Views/`）

| 画面 | 主なファイル | 内容 |
|---|---|---|
| 接続 | `Connection/ConnectionView.swift` | サーバー URL・Basic 認証入力、保存済みサーバー一覧、ヘルスチェック、Provider 使用量、音声設定、ヘルプ |
| プロジェクト一覧 | `Projects/ProjectListView.swift` | プロジェクト一覧・作成・設定、MCP 一覧、プロバイダ/設定シート |
| プロジェクト内タブ | `Root/ProjectContentView.swift` | `sessions` / `git` / `terminal` / `mcp` の4タブ |
| セッション一覧 | `Sessions/SessionListView.swift` | セッション一覧（ページング）、作成、ワークスペース(worktree)作成、アクティビティ |
| チャット | `Chat/ChatView.swift`(7.5k行), `MessageBubble`, `MessageComposer`(3.6k行), `MarkdownMessageText` | ストリーミング表示、Markdown/コードハイライト、reasoning、ツール実行グルーピング、Todo ストリップ、権限(permission)カード、質問(question)パネル、フォーム、モデル/エージェント切替、フォーク、添付、スラッシュコマンド |
| Git | `Git/GitStatusView`, `GitDiffView` | VCS ステータスと diff |
| ターミナル | `Terminal/TerminalProjectView.swift` | PTY を WebSocket で接続、GhosttyKit で描画 |
| ブラウザ | `Browser/BrowserView.swift` | WebKit 内蔵ブラウザ |
| その他 | Commerce, WhatsNew, ミニゲーム, Talk(音声会話)モード | 付加機能 |

OS 連携: Live Activity（Dynamic Island）、ウィジェット、Share Extension、Shortcuts(AppIntents)、Keychain、SwiftData キャッシュ、StoreKit 課金、音声認識/読み上げ。

### OpenCode サーバーとの通信

- **HTTP(S) + Basic 認証**（`OPENCODE_SERVER_USERNAME/PASSWORD`）。ディレクトリ単位のスコープは `?directory=` クエリと `x-opencode-directory` ヘッダ。
- **2系統の API を自動判別**: `GET /api/health` が `{healthy:true, version, pid}` を返せば v2 (`/api/...` HttpAPI)、404/405 等なら legacy（`/global/health` ＋ルートパス API）。401/403・ネットワークエラーではフォールバックしない。
- 主要 legacy エンドポイント: `/project`, `/project/current`, `/session?directory=`, `POST /session/:id/prompt_async`, `/session/:id/message`, `/session/:id/abort`, `/session/:id/fork`, `/session/:id/todo`, `/permission` + `POST /permission/:id/reply`, `/question` + `/question/:id/reply|reject`, `/command`, `/provider`, `/config`, `/vcs`, `/vcs/diff`, `/file/*`, `/find/file`, `/mcp`, `/pty`（WebSocket `/pty/:id/connect`）, `/experimental/worktree`。
- v2 側は `/api/project`, `/api/session/...`（prompt, interrupt, model, agent, fork, compact, permission, form）, `/api/fs/*`, `/api/vcs/*`, `/api/mcp`, `/api/provider`, `/api/model`, `/api/pty` など。v2 はまだプレビューで契約が揺れている（`preview17155` 分岐あり）。
- **リアルタイム更新は SSE**: `/event`（ディレクトリ）と `/global/event`（全体）。イベント型は `message.updated`, `message.part.updated`, `message.part.delta`, `session.status/idle/error/updated/created/deleted`, `permission.asked/replied`, `question.asked/replied/rejected`, `todo.updated`, `project.updated`, `pty.*`, `vcs.branch.updated`, `worktree.*` など約30種。
- 独自 `OpenClientPlugin`（サーバー側プラグイン、`/openclient/v1/*` と WebSocket）は画像/動画/通知ブリッジ用。作者自身が v2 安定まで保留中。

### 状態管理の設計

- 上流 OpenCode Web アプリ（`packages/app/src/context/global-sync`）に合わせた構成: **単一の SSE パイプライン → 型付きイベント → reducer で Store に適用 → View が購読**。サーバーが唯一の正。
- 層: `API`（transport）→ `Backends`（legacy/v2 の差異吸収）→ `Coordinators`（ブートストラップ、イベント同期、再接続等の手順）→ `Stores`（小さな `ObservableObject` 状態スライス ~28個）→ `Facades`（View 向け集約）→ `Views`。巨大 `AppViewModel` は移行中のレガシー。
- ストリーミングの注意点（AGENTS.md より）: `message.part.delta` は既存 part のフィールドへの追記。`part.updated` より先に来た delta は無視。reasoning/text の判定はサーバーの part `type` で行う。SSE は空行区切りだけを前提にしないパーサーが必要。送信は**自動リトライしない**（重複送信防止のため、正規データとイベントで突き合わせる）。

## 2. Flutter 技術選定（推奨）

| 用途 | パッケージ | 備考 |
|---|---|---|
| 状態管理 | `flutter_riverpod`（+ `riverpod_generator`） | Store/Coordinator 構成を Notifier/Provider に素直に写せる。reducer は純関数で書いてテスト |
| HTTP | `dio` | インターセプタで Basic 認証・directory ヘッダ付与 |
| SSE | 自前実装（`dio` の `ResponseType.stream` + 行デコーダ） | 元アプリ同様の頑健なパーサーが必要なので既製品より自作推奨 |
| WebSocket (PTY) | `web_socket_channel` | |
| ターミナル描画 | `xterm`（xterm.dart） | GhosttyKit の代替 |
| モデル/JSON | `freezed` + `json_serializable` | union 型でイベント/part を表現 |
| ルーティング | `go_router` | Project → Session → Chat の階層、iPad 用は分割レイアウト |
| Markdown | `flutter_markdown_plus` または `gpt_markdown` + `flutter_highlight`(`re_highlight`) | ストリーミング中の再描画性能に注意 |
| 秘密情報 | `flutter_secure_storage` | Keychain/Keystore |
| ローカルキャッシュ | `drift`（SQLite） | SwiftData 代替。初期は `shared_preferences` でも可 |
| 画像添付 | `image_picker`, `file_picker` | |
| 内蔵ブラウザ | `webview_flutter` | 後回し可 |
| diff 表示 | 自前ウィジェット（unified diff の行色分け） | |

OS 固有機能（Live Activity、ウィジェット、Share Extension、Shortcuts）は Flutter 単体では書けず、iOS ネイティブ側の Swift 実装＋`home_widget`/`live_activities`/`receive_sharing_intent` などのブリッジが必要。最終フェーズに回します。

## 3. ディレクトリ構成案（feature-first）

```
lib/
  main.dart
  app/                 # ルーター, テーマ, DI(ProviderScope)
  core/
    api/               # dio クライアント, legacy/v2 実装, API 自動判別(probe)
    sse/               # SSE パーサー, EventManager(単一パイプライン, 再接続)
    models/            # freezed モデル: Project, Session, Message, Part, Event, Permission, Question, Todo...
    sync/              # bootstrap, event reducer(純関数), directory/session スコープ
    storage/           # secure storage, 保存サーバー, キャッシュ
  features/
    connection/        # 接続画面, 保存済みサーバー
    projects/          # プロジェクト一覧/作成/設定
    sessions/          # セッション一覧/作成/worktree
    chat/              # トランスクリプト, バブル, composer, permission/question/todo, model/agent picker
    git/               # status, diff
    terminal/          # PTY + xterm
    mcp/               # MCP 一覧/接続
    settings/
test/                  # reducer, SSE パーサー, API(モックサーバー) のユニットテスト
```

## 4. 段階的な実装順

1. **基盤**: プロジェクト作成、モデル定義、dio クライアント、Basic 認証、`/api/health` → legacy フォールバックの自動判別、接続画面と保存サーバー（secure storage）。
2. **閲覧**: プロジェクト一覧 → セッション一覧（ページング）→ メッセージ履歴の読み込みと静的表示（Markdown・コードハイライト）。
3. **リアルタイム**: SSE パーサー＋EventManager（単一接続、再接続、directory ファンアウト）＋reducer。`message.part.delta` のストリーミング表示、session status。ここが最重要なので reducer/パーサーはテスト先行。
4. **操作**: メッセージ送信（`prompt_async`、楽観表示、非リトライ）、中断(abort)、新規セッション、モデル/エージェント選択、スラッシュコマンド、画像/ファイル添付。
5. **対話プロンプト**: permission カードと返信、question パネル、Todo ストリップ、ツール実行のグルーピング表示、reasoning 折りたたみ。
6. **プロジェクト機能**: Git ステータス/diff、MCP 一覧と接続、ファイル検索、フォーク、compact/summarize、worktree。
7. **ターミナル**: PTY 作成 + WebSocket + xterm.dart。
8. **v2 API 対応の拡充**（legacy で動くものを v2 実装に差し替え。契約が揺れているので後回し推奨）。
9. **OS 連携・付加機能**（任意）: ローカルキャッシュ、通知、ウィジェット/Live Activity、共有、音声、内蔵ブラウザ。課金・ミニゲーム・OpenClientPlugin は対象外推奨。

フェーズ 1〜5 で「接続してセッションを開き、ストリーミングで会話し、権限・質問に答えられる」MVP になります。

## 5. 決めてほしいこと

- Flutter コードの置き場所（新規 GitHub リポジトリ / 既存リポジトリ / 未定）
- 対象プラットフォーム（iOS のみ / iOS + Android / デスクトップ・Web も）
- 配布予定の有無（ライセンス上の扱いが変わるため）
