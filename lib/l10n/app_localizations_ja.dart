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
  String get create => '作成';

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
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get passwordHelper => 'OPENCODE_SERVER_PASSWORD（未設定なら空欄）';

  @override
  String get displayNameOptional => '名前（任意）';

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
  String serverSaved(String name) {
    return '「$name」を保存しました';
  }

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
  String foldersLoadFailed(Object error) {
    return 'フォルダを読み込めませんでした: $error';
  }

  @override
  String projectOpenFailed(Object error) {
    return 'フォルダを開けませんでした: $error';
  }

  @override
  String get tabSessions => 'セッション';

  @override
  String get tabFiles => 'ファイル';

  @override
  String get tabTerminal => 'ターミナル';

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
  String get fork => 'フォーク';

  @override
  String get compact => '会話を要約';

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
  String modelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'モデル $count 個',
    );
    return '$_temp0';
  }

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
  String get newWorktree => '新しい worktree';

  @override
  String get mainWorktree => 'メイン';

  @override
  String worktreesLoadFailed(Object error) {
    return 'worktree を読み込めませんでした: $error';
  }

  @override
  String createFailed(Object error) {
    return '作成できませんでした: $error';
  }

  @override
  String deleteWorktreeTitle(Object name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deleteWorktreeBody => 'フォルダごと削除します。元に戻せません。';

  @override
  String get uncommittedChangesTitle => 'コミットしていない変更があります';

  @override
  String get uncommittedChangesBody => '変更も含めて削除しますか？元に戻せません。';

  @override
  String deleteFailedWithError(Object error) {
    return '削除できませんでした: $error';
  }

  @override
  String get worktreeNameHint => '名前（省略するとサーバーが決めます）';

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
}
