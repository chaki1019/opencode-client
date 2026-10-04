# お問い合わせ・プライバシーポリシー・クラッシュレポート

ストアに出すために必要な「お問い合わせ先」「プライバシーポリシー」「サポートページ」と、クラッシュレポート（Firebase Crashlytics）の設定です。

## アプリ側

設定画面の下に「サポートとプライバシー」の欄があります。

- **お問い合わせ**: メールアプリを開き、件名と、本文の末尾にアプリのバージョンと OS を入れた下書きを作ります。
- **プライバシーポリシー**: アプリの言語に合わせて `SITE_URL/ja/privacy/`（日本語）か `SITE_URL/en/privacy/`（英語）をブラウザで開きます。
- **クラッシュレポートを送信**: 既定はオンです。オフにすると Crashlytics の送信を止め、未送信のレポートも消します。

宛先とサイトの URL は `app.env.example.json` を `app.env.json` にコピーして埋めます（`app.env.json` は git に入りません）。指定しないでビルドしたときは `support@opencodemobile.app` と `https://opencodemobile.app` を使います。空の文字列を指定した項目の行は表示しません。

```bash
flutter build ipa \
  --dart-define-from-file=push.env.json \
  --dart-define-from-file=ads.env.json \
  --dart-define-from-file=app.env.json
```

コードは `lib/core/support/`、`lib/core/crash/`、`lib/features/settings/support_section.dart` にあります。

## 公開サイト（`site/`）

サイトは `https://opencodemobile.app` で公開します（Cloudflare Pages に独自ドメインを割り当て）。push の中継で使っている Cloudflare アカウントをそのまま使えます。

| パス | 内容 |
| --- | --- |
| `/` | ブラウザの言語を見て `/ja/` か `/en/` へ移動（どちらでもなければ `/en/`） |
| `/ja/` , `/en/` | アプリの紹介と使い方（LP） |
| `/ja/support/` , `/en/support/` | サポートページ（お問い合わせ先、よくある質問） |
| `/ja/privacy/` , `/en/privacy/` | プライバシーポリシー |
| `/app-ads.txt` | AdMob の app-ads.txt |
| `/favicon.svg` , `/favicon.ico` , `/apple-touch-icon.png` | アプリアイコンと同じ図柄の favicon。`branding/app-icon/generate.mjs` で書き出します |

ページは言語コードのフォルダーに分けています。左側のメニューは各ページに HTML で書いてあり、そのページの見出し（`h2` の `id`）から目次を `site/site.js` が組み立てます。ページを足したら全ページのメニューにも足します。言語を増やすときは `site/<言語コード>/` を作り、各ページの言語切替リンク、`hreflang`、`site/index.html` の `langs` に足します。

### 公開前に直すところ

1. お問い合わせ先は `support@opencodemobile.app` です。Cloudflare の Email Routing で、このアドレス宛てのメールを普段のメールボックスへ転送します（ドメインの DNS が Cloudflare にあることが前提です）。
2. `site/app-ads.txt` には AdMob のパブリッシャー ID（AdMob の「設定」→「アカウント情報」）を書いてあります。アカウントを変えたらここも直す。
3. プライバシーポリシーの内容が実際のアプリと合っているか読み直す。データの扱いを変えたら、ここも合わせて直す。
4. LP（`site/ja/index.html` と `site/en/index.html`）のストアのボタンは仮置きです。ストアの URL が決まったら、HTML のコメントがある箇所をバッジに差し替えます。
5. LP のスクリーンショット（`site/img/<言語>/*.webp`）はストア用とは別に作った、説明文や端末の枠を含まないアプリ画面だけの画像です（スマホ 540×1170、タブレットは横向きで 1600×1200 と 1000×750）。ストア用画像と同じ素の画面（`store_screenshots_test.dart` の出力）から、プロジェクト共有フォルダの `store-listing/src/lp-render.mjs` でステータスバーを付けて書き出します。リポジトリのルートで `node lp-render.mjs <素の画面のフォルダ> site branding/app-icon/app-store-1024.png` を実行すると、全言語分が上書きされます。

### デプロイ

どちらか一方で公開します。

- **Git 連携（おすすめ）**: Cloudflare のダッシュボードで Workers & Pages → 作成 → Pages → Git に接続 → このリポジトリを選び、ビルドコマンドは空、出力ディレクトリは `site` にします。main に push するたびに自動で更新されます。
- **手元から**: `npx wrangler pages deploy site --project-name opencode-mobile`

公開後、Pages プロジェクトの「カスタムドメイン」で `opencodemobile.app` を追加します。`app.env.json` の `SITE_URL` は `https://opencodemobile.app` にします。

### ストアに書く URL

- App Store Connect: 「プライバシーポリシー URL」に `/ja/privacy/`（英語ストアには `/en/privacy/`）、「サポート URL」に `/ja/support/`（英語ストアには `/en/support/`）、「マーケティング URL」に `/ja/`（英語は `/en/`）。
- Play Console: 「アプリのコンテンツ」→「プライバシー ポリシー」に `/ja/privacy/`。ストアの掲載情報の「ウェブサイト」にサイトの URL、「メールアドレス」にお問い合わせ先を書きます。
- AdMob は、ストアの「ウェブサイト」に書いたドメインの直下で `app-ads.txt` を探します。ストアのウェブサイト欄には `https://opencodemobile.app` を書きます。

### ストアのデータ開示

App Store の「App のプライバシー」と Play の「データ セーフティ」には、おおむね次のように答えます（最終的には各ストアの質問文に沿って確認してください）。

| データ | 用途 | 送り先 |
| --- | --- | --- |
| 広告 ID・端末情報・おおよその位置（IP から） | 広告の表示と測定 | AdMob（広告を外したユーザーを除く） |
| クラッシュログ・診断情報 | アプリの不具合修正 | Firebase Crashlytics |
| 通知トークン | プッシュ通知 | 通知中継（Cloudflare）、FCM |
| 購入履歴 | 「広告を外す」 | App Store / Google Play |

チャット、ファイル、サーバーの接続情報は利用者自身のサーバーとの間だけでやり取りし、開発者は収集しません。

## Crashlytics

Firebase は push と同じプロジェクトを使い、値も `push.env.json` の `FIREBASE_*` から読みます。これがないビルドや、debug ビルドではクラッシュレポートを送りません。

1. Firebase コンソールで Crashlytics を有効にする。
2. release ビルドを実機で起動し、わざと例外を起こすなどして、コンソールにレポートが届くことを確かめる。

### iOS: dSYM のアップロード

ネイティブのスタックトレースを読める形にするには dSYM が必要です。`ios/firebase_app_id_file.json`（git に入りません）を置くと、`pod install` のときに firebase_crashlytics が Xcode の Run Script（upload-symbols）を自動で追加します。

```json
{
  "file_generated_by": "FlutterFire CLI",
  "purpose": "FirebaseAppID & ProjectID for this Firebase app in this directory",
  "GOOGLE_APP_ID": "<FIREBASE_IOS_APP_ID>",
  "FIREBASE_PROJECT_ID": "<FIREBASE_PROJECT_ID>",
  "GCM_SENDER_ID": "<FIREBASE_SENDER_ID>"
}
```

### Android

Dart のエラーは追加の設定なしで届きます。Crashlytics の Gradle プラグインは入れていません（AGP 9 との組み合わせを確かめられていないため）。代わりに `com.crashlytics.RequireBuildId` を `false` にして、プラグインなしでも起動時に落ちないようにしています。

Java/Kotlin のクラッシュを R8 の難読化前の名前で読みたくなったら、`android/settings.gradle.kts` に `com.google.firebase.crashlytics` プラグインを足し、`android/app/build.gradle.kts` で適用してください。そのときは `RequireBuildId` の行を消します。

### Dart の難読化をする場合

`--obfuscate --split-debug-info=build/symbols` でビルドしたときは、シンボルを上げないと Dart のスタックトレースが読めません。

```bash
firebase crashlytics:symbols:upload --app=<FIREBASE_APP_ID> build/symbols
```
