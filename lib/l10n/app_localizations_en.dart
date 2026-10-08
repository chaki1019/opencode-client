// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get reload => 'Reload';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get close => 'Close';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get connectTitle => 'Connect to an OpenCode server';

  @override
  String get connectUnsupported =>
      'This server doesn\'t support the OpenCode v2 API. Please update OpenCode.';

  @override
  String get connectWrongCredentials => 'Wrong username or password';

  @override
  String connectFailed(Object error) {
    return 'Couldn\'t connect: $error';
  }

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlRequired => 'Enter a URL';

  @override
  String get serverUrlInvalid =>
      'Not a valid URL (e.g. http://192.168.1.10:4096)';

  @override
  String get connectTimeout =>
      'The server didn\'t answer in time. Check that it is running and reachable from this network.';

  @override
  String get connectUnreachable =>
      'Couldn\'t reach the server. Check the URL, that the server is running, and that it listens on the network (--hostname 0.0.0.0).';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get passwordHelper =>
      'OPENCODE_SERVER_PASSWORD (leave blank if unset)';

  @override
  String get connect => 'Connect';

  @override
  String get savedServers => 'Saved servers';

  @override
  String savedServersLoadFailed(Object error) {
    return 'Couldn\'t load saved servers: $error';
  }

  @override
  String get saveServer => 'Save';

  @override
  String get saveServerTitle => 'Connected. Save this server?';

  @override
  String get dontSave => 'Don\'t save';

  @override
  String get editServer => 'Edit';

  @override
  String get editServerTitle => 'Edit server';

  @override
  String get serverName => 'Name';

  @override
  String get discoveredServers => 'Found on this network';

  @override
  String get discoveringServers =>
      'Searching the network for OpenCode servers…';

  @override
  String get discoveryNoneFound => 'No servers found';

  @override
  String get scanNetwork => 'Search the network';

  @override
  String get rescanNetwork => 'Search again';

  @override
  String get discoveryHint =>
      'Looks for servers on port 4096 that accept connections from the network (opencode serve --hostname 0.0.0.0), and for servers announced over mDNS';

  @override
  String get reconnecting => 'Reconnecting to the server…';

  @override
  String get projects => 'Projects';

  @override
  String get disconnect => 'Disconnect';

  @override
  String projectsLoadFailed(Object error) {
    return 'Couldn\'t load projects: $error';
  }

  @override
  String get hideProject => 'Remove from list';

  @override
  String get hideProjectNote =>
      'The project and its sessions stay on the server. Bring it back with the eye button at the top right of the list.';

  @override
  String projectHidden(Object name) {
    return 'Removed \"$name\" from the list';
  }

  @override
  String get showAllProjects => 'Show all projects';

  @override
  String get showListedProjects => 'Show listed projects only';

  @override
  String get pinProject => 'Pin to top';

  @override
  String get unpinProject => 'Unpin';

  @override
  String get pinnedProject => 'Pinned';

  @override
  String get unhideProject => 'Show in list';

  @override
  String get undo => 'Undo';

  @override
  String get addProject => 'Add project';

  @override
  String get projectFolderLabel => 'Folder path on the server';

  @override
  String get projectFolderHint => '/home/me/my-app';

  @override
  String get projectFolderMustBeAbsolute => 'Enter an absolute path';

  @override
  String get chooseFolder => 'Choose a folder';

  @override
  String get openThisFolder => 'Open this folder';

  @override
  String get noSubfolders => 'No folders here';

  @override
  String get searchFolders => 'Search folders below';

  @override
  String get showHiddenFolders => 'Show hidden folders';

  @override
  String get hideHiddenFolders => 'Hide hidden folders';

  @override
  String get enterFolderPath => 'Enter a path';

  @override
  String get goToFolder => 'Go';

  @override
  String get parentFolder => 'Parent folder';

  @override
  String foldersLoadFailed(Object error) {
    return 'Couldn\'t load folders: $error';
  }

  @override
  String projectOpenFailed(Object error) {
    return 'Couldn\'t open the folder: $error';
  }

  @override
  String get files => 'Files';

  @override
  String get terminal => 'Terminal';

  @override
  String get projectTools => 'Project tools';

  @override
  String get newSession => 'New session';

  @override
  String get sessionsEmpty => 'No sessions yet';

  @override
  String sessionsLoadFailed(Object error) {
    return 'Couldn\'t load sessions: $error';
  }

  @override
  String sessionCreateFailed(Object error) {
    return 'Couldn\'t create a session: $error';
  }

  @override
  String get untitledSession => 'Untitled session';

  @override
  String get rename => 'Rename';

  @override
  String get compact => 'Summarize conversation';

  @override
  String get compactHelp =>
      'Summarizes the conversation so far to free up context. Use it when the window is getting full.';

  @override
  String get renameFailed => 'Couldn\'t rename';

  @override
  String get forkFailed => 'Couldn\'t fork';

  @override
  String get compacting => 'Summarizing the conversation…';

  @override
  String get compactBusy => 'You can summarize once the current run finishes.';

  @override
  String get compactFailed => 'Couldn\'t request a summary';

  @override
  String get compactRequested => 'Requested a summary of the conversation';

  @override
  String get deleteSessionTitle => 'Delete this session?';

  @override
  String deleteSessionBody(Object title) {
    return '\"$title\" will be deleted. This can\'t be undone.';
  }

  @override
  String get deleteFailed => 'Couldn\'t delete';

  @override
  String get sessionName => 'Session name';

  @override
  String get renameConfirm => 'Rename';

  @override
  String get messagesEmpty => 'No messages yet';

  @override
  String messagesLoadFailed(Object error) {
    return 'Couldn\'t load messages: $error';
  }

  @override
  String get rewindHere => 'Rewind to here';

  @override
  String get rewindHereHelp =>
      'Undo this message, everything after it, and their file changes';

  @override
  String get rewoundNotice => 'Rewound. Sending a new message makes it final.';

  @override
  String get rewindUndo => 'Undo';

  @override
  String rewindFailed(Object error) {
    return 'Could not rewind: $error';
  }

  @override
  String get forkFromHere => 'Fork from before this message';

  @override
  String get forkFromHereHelp =>
      'Copies the conversation before this message into a new session';

  @override
  String get running => 'Running';

  @override
  String get sendFailed => 'Couldn\'t send. Check the message and try again.';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String imageLoadFailed(Object error) {
    return 'Couldn\'t load the image: $error';
  }

  @override
  String interruptFailed(Object error) {
    return 'Couldn\'t stop: $error';
  }

  @override
  String get attachImage => 'Attach image';

  @override
  String get messageHint => 'Message';

  @override
  String get interrupt => 'Stop';

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String get agent => 'Agent';

  @override
  String get model => 'Model';

  @override
  String changeFailed(Object error) {
    return 'Couldn\'t change: $error';
  }

  @override
  String agentsLoadFailed(Object error) {
    return 'Couldn\'t load agents: $error';
  }

  @override
  String get noMatchingModels => 'No matching models';

  @override
  String get searchModels => 'Search models';

  @override
  String modelsLoadFailed(Object error) {
    return 'Couldn\'t load models: $error';
  }

  @override
  String get variant => 'Variant';

  @override
  String get agentBuildDescription =>
      'The default agent with all tools enabled. The standard agent for development work that needs full access to file operations and system commands.';

  @override
  String get agentPlanDescription =>
      'A restricted agent for planning and analysis. Permissions prevent unintended changes.';

  @override
  String tooManyAttachments(Object count) {
    return 'Up to $count attachments';
  }

  @override
  String get attachmentTooLarge => 'Each file must be 10 MB or less';

  @override
  String get attachmentsTooLarge => 'Attachments must total 24 MB or less';

  @override
  String get sending => 'Sending…';

  @override
  String get sendUncertain =>
      'Checking whether it was sent. It hasn\'t been resent.';

  @override
  String get dismiss => 'Remove from view';

  @override
  String get thinking => 'Thinking…';

  @override
  String get reasoning => 'Thinking';

  @override
  String get noOutput => 'No output';

  @override
  String get compacted => 'Summarized the conversation so far';

  @override
  String contextAgent(Object name) {
    return 'Agent: $name';
  }

  @override
  String contextModel(Object name) {
    return 'Model: $name';
  }

  @override
  String contextLocation(Object path) {
    return 'Location: $path';
  }

  @override
  String contextSkill(Object name) {
    return 'Skill: $name';
  }

  @override
  String linesOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines omitted',
      one: '1 line omitted',
    );
    return '$_temp0';
  }

  @override
  String get scrollToNewest => 'Jump to latest';

  @override
  String get reloadOlderMessages => 'Reload earlier messages';

  @override
  String replyFailed(Object error) {
    return 'Couldn\'t reply: $error';
  }

  @override
  String permissionNeeded(Object action) {
    return 'Permission needed for \"$action\"';
  }

  @override
  String moreWaiting(Object count) {
    return '+$count more';
  }

  @override
  String get deny => 'Deny';

  @override
  String get allowAlways => 'Always allow';

  @override
  String get allowOnce => 'Allow once';

  @override
  String get sendFailedShort => 'Couldn\'t send';

  @override
  String get cancelFailed => 'Couldn\'t cancel';

  @override
  String get questionTitle => 'A question for you';

  @override
  String get formUnsupported =>
      'This question has fields the app doesn\'t support. Dismiss it or answer from another client.';

  @override
  String get dontAnswer => 'Don\'t answer';

  @override
  String get otherFreeText => 'Other (free text)';

  @override
  String get otherCommaSeparated => 'Other (comma-separated)';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get doneInBrowser => 'Done in the browser';

  @override
  String get allDone => 'All done';

  @override
  String get fieldRequired => 'Required';

  @override
  String get fieldText => 'Enter text';

  @override
  String get fieldPickOption => 'Pick one of the options';

  @override
  String fieldMinLength(Object count) {
    return 'At least $count characters';
  }

  @override
  String fieldMaxLength(Object count) {
    return 'At most $count characters';
  }

  @override
  String get fieldPattern => 'Invalid format';

  @override
  String get fieldNumber => 'Enter a number';

  @override
  String get fieldInteger => 'Enter a whole number';

  @override
  String fieldMinimum(Object value) {
    return 'Must be $value or more';
  }

  @override
  String fieldMaximum(Object value) {
    return 'Must be $value or less';
  }

  @override
  String get fieldChoose => 'Make a selection';

  @override
  String fieldMinItems(Object count) {
    return 'Pick at least $count';
  }

  @override
  String fieldMaxItems(Object count) {
    return 'Pick at most $count';
  }

  @override
  String get fieldExternal => 'Check this once you\'re done';

  @override
  String get searchFiles => 'Search by file name';

  @override
  String get notFound => 'Nothing found';

  @override
  String get emptyFolder => 'This folder is empty';

  @override
  String filesLoadFailed(Object error) {
    return 'Couldn\'t load files: $error';
  }

  @override
  String binaryFile(Object bytes) {
    return 'Can\'t display this file ($bytes bytes)';
  }

  @override
  String get fileTruncated =>
      'This file is long, so only the beginning is shown';

  @override
  String fileOpenFailed(Object error) {
    return 'Couldn\'t open the file: $error';
  }

  @override
  String get unknownBranch => 'Unknown branch';

  @override
  String get uncommitted => 'Uncommitted';

  @override
  String get wholeBranch => 'Whole branch';

  @override
  String diffAgainst(Object branch) {
    return 'Diff against $branch';
  }

  @override
  String get noChanges => 'No changes';

  @override
  String gitLoadFailed(Object error) {
    return 'Couldn\'t load the Git status: $error';
  }

  @override
  String get noDiff => 'No diff';

  @override
  String get mcpEmpty => 'No MCP servers configured';

  @override
  String mcpLoadFailed(Object error) {
    return 'Couldn\'t load MCP servers: $error';
  }

  @override
  String toggleFailed(Object error) {
    return 'Couldn\'t switch: $error';
  }

  @override
  String get mcpConnected => 'Connected';

  @override
  String get mcpDisconnected => 'Disconnected';

  @override
  String get mcpDisabled => 'Disabled';

  @override
  String get mcpFailed => 'Failed';

  @override
  String get mcpNeedsAuth => 'Needs authentication';

  @override
  String get mcpNeedsClientRegistration => 'Needs client registration';

  @override
  String get newTerminal => 'New terminal';

  @override
  String get terminalsEmpty => 'No terminals yet';

  @override
  String terminalExited(Object code) {
    return 'Exited (code $code)';
  }

  @override
  String terminalsLoadFailed(Object error) {
    return 'Couldn\'t load terminals: $error';
  }

  @override
  String terminalOpenFailed(Object error) {
    return 'Couldn\'t open a terminal: $error';
  }

  @override
  String closeFailed(Object error) {
    return 'Couldn\'t close: $error';
  }

  @override
  String get ptyConnecting => 'Connecting…';

  @override
  String get ptyFailed => 'Connection lost';

  @override
  String get ptyClosed => 'The terminal has exited';

  @override
  String get reconnect => 'Reconnect';

  @override
  String terminalTitle(Object count) {
    return 'Terminal $count';
  }

  @override
  String get sessionWaiting => 'Needs you';

  @override
  String get sessionFailed => 'Error';

  @override
  String get usageTitle => 'Context';

  @override
  String get usageTooltip => 'Context and usage';

  @override
  String usageTokensUsed(String count) {
    return '$count tokens used';
  }

  @override
  String get usageProvider => 'Provider';

  @override
  String get usageModel => 'Model';

  @override
  String get usageLimit => 'Context limit';

  @override
  String get usageTotalTokens => 'Total tokens';

  @override
  String get usagePercent => 'Usage';

  @override
  String get usageInputTokens => 'Input tokens';

  @override
  String get usageOutputTokens => 'Output tokens';

  @override
  String get usageReasoningTokens => 'Reasoning tokens';

  @override
  String get usageCacheTokens => 'Cache read / write';

  @override
  String get usageLastActivity => 'Last activity';

  @override
  String get usageNoReplies =>
      'No replies yet. Usage appears after the first reply.';

  @override
  String get usageLastStepHelp =>
      'Counts from the latest reply, which is what fills the context window.';

  @override
  String get sessionUsage => 'Whole session';

  @override
  String get sessionCost => 'Cost';

  @override
  String get sessionCreated => 'Created';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get pushTitle => 'Notifications';

  @override
  String get pushReceive => 'Get notified for this server';

  @override
  String get pushChooseServer =>
      'Notifications are set up for each server. Choose a server.';

  @override
  String get pushOn => 'On';

  @override
  String get pushOff => 'Off';

  @override
  String get pushOnActive => 'On · running on the computer';

  @override
  String get pushOnCheck => 'On · check the setup on the computer';

  @override
  String get pushWhat =>
      'Notifies you when the agent finishes, stops on an error, or waits for a permission or an answer. Needs the plugin below in OpenCode on your computer. Project and session names are encrypted, so the relay server cannot read them.';

  @override
  String get pushNotConfigured =>
      'This build has no push settings. Build it with PUSH_RELAY_URL and the Firebase values (see docs/push-notifications.md).';

  @override
  String get pushPermissionDenied =>
      'Notifications are turned off for this app in system settings';

  @override
  String get pushNoToken =>
      'Couldn\'t get a push token from the device. Try again later.';

  @override
  String pushFailed(Object error) {
    return 'Couldn\'t update notifications: $error';
  }

  @override
  String get pushSetupTitle => 'Set up OpenCode on your computer';

  @override
  String get pushSetupStep1 =>
      '1. Add this entry to ~/.config/opencode/opencode.json (or opencode.jsonc)';

  @override
  String get pushSetupStep2 => '2. Restart OpenCode';

  @override
  String get pushSendTest => 'Send a test notification';

  @override
  String get pushTestTitle => 'Test notification from OpenCode';

  @override
  String get pushTestSent => 'Sent. It should arrive in a few seconds.';

  @override
  String get pushOpen => 'Open';

  @override
  String get pushHeadlineCompleted => 'Reply finished';

  @override
  String get pushHeadlineFailed => 'Stopped with an error';

  @override
  String get pushHeadlinePermission => 'Waiting for permission';

  @override
  String get pushHeadlineQuestion => 'Waiting for your answer';

  @override
  String get pushChannelName => 'Agent updates';

  @override
  String pushOpenFailed(Object error) {
    return 'Couldn\'t open the session: $error';
  }

  @override
  String get servers => 'Servers';

  @override
  String serverRunning(int count) {
    return '$count running';
  }

  @override
  String serverFinished(int count) {
    return '$count done';
  }

  @override
  String get serverUnreachable => 'Can\'t connect';

  @override
  String get addServer => 'Add server';

  @override
  String serverSwitchFailed(String name, String error) {
    return 'Couldn\'t connect to $name: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsFollowSystem => 'Use system setting';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get chatPaneEmpty => 'Pick a session to show its chat here';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get hapticsOff => 'Off';

  @override
  String get hapticsLight => 'Light';

  @override
  String get hapticsLightHelp =>
      'Vibrate on send, when a reply finishes, and when the AI needs your answer';

  @override
  String get hapticsStrong => 'Strong';

  @override
  String get hapticsStrongHelp =>
      'A little stronger, and also vibrates when the AI starts writing its reply';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateRequiredBody(String installed, String minimum) {
    return 'Version $installed can no longer be used. Please update to version $minimum or later.';
  }

  @override
  String get updateOpenStore => 'Open the store';

  @override
  String get updateFromStore =>
      'Update the app from the App Store or Google Play.';

  @override
  String get rewardTitle => 'Today\'s messages are used up';

  @override
  String rewardBody(int free, int more) {
    return 'You can send $free messages a day without ads. Watch a short ad to send $more more.';
  }

  @override
  String get rewardWatch => 'Watch ad';

  @override
  String get rewardSkipped => 'Watch the ad to the end to send this message.';

  @override
  String get settingsAds => 'Ads';

  @override
  String get settingsMessages => 'Messages';

  @override
  String get messagesToday => 'Sent today';

  @override
  String messagesTodayValue(int sent, int allowance) {
    return '$sent/$allowance';
  }

  @override
  String messagesTodayEarned(int sent, int allowance, int earned) {
    return '$sent/$allowance ($earned earned from ads)';
  }

  @override
  String messagesLeft(int left) {
    return '$left messages left';
  }

  @override
  String get quotaReminder => 'Notify when messages reset';

  @override
  String get quotaReminderSubtitle =>
      'On days you send messages, get a notice at midnight when they are back';

  @override
  String get quotaReminderTitle => 'Today\'s messages are back';

  @override
  String quotaReminderBody(int free) {
    return 'You can send $free messages without ads today';
  }

  @override
  String get quotaReminderChannel => 'Message count';

  @override
  String get rewardEarnMore => 'Watch an ad for more messages';

  @override
  String rewardEarnMoreSubtitle(int more) {
    return 'A short ad adds $more messages for today';
  }

  @override
  String rewardEarnMoreCarry(int more, int limit) {
    return 'A short ad adds $more messages. Up to $limit unused ones carry over to the next day';
  }

  @override
  String rewardAdded(int more) {
    return 'Added $more messages';
  }

  @override
  String get rewardEarnSkipped =>
      'Watch the ad to the end to get more messages.';

  @override
  String get rewardUnavailable =>
      'No ad is available right now. Please try again later.';

  @override
  String get removeAds => 'Remove ads';

  @override
  String get removeAdsSubtitle =>
      'One-time purchase. Hides banners and the ad before sending.';

  @override
  String get removeAdsDone => 'Ads are removed. Thank you for your support!';

  @override
  String get restorePurchases => 'Restore purchase';

  @override
  String get restoreStarted => 'Checking your purchases…';

  @override
  String get purchaseFailed => 'The purchase didn\'t go through.';

  @override
  String get adPrivacy => 'Ad privacy choices';

  @override
  String get settingsSupport => 'Support and privacy';

  @override
  String get contactUs => 'Contact us';

  @override
  String get contactSubject => 'Pocket Agent feedback';

  @override
  String get contactBodyPrompt =>
      '(Please write your question or the problem you ran into here.)';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get crashReports => 'Send crash reports';

  @override
  String get crashReportsHelp =>
      'When the app crashes, send the error details (no chat content) to help fix it';

  @override
  String get usageAnalytics => 'Send usage statistics';

  @override
  String get usageAnalyticsHelp =>
      'Send which screens you open, on which days and where you tap, to help improve the app (chat content, server details and what you type are hidden and never sent)';

  @override
  String get linkOpenFailed => 'Couldn\'t open this:';

  @override
  String get pushComputerTitle => 'Push notification plugin';

  @override
  String get pushComputerActive => 'Running';

  @override
  String pushComputerFailed(Object error) {
    return 'The plugin failed to load: $error';
  }

  @override
  String get pushComputerOtherKey =>
      'The plugin uses another relay or key. Change its entry in opencode.json(c) to the one below.';

  @override
  String get pushComputerNotLoaded =>
      'It is configured but not loaded yet. Restart OpenCode.';

  @override
  String get pushComputerMissing =>
      'Not set up yet. Add it with the steps below.';

  @override
  String get pushComputerUnknown => 'Couldn\'t check';

  @override
  String get pushComputerRefresh => 'Check again';

  @override
  String get pushPluginOutdated => 'A newer version is available';

  @override
  String pushPluginOutdatedTo(String version) {
    return 'Version $version is available';
  }

  @override
  String get pushPluginUpdate => 'Update';

  @override
  String get pushPluginUpdated => 'Plugin updated';

  @override
  String pushPluginUpdateFailed(Object error) {
    return 'Couldn\'t update the plugin: $error';
  }

  @override
  String get diagnosticsTitle => 'Connection check';

  @override
  String get diagnosticsServer => 'Server';

  @override
  String get diagnosticsAddress => 'Address';

  @override
  String get diagnosticsHealth => 'OpenCode';

  @override
  String diagnosticsHealthOk(String version, int ms) {
    return 'OpenCode $version · responded in $ms ms';
  }

  @override
  String diagnosticsHealthFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String get diagnosticsLive => 'Live updates';

  @override
  String get diagnosticsLiveUpdates => 'Event stream';

  @override
  String get diagnosticsLiveConnected => 'Connected';

  @override
  String get diagnosticsLiveStopped => 'Stopped';

  @override
  String get diagnosticsPlugin => 'Push notification plugin';

  @override
  String get diagnosticsPluginOtherKey =>
      'The plugin uses another relay or key. Check it under Notifications in the menu.';

  @override
  String get diagnosticsMcpNone => 'No MCP servers';

  @override
  String get settingsAbout => 'This app';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsOs => 'OS';

  @override
  String get diagnosticsChecking => 'Checking…';

  @override
  String get diagnosticsRecheck => 'Check again';

  @override
  String get diagnosticsCopy => 'Copy the results';

  @override
  String get connectGuide => 'How to connect from home or away';

  @override
  String get conversationMode => 'Conversation mode';

  @override
  String get conversationPreparing => 'Getting ready…';

  @override
  String get conversationListening => 'Listening…';

  @override
  String get conversationSending => 'Sending';

  @override
  String get conversationWaiting => 'OpenCode is working…';

  @override
  String get conversationNeedsInput => 'Waiting for your answer on screen';

  @override
  String get conversationSpeaking => 'Reading the reply';

  @override
  String get conversationIdle => 'Tap the mic once, then speak';

  @override
  String conversationListenFailed(Object error) {
    return 'Couldn\'t listen ($error). Tap the mic to try again.';
  }

  @override
  String get conversationUnavailable =>
      'Speech recognition is unavailable. Allow the microphone and speech recognition for this app in Settings.';

  @override
  String get conversationListen => 'Speak';

  @override
  String get conversationDoneSpeaking => 'Done speaking';

  @override
  String get conversationEnd => 'End conversation mode';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get readingAloud => 'Reading aloud…';

  @override
  String get stopReading => 'Stop';

  @override
  String get speechCodeSkipped => '(code omitted)';

  @override
  String get speechTruncated => 'The rest is omitted.';

  @override
  String get attentionTitle => 'Needs you';

  @override
  String get attentionEmpty => 'Nothing needs you right now.';

  @override
  String get attentionScope =>
      'Shows the servers connected in this app: permissions and questions waiting for an answer, and replies finished in the last 3 days that nobody has looked at yet.';

  @override
  String get attentionMarkSeen => 'Mark as seen';
}
