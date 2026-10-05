import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to an OpenCode server'**
  String get connectTitle;

  /// No description provided for @connectUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t support the OpenCode v2 API. Please update OpenCode.'**
  String get connectUnsupported;

  /// No description provided for @connectWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password'**
  String get connectWrongCredentials;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect: {error}'**
  String connectFailed(Object error);

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a URL'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid URL (e.g. http://192.168.1.10:4096)'**
  String get serverUrlInvalid;

  /// No description provided for @connectTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t answer in time. Check that it is running and reachable from this network.'**
  String get connectTimeout;

  /// No description provided for @connectUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check the URL, that the server is running, and that it listens on the network (--hostname 0.0.0.0).'**
  String get connectUnreachable;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'OPENCODE_SERVER_PASSWORD (leave blank if unset)'**
  String get passwordHelper;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @savedServers.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get savedServers;

  /// No description provided for @savedServersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load saved servers: {error}'**
  String savedServersLoadFailed(Object error);

  /// No description provided for @saveServer.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveServer;

  /// No description provided for @saveServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected. Save this server?'**
  String get saveServerTitle;

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dontSave;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editServer;

  /// No description provided for @editServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServerTitle;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get serverName;

  /// No description provided for @discoveredServers.
  ///
  /// In en, this message translates to:
  /// **'Found on this network'**
  String get discoveredServers;

  /// No description provided for @discoveringServers.
  ///
  /// In en, this message translates to:
  /// **'Searching the network for OpenCode servers…'**
  String get discoveringServers;

  /// No description provided for @discoveryNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No servers found'**
  String get discoveryNoneFound;

  /// No description provided for @rescanNetwork.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get rescanNetwork;

  /// No description provided for @discoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Looks for servers on port 4096 that accept connections from the network (opencode serve --hostname 0.0.0.0), and for servers announced over mDNS'**
  String get discoveryHint;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to the server…'**
  String get reconnecting;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @projectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load projects: {error}'**
  String projectsLoadFailed(Object error);

  /// No description provided for @currentProject.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentProject;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add project'**
  String get addProject;

  /// No description provided for @projectFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder path on the server'**
  String get projectFolderLabel;

  /// No description provided for @projectFolderHint.
  ///
  /// In en, this message translates to:
  /// **'/home/me/my-app'**
  String get projectFolderHint;

  /// No description provided for @projectFolderMustBeAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute path'**
  String get projectFolderMustBeAbsolute;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get chooseFolder;

  /// No description provided for @openThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Open this folder'**
  String get openThisFolder;

  /// No description provided for @noSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No folders here'**
  String get noSubfolders;

  /// No description provided for @searchFolders.
  ///
  /// In en, this message translates to:
  /// **'Search folders below'**
  String get searchFolders;

  /// No description provided for @showHiddenFolders.
  ///
  /// In en, this message translates to:
  /// **'Show hidden folders'**
  String get showHiddenFolders;

  /// No description provided for @hideHiddenFolders.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden folders'**
  String get hideHiddenFolders;

  /// No description provided for @enterFolderPath.
  ///
  /// In en, this message translates to:
  /// **'Enter a path'**
  String get enterFolderPath;

  /// No description provided for @goToFolder.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get goToFolder;

  /// No description provided for @parentFolder.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get parentFolder;

  /// No description provided for @foldersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load folders: {error}'**
  String foldersLoadFailed(Object error);

  /// No description provided for @projectOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the folder: {error}'**
  String projectOpenFailed(Object error);

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @projectTools.
  ///
  /// In en, this message translates to:
  /// **'Project tools'**
  String get projectTools;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionsEmpty;

  /// No description provided for @sessionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load sessions: {error}'**
  String sessionsLoadFailed(Object error);

  /// No description provided for @sessionCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create a session: {error}'**
  String sessionCreateFailed(Object error);

  /// No description provided for @untitledSession.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get untitledSession;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Summarize conversation'**
  String get compact;

  /// No description provided for @compactHelp.
  ///
  /// In en, this message translates to:
  /// **'Summarizes the conversation so far to free up context. Use it when the window is getting full.'**
  String get compactHelp;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename'**
  String get renameFailed;

  /// No description provided for @forkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fork'**
  String get forkFailed;

  /// No description provided for @compactFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t request a summary'**
  String get compactFailed;

  /// No description provided for @compactRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested a summary of the conversation'**
  String get compactRequested;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be deleted. This can\'t be undone.'**
  String deleteSessionBody(Object title);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete'**
  String get deleteFailed;

  /// No description provided for @sessionName.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get sessionName;

  /// No description provided for @renameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameConfirm;

  /// No description provided for @messagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get messagesEmpty;

  /// No description provided for @messagesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages: {error}'**
  String messagesLoadFailed(Object error);

  /// No description provided for @rewindHere.
  ///
  /// In en, this message translates to:
  /// **'Rewind to here'**
  String get rewindHere;

  /// No description provided for @rewindHereHelp.
  ///
  /// In en, this message translates to:
  /// **'Undo this message, everything after it, and their file changes'**
  String get rewindHereHelp;

  /// No description provided for @rewoundNotice.
  ///
  /// In en, this message translates to:
  /// **'Rewound. Sending a new message makes it final.'**
  String get rewoundNotice;

  /// No description provided for @rewindUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get rewindUndo;

  /// No description provided for @rewindFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rewind: {error}'**
  String rewindFailed(Object error);

  /// No description provided for @forkFromHere.
  ///
  /// In en, this message translates to:
  /// **'Fork from before this message'**
  String get forkFromHere;

  /// No description provided for @forkFromHereHelp.
  ///
  /// In en, this message translates to:
  /// **'Copies the conversation before this message into a new session'**
  String get forkFromHereHelp;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check the message and try again.'**
  String get sendFailed;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @imageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the image: {error}'**
  String imageLoadFailed(Object error);

  /// No description provided for @interruptFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t stop: {error}'**
  String interruptFailed(Object error);

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get attachImage;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @interrupt.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get interrupt;

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get removeAttachment;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @changeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change: {error}'**
  String changeFailed(Object error);

  /// No description provided for @agentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load agents: {error}'**
  String agentsLoadFailed(Object error);

  /// No description provided for @noMatchingModels.
  ///
  /// In en, this message translates to:
  /// **'No matching models'**
  String get noMatchingModels;

  /// No description provided for @searchModels.
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get searchModels;

  /// No description provided for @modelsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load models: {error}'**
  String modelsLoadFailed(Object error);

  /// No description provided for @variant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variant;

  /// No description provided for @agentBuildDescription.
  ///
  /// In en, this message translates to:
  /// **'The default agent with all tools enabled. The standard agent for development work that needs full access to file operations and system commands.'**
  String get agentBuildDescription;

  /// No description provided for @agentPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'A restricted agent for planning and analysis. Permissions prevent unintended changes.'**
  String get agentPlanDescription;

  /// No description provided for @tooManyAttachments.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} attachments'**
  String tooManyAttachments(Object count);

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Each file must be 10 MB or less'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachments must total 24 MB or less'**
  String get attachmentsTooLarge;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @sendUncertain.
  ///
  /// In en, this message translates to:
  /// **'Checking whether it was sent. It hasn\'t been resent.'**
  String get sendUncertain;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Remove from view'**
  String get dismiss;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @reasoning.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get reasoning;

  /// No description provided for @noOutput.
  ///
  /// In en, this message translates to:
  /// **'No output'**
  String get noOutput;

  /// No description provided for @compacted.
  ///
  /// In en, this message translates to:
  /// **'Summarized the conversation so far'**
  String get compacted;

  /// No description provided for @contextAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent: {name}'**
  String contextAgent(Object name);

  /// No description provided for @contextModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {name}'**
  String contextModel(Object name);

  /// No description provided for @contextLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {path}'**
  String contextLocation(Object path);

  /// No description provided for @contextSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill: {name}'**
  String contextSkill(Object name);

  /// No description provided for @linesOmitted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line omitted} other{{count} lines omitted}}'**
  String linesOmitted(int count);

  /// No description provided for @scrollToNewest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get scrollToNewest;

  /// No description provided for @reloadOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Reload earlier messages'**
  String get reloadOlderMessages;

  /// No description provided for @replyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reply: {error}'**
  String replyFailed(Object error);

  /// No description provided for @permissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission needed for \"{action}\"'**
  String permissionNeeded(Object action);

  /// No description provided for @moreWaiting.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreWaiting(Object count);

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @allowAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get allowAlways;

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get allowOnce;

  /// No description provided for @sendFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send'**
  String get sendFailedShort;

  /// No description provided for @cancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel'**
  String get cancelFailed;

  /// No description provided for @questionTitle.
  ///
  /// In en, this message translates to:
  /// **'A question for you'**
  String get questionTitle;

  /// No description provided for @formUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This question has fields the app doesn\'t support. Dismiss it or answer from another client.'**
  String get formUnsupported;

  /// No description provided for @dontAnswer.
  ///
  /// In en, this message translates to:
  /// **'Don\'t answer'**
  String get dontAnswer;

  /// No description provided for @otherFreeText.
  ///
  /// In en, this message translates to:
  /// **'Other (free text)'**
  String get otherFreeText;

  /// No description provided for @otherCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Other (comma-separated)'**
  String get otherCommaSeparated;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @doneInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Done in the browser'**
  String get doneInBrowser;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get allDone;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @fieldText.
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get fieldText;

  /// No description provided for @fieldPickOption.
  ///
  /// In en, this message translates to:
  /// **'Pick one of the options'**
  String get fieldPickOption;

  /// No description provided for @fieldMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String fieldMinLength(Object count);

  /// No description provided for @fieldMaxLength.
  ///
  /// In en, this message translates to:
  /// **'At most {count} characters'**
  String fieldMaxLength(Object count);

  /// No description provided for @fieldPattern.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get fieldPattern;

  /// No description provided for @fieldNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get fieldNumber;

  /// No description provided for @fieldInteger.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get fieldInteger;

  /// No description provided for @fieldMinimum.
  ///
  /// In en, this message translates to:
  /// **'Must be {value} or more'**
  String fieldMinimum(Object value);

  /// No description provided for @fieldMaximum.
  ///
  /// In en, this message translates to:
  /// **'Must be {value} or less'**
  String fieldMaximum(Object value);

  /// No description provided for @fieldChoose.
  ///
  /// In en, this message translates to:
  /// **'Make a selection'**
  String get fieldChoose;

  /// No description provided for @fieldMinItems.
  ///
  /// In en, this message translates to:
  /// **'Pick at least {count}'**
  String fieldMinItems(Object count);

  /// No description provided for @fieldMaxItems.
  ///
  /// In en, this message translates to:
  /// **'Pick at most {count}'**
  String fieldMaxItems(Object count);

  /// No description provided for @fieldExternal.
  ///
  /// In en, this message translates to:
  /// **'Check this once you\'re done'**
  String get fieldExternal;

  /// No description provided for @searchFiles.
  ///
  /// In en, this message translates to:
  /// **'Search by file name'**
  String get searchFiles;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get notFound;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyFolder;

  /// No description provided for @filesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load files: {error}'**
  String filesLoadFailed(Object error);

  /// No description provided for @binaryFile.
  ///
  /// In en, this message translates to:
  /// **'Can\'t display this file ({bytes} bytes)'**
  String binaryFile(Object bytes);

  /// No description provided for @fileTruncated.
  ///
  /// In en, this message translates to:
  /// **'This file is long, so only the beginning is shown'**
  String get fileTruncated;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file: {error}'**
  String fileOpenFailed(Object error);

  /// No description provided for @unknownBranch.
  ///
  /// In en, this message translates to:
  /// **'Unknown branch'**
  String get unknownBranch;

  /// No description provided for @uncommitted.
  ///
  /// In en, this message translates to:
  /// **'Uncommitted'**
  String get uncommitted;

  /// No description provided for @wholeBranch.
  ///
  /// In en, this message translates to:
  /// **'Whole branch'**
  String get wholeBranch;

  /// No description provided for @diffAgainst.
  ///
  /// In en, this message translates to:
  /// **'Diff against {branch}'**
  String diffAgainst(Object branch);

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// No description provided for @gitLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the Git status: {error}'**
  String gitLoadFailed(Object error);

  /// No description provided for @noDiff.
  ///
  /// In en, this message translates to:
  /// **'No diff'**
  String get noDiff;

  /// No description provided for @mcpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured'**
  String get mcpEmpty;

  /// No description provided for @mcpLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load MCP servers: {error}'**
  String mcpLoadFailed(Object error);

  /// No description provided for @toggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch: {error}'**
  String toggleFailed(Object error);

  /// No description provided for @mcpConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get mcpConnected;

  /// No description provided for @mcpDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get mcpDisconnected;

  /// No description provided for @mcpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mcpDisabled;

  /// No description provided for @mcpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mcpFailed;

  /// No description provided for @mcpNeedsAuth.
  ///
  /// In en, this message translates to:
  /// **'Needs authentication'**
  String get mcpNeedsAuth;

  /// No description provided for @mcpNeedsClientRegistration.
  ///
  /// In en, this message translates to:
  /// **'Needs client registration'**
  String get mcpNeedsClientRegistration;

  /// No description provided for @newTerminal.
  ///
  /// In en, this message translates to:
  /// **'New terminal'**
  String get newTerminal;

  /// No description provided for @terminalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No terminals yet'**
  String get terminalsEmpty;

  /// No description provided for @terminalExited.
  ///
  /// In en, this message translates to:
  /// **'Exited (code {code})'**
  String terminalExited(Object code);

  /// No description provided for @terminalsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load terminals: {error}'**
  String terminalsLoadFailed(Object error);

  /// No description provided for @terminalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a terminal: {error}'**
  String terminalOpenFailed(Object error);

  /// No description provided for @closeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t close: {error}'**
  String closeFailed(Object error);

  /// No description provided for @ptyConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get ptyConnecting;

  /// No description provided for @ptyFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get ptyFailed;

  /// No description provided for @ptyClosed.
  ///
  /// In en, this message translates to:
  /// **'The terminal has exited'**
  String get ptyClosed;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal {count}'**
  String terminalTitle(Object count);

  /// Session list: a permission request or question is waiting on the user.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get sessionWaiting;

  /// Session list: the session's last run ended in an error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sessionFailed;

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get usageTitle;

  /// No description provided for @usageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Context and usage'**
  String get usageTooltip;

  /// No description provided for @usageTokensUsed.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens used'**
  String usageTokensUsed(String count);

  /// No description provided for @usageProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get usageProvider;

  /// No description provided for @usageModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get usageModel;

  /// No description provided for @usageLimit.
  ///
  /// In en, this message translates to:
  /// **'Context limit'**
  String get usageLimit;

  /// No description provided for @usageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total tokens'**
  String get usageTotalTokens;

  /// No description provided for @usagePercent.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usagePercent;

  /// No description provided for @usageInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input tokens'**
  String get usageInputTokens;

  /// No description provided for @usageOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output tokens'**
  String get usageOutputTokens;

  /// No description provided for @usageReasoningTokens.
  ///
  /// In en, this message translates to:
  /// **'Reasoning tokens'**
  String get usageReasoningTokens;

  /// No description provided for @usageCacheTokens.
  ///
  /// In en, this message translates to:
  /// **'Cache read / write'**
  String get usageCacheTokens;

  /// No description provided for @usageLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity'**
  String get usageLastActivity;

  /// No description provided for @usageNoReplies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet. Usage appears after the first reply.'**
  String get usageNoReplies;

  /// No description provided for @usageLastStepHelp.
  ///
  /// In en, this message translates to:
  /// **'Counts from the latest reply, which is what fills the context window.'**
  String get usageLastStepHelp;

  /// No description provided for @sessionUsage.
  ///
  /// In en, this message translates to:
  /// **'Whole session'**
  String get sessionUsage;

  /// No description provided for @sessionCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get sessionCost;

  /// No description provided for @sessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get sessionCreated;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pushTitle;

  /// No description provided for @pushReceive.
  ///
  /// In en, this message translates to:
  /// **'Get notified for this server'**
  String get pushReceive;

  /// No description provided for @pushWhat.
  ///
  /// In en, this message translates to:
  /// **'Notifies you when the agent finishes, stops on an error, or waits for a permission or an answer. Needs the plugin below in OpenCode on your computer. Project and session names are encrypted, so the relay server cannot read them.'**
  String get pushWhat;

  /// No description provided for @pushNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This build has no push settings. Build it with PUSH_RELAY_URL and the Firebase values (see docs/push-notifications.md).'**
  String get pushNotConfigured;

  /// No description provided for @pushPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in system settings'**
  String get pushPermissionDenied;

  /// No description provided for @pushNoToken.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a push token from the device. Try again later.'**
  String get pushNoToken;

  /// No description provided for @pushFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update notifications: {error}'**
  String pushFailed(Object error);

  /// No description provided for @pushSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up OpenCode on your computer'**
  String get pushSetupTitle;

  /// No description provided for @pushSetupSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Add the entry below to ~/.config/opencode/opencode.json (or opencode.jsonc)\n2. Restart OpenCode\n\nOpenCode installs the plugin from npm, and the plugin makes its own pairing key on the computer. The app reads that key by itself, so there is nothing to copy.'**
  String get pushSetupSteps;

  /// No description provided for @pushSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get pushSendTest;

  /// No description provided for @pushTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test notification from OpenCode'**
  String get pushTestTitle;

  /// No description provided for @pushTestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. It should arrive in a few seconds.'**
  String get pushTestSent;

  /// No description provided for @pushOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get pushOpen;

  /// No description provided for @pushHeadlineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reply finished'**
  String get pushHeadlineCompleted;

  /// No description provided for @pushHeadlineFailed.
  ///
  /// In en, this message translates to:
  /// **'Stopped with an error'**
  String get pushHeadlineFailed;

  /// No description provided for @pushHeadlinePermission.
  ///
  /// In en, this message translates to:
  /// **'Waiting for permission'**
  String get pushHeadlinePermission;

  /// No description provided for @pushHeadlineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your answer'**
  String get pushHeadlineQuestion;

  /// No description provided for @pushChannelName.
  ///
  /// In en, this message translates to:
  /// **'Agent updates'**
  String get pushChannelName;

  /// No description provided for @pushOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the session: {error}'**
  String pushOpenFailed(Object error);

  /// No description provided for @servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get servers;

  /// No description provided for @serverRunning.
  ///
  /// In en, this message translates to:
  /// **'{count} running'**
  String serverRunning(int count);

  /// No description provided for @serverFinished.
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String serverFinished(int count);

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect'**
  String get serverUnreachable;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @serverSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to {name}: {error}'**
  String serverSwitchFailed(String name, String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Use system setting'**
  String get settingsFollowSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @chatPaneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick a session to show its chat here'**
  String get chatPaneEmpty;

  /// No description provided for @settingsInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction'**
  String get settingsInteraction;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Vibrate lightly on send, when a reply finishes, and when the AI needs your answer'**
  String get settingsHapticsHelp;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Version {installed} can no longer be used. Please update to version {minimum} or later.'**
  String updateRequiredBody(String installed, String minimum);

  /// No description provided for @updateOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Open the store'**
  String get updateOpenStore;

  /// No description provided for @updateFromStore.
  ///
  /// In en, this message translates to:
  /// **'Update the app from the App Store or Google Play.'**
  String get updateFromStore;

  /// No description provided for @rewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s free messages are used up'**
  String get rewardTitle;

  /// No description provided for @rewardBody.
  ///
  /// In en, this message translates to:
  /// **'You can send {free} messages a day without ads. Watch a short ad to send {more} more today.'**
  String rewardBody(int free, int more);

  /// No description provided for @rewardWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get rewardWatch;

  /// No description provided for @rewardSkipped.
  ///
  /// In en, this message translates to:
  /// **'Watch the ad to the end to send this message.'**
  String get rewardSkipped;

  /// No description provided for @settingsAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get settingsAds;

  /// No description provided for @adsFreeLeft.
  ///
  /// In en, this message translates to:
  /// **'Messages without ads today'**
  String get adsFreeLeft;

  /// No description provided for @adsFreeLeftValue.
  ///
  /// In en, this message translates to:
  /// **'{left} left'**
  String adsFreeLeftValue(int left);

  /// No description provided for @removeAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get removeAds;

  /// No description provided for @removeAdsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. Hides banners and the ad before sending.'**
  String get removeAdsSubtitle;

  /// No description provided for @removeAdsDone.
  ///
  /// In en, this message translates to:
  /// **'Ads are removed. Thank you for your support!'**
  String get removeAdsDone;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchases;

  /// No description provided for @restoreStarted.
  ///
  /// In en, this message translates to:
  /// **'Checking your purchases…'**
  String get restoreStarted;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through.'**
  String get purchaseFailed;

  /// No description provided for @adPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacy;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Support and privacy'**
  String get settingsSupport;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @contactSubject.
  ///
  /// In en, this message translates to:
  /// **'OpenCode Mobile feedback'**
  String get contactSubject;

  /// No description provided for @contactBodyPrompt.
  ///
  /// In en, this message translates to:
  /// **'(Please write your question or the problem you ran into here.)'**
  String get contactBodyPrompt;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @crashReports.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports'**
  String get crashReports;

  /// No description provided for @crashReportsHelp.
  ///
  /// In en, this message translates to:
  /// **'When the app crashes, send the error details (no chat content) to help fix it'**
  String get crashReportsHelp;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this:'**
  String get linkOpenFailed;

  /// No description provided for @pushComputerTitle.
  ///
  /// In en, this message translates to:
  /// **'On the computer'**
  String get pushComputerTitle;

  /// No description provided for @pushComputerActive.
  ///
  /// In en, this message translates to:
  /// **'The plugin is running'**
  String get pushComputerActive;

  /// No description provided for @pushComputerFailed.
  ///
  /// In en, this message translates to:
  /// **'The plugin failed to load: {error}'**
  String pushComputerFailed(Object error);

  /// No description provided for @pushComputerOtherKey.
  ///
  /// In en, this message translates to:
  /// **'The plugin on the computer uses another relay or key. Change its entry in opencode.json(c) to the one below.'**
  String get pushComputerOtherKey;

  /// No description provided for @pushComputerNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'It is configured but not loaded yet. Restart OpenCode.'**
  String get pushComputerNotLoaded;

  /// No description provided for @pushComputerMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet. Add it with the steps below.'**
  String get pushComputerMissing;

  /// No description provided for @pushComputerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check'**
  String get pushComputerUnknown;

  /// No description provided for @pushComputerRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get pushComputerRefresh;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection check'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get diagnosticsServer;

  /// No description provided for @diagnosticsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get diagnosticsAddress;

  /// No description provided for @diagnosticsHealth.
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get diagnosticsHealth;

  /// No description provided for @diagnosticsHealthOk.
  ///
  /// In en, this message translates to:
  /// **'OpenCode {version} · responded in {ms} ms'**
  String diagnosticsHealthOk(String version, int ms);

  /// No description provided for @diagnosticsHealthFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String diagnosticsHealthFailed(Object error);

  /// No description provided for @diagnosticsLive.
  ///
  /// In en, this message translates to:
  /// **'Live updates'**
  String get diagnosticsLive;

  /// No description provided for @diagnosticsLiveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Event stream'**
  String get diagnosticsLiveUpdates;

  /// No description provided for @diagnosticsLiveConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get diagnosticsLiveConnected;

  /// No description provided for @diagnosticsLiveStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get diagnosticsLiveStopped;

  /// No description provided for @diagnosticsPlugin.
  ///
  /// In en, this message translates to:
  /// **'Push notification plugin'**
  String get diagnosticsPlugin;

  /// No description provided for @diagnosticsPluginOtherKey.
  ///
  /// In en, this message translates to:
  /// **'The plugin on the computer uses another relay or key. Tap to check.'**
  String get diagnosticsPluginOtherKey;

  /// No description provided for @diagnosticsMcpNone.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers'**
  String get diagnosticsMcpNone;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'This app'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsOs.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get settingsOs;

  /// No description provided for @diagnosticsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get diagnosticsChecking;

  /// No description provided for @diagnosticsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get diagnosticsRecheck;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the results'**
  String get diagnosticsCopy;

  /// No description provided for @connectGuide.
  ///
  /// In en, this message translates to:
  /// **'How to connect from home or away'**
  String get connectGuide;

  /// No description provided for @conversationMode.
  ///
  /// In en, this message translates to:
  /// **'Conversation mode'**
  String get conversationMode;

  /// No description provided for @conversationPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get conversationPreparing;

  /// No description provided for @conversationListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get conversationListening;

  /// No description provided for @conversationSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get conversationSending;

  /// No description provided for @conversationWaiting.
  ///
  /// In en, this message translates to:
  /// **'OpenCode is working…'**
  String get conversationWaiting;

  /// No description provided for @conversationNeedsInput.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your answer on screen'**
  String get conversationNeedsInput;

  /// No description provided for @conversationSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Reading the reply'**
  String get conversationSpeaking;

  /// No description provided for @conversationIdle.
  ///
  /// In en, this message translates to:
  /// **'Tap the mic once, then speak'**
  String get conversationIdle;

  /// No description provided for @conversationListenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t listen ({error}). Tap the mic to try again.'**
  String conversationListenFailed(Object error);

  /// No description provided for @conversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is unavailable. Allow the microphone and speech recognition for this app in Settings.'**
  String get conversationUnavailable;

  /// No description provided for @conversationListen.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get conversationListen;

  /// No description provided for @conversationDoneSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Done speaking'**
  String get conversationDoneSpeaking;

  /// No description provided for @conversationEnd.
  ///
  /// In en, this message translates to:
  /// **'End conversation mode'**
  String get conversationEnd;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @readingAloud.
  ///
  /// In en, this message translates to:
  /// **'Reading aloud…'**
  String get readingAloud;

  /// No description provided for @stopReading.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopReading;

  /// No description provided for @speechCodeSkipped.
  ///
  /// In en, this message translates to:
  /// **'(code omitted)'**
  String get speechCodeSkipped;

  /// No description provided for @speechTruncated.
  ///
  /// In en, this message translates to:
  /// **'The rest is omitted.'**
  String get speechTruncated;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
