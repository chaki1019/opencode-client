# 強制アップデート

起動時とアプリが前面に戻ったとき（30 分に 1 回まで）に最低バージョンを問い合わせ、インストール中のバージョンがそれより古ければアプリ全体を「アップデートが必要です」の画面に置き換えます。ストアで更新するまでアプリは使えません。

- 問い合わせ先は中継サーバーの `GET /v1/app-version` です（`PUSH_RELAY_URL` から自動で決まります）。別の場所に置くときは `UPDATE_CHECK_URL` に JSON の URL を指定してビルドします。
- 比べるのは `pubspec.yaml` の `version` の `+` より前（例 `1.2.0`）です。
- 問い合わせに失敗したとき（オフライン、タイムアウト、不正な応答）はそのまま使えます。中継サーバーが止まってもユーザーを締め出しません。
- どちらの URL も無いビルドではチェックしません。

## 最低バージョンを上げる

`push/relay/wrangler.toml` の `[vars]` を書き換えて `npx wrangler deploy` するか、Cloudflare ダッシュボードの Worker → Settings → Variables で直接変更します。

| 変数 | 内容 |
|---|---|
| `MIN_VERSION_IOS` / `MIN_VERSION_ANDROID` | これより古いバージョンをブロックする（空ならブロックしない） |
| `STORE_URL_IOS` | App Store のページ（例 `https://apps.apple.com/app/id1234567890`）。空だとボタンを出さず「App Store から更新してください」とだけ表示します |
| `STORE_URL_ANDROID` | 空なら `https://play.google.com/store/apps/details?id=<applicationId>` を使います |

応答は 5 分キャッシュされるので、反映まで最大 5 分ほどかかります。

```json
{
  "ios": { "minimum": "1.2.0", "storeUrl": "https://apps.apple.com/app/id1234567890" },
  "android": { "minimum": "1.2.0", "storeUrl": null }
}
```

新しい版がストアの審査を通って公開されてから最低バージョンを上げてください。先に上げると、更新先がないまま使えなくなります。
