# ストア掲載情報

App Store と Google Play に登録するテキストと画像です。ストアごと、言語ごとにフォルダを分けています。
`.txt` は各項目にそのまま貼り付けられるプレーンテキストです。言語フォルダ名とテキストのファイル名は fastlane（deliver / supply）のメタデータと同じにしているので、CI/CD から自動でアップロードするときにも流用できます。

```
app-store/
  ja/  en-US/
    name.txt               名前（30 文字まで）
    subtitle.txt           サブタイトル（30 文字まで）
    promotional_text.txt   プロモーションテキスト（170 文字まで）
    keywords.txt           キーワード（100 文字まで、カンマ区切り）
    description.txt        説明文（4000 文字まで）
    release_notes.txt      このバージョンの新機能
    screenshots/
      iphone-6.9/          1290×2796 ×6（小さい iPhone には自動で縮小）
      ipad-13/             2064×2752 ×5（縦）
      ipad-13-landscape/   2752×2064 ×5（横）
google-play/
  ja-JP/  en-US/
    title.txt              アプリ名（30 文字まで）
    short_description.txt  簡単な説明（80 文字まで）
    full_description.txt   詳しい説明（4000 文字まで）
    feature-graphic.png    フィーチャー グラフィック 1024×500
    promo-video.mp4        紹介動画 1920×1080・約 22 秒（YouTube に上げて URL を登録）
    screenshots/
      phone/               スマートフォン 1080×1920 ×6
      tablet-7/            7 インチ タブレット 1200×1920 ×6（縦）
      tablet-7-landscape/  7 インチ タブレット 1920×1200 ×5（横）
      tablet-10/           10 インチ タブレット 1600×2560 ×5（縦）
      tablet-10-landscape/ 10 インチ タブレット 2560×1600 ×5（横）
```

タブレットは縦向きと横向きの両方を用意しています。横向きでは一覧とチャットを並べた 2 画面表示になります。ストアには向きの違う画像を混ぜて登録できますが、1 つのセットの中ではどちらかにそろえたほうが見栄えがよくなります。

アプリのアイコンは `branding/app-icon/` にあります（App Store 用 `app-store-1024.png`、Google Play 用 `play-store-512.png`）。

## 内容について

- どの説明文にも、OpenCode とは関係のない非公式クライアントである旨を入れています。
- Google Play の詳しい説明は App Store の説明文をもとに、「キーチェーン」を「Android Keystore」に、「iPad」を「タブレット」に替えています。片方を直したら、もう片方も直してください。
- 料金の説明（1 日 10 回まで無料、リワード広告で追加）は `AdsConfig` の値に合わせています。値を変えたら説明文も直してください。
- Google Play の動画は YouTube の URL で登録します。`promo-video.mp4` を YouTube に（限定公開でも可）アップロードし、広告を付けない設定にしてください。
- App Store のプレビュー動画は用意していません。Apple はプレビューにアプリの実際の画面収録を求めるため、静止画をつないだ動画は却下されることがあります。作る場合は実機の画面収録から作ってください。
- カテゴリは App Store が「デベロッパツール」、Google Play が「ツール」の想定です。
- Apple はガイドライン 5.2.1 で、他者の名称を含むアプリ名を却下することがあります。指摘された場合は「〜 for OpenCode」の形にする案があります。

## スクリーンショットの作り直し

画面は実際のアプリをウィジェットテストで描画し、キャプションと端末の枠を付けて合成しています。画面のデザインが変わったら、次の手順で作り直せます。

1. 静的な Noto Sans JP（`NotoSansJP-{400,500,600,700}.ttf`）を用意します。Google Fonts の CSS API（`https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400`）から TTF の URL を取れます。
2. `tool/store_screenshots_test.dart` を `test/zz_store/` にコピーして撮影します（テストスイートには含めません）。

   ```bash
   flutter test test/zz_store --name "(chat|diff|permission)\$" \
     --dart-define=OUT=/tmp/shots --dart-define=FONT_DIR=<フォントのフォルダ>
   # connect の撮影は終わったあと止まるので、1 つずつ timeout を付けて実行します
   for t in ja en; do for d in phone tablet tablet7 tabletLand tablet7Land; do
     timeout 45 flutter test test/zz_store --plain-name "$t/$d connect" \
       --dart-define=OUT=/tmp/shots --dart-define=FONT_DIR=<フォントのフォルダ>
   done; done
   rm -r test/zz_store
   ```

3. リポジトリのルートで合成します（Node、Playwright、ffmpeg が必要です）。スクリーンショット、フィーチャー グラフィック、紹介動画がまとめて作り直されます。

   ```bash
   NOTO_JP_DIR=<フォントのフォルダ> node branding/store-listing/tool/render.mjs /tmp/shots branding/store-listing
   ```

   `ONLY=<正規表現>` を付けると、フォルダ名が一致するスクリーンショットだけを作り直します（フィーチャー グラフィックと動画は作りません）。例：`ONLY=landscape`

キャプションの文言は `tool/render.mjs` の `copy` にあります。
