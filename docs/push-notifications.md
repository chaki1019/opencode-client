# プッシュ通知

PC/Mac の OpenCode で Agent の応答が終わったとき（またはエラーで止まったとき、許可や回答を待っているとき）に、スマホへ通知を届けます。

```
OpenCode（PC/Mac）
  └─ プラグイン push/plugin/opencode-push.js
       │  POST /v1/notify（ペアリングキーで認証）
       ▼
中継サーバー push/relay（Cloudflare Workers + KV）
       │  FCM HTTP v1
       ▼
FCM ──(iOS は APNs 経由)──▶ アプリ
```

- **ペアリングキー**: アプリがサーバーごとに作る 43 文字のランダムな鍵です。アプリはこの鍵で端末を中継に登録し、プラグインは同じ鍵で通知を送ります。中継は鍵を SHA-256 のハッシュでしか保存しません。
- **通知の内容**: タイトルは「プロジェクト名: 応答が完了しました」などで、本文はセッションのタイトルです。プラグインの `includeTitle: false` で本文を空にできます。
- **タップ時**: 通知を送ったサーバーに接続し（必要なら保存済みの認証情報で再接続し）、そのセッションのチャットを開きます。アプリが前面にあるときは画面下部に表示します。
- サブエージェントのセッションは通知しません。同じ種類の通知は 15 秒以内に重複して送りません。

## 1. Firebase（無料）

1. [Firebase コンソール](https://console.firebase.google.com/) でプロジェクトを作る。
2. Android アプリ（パッケージ名は `android/app/build.gradle.kts` の `applicationId`）と iOS アプリ（Xcode の Bundle Identifier）を登録する。`google-services.json` と `GoogleService-Info.plist` はリポジトリに入れません。中の値を下の `push.env.json` に写します。
3. iOS: Apple Developer の「Certificates, Identifiers & Profiles → Keys」で APNs 認証キー（.p8）を作り、Firebase の「プロジェクトの設定 → Cloud Messaging → Apple アプリの構成」にアップロードする。App ID で Push Notifications を有効にする。
4. 「プロジェクトの設定 → サービスアカウント → 新しい秘密鍵を生成」でサービスアカウントの JSON をダウンロードする（中継サーバーで使う）。

## 2. 中継サーバー（Cloudflare Workers、無料枠で足ります）

```bash
cd push/relay
npx wrangler login
npx wrangler kv namespace create DEVICES   # 出力された id を wrangler.toml に貼る
npx wrangler secret put FCM_SERVICE_ACCOUNT < /path/to/service-account.json
npx wrangler deploy                        # https://opencode-push-relay.<account>.workers.dev
```

テスト: `node --test push/relay/test/*.test.js`

## 3. アプリのビルド

`push.env.example.json` を `push.env.json` にコピーして値を埋め（`push.env.json` は git に入りません）、次のようにビルドします。

```bash
flutter run --dart-define-from-file=push.env.json
```

| キー | 値の場所 |
|---|---|
| `PUSH_RELAY_URL` | `wrangler deploy` で表示された URL |
| `FIREBASE_PROJECT_ID` | `project_id` |
| `FIREBASE_SENDER_ID` | `project_number`（`GCM_SENDER_ID`） |
| `FIREBASE_ANDROID_API_KEY` / `FIREBASE_ANDROID_APP_ID` | `google-services.json` の `current_key` / `mobilesdk_app_id` |
| `FIREBASE_IOS_API_KEY` / `FIREBASE_IOS_APP_ID` / `FIREBASE_IOS_BUNDLE_ID` | `GoogleService-Info.plist` の `API_KEY` / `GOOGLE_APP_ID` / `BUNDLE_ID` |

これらの値が無いビルドでは通知画面に「設定が含まれていません」と表示され、通知機能は動きません。

iOS は `ios/Runner/Runner.entitlements` に `aps-environment` を入れてあります。初回は Xcode の Signing & Capabilities で Push Notifications が有効になっているか確認してください。

## 4. アプリと PC/Mac の設定

1. アプリでサーバーに接続し、プロジェクト一覧右上のベルから「このサーバーの通知を受け取る」をオンにする。
2. `push/plugin/opencode-push.js` を PC/Mac の `~/.config/opencode/plugins/` にコピーする。
3. アプリに表示される項目（コピーボタンあり）を `~/.config/opencode/opencode.json` に追加し、OpenCode を再起動する。

```jsonc
"plugins": [
  {
    "package": "./plugins/opencode-push.js",
    "options": {
      "relay": "https://opencode-push-relay.<account>.workers.dev",
      "key": "<アプリが表示するペアリングキー>",
      // 任意（既定はすべて true）
      "includeTitle": true,
      "notifyOnComplete": true,
      "notifyOnError": true,
      "notifyOnPermission": true,
      "notifyOnQuestion": true
    }
  }
]
```

アプリの「テスト通知を送る」は、プラグインと同じ経路（中継 → FCM → 端末）で通知を送ります。PC 側の設定前に中継と Firebase の確認ができます。

テスト: `node --test push/plugin/*.test.js`

## 対象のイベント

`@opencode/plugin` 2.0.22 の型で確認しています。v2 は `session.idle` を出さないため、完了は `session.execution.succeeded` で判定します。

| 通知 | イベント |
|---|---|
| 応答が完了しました | `session.execution.succeeded` |
| エラーで停止しました | `session.execution.failed` |
| 許可を待っています | `permission.asked` |
| 質問に回答を待っています | `form.created` |
