# 広告と「広告を外す」課金

アプリは誰でも無料で使えます。運営費の足しとして広告を出しますが、機能や回数のハードな制限はかけません。

## 仕組み

- **バナー**: プロジェクト一覧とセッション一覧の画面下部にアダプティブバナーを1枠出します。チャット画面には出しません。
- **リワード広告**: 広告なしで送れるのは1日10回までです。11回目の送信時に案内を出し、広告を最後まで見るとその日さらに10回送れます。
  - 広告が読み込めない・表示できないときは、そのまま送信を通します（広告の不調で使えなくなることはありません）。
  - 途中で閉じた場合は送信せず、入力した文はそのまま残ります。
  - 回数は端末内（`flutter_secure_storage`）で数え、端末のローカル日付が変わるとリセットします。
  - 回数とリワード広告のオン・オフは、アプリを出し直さずに中継サーバーから変えられます（下の「リワード広告をサーバーから切り替える」）。アプリ内の既定値は `lib/core/ads/ads_config.dart` の `dailyFreeMessages` / `messagesPerReward` です。
- **広告を外す**: 買い切りの非消耗型アイテム（既定の商品 ID は `remove_ads`）。購入すると両方の広告が出なくなります。購入の復元にも対応します。購入状態は端末内に保存し、レシートのサーバー検証はしていません。
- **同意**: 起動時に Google の UMP で同意を集めます（EEA・英国の同意画面、AdMob 側で設定すれば iOS の ATT ダイアログも）。設定画面の「広告のプライバシー設定」から同意をやり直せます。広告を外したユーザーには同意画面も出しません。

広告まわりのコードは `lib/core/ads/` と `lib/features/ads/` にあります。

## リワード広告をサーバーから切り替える

強制アップデートと同じ中継サーバーの `GET /v1/app-version`（[force-update.md](force-update.md)）が、最低バージョンと一緒に `ads` を返します。値は Cloudflare の Workers KV に JSON で置き、ダッシュボードで書き換えるだけで変わります（デプロイ不要）。

### 最初に一度だけ

1. `cd push/relay && npx wrangler kv namespace create opencode-config` を実行し、表示された `id` を `wrangler.toml` の `[[kv_namespaces]]`（`binding = "CONFIG"`）に貼ってコメントを外す。
2. `npx wrangler deploy` する。

KV が無い間はアプリの既定値のままです。

### 値を変える

Cloudflare ダッシュボードの Storage & Databases → KV → `opencode-config` で、キー `ads` に JSON を保存します（コマンドなら `npx wrangler kv key put --binding CONFIG --remote ads '{"rewarded":false}'`）。

```json
{ "rewarded": false, "freeMessages": 20, "messagesPerReward": 10 }
```

| キー | 内容 |
|---|---|
| `rewarded` | `false` でリワード広告と 1 日の回数制限をなくす（バナーはそのまま）。`true` または省略で今まで通り |
| `freeMessages` | 広告なしで送れる 1 日の回数（1〜1000 の整数）。省略ならアプリの既定値（10） |
| `messagesPerReward` | 広告 1 回で増える回数（1〜1000 の整数）。省略ならアプリの既定値（10） |

- 中継サーバーには 1 分ほどで反映されます。アプリは起動時と前面に戻ったとき（30 分に 1 回まで）に読むので、各端末に届くのはその次の問い合わせです。
- 型が違う値（`"10"`、`0`、`"no"` など）や壊れた JSON は省略と同じ扱いで、アプリの既定値になります。キーを消すと既定値に戻ります。
- 問い合わせに失敗したときは、前回受け取った値（端末に保存）を使います。一度も受け取っていなければアプリの既定値です。失敗時に広告をオフにしないのは、中継サーバーへの通信を止めるだけで広告を避けられないようにするためです。
- 無料回数を増やすとその日のうちに反映し、減らすと翌日から効きます。
- 中継サーバーの URL が無いビルド（`PUSH_RELAY_URL` も `UPDATE_CHECK_URL` も無し）では切り替えられず、常にアプリの既定値です。

## ビルド設定

何も設定しなければ Google のテスト用 ID で動き、テスト広告だけが出ます。本番の ID は `ads.env.example.json` を `ads.env.json` にコピーして埋めます（`ads.env.json` は git に入りません）。

```bash
flutter run --dart-define-from-file=push.env.json --dart-define-from-file=ads.env.json
```

- Android のアプリ ID（`ADMOB_ANDROID_APP_ID`）は同じ `ads.env.json` を Gradle が読み、`AndroidManifest.xml` に入れます。
- iOS のアプリ ID は `ios/Flutter/Ads.xcconfig`（git に入りません）に書きます。

  ```
  ADMOB_IOS_APP_ID = ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
  ```

- 「広告を外す」はストアに商品を登録するまで `REMOVE_ADS_ENABLED` を `false` のままにします。`true` にしても、ストアから商品情報が取れない間は購入ボタンを出しません。

## 公開前にやること

1. [AdMob](https://admob.google.com/) でアカウントを作り、iOS と Android のアプリを登録してアプリ ID を発行する。
2. 各アプリにバナー（アダプティブ）とリワードの広告ユニットを作り、ID を `ads.env.json` に書く。
3. AdMob の「プライバシーとメッセージ」で、EEA・英国向けの GDPR メッセージと、iOS の IDFA 説明メッセージ（ATT）を作成して公開する。
4. App Store Connect と Play Console で非消耗型アイテム `remove_ads` を登録し、価格（案: 480円）を設定する。登録後に `REMOVE_ADS_ENABLED` を `true` にする。
5. 公開サイト（`site/`、[docs/support.md](support.md)）の `app-ads.txt` にパブリッシャー ID を書き、ストアの掲載情報のウェブサイト欄にそのドメインを書く。
6. App Store の「App のプライバシー」と Play の「データ セーフティ」に、広告 SDK が集めるデータ（デバイス ID、利用状況など）を記載する。
7. iOS の `SKAdNetworkItems`（`ios/Runner/Info.plist`）には Google の ID だけを入れています。メディエーションを使う場合は、Google が公開している一覧に合わせて足す。
