# 強制アップデート

インストール中のバージョンが最低バージョンより古ければ、アプリ全体を「アップデートが必要です」の画面に置き換えます。ストアで更新するまでアプリは使えません。

- 最低バージョンは Firebase Remote Config から読みます。起動時と前面に戻ったとき（30 分に 1 回まで）に取りに行き、コンソールで値を変えるとアプリを開いている間にも届きます。
- 比べるのは `pubspec.yaml` の `version` の `+` より前（例 `1.2.0`）です。
- 取得に失敗したとき（オフライン、タイムアウト）は前回取れた値で判断し、一度も取れていなければそのまま使えます。ユーザーを締め出しません。
- Firebase の設定が無いビルド（`push.env.json` 無し）は、代わりに中継サーバーの `GET /v1/app-version` に問い合わせます（下の「中継サーバー」）。

## 最低バージョンを上げる

Firebase コンソールの Remote Config で、次のパラメータを追加・変更して公開します。広告の切り替え（[ads.md](ads.md)）も同じ画面です。

| パラメータ | 内容 |
|---|---|
| `min_version_ios` / `min_version_android` | これより古いバージョンをブロックする（未設定や空ならブロックしない） |
| `store_url_ios` | App Store のページ（例 `https://apps.apple.com/app/id1234567890`）。未設定だとボタンを出さず「App Store から更新してください」とだけ表示します |
| `store_url_android` | 未設定なら `https://play.google.com/store/apps/details?id=<applicationId>` を使います |

型はどれも文字列で作ります。

新しい版がストアの審査を通って公開されてから最低バージョンを上げてください。先に上げると、更新先がないまま使えなくなります。

## 中継サーバー（Remote Config 対応前のビルド向け）

Remote Config を読む前に配布したビルドは、中継サーバーの `GET /v1/app-version` だけを見ます（`PUSH_RELAY_URL` から自動で決まり、`UPDATE_CHECK_URL` で別の URL も指定できます）。そうしたビルドに更新を促すときだけ、こちらを使います。

Remote Config 対応版がストアに出たら、中継サーバーの最低バージョンを一度だけその版に上げると、古いビルドの利用者が全員 Remote Config 対応版に移ります。それ以降は中継サーバーを触る必要はありません。

`push/relay/wrangler.toml` の `[vars]` を書き換えて `npx wrangler deploy` するか、Cloudflare ダッシュボードの Worker → Settings → Variables で直接変更します。ダッシュボードで変えた値は、次に `wrangler deploy` すると `wrangler.toml` の値に戻るので、両方そろえておいてください。

| 変数 | 内容 |
|---|---|
| `MIN_VERSION_IOS` / `MIN_VERSION_ANDROID` | Remote Config の `min_version_*` と同じ |
| `STORE_URL_IOS` / `STORE_URL_ANDROID` | Remote Config の `store_url_*` と同じ |

応答は 5 分キャッシュされるので、反映まで最大 5 分ほどかかります。

```json
{
  "ios": { "minimum": "1.2.0", "storeUrl": "https://apps.apple.com/app/id1234567890" },
  "android": { "minimum": "1.2.0", "storeUrl": null }
}
```
