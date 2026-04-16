import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Generate device ID if not exists
    if (_prefs!.getString(_deviceIdKey) == null) {
      final deviceId = const Uuid().v4();
      await _prefs!.setString(_deviceIdKey, deviceId);
    }
  }

  static String? getDeviceId() => _prefs?.getString(_deviceIdKey);

  static String getTheme() => _prefs.getString('theme') ?? 'light';
  static Future<void> setTheme(String theme) => _prefs.setString('theme', theme);

  static bool getFollowSystemTheme() => _prefs.getBool('follow_system_theme') ?? false;
  static Future<void> setFollowSystemTheme(bool value) =>
      _prefs.setBool('follow_system_theme', value);

  static int getAccentIndex() => _prefs.getInt('accent_index') ?? 0;
  static Future<void> setAccentIndex(int index) => _prefs.setInt('accent_index', index);

  static bool getRememberMe() => _prefs.getBool('remember_me') ?? false;
  static Future<void> setRememberMe(bool value) => _prefs.setBool('remember_me', value);

  static String? getSavedUserId() => _prefs.getString('saved_user_id');
  static Future<void> setSavedUserId(String? id) {
    if (id == null) return _prefs.remove('saved_user_id');
    return _prefs.setString('saved_user_id', id);
  }

  static bool getBlockApp() => _prefs.getBool('block_app') ?? false;
  static Future<void> setBlockApp(bool value) => _prefs.setBool('block_app', value);

  static String? getDraft(String conversationId) =>
      _prefs.getString('draft_$conversationId');
  static Future<void> setDraft(String conversationId, String? text) {
    if (text == null || text.isEmpty) {
      return _prefs.remove('draft_$conversationId');
    }
    return _prefs.setString('draft_$conversationId', text);
  }

  static const _pendingMessagesKey = 'pending_messages';

  static List<Map<String, dynamic>> getPendingMessages() {
    final json = _prefs.getString(_pendingMessagesKey);
    if (json == null) return [];
    try {
      final list = (jsonDecode(json) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addPendingMessage(Map<String, dynamic> msg) async {
    final list = getPendingMessages();
    list.add(msg);
    await _prefs.setString(_pendingMessagesKey, jsonEncode(list));
  }

  static Future<void> removePendingMessage(String clientMessageId) async {
    final list = getPendingMessages();
    list.removeWhere((m) => m['clientMessageId'] == clientMessageId);
    await _prefs.setString(_pendingMessagesKey, jsonEncode(list));
  }

  // E2EE: cache decrypted plaintext for encrypted messages.
  // Stored by clientMessageId (for sent) and by message ID (for received).
  static const _e2eePlaintextPrefix = 'e2ee_pt_';
  static const _e2eeMsgIdPrefix = 'e2ee_mid_';

  static Future<void> cacheEncryptedPlaintext(String clientMessageId, String plaintext) async {
    await _prefs.setString('$_e2eePlaintextPrefix$clientMessageId', plaintext);
  }

  static String? getCachedPlaintext(String clientMessageId) {
    return _prefs.getString('$_e2eePlaintextPrefix$clientMessageId');
  }

  static Future<void> cacheDecryptedMessage(String messageId, String plaintext) async {
    await _prefs.setString('$_e2eeMsgIdPrefix$messageId', plaintext);
  }

  static String? getDecryptedMessage(String messageId) {
    return _prefs.getString('$_e2eeMsgIdPrefix$messageId');
  }

  // E2EE: cache last decrypted preview per conversation (survives app restarts)
  static const _e2eeConvPreviewPrefix = 'e2ee_cv_';

  static Future<void> cacheConversationPreview(String conversationId, String plaintext) async {
    await _prefs.setString('$_e2eeConvPreviewPrefix$conversationId', plaintext);
  }

  static String? getConversationPreview(String conversationId) {
    return _prefs.getString('$_e2eeConvPreviewPrefix$conversationId');
  }

  static String getChatWallpaper() => _prefs.getString('chat_wallpaper') ?? 'cosmos';
  static Future<void> setChatWallpaper(String id) => _prefs.setString('chat_wallpaper', id);

  static String getLocale() => _prefs.getString('app_locale') ?? 'ru';
  static Future<void> setLocale(String locale) => _prefs.setString('app_locale', locale);
}
