# プッシュ通知

PC/Mac の OpenCode で Agent の応答が終わったとき（またはエラーで止まったとき、許可や回答を待っているとき）に、スマホへ通知を届けます。

```
OpenCode（PC/Mac）
  └─ プラグイン push/plugin/opencode-mobile-push.js
       │  POST /v1/notify（認証キー + 暗号文）
       ▼
中継サーバー push/relay（Cloudflare Workers + D1）
       │  FCM HTTP v1（中身は暗号文のまま）
       ▼
FCM ──(iOS は APNs 経由)──▶ アプリが復号して表示
```

- **ペアリングキー**: PC/Mac のプラグインが最初の起動時に作る 43 文字のランダムな鍵です。`~/.config/opencode/opencode-mobile-push.json`（本人だけが読める権限）に保存され、アプリは OpenCode サーバー経由でこのファイルを読んで同じ鍵を使います。
- **暗号化**: ペアリングキーから HKDF-SHA256 で 2 つの鍵を作ります。「認証キー」は中継への端末登録と通知の送信に使い、中継は SHA-256 のハッシュでしか保存しません。「暗号鍵」は中継に渡さず、プロジェクト名とセッションのタイトルを AES-256-GCM で暗号化します。中継が知るのは通知の種類（完了・エラー・許可待ち・質問）とセッション ID だけです。暗号文は種類とセッション ID に結び付けてあるので、中継が組み替えると復号に失敗します。
- **表示**: Android は本文なしのデータ通知を受けてアプリが復号し、ローカル通知を出します。iOS は「OpenCode」という仮の通知を受け、Notification Service Extension が表示の直前に復号して書き換えます。復号できないときは「応答が完了しました」などの見出しだけを出します。
- **通知の内容**: タイトルは「プロジェクト名: 応答が完了しました」などで、本文はセッションのタイトルです。プラグインの `includeTitle: false` で本文を空にできます。
- 暗号化の仕様は `push/test-vector.json` の値で、プラグイン（JavaScript）とアプリ（Dart）のテストが同じ結果になることを確かめています。
- **タップ時**: 通知を送ったサーバーに接続し（必要なら保存済みの認証情報で再接続し）、そのセッションのチャットを開きます。アプリが前面にあるときは画面下部に表示します。
- サブエージェントのセッションは通知しません。同じ種類の通知は 15 秒以内に重複して送りません。
- **乱用対策**: 中継は接続元 IP ごとに 1 分 60 リクエスト、ペアリングキーごとに 1 分 30 通知までに制限し、超えると 429 を返します。1 つのキーに登録できる端末は新しい順に 10 台までです。値は `push/relay/wrangler.toml` で変えられます。

## 1. Firebase（無料）

1. [Firebase コンソール](https://console.firebase.google.com/) でプロジェクトを作る。
2. Android アプリ（パッケージ名は `android/app/build.gradle.kts` の `applicationId`）と iOS アプリ（Xcode の Bundle Identifier）を登録する。`google-services.json` と `GoogleService-Info.plist` はリポジトリに入れません。中の値を下の `push.env.json` に写します。
3. iOS: Apple Developer の「Certificates, Identifiers & Profiles → Keys」で APNs 認証キー（.p8）を作り、Firebase の「プロジェクトの設定 → Cloud Messaging → Apple アプリの構成」にアップロードする。App ID で Push Notifications を有効にする。
4. 「プロジェクトの設定 → サービスアカウント → 新しい秘密鍵を生成」でサービスアカウントの JSON をダウンロードする（中継サーバーで使う）。

## 2. 中継サーバー（Cloudflare Workers、無料枠で足ります）

```bash
cd push/relay
npx wrangler login
npx wrangler d1 create opencode-push       # 出力された database_id を wrangler.toml に貼る
npx wrangler d1 migrations apply opencode-push --remote
npx wrangler secret put FCM_SERVICE_ACCOUNT < /path/to/service-account.json
npx wrangler deploy                        # https://relay.opencodemobile.app
```

`wrangler.toml` の `routes` で `relay.opencodemobile.app` に割り当てます。ドメインの DNS が同じ Cloudflare アカウントにあれば、DNS レコードと証明書はデプロイ時に自動で作られます。`workers.dev` のアドレスも引き続き使えます。

テスト: `node --test push/relay/test/*.test.js`

### KV 版から移行するとき

以前の版は端末の登録を KV（`DEVICES`）に保存していました。上の手順で D1 を用意したうえで、`wrangler.toml` の末尾にあるコメントを外して古い KV の id を書いてからデプロイします。各ペアリングキーの登録は、そのキーで最初に通知や登録があったときに D1 へ移って KV から消えます。全員の移行が済んだら（`npx wrangler kv key list --binding DEVICES` が空になったら）、この設定を消してかまいません。

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

Android は同じ `push.env.json` を Gradle が読み、FCM がアプリの起動前でも通知を受けられるように Firebase の設定をリソースに入れます。

### iOS の追加設定（Xcode で一度だけ）

`ios/Runner/Runner.entitlements` には Push Notifications（`aps-environment`）と App Group（`group.app.opencodemobile`）を入れてあります。Notification Service Extension のソースは `ios/NotificationService/` にありますが、Xcode のターゲットの追加は手作業が必要です。

1. `ios/Runner.xcworkspace` を開き、File → New → Target → Notification Service Extension を選ぶ。Product Name は `NotificationService`、言語は Swift。「Activate scheme」は Cancel でかまいません。
2. Xcode が作った `NotificationService.swift` と `Info.plist` を削除し、`ios/NotificationService/` の同名ファイルをターゲットに追加する。
3. NotificationService ターゲットの Build Settings（上部のフィルターを All にする）で `CODE_SIGN_ENTITLEMENTS` を `NotificationService/NotificationService.entitlements` にし、iOS Deployment Target を Runner と同じ 18.0 にする（アプリの対応は iOS 18 以降）。
4. Runner と NotificationService の両方で Signing & Capabilities を開き、Push Notifications（Runner のみ）と App Groups（`group.app.opencodemobile`）が有効になっていることを確認する。Bundle ID を変えたときは App Group 名も `ios/Runner/AppDelegate.swift` と `NotificationService.swift` で合わせて変える。
5. Runner ターゲットの Build Phases で、**Embed Foundation Extensions** を **Thin Binary** より上（Copy Bundle Resources のすぐ下）に移動する。これをしないと「Cycle inside Runner」でビルドが止まります。

ビルドで「Multiple commands produce ... NotificationService.appex/Info.plist」と出たときは、NotificationService ターゲットの Build Phases → Copy Bundle Resources から `Info.plist`（と `.entitlements`）を外します。一覧に無ければ、`NotificationService/Info.plist` の Target Membership から NotificationService のチェックを外します。

この設定をしなくても通知は届きますが、iOS では中身が「OpenCode」だけになります。

Apple Developer の Identifiers に `app.opencodemobile`（Push Notifications と App Groups を有効）が登録されていないと、中継のログに `FCM 400` と `TopicDisallowed` が出て通知が届きません。シミュレーター向けのビルドは署名しないので、Xcode が App ID を自動登録しないことがあります。その場合は手で登録します。

## 4. アプリと PC/Mac の設定

1. `~/.config/opencode/opencode.json`（または `opencode.jsonc`）に `"plugins": ["opencode-mobile-push"]` を追加し、OpenCode を再起動する。プラグインは npm から入り、最初の起動時にペアリングキーを作って `~/.config/opencode/opencode-mobile-push.json` に保存します。中継は既定で `https://relay.opencodemobile.app` を使います。
2. アプリでサーバーに接続し、プロジェクト一覧右上のベルから「このサーバーの通知を受け取る」をオンにする。アプリは `GET /api/config` で設定ファイルの場所を知り、`GET /api/fs/read/opencode-mobile-push.json` で PC のキーを読んで、自動でそのキーに合わせます。キーのコピーは要りません。2台目以降の端末も同じキーに合わせるので、全部の端末に通知が届きます（1つのキーで最大10台）。
3. アプリの通知画面の「プッシュ通知プラグイン」で、プラグインが動いているかと今の版を確認できます（`GET /api/plugin` と `GET /api/config` を読みます）。
4. プラグインに新しい版が出ると、通知画面と接続の診断に今の版と新しい版、「プラグインを更新」ボタンが出ます。押すと OpenCode の `POST /api/plugin/update` で入れ替えて読み込み直します。OpenCode は版を書かない npm プラグインを一度入れたら自分では入れ替えないので、`opencode.json` を書き換えずに版を上げるにはこれを使います。新しい版の有無は OpenCode の確認結果（`GET /api/plugin` の `outdated`）と npm の `latest` で判断します。版を指定した書き方（`@0.3.0` など）のときはボタンを出しません。

アプリが PC のファイルを書き換えることはありません（プラグインの更新は OpenCode 自身の更新機能を呼ぶだけです）。キーの持ち主は常に PC 側です。

自前の中継を使う場合や、キーを自分で決めたい場合は、オプションで渡します。`opencode.json` / `opencode.jsonc` のオプションは設定ファイルより優先されます。アプリは `opencode.json` のキーも読み取って合わせます。npm を使わない場合は、`push/plugin/opencode-mobile-push.js` を `~/.config/opencode/plugins/` にコピーします（v2 は `"package"` にファイルのパスを書くと無視します）。オプションを渡せないので、プラグインは同じ設定ファイルから中継とキーを読みます。

```jsonc
"plugins": [
  {
    "package": "opencode-mobile-push",
    "options": {
      // 任意。省略すると公開の中継と、自動で作ったキーを使う
      "relay": "https://<自前の中継>",
      "key": "<ペアリングキー>",
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

### プラグインを npm に公開する

`push/plugin` がそのまま npm パッケージ `opencode-mobile-push` になります（MIT ライセンス）。公開されるのは `opencode-mobile-push.js`、`README.md`、`LICENSE` だけです（`npm pack --dry-run` で確認できます）。

公開は GitHub Actions の「Publish plugin」ワークフロー（`.github/workflows/publish-plugin.yml`）で行います。npm の Trusted Publishing を使うので、npm のトークンは要りません。

1. 最初の 1 回だけ手元で公開する（Trusted Publishing はパッケージが存在しないと設定できないため）: `cd push/plugin && npm login && npm publish --access public`
2. npmjs.com のパッケージ設定 → Trusted Publisher で GitHub Actions を選び、リポジトリ `chaki1019/opencode-mobile`、ワークフロー `publish-plugin.yml` を登録する。
   「Allow npm publish」と「Allow npm dist-tag」はオフのままにする。
3. 以降は `push/plugin/package.json` の `version` を上げて main にマージすると、ワークフローが自動で動く（手動でも実行できる）。npm にすでにある版なら何もしない。ワークフローは公開待ち（stage）までを行い、npmjs.com で承認すると公開される。
