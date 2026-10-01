# opencode-client

自前でホストしている [OpenCode](https://opencode.ai) サーバーにつなぐ、iOS / Android 向けの Flutter クライアントです。

- 対象サーバー: **OpenCode v2 HttpAPI (`/api/...`) のみ**。`/api/health` か `/api/info` を持たない古いサーバーには接続しません。
- 認証: OpenCode サーバーの HTTP Basic 認証（`OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`）。パスワードは Keychain / Keystore に保存します。

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
```

移植計画とフェーズは [docs/porting-plan.md](docs/porting-plan.md) を参照。

## 進捗

- [x] フェーズ1: v2 接続（ヘルスチェック）、保存済みサーバー、プロジェクト一覧
- [x] フェーズ2: セッション一覧、メッセージ履歴表示
- [x] フェーズ3: SSE によるリアルタイム更新とストリーミング表示
- [ ] フェーズ4: 送信、中断、モデル/エージェント選択、添付
- [ ] フェーズ5: permission / question / todo / ツール表示
