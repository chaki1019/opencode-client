# opencode-mobile

自前でホストしている [OpenCode](https://opencode.ai) サーバーにつなぐ、iOS / Android 向けの Flutter クライアントです。

- 対象サーバー: **OpenCode v2 HttpAPI (`/api/...`) のみ**。`/api/health` か `/api/info` を持たない古いサーバーには接続しません。
- 認証: OpenCode サーバーの HTTP Basic 認証（`OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`）。パスワードは Keychain / Keystore に保存します。

> [!NOTE]
> このアプリは OpenCode チームが作ったものではなく、OpenCode とは一切関係のない非公式クライアントです。
> This project is not built by the OpenCode team and is not affiliated with OpenCode in any way.
> OpenCode のロゴは [OpenCode Brand guidelines](https://opencode.ai/brand) で公開されている素材をもとにしています。

## 開発

```bash
flutter pub get
dart run build_runner build   # freezed / json_serializable のコード生成（生成物はコミット済み）
flutter analyze
flutter test
flutter run
```

## 構成

```
lib/
  app/          ルーター
  core/api/     v2 HTTP クライアント、エラー型
  core/models/  freezed モデル
  core/storage/ 保存済みサーバー（flutter_secure_storage）
  features/     画面ごとの UI と Riverpod プロバイダ
push/
  plugin/       OpenCode 用プラグイン（PC/Mac に置く）
  relay/        通知の中継サーバー（Cloudflare Workers）
```

移植計画とフェーズは [docs/porting-plan.md](docs/porting-plan.md) を参照。

## 進捗

- [x] フェーズ1: v2 接続（ヘルスチェック）、保存済みサーバー、プロジェクト一覧
- [x] フェーズ2: セッション一覧、メッセージ履歴表示
- [x] フェーズ3: SSE によるリアルタイム更新とストリーミング表示
- [x] フェーズ4: 送信、中断、モデル/エージェント選択、新規セッション（画像添付は後回し）
- [x] フェーズ5: 権限確認、質問（v2 フォーム）、Todo、ツール表示
- [x] フェーズ6: Git（ブランチ・変更ファイル・差分）、MCP 接続切替、フォーク、要約、名前変更、削除
- [x] フェーズ7: ファイル閲覧・検索、worktree、画像添付
- [x] フェーズ8: ターミナル（PTY + WebSocket + xterm）
- [x] プッシュ通知: Agent の完了・エラー・許可待ち・質問を通知（OpenCode プラグイン + 中継 + FCM、[設定手順](docs/push-notifications.md)）
- [x] 広告: 一覧画面のバナー、1日10回を超えたらリワード広告、買い切りの「広告を外す」（[設定手順](docs/ads.md)）
- [x] サポート: 設定画面のお問い合わせ・プライバシーポリシー、Crashlytics によるクラッシュレポート、公開用サイト `site/`（[設定手順](docs/support.md)）
- [x] CI / 配信: PR ごとのチェック（GitHub Actions）、タグ push で TestFlight と Play 製品版へ配信（Codemagic、[設定手順](docs/release.md)）
