// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get reload => '再読み込み';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get send => '送信';

  @override
  String get close => '閉じる';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分前',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間前',
    );
    return '$_temp0';
  }

  @override
  String get yesterday => '昨日';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日前',
    );
    return '$_temp0';
  }

  @override
  String get connectTitle => 'OpenCode サーバーに接続';

  @override
  String get connectUnsupported =>
      'このサーバーは OpenCode v2 API に対応していません。OpenCode を更新してください';

  @override
  String get connectWrongCredentials => 'ユーザー名またはパスワードが違います';

  @override
  String connectFailed(Object error) {
    return '接続できませんでした: $error';
  }

  @override
  String get serverUrl => 'サーバー URL';

  @override
  String get serverUrlRequired => 'URL を入力してください';

  @override
  String get serverUrlInvalid =>
      'URL の形式が正しくありません（例: http://192.168.1.10:4096）';

  @override
  String get connectTimeout =>
      'サーバーから応答がありませんでした。サーバーが起動していて、このネットワークから届くか確認してください。';

  @override
  String get connectUnreachable =>
      'サーバーに接続できませんでした。URL、サーバーが起動しているか、ネットワークからの接続を受け付けているか（--hostname 0.0.0.0）を確認してください。';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get passwordHelper => 'OPENCODE_SERVER_PASSWORD（未設定なら空欄）';

  @override
  String get connect => '接続';

  @override
  String get savedServers => '保存済みサーバー';

  @override
  String savedServersLoadFailed(Object error) {
    return '保存済みサーバーを読み込めませんでした: $error';
  }

  @override
  String get saveServer => '保存';

  @override
  String get saveServerTitle => '接続できました。この接続先を保存しますか？';

  @override
  String get dontSave => '保存しない';

  @override
  String get editServer => '編集';

  @override
  String get editServerTitle => '接続先を編集';

  @override
  String get serverName => '名前';

  @override
  String get discoveredServers => 'このネットワークで見つかったサーバー';

  @override
  String get discoveringServers => 'ネットワーク上の OpenCode サーバーを探しています…';

  @override
  String get discoveryNoneFound => '見つかりませんでした';

  @override
  String get scanNetwork => 'ネットワークを探す';

  @override
  String get rescanNetwork => 'もう一度探す';

  @override
  String get discoveryHint =>
      'ポート 4096 でネットワークからの接続を受け付けているサーバー（opencode serve --hostname 0.0.0.0）と、mDNS で知らせているサーバーを探します';

  @override
  String get reconnecting => 'サーバーに再接続しています…';

  @override
  String get projects => 'プロジェクト';

  @override
  String get disconnect => '切断';

  @override
  String projectsLoadFailed(Object error) {
    return 'プロジェクトを読み込めませんでした: $error';
  }

  @override
  String get currentProject => '現在';

  @override
  String get hideProject => '一覧から外す';

  @override
  String get hideProjectNote =>
      'サーバー上のプロジェクトとセッションはそのまま残ります。「＋」から開き直すと一覧に戻ります。';

  @override
  String projectHidden(Object name) {
    return '「$name」を一覧から外しました';
  }

  @override
  String get undo => '元に戻す';

  @override
  String get addProject => 'プロジェクトを追加';

  @override
  String get projectFolderLabel => 'サーバー上のフォルダのパス';

  @override
  String get projectFolderHint => '/home/me/my-app';

  @override
  String get projectFolderMustBeAbsolute => '絶対パスを入力してください';

  @override
  String get chooseFolder => 'フォルダを選択';

  @override
  String get openThisFolder => 'このフォルダを開く';

  @override
  String get noSubfolders => 'フォルダはありません';

  @override
  String get searchFolders => 'この下のフォルダを検索';

  @override
  String get showHiddenFolders => '隠しフォルダを表示';

  @override
  String get hideHiddenFolders => '隠しフォルダを隠す';

  @override
  String get enterFolderPath => 'パスを入力';

  @override
  String get goToFolder => '移動';

  @override
  String get parentFolder => '上の階層へ';

  @override
  String foldersLoadFailed(Object error) {
    return 'フォルダを読み込めませんでした: $error';
  }

  @override
  String projectOpenFailed(Object error) {
    return 'フォルダを開けませんでした: $error';
  }

  @override
  String get files => 'ファイル';

  @override
  String get terminal => 'ターミナル';

  @override
  String get projectTools => 'プロジェクトのツール';

  @override
  String get newSession => '新しいセッション';

  @override
  String get sessionsEmpty => 'セッションはまだありません';

  @override
  String sessionsLoadFailed(Object error) {
    return 'セッションを読み込めませんでした: $error';
  }

  @override
  String sessionCreateFailed(Object error) {
    return 'セッションを作成できませんでした: $error';
  }

  @override
  String get untitledSession => '無題のセッション';

  @override
  String get rename => '名前を変更';

  @override
  String get compact => '会話を要約';

  @override
  String get compactHelp => 'これまでの会話を要約してコンテキストを空けます。使用率が高くなってきたときに使います。';

  @override
  String get renameFailed => '名前を変更できませんでした';

  @override
  String get forkFailed => 'フォークできませんでした';

  @override
  String get compactFailed => '要約を依頼できませんでした';

  @override
  String get compactRequested => '会話の要約を依頼しました';

  @override
  String get deleteSessionTitle => 'セッションを削除しますか？';

  @override
  String deleteSessionBody(Object title) {
    return '「$title」を削除します。元に戻せません。';
  }

  @override
  String get deleteFailed => '削除できませんでした';

  @override
  String get sessionName => 'セッション名';

  @override
  String get renameConfirm => '変更';

  @override
  String get messagesEmpty => 'メッセージはまだありません';

  @override
  String messagesLoadFailed(Object error) {
    return 'メッセージを読み込めませんでした: $error';
  }

  @override
  String get rewindHere => 'ここまで戻す';

  @override
  String get rewindHereHelp => 'このメッセージ以降の会話と、そのファイルの変更を取り消します';

  @override
  String get rewoundNotice => '巻き戻しました。新しく送信すると確定します。';

  @override
  String get rewindUndo => '元に戻す';

  @override
  String rewindFailed(Object error) {
    return '巻き戻せませんでした: $error';
  }

  @override
  String get forkFromHere => 'このメッセージの前からフォーク';

  @override
  String get forkFromHereHelp => 'これより前の会話を新しいセッションにコピーします';

  @override
  String get running => '実行中';

  @override
  String get sendFailed => '送信できませんでした。内容を確認してもう一度送ってください';

  @override
  String get choosePhoto => '写真を選ぶ';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String imageLoadFailed(Object error) {
    return '画像を読み込めませんでした: $error';
  }

  @override
  String interruptFailed(Object error) {
    return '中断できませんでした: $error';
  }

  @override
  String get attachImage => '画像を添付';

  @override
  String get messageHint => 'メッセージを入力';

  @override
  String get interrupt => '中断';

  @override
  String get removeAttachment => '添付を外す';

  @override
  String get agent => 'エージェント';

  @override
  String get model => 'モデル';

  @override
  String changeFailed(Object error) {
    return '変更できませんでした: $error';
  }

  @override
  String agentsLoadFailed(Object error) {
    return 'エージェントを読み込めませんでした: $error';
  }

  @override
  String get noMatchingModels => '該当するモデルはありません';

  @override
  String get searchModels => 'モデルを検索';

  @override
  String modelsLoadFailed(Object error) {
    return 'モデルを読み込めませんでした: $error';
  }

  @override
  String get variant => 'バリアント';

  @override
  String get agentBuildDescription =>
      'すべてのツールが有効なデフォルトのエージェントです。ファイル操作やシステムコマンドを自由に使う、通常の開発作業向けです。';

  @override
  String get agentPlanDescription =>
      '計画と分析のための制限付きエージェントです。権限設定により、意図しない変更を防ぎます。';

  @override
  String tooManyAttachments(Object count) {
    return '添付は$count件までです';
  }

  @override
  String get attachmentTooLarge => '1ファイル10MBまでです';

  @override
  String get attachmentsTooLarge => '添付は合計24MBまでです';

  @override
  String get sending => '送信中…';

  @override
  String get sendUncertain => '送信できたか確認中です。再送はしていません';

  @override
  String get dismiss => '表示から消す';

  @override
  String get thinking => '考え中…';

  @override
  String get reasoning => '思考';

  @override
  String get noOutput => '出力なし';

  @override
  String get compacted => 'ここまでの会話を要約しました';

  @override
  String contextAgent(Object name) {
    return 'エージェント: $name';
  }

  @override
  String contextModel(Object name) {
    return 'モデル: $name';
  }

  @override
  String contextLocation(Object path) {
    return '場所: $path';
  }

  @override
  String contextSkill(Object name) {
    return 'スキル: $name';
  }

  @override
  String linesOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行省略',
    );
    return '$_temp0';
  }

  @override
  String get scrollToNewest => '最新のメッセージへ';

  @override
  String get reloadOlderMessages => '過去のメッセージを再読み込み';

  @override
  String replyFailed(Object error) {
    return '返答できませんでした: $error';
  }

  @override
  String permissionNeeded(Object action) {
    return '「$action」の許可が必要です';
  }

  @override
  String moreWaiting(Object count) {
    return 'ほか$count件';
  }

  @override
  String get deny => '拒否';

  @override
  String get allowAlways => '常に許可';

  @override
  String get allowOnce => '今回だけ許可';

  @override
  String get sendFailedShort => '送信できませんでした';

  @override
  String get cancelFailed => '取り消せませんでした';

  @override
  String get questionTitle => '質問があります';

  @override
  String get formUnsupported =>
      'この質問にはアプリが対応していない項目があります。取り消すか、別のクライアントで答えてください。';

  @override
  String get dontAnswer => '答えない';

  @override
  String get otherFreeText => 'その他（自由入力）';

  @override
  String get otherCommaSeparated => 'その他（カンマ区切り）';

  @override
  String get copyUrl => 'URLをコピー';

  @override
  String get doneInBrowser => 'ブラウザで完了した';

  @override
  String get allDone => 'すべて完了';

  @override
  String get fieldRequired => '入力してください';

  @override
  String get fieldText => '文字を入力してください';

  @override
  String get fieldPickOption => '選択肢から選んでください';

  @override
  String fieldMinLength(Object count) {
    return '$count文字以上で入力してください';
  }

  @override
  String fieldMaxLength(Object count) {
    return '$count文字以内で入力してください';
  }

  @override
  String get fieldPattern => '形式が正しくありません';

  @override
  String get fieldNumber => '数値を入力してください';

  @override
  String get fieldInteger => '整数を入力してください';

  @override
  String fieldMinimum(Object value) {
    return '$value以上にしてください';
  }

  @override
  String fieldMaximum(Object value) {
    return '$value以下にしてください';
  }

  @override
  String get fieldChoose => '選んでください';

  @override
  String fieldMinItems(Object count) {
    return '$count個以上選んでください';
  }

  @override
  String fieldMaxItems(Object count) {
    return '$count個以内で選んでください';
  }

  @override
  String get fieldExternal => '完了したら確認してください';

  @override
  String get searchFiles => 'ファイル名で検索';

  @override
  String get notFound => '見つかりませんでした';

  @override
  String get emptyFolder => '空のフォルダです';

  @override
  String filesLoadFailed(Object error) {
    return 'ファイルを読み込めませんでした: $error';
  }

  @override
  String binaryFile(Object bytes) {
    return '表示できないファイルです（$bytes バイト）';
  }

  @override
  String get fileTruncated => '長いファイルのため途中までを表示しています';

  @override
  String fileOpenFailed(Object error) {
    return 'ファイルを開けませんでした: $error';
  }

  @override
  String get unknownBranch => 'ブランチ不明';

  @override
  String get uncommitted => '未コミット';

  @override
  String get wholeBranch => 'ブランチ全体';

  @override
  String diffAgainst(Object branch) {
    return '$branchとの差分';
  }

  @override
  String get noChanges => '変更はありません';

  @override
  String gitLoadFailed(Object error) {
    return 'Git の状態を読み込めませんでした: $error';
  }

  @override
  String get noDiff => '差分はありません';

  @override
  String get mcpEmpty => 'MCP サーバーは設定されていません';

  @override
  String mcpLoadFailed(Object error) {
    return 'MCP サーバーを読み込めませんでした: $error';
  }

  @override
  String toggleFailed(Object error) {
    return '切り替えられませんでした: $error';
  }

  @override
  String get mcpConnected => '接続中';

  @override
  String get mcpDisconnected => '未接続';

  @override
  String get mcpDisabled => '無効';

  @override
  String get mcpFailed => '失敗';

  @override
  String get mcpNeedsAuth => '認証が必要';

  @override
  String get mcpNeedsClientRegistration => 'クライアント登録が必要';

  @override
  String get newTerminal => '新しいターミナル';

  @override
  String get terminalsEmpty => 'ターミナルはまだありません';

  @override
  String terminalExited(Object code) {
    return '終了しました（コード $code）';
  }

  @override
  String terminalsLoadFailed(Object error) {
    return 'ターミナルを読み込めませんでした: $error';
  }

  @override
  String terminalOpenFailed(Object error) {
    return 'ターミナルを開けませんでした: $error';
  }

  @override
  String closeFailed(Object error) {
    return '閉じられませんでした: $error';
  }

  @override
  String get ptyConnecting => '接続しています…';

  @override
  String get ptyFailed => '接続が切れました';

  @override
  String get ptyClosed => 'ターミナルは終了しました';

  @override
  String get reconnect => '再接続';

  @override
  String terminalTitle(Object count) {
    return 'ターミナル $count';
  }

  @override
  String get sessionWaiting => '対応待ち';

  @override
  String get sessionFailed => 'エラー';

  @override
  String get usageTitle => 'コンテキスト';

  @override
  String get usageTooltip => 'コンテキストと使用量';

  @override
  String usageTokensUsed(String count) {
    return '$count トークン使用';
  }

  @override
  String get usageProvider => 'プロバイダー';

  @override
  String get usageModel => 'モデル';

  @override
  String get usageLimit => 'コンテキスト上限';

  @override
  String get usageTotalTokens => '合計トークン';

  @override
  String get usagePercent => '使用率';

  @override
  String get usageInputTokens => '入力トークン';

  @override
  String get usageOutputTokens => '出力トークン';

  @override
  String get usageReasoningTokens => '推論トークン';

  @override
  String get usageCacheTokens => 'キャッシュ 読み / 書き';

  @override
  String get usageLastActivity => '最終アクティビティ';

  @override
  String get usageNoReplies => 'まだ応答がありません。最初の応答のあとに使用量が表示されます。';

  @override
  String get usageLastStepHelp => '直近の応答の数値です。これがコンテキストを占める量になります。';

  @override
  String get sessionUsage => 'セッション全体';

  @override
  String get sessionCost => 'コスト';

  @override
  String get sessionCreated => '作成日時';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get pushTitle => '通知';

  @override
  String get pushReceive => 'このサーバーの通知を受け取る';

  @override
  String get pushChooseServer => '通知はサーバーごとに設定します。設定するサーバーを選んでください。';

  @override
  String get pushOn => 'オン';

  @override
  String get pushOff => 'オフ';

  @override
  String get pushOnActive => 'オン · PC/Mac 側も稼働中';

  @override
  String get pushOnCheck => 'オン · PC/Mac 側の設定を確認してください';

  @override
  String get pushWhat =>
      'Agent の応答が終わったとき、エラーで止まったとき、許可や回答を待っているときに通知します。PC/Mac の OpenCode に下のプラグインを入れる必要があります。プロジェクト名やセッション名は暗号化して送るため、中継サーバーからは読めません。';

  @override
  String get pushNotConfigured =>
      'このビルドには通知の設定が含まれていません。PUSH_RELAY_URL と Firebase の値を指定してビルドしてください（docs/push-notifications.md）。';

  @override
  String get pushPermissionDenied => 'システム設定でこのアプリの通知がオフになっています';

  @override
  String get pushNoToken => '端末のプッシュトークンを取得できませんでした。時間をおいて試してください。';

  @override
  String pushFailed(Object error) {
    return '通知の設定を変更できませんでした: $error';
  }

  @override
  String get pushSetupTitle => 'PC/Mac の OpenCode の設定';

  @override
  String get pushSetupStep1 =>
      '1. ~/.config/opencode/opencode.json（または opencode.jsonc）に次の項目を追加';

  @override
  String get pushSetupStep2 => '2. OpenCode を再起動';

  @override
  String get pushSendTest => 'テスト通知を送る';

  @override
  String get pushTestTitle => 'OpenCode からのテスト通知';

  @override
  String get pushTestSent => '送信しました。数秒で届きます。';

  @override
  String get pushOpen => '開く';

  @override
  String get pushHeadlineCompleted => '応答が完了しました';

  @override
  String get pushHeadlineFailed => 'エラーで停止しました';

  @override
  String get pushHeadlinePermission => '許可を待っています';

  @override
  String get pushHeadlineQuestion => '質問に回答を待っています';

  @override
  String get pushChannelName => 'Agent の通知';

  @override
  String pushOpenFailed(Object error) {
    return 'セッションを開けませんでした: $error';
  }

  @override
  String get servers => 'サーバー';

  @override
  String serverRunning(int count) {
    return '$count件作業中';
  }

  @override
  String serverFinished(int count) {
    return '$count件完了';
  }

  @override
  String get serverUnreachable => '接続できません';

  @override
  String get addServer => 'サーバーを追加';

  @override
  String serverSwitchFailed(String name, String error) {
    return '$name に接続できませんでした: $error';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsFollowSystem => 'システム設定に従う';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get chatPaneEmpty => 'セッションを選ぶと\nここにチャットが表示されます';

  @override
  String get settingsHaptics => '触覚フィードバック';

  @override
  String get hapticsOff => 'オフ';

  @override
  String get hapticsLight => '弱';

  @override
  String get hapticsLightHelp => '送信時、AI の返信完了時、AI が回答を待っているときに振動します';

  @override
  String get hapticsStrong => '強';

  @override
  String get hapticsStrongHelp => '弱より少し強めに振動し、AI が返信を書き始めたときにも振動します';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String updateRequiredBody(String installed, String minimum) {
    return 'このバージョン（$installed）は使えなくなりました。$minimum 以降に更新してください。';
  }

  @override
  String get updateOpenStore => 'ストアを開く';

  @override
  String get updateFromStore => 'App Store または Google Play からアプリを更新してください。';

  @override
  String get rewardTitle => '今日の送信回数を使い切りました';

  @override
  String rewardBody(int free, int more) {
    return '広告なしで送れるのは1日$free回までです。短い広告を見ると、さらに$more回送れます。';
  }

  @override
  String get rewardWatch => '広告を見る';

  @override
  String get rewardSkipped => '広告を最後まで見ると送信できます。';

  @override
  String get settingsAds => '広告';

  @override
  String get settingsMessages => 'メッセージ回数';

  @override
  String get messagesToday => '本日の送信回数';

  @override
  String messagesTodayValue(int sent, int allowance) {
    return '$sent/$allowance回';
  }

  @override
  String messagesTodayEarned(int sent, int allowance, int earned) {
    return '$sent/$allowance回（内、広告獲得分 $earned回）';
  }

  @override
  String messagesLeft(int left) {
    return '残り$left回';
  }

  @override
  String get quotaReminder => '回数回復の通知';

  @override
  String get quotaReminderSubtitle => 'メッセージを送った日は、0時に回数が回復したらお知らせします';

  @override
  String get quotaReminderTitle => '本日分の送信回数が回復しました';

  @override
  String quotaReminderBody(int free) {
    return '今日も$free回まで広告なしで送れます';
  }

  @override
  String get quotaReminderChannel => '送信回数のお知らせ';

  @override
  String get rewardEarnMore => '広告を見て回数を増やす';

  @override
  String rewardEarnMoreSubtitle(int more) {
    return '短い広告を見ると、今日はさらに$more回送れます';
  }

  @override
  String rewardEarnMoreCarry(int more, int limit) {
    return '短い広告を見ると$more回増えます。使わなかった分は$limit回まで翌日に持ち越せます';
  }

  @override
  String rewardAdded(int more) {
    return '送信回数を$more回増やしました';
  }

  @override
  String get rewardEarnSkipped => '広告を最後まで見ると回数が増えます。';

  @override
  String get rewardUnavailable => '今は広告を表示できません。しばらくしてからお試しください。';

  @override
  String get removeAds => '広告を外す';

  @override
  String get removeAdsSubtitle => '買い切りです。バナーと送信前の広告が出なくなります。';

  @override
  String get removeAdsDone => '広告を外しました。ご支援ありがとうございます！';

  @override
  String get restorePurchases => '購入を復元';

  @override
  String get restoreStarted => '購入履歴を確認しています…';

  @override
  String get purchaseFailed => '購入を完了できませんでした。';

  @override
  String get adPrivacy => '広告のプライバシー設定';

  @override
  String get settingsSupport => 'サポートとプライバシー';

  @override
  String get contactUs => 'お問い合わせ';

  @override
  String get contactSubject => 'Pocket Agent へのお問い合わせ';

  @override
  String get contactBodyPrompt => '（お問い合わせ内容や、起きた問題をここにお書きください）';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get crashReports => 'クラッシュレポートを送信';

  @override
  String get crashReportsHelp =>
      'アプリが異常終了したとき、修正のためにエラーの情報を送ります（チャットの内容は送りません）';

  @override
  String get usageAnalytics => '利用状況を送信';

  @override
  String get usageAnalyticsHelp =>
      '改善のために、開いた画面や利用した日などの統計を送ります（チャットの内容やサーバーの情報は送りません）';

  @override
  String get linkOpenFailed => '開けませんでした:';

  @override
  String get pushComputerTitle => 'プッシュ通知プラグイン';

  @override
  String get pushComputerActive => '稼働中';

  @override
  String pushComputerFailed(Object error) {
    return 'プラグインの読み込みに失敗しました: $error';
  }

  @override
  String get pushComputerOtherKey =>
      'プラグインが別のリレーかキーを使っています。opencode.json(c) のプラグインの項目を下の内容にしてください。';

  @override
  String get pushComputerNotLoaded =>
      '設定はありますが、まだ読み込まれていません。OpenCode を再起動してください。';

  @override
  String get pushComputerMissing => 'まだ設定されていません。下の手順で追加してください。';

  @override
  String get pushComputerUnknown => '状態を確認できませんでした';

  @override
  String get pushComputerRefresh => 'もう一度確認';

  @override
  String pushPluginVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get pushPluginOutdated => '新しいバージョンがあります';

  @override
  String pushPluginOutdatedTo(String version) {
    return '新しいバージョン $version があります';
  }

  @override
  String get pushPluginUpdate => '更新';

  @override
  String get pushPluginUpdated => 'プラグインを更新しました';

  @override
  String pushPluginUpdateFailed(Object error) {
    return 'プラグインを更新できませんでした: $error';
  }

  @override
  String get diagnosticsTitle => '接続の診断';

  @override
  String get diagnosticsServer => 'サーバー';

  @override
  String get diagnosticsAddress => 'アドレス';

  @override
  String get diagnosticsHealth => 'OpenCode';

  @override
  String diagnosticsHealthOk(String version, int ms) {
    return 'OpenCode $version・$ms ミリ秒で応答';
  }

  @override
  String diagnosticsHealthFailed(Object error) {
    return '失敗しました: $error';
  }

  @override
  String get diagnosticsLive => 'リアルタイム更新';

  @override
  String get diagnosticsLiveUpdates => 'イベントの受信';

  @override
  String get diagnosticsLiveConnected => '接続中';

  @override
  String get diagnosticsLiveStopped => '止まっています';

  @override
  String get diagnosticsPlugin => 'プッシュ通知プラグイン';

  @override
  String get diagnosticsPluginOtherKey =>
      'プラグインが別のリレーかキーを使っています。メニューの「通知」で確認してください。';

  @override
  String get diagnosticsMcpNone => 'MCP サーバーはありません';

  @override
  String get settingsAbout => 'このアプリ';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsOs => 'OS';

  @override
  String get diagnosticsChecking => '確認しています…';

  @override
  String get diagnosticsRecheck => 'もう一度確認';

  @override
  String get diagnosticsCopy => '結果をコピー';

  @override
  String get connectGuide => '外出先からのつなぎ方など';

  @override
  String get conversationMode => '会話モード';

  @override
  String get conversationPreparing => '準備しています…';

  @override
  String get conversationListening => '聞いています…';

  @override
  String get conversationSending => '送信しています';

  @override
  String get conversationWaiting => 'OpenCode が作業しています…';

  @override
  String get conversationNeedsInput => '画面での回答を待っています';

  @override
  String get conversationSpeaking => '返答を読み上げています';

  @override
  String get conversationIdle => 'マイクを1回タップしてから話してください';

  @override
  String conversationListenFailed(Object error) {
    return '聞き取れませんでした（$error）。もう一度マイクをタップしてください';
  }

  @override
  String get conversationUnavailable =>
      '音声認識を使えません。端末の設定で、このアプリのマイクと音声認識を許可してください。';

  @override
  String get conversationListen => '話す';

  @override
  String get conversationDoneSpeaking => '話し終えた';

  @override
  String get conversationEnd => '会話モードを終える';

  @override
  String get readAloud => '読み上げる';

  @override
  String get readingAloud => '読み上げています…';

  @override
  String get stopReading => '停止';

  @override
  String get speechCodeSkipped => '（コードは省略します）';

  @override
  String get speechTruncated => '以下は省略します。';
}
