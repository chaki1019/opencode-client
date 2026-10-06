# CI とストア配信

| いつ | どこで | 何をするか |
| --- | --- | --- |
| PR を出したとき・追加で push したとき | GitHub Actions（`.github/workflows/ci.yml`） | format チェック、`flutter analyze`、`flutter test`、Android の debug ビルド、`push/` の Node テスト |
| `v1.0.1` のようなタグを push したとき | Codemagic（`codemagic.yaml`） | iOS / Android のリリースビルドを作り、App Store と Google Play の審査に出す（承認されると公開） |

GitHub Actions は Linux で動くので、private リポジトリの無料枠（月 2,000 分）をそのまま消費します。`site/` `docs/`、Markdown、`release_notes.json` だけを変えた PR ではチェックを動かしません。main へのマージ時も再実行しません。

Codemagic の無料枠（macOS で月 500 分）はリリースビルドにだけ使います。

## リリースのしかた

1. ルートの `release_notes.json` に今回の変更点を書き、PR でマージする（下の「リリースノート」）。
2. main でタグを打って push する。

```bash
git checkout main && git pull
git tag v1.0.1
git push origin v1.0.1
```

- バージョン名（`1.0.1`）はタグから取ります。`pubspec.yaml` の `version` を書き換える必要はありません。
- ビルド番号は TestFlight と Google Play に上がっている最大の番号に 1 を足したものを自動で使います。
- iOS は TestFlight に上げたうえで App Store の審査に出し、承認されると公開されます。「このバージョンの最新情報」には `release_notes.json` の内容が入ります。
- Play は製品版トラックにリリースを作るところまで行います。Play Console の「公開の概要」で「変更を審査に送信」を押すと審査に出て、承認されると公開されます。審査に一度リジェクトされたアプリは Play が API からの自動送信を受け付けないため、この手順にしています。事前に動作確認したいときは、タグを打つ前に `Android AAB (manual upload)` で作った AAB を内部テストに手で上げて確かめてください。

## リリースノート

`release_notes.json` の `text` が、次の欄にそのまま入ります。

| 言語コード | 入る場所 |
| --- | --- |
| `ja` | App Store の「このバージョンの最新情報」と TestFlight の「テスト内容」（日本語） |
| `ja-JP` | Google Play のリリースノート（日本語） |
| `en-US` | App Store・TestFlight・Google Play の英語 |

App Store と Google Play で日本語のコードが違うため、日本語は同じ文を 2 回書きます。ストアに登録していない言語は無視されます。`<` と `>` は Apple の API が受け付けないので使わないでください。Google Play のリリースノートは 1 言語 500 文字までです。

ファイルを更新し忘れると前回の文がそのまま使われるので、タグを打つ前に書き換えてください。

## 初回セットアップ

### 1. Codemagic にリポジトリをつなぐ

1. [Codemagic](https://codemagic.io/) に GitHub アカウントでサインアップする（個人の無料プラン）。
2. 「Add application」で `chaki1019/opencode-mobile` を選び、プロジェクトの種類は Flutter、設定は「codemagic.yaml」を選ぶ。

### 2. App Store Connect API キー

1. App Store Connect の「ユーザとアクセス」→「統合」→「App Store Connect API」で、アクセス権「App Manager」のキーを作り、`.p8` をダウンロードする。
2. Codemagic の Settings（個人アカウントでは「Personal account settings」、チームでは「Team settings」）→「Integrations」→「Developer Portal」の「Connect」か「Manage keys」で、名前を **`opencode-mobile`** にしてキーを登録する（Issuer ID、Key ID、`.p8`）。
3. App Store Connect でアプリ（バンドル ID `app.opencodemobile`）を作り、「App 情報」の Apple ID（数字）を `codemagic.yaml` の `APP_STORE_APPLE_ID` に書く。

### 3. iOS の署名

Apple Developer の「Identifiers」で、次の 2 つの App ID に機能が付いていることを確かめます。

| App ID | 必要な機能 |
| --- | --- |
| `app.opencodemobile` | Push Notifications、App Groups（`group.app.opencodemobile`） |
| `app.opencodemobile.NotificationService` | App Groups（`group.app.opencodemobile`） |

そのうえで Codemagic の Settings（上と同じページ）→「codemagic.yaml settings」→「Code signing identities」で次を行います。

1. 「iOS certificates」で Apple Distribution 証明書を作る（「Generate certificate」）か、手元の `.p12` を上げる。
2. 「iOS provisioning profiles」→「Fetch profiles」で、上の 2 つの App ID の App Store 用プロファイルを取り込む。なければ Apple Developer で作ってから取り込む。

`ios_signing` の `bundle_identifier: app.opencodemobile` で、拡張機能（NotificationService）のプロファイルも一緒に使われます。

### 4. Android の署名（アップロード鍵）

アップロード用の鍵を作ります。なくすと Play への更新が出せなくなるので、パスワードと一緒に安全な場所に保管してください。

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Codemagic の「Code signing identities」→「Android keystores」に、参照名 **`opencode_android`** で上げます（パスワードとエイリアスも入力）。

手元でリリースビルドに署名したいときは、`android/key.properties`（git に入りません）を置きます。

```properties
storeFile=/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

鍵がないときのリリースビルドは debug 鍵で署名されます（Play には上げられません）。

### 5. Google Play

1. Play Console でアプリ（パッケージ名 `app.opencodemobile`）を作る。
2. **最初の 1 回だけ** AAB を手で上げる（Play の API は、まだ一度もビルドが上がっていないアプリには上げられないため）。Codemagic で「Start new build」からワークフロー **Android AAB (manual upload)** を選んで実行し（タグは不要）、Artifacts の `.aab` を内部テストトラックに上げます。このワークフローは Android だけをビルドし、ストアには上げません。先に 6 の `app_config` を作っておくと、本番の設定入りでビルドされます（未設定の項目は push や本番広告がオフのビルドになります）。
3. Google Cloud でサービスアカウントを作り、JSON キーを発行する。Play Console の「ユーザーと権限」でそのアカウントを招待し、このアプリのリリース権限を付ける。
4. 最初のリリースを公開するまでは、Play が下書きしか受け付けません。それまでは `codemagic.yaml` の `submit_as_draft` を `true` にしておきます（今は公開済みなので `false`）。

### 6. 環境変数

Codemagic のアプリ設定 →「Environment variables」で、次の 2 つのグループを作ります。値はすべて「Secret」にします。空の変数はスキップされ、その機能がオフのビルドになります。

グループ **`app_config`**

| 変数 | 中身 |
| --- | --- |
| `PUSH_ENV_JSON` | `push.env.json` の中身（JSON をそのまま貼る） |
| `ADS_ENV_JSON` | `ads.env.json` の中身 |
| `APP_ENV_JSON` | `app.env.json` の中身 |
| `ADMOB_IOS_APP_ID` | iOS の AdMob アプリ ID（`ios/Flutter/Ads.xcconfig` に書く値） |
| `FIREBASE_APP_ID_FILE_JSON` | 任意。`ios/firebase_app_id_file.json` の中身（[support.md](support.md#ios-dsym-のアップロード)） |

グループ **`google_play`**

| 変数 | 中身 |
| --- | --- |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | 5 で作ったサービスアカウントの JSON キー |

## 費用の目安

1 回のリリースは iOS と Android を続けてビルドして 20〜25 分ほどの見込みで、無料枠では月 20 回前後です。足りなくなったら、ビルド時間を見ながら iOS と Android でワークフローを分ける（片方だけ出す）こともできます。

「Language 'ja-JP' is not supported by App Store Connect」というログは、App Store が `ja-JP` を読み飛ばしたという意味です。日本語は `ja` で入るので問題ありません。
