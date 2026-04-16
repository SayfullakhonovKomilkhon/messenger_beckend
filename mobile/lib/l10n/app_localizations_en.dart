// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get copied => 'Copied';

  @override
  String get idCopied => 'ID copied';

  @override
  String get unknown => 'Unknown';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get privacy => 'Privacy';

  @override
  String get notifications => 'Notifications';

  @override
  String get conversations => 'Conversations';

  @override
  String get messageRequests => 'Message Requests';

  @override
  String get appearance => 'Appearance';

  @override
  String get appLock => 'App Lock';

  @override
  String get help => 'Help';

  @override
  String get helpInDevelopment => 'Help section is under development';

  @override
  String get inviteFriend => 'Invite a Friend';

  @override
  String inviteText(String login) {
    return 'Join Demos! My login: $login';
  }

  @override
  String get regenerateKeys => 'Regenerate Encryption Keys';

  @override
  String get keysUpdated => 'Encryption keys updated';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutTitle => 'Log Out';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get clearAllData => 'Clear All Data';

  @override
  String get clearAllDataConfirm =>
      'This action is irreversible. All your data will be permanently deleted.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get copyId => 'Copy ID';

  @override
  String get shareId => 'Share';

  @override
  String myIdInDemos(String id) {
    return 'My Demos ID: $id';
  }

  @override
  String get appVersion => 'Demos Chat 1.0.3 — End-to-End Encryption (E2EE)';

  @override
  String get language => 'Language';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String avatarNameLabel(String name) {
    return 'Avatar name: $name';
  }

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get yourId => 'Your ID';

  @override
  String get idDescription =>
      'Unique identifier for search and transactions. Cannot be changed.';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Russian letters only';

  @override
  String get nicknameDescription => 'Display name. Must be unique.';

  @override
  String get aiAgentName => 'AI Agent Name';

  @override
  String get aiNameHint => 'Name for AI and Telepathy';

  @override
  String get aiNameDescription => 'Used for AI agent and Telepathy features.';

  @override
  String get aboutYou => 'About';

  @override
  String get aboutHint => 'Tell us about yourself';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get errorSaving => 'Error saving';

  @override
  String get nickCannotBeEmpty => 'Nickname cannot be empty';

  @override
  String get pickFromGallery => 'Choose from Gallery';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get deletePhoto => 'Delete Photo';

  @override
  String get photoUploadFailed => 'Failed to upload photo';

  @override
  String get photoUrlFailed => 'Failed to get uploaded photo URL';

  @override
  String get tabMessages => 'Messages';

  @override
  String get tabCalls => 'Calls';

  @override
  String get tabTelepathy => 'Telepathy';

  @override
  String get tabSettings => 'Settings';

  @override
  String get searchHint => 'Search...';

  @override
  String get newGroup => 'New Group';

  @override
  String get darkThemeMenu => 'Dark Theme';

  @override
  String get lightThemeMenu => 'Light Theme';

  @override
  String get wallet => 'Wallet';

  @override
  String get markAsRead => 'Mark as Read';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get failedToLoadChats => 'Failed to load chats';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get findContactViaSearch => 'Find someone via search';

  @override
  String get chatsSection => 'Chats';

  @override
  String get usersSection => 'Users';

  @override
  String get foundById => 'Found by ID';

  @override
  String get foundByAvatarName => 'Found by avatar name';

  @override
  String get foundByNickname => 'Found by nickname';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get failedToLoadCalls => 'Failed to load call history';

  @override
  String get noCallsYet => 'No calls yet';

  @override
  String get callHistoryHere => 'Your call history will appear here';

  @override
  String get videoCall => 'Video Call';

  @override
  String get audioCall => 'Audio Call';

  @override
  String get group => 'Group';

  @override
  String get noMessagesPreview => 'No messages yet';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get attachment => 'Attachment';

  @override
  String get encryptedMessage => 'Encrypted message';

  @override
  String get telepathy => 'Telepathy';

  @override
  String get members => 'members';

  @override
  String get pinTooltip => 'Pin';

  @override
  String get muteTooltip => 'Mute';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get messageHint => 'Message...';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get reply => 'Reply';

  @override
  String get copyText => 'Copy';

  @override
  String get forward => 'Forward';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get edit => 'Edit';

  @override
  String get deleteMsg => 'Delete';

  @override
  String get editMessage => 'Edit Message';

  @override
  String get forwardMessage => 'Forward Message';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get messageForwarded => 'Message forwarded';

  @override
  String get groupE2eeTitle => 'Group End-to-End Encryption';

  @override
  String get groupE2eeDescription =>
      'This group uses the Sender Keys protocol.\nEach member generates their own key,\nand all messages are encrypted so that only\ngroup members can read them.';

  @override
  String membersWithE2ee(int count) {
    return '$count member(s) with E2EE';
  }

  @override
  String get clearHistoryTitle => 'Clear History';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to clear history for everyone?';

  @override
  String get clear => 'Clear';

  @override
  String get deleteChatTitle => 'Delete Chat';

  @override
  String get deleteChatConfirm => 'Are you sure you want to delete this chat?';

  @override
  String typingStatus(String name) {
    return '$name is typing...';
  }

  @override
  String get typing => 'typing...';

  @override
  String get online => 'online';

  @override
  String get offline => 'offline';

  @override
  String get searchInChat => 'Search in chat...';

  @override
  String get errorLoadingMessages => 'Error loading messages';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get disableNotifications => 'Disable Notifications';

  @override
  String get encryption => 'Encryption';

  @override
  String get clearHistoryAll => 'Clear History for All';

  @override
  String get deleteChat => 'Delete Chat';

  @override
  String get groupInfo => 'Group Info';

  @override
  String get pinnedMessage => 'Pinned Message';

  @override
  String get you => 'You';

  @override
  String get fileUploadError => 'File upload error';

  @override
  String get micPermissionError => 'No microphone access';

  @override
  String get voiceUploadError => 'Voice upload error';

  @override
  String get voiceSendError => 'Voice send error';

  @override
  String get trustBannerTitle => 'Trust this user?';

  @override
  String get trustBannerDescription =>
      'If both users confirm trust, full profiles will be visible (name, avatar, photo).';

  @override
  String get trustNo => 'No';

  @override
  String get trustYes => 'Trust';

  @override
  String membersCount(int count) {
    return '$count member(s)';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get userFallback => 'User';

  @override
  String userBlocked(String name) {
    return '$name blocked';
  }

  @override
  String userUnblocked(String name) {
    return '$name unblocked';
  }

  @override
  String get blockError => 'Error blocking user';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmMessage =>
      'Blocked user will not be able to send you messages or see your profile.';

  @override
  String get block => 'Block';

  @override
  String get userNotFound => 'User not found';

  @override
  String get info => 'Info';

  @override
  String get trustNotConfirmed => 'Trust not confirmed';

  @override
  String get writeMessage => 'Write';

  @override
  String get callAction => 'Call';

  @override
  String get videoCallAction => 'Video';

  @override
  String get muteSound => 'Mute';

  @override
  String get unmuteSound => 'Unmute';

  @override
  String get mediaFiles => 'Media Files';

  @override
  String get viewAll => 'All →';

  @override
  String get noMediaFiles => 'No media files';

  @override
  String get allMedia => 'All Media';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String get settingSaveError => 'Failed to save setting';

  @override
  String get voiceVideoBeta => 'Voice & Video (Beta)';

  @override
  String get voiceVideoCalls => 'Voice & Video Calls';

  @override
  String get allowCalls => 'Allow incoming and outgoing calls';

  @override
  String get screenSecurity => 'Screen Security';

  @override
  String get lockApp => 'Lock App';

  @override
  String get lockAppDescription =>
      'Use Touch ID, Face ID or device password to open Demos';

  @override
  String get readReceipts => 'Read Receipts';

  @override
  String get readReceiptsDescription => 'Send read receipts in private chats';

  @override
  String get typingIndicators => 'Typing Indicators';

  @override
  String get typingIndicatorsDescription =>
      'See and show when someone is typing';

  @override
  String get linkPreviews => 'Link Previews';

  @override
  String get linkPreviewsDescription => 'Generate previews for supported links';

  @override
  String get strategy => 'Strategy';

  @override
  String get fastMode => 'Fast Mode';

  @override
  String get fastModeDescription => 'Instant notifications via Google servers';

  @override
  String get systemSettings => 'System Settings';

  @override
  String get systemSettingsDescription => 'Device notification settings';

  @override
  String get styleSection => 'Style';

  @override
  String get sound => 'Sound';

  @override
  String get soundDefault => 'Default';

  @override
  String get soundNone => 'None';

  @override
  String get soundSystem => 'System';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibDefault => 'Default';

  @override
  String get vibShort => 'Short';

  @override
  String get vibLong => 'Long';

  @override
  String get vibOff => 'Off';

  @override
  String get popup => 'Popup';

  @override
  String get popupAlways => 'Always';

  @override
  String get popupScreenOn => 'Only when screen is on';

  @override
  String get popupNever => 'Never';

  @override
  String get inAppSound => 'In-App Sound';

  @override
  String get inAppSoundDescription => 'Play sound when app is open';

  @override
  String get contentSection => 'Content';

  @override
  String get notificationContent => 'Notification Content';

  @override
  String get contentNameAndText => 'Name and text';

  @override
  String get contentNameOnly => 'Name only';

  @override
  String get contentHidden => 'Hidden';

  @override
  String get mediaPreview => 'Media Preview';

  @override
  String get mediaPreviewDescription =>
      'Show photos and videos in notifications';

  @override
  String get exceptions => 'Exceptions';

  @override
  String get doNotDisturb => 'Do Not Disturb';

  @override
  String get doNotDisturbDescription => 'Mute notifications at certain times';

  @override
  String get notificationSound => 'Notification Sound';

  @override
  String get popupNotification => 'Popup Notification';

  @override
  String get create => 'Create';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupDescriptionOptional => 'Description (optional)';

  @override
  String get searchByNameOrId => 'Search by name or ID...';

  @override
  String get enterGroupName => 'Enter group name';

  @override
  String get foundByName => 'Found by name';

  @override
  String get idUser => 'ID user';

  @override
  String get messageCleanup => 'Message Cleanup';

  @override
  String get communityCleanup => 'Community Cleanup';

  @override
  String get communityCleanupDescription =>
      'Delete messages from communities older than 6 months or over 2000';

  @override
  String get enterKey => 'Enter Key';

  @override
  String get enterSends => 'Send with Enter';

  @override
  String get enterSendsDescription => 'Pressing Enter will send your message';

  @override
  String get voiceMessages => 'Voice Messages';

  @override
  String get autoPlay => 'Auto-play';

  @override
  String get autoPlayDescription => 'Automatically play messages in sequence';

  @override
  String get blockedContacts => 'Blocked Contacts';

  @override
  String get theme => 'Theme';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get chatWallpaper => 'Chat Wallpaper';

  @override
  String get systemTheme => 'System Theme';

  @override
  String get followSystem => 'Follow System';

  @override
  String unblockConfirm(String name) {
    return 'Unblock $name?';
  }

  @override
  String get contactUnblocked => 'Contact unblocked';

  @override
  String get noBlockedContacts => 'No blocked contacts';

  @override
  String get blockedContactsHint => 'Contacts you block\nwill appear here';

  @override
  String get requestAccepted => 'Request accepted';

  @override
  String get acceptError => 'Error accepting request';

  @override
  String get requestDeclinedBlocked => 'Request declined, user blocked';

  @override
  String get requestDeclined => 'Request declined';

  @override
  String get declineError => 'Error declining request';

  @override
  String get decline => 'Decline';

  @override
  String get declineAndBlock => 'Decline and Block';

  @override
  String get clearAllRequests => 'Clear All';

  @override
  String get clearAllRequestsConfirm =>
      'Are you sure you want to decline all message requests?';

  @override
  String get declineAll => 'Decline All';

  @override
  String get allRequestsDeclined => 'All requests declined';

  @override
  String get clearRequestsError => 'Error clearing requests';

  @override
  String get noRequests => 'No requests';

  @override
  String get noRequestsHint => 'Requests from new contacts will appear here';

  @override
  String get noMessages => 'No messages';

  @override
  String get accept => 'Accept';

  @override
  String get e2eeTitle => 'End-to-End Encryption';

  @override
  String e2eeDescription(String name) {
    return 'Messages in this chat are protected by end-to-end encryption. Only you and $name can read them.';
  }

  @override
  String get securityCode => 'Security Code';

  @override
  String securityCodeHint(String name) {
    return 'Compare this code with $name\'s code to verify chat security.';
  }

  @override
  String get copyCode => 'Copy Code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get securityCodeUnavailable =>
      'Security code will be available after exchanging messages.';

  @override
  String get wallpaperLove => 'Love';

  @override
  String get wallpaperStarwars => 'Star Wars';

  @override
  String get wallpaperDoodles => 'Doodles';

  @override
  String get wallpaperMath => 'Math';

  @override
  String get wallpaperCosmos => 'Cosmos';

  @override
  String get wallpaperNone => 'No Background';

  @override
  String get myBots => 'My Bots';

  @override
  String get createBot => 'Create Bot';

  @override
  String get botName => 'Bot Name';

  @override
  String get botUsername => 'Bot Username';

  @override
  String get botDescription => 'Description';

  @override
  String get botDescriptionHint => 'What does this bot do?';

  @override
  String get botAvatar => 'Avatar';

  @override
  String get botWebhookUrl => 'Webhook URL';

  @override
  String get botWebhookHint => 'https://example.com/webhook';

  @override
  String get botToken => 'Bot Token';

  @override
  String get botTokenCopied => 'Token copied to clipboard';

  @override
  String get botRegenerateToken => 'Regenerate Token';

  @override
  String get botRegenerateTokenConfirm =>
      'Generate a new token? The old one will stop working.';

  @override
  String get botSetWebhook => 'Set Webhook';

  @override
  String get botDeleteWebhook => 'Delete Webhook';

  @override
  String get botDelete => 'Delete Bot';

  @override
  String get botDeleteConfirm =>
      'Are you sure you want to delete this bot? This action cannot be undone.';

  @override
  String get botCreated => 'Bot created';

  @override
  String get botUpdated => 'Bot updated';

  @override
  String get botDeleted => 'Bot deleted';

  @override
  String get botActive => 'Active';

  @override
  String get botInactive => 'Inactive';

  @override
  String get botToggleActive => 'Toggle Active';

  @override
  String get noBots => 'No bots yet';

  @override
  String get noBotsHint => 'Create your first bot to get started';

  @override
  String get botNameRequired => 'Bot name is required';

  @override
  String get botUsernameRequired => 'Bot username is required';

  @override
  String get botBadge => 'BOT';

  @override
  String get botEditTitle => 'Edit Bot';

  @override
  String get botWebhookUpdated => 'Webhook updated';

  @override
  String get botWebhookDeleted => 'Webhook removed';

  @override
  String get botWebhookUseRailwayDefault => 'Use test URL (Railway)';
}
