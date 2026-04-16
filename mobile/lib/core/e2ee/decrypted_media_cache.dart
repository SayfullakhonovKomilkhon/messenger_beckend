import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/local_storage.dart';
import 'crypto_service.dart';
import 'key_manager.dart';

/// In-memory + temp-file cache for decrypted E2EE media.
class DecryptedMediaCache {
  DecryptedMediaCache._();

  static final Map<String, Uint8List> _bytesCache = {};
  static final Map<String, String> _filePathCache = {};
  static final Map<String, Future<Uint8List?>> _pendingDecrypts = {};

  /// Cache raw decrypted bytes by key (messageId or clientMessageId).
  static void cacheBytes(String key, Uint8List bytes) {
    _bytesCache[key] = bytes;
  }

  /// Get cached decrypted bytes.
  static Uint8List? getBytes(String key) => _bytesCache[key];

  /// Get cached temp file path (for video/audio).
  static String? getFilePath(String key) => _filePathCache[key];

  /// Download, decrypt and cache media bytes for a message.
  /// Returns decrypted bytes or null on failure.
  /// Uses deduplication to avoid parallel decryptions of the same message.
  static Future<Uint8List?> getOrDecrypt({
    required String messageId,
    required String clientMessageId,
    required String fileUrl,
    required String senderId,
    required String? encryptedFileKey,
    required String? fileIv,
    required bool isMine,
    String? groupId,
  }) async {
    final key = messageId.isNotEmpty ? messageId : clientMessageId;

    final cached = _bytesCache[key] ?? _bytesCache[clientMessageId];
    if (cached != null) return cached;

    if (_pendingDecrypts.containsKey(key)) {
      return _pendingDecrypts[key];
    }

    final future = _doDecrypt(
      key: key,
      clientMessageId: clientMessageId,
      fileUrl: fileUrl,
      senderId: senderId,
      encryptedFileKey: encryptedFileKey,
      isMine: isMine,
      groupId: groupId,
    );
    _pendingDecrypts[key] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _pendingDecrypts.remove(key);
    }
  }

  static Future<Uint8List?> _doDecrypt({
    required String key,
    required String clientMessageId,
    required String fileUrl,
    required String senderId,
    required String? encryptedFileKey,
    required bool isMine,
    String? groupId,
  }) async {
    if (encryptedFileKey == null || encryptedFileKey.isEmpty) return null;
    if (!E2eeKeyManager().isInitialized) return null;

    try {
      final crypto = E2eeCryptoService();

      Uint8List? aesKey;
      final cachedKeyStr = LocalStorage.getDecryptedMessage('filekey_$key')
          ?? LocalStorage.getDecryptedMessage('filekey_$clientMessageId');
      if (cachedKeyStr != null) {
        aesKey = Uint8List.fromList(base64Decode(cachedKeyStr));
      } else if (!isMine) {
        if (groupId != null && groupId.isNotEmpty) {
          aesKey = await crypto.decryptGroupFileKey(
            groupId, senderId, encryptedFileKey,
          );
        } else {
          aesKey = await crypto.decryptFileKey(
            senderId, encryptedFileKey, CiphertextMessage.prekeyType,
          );
          aesKey ??= await crypto.decryptFileKey(
            senderId, encryptedFileKey, CiphertextMessage.whisperType,
          );
        }
        if (aesKey != null && key.isNotEmpty) {
          LocalStorage.cacheDecryptedMessage('filekey_$key', base64Encode(aesKey));
        }
      }

      if (aesKey == null) {
        debugPrint('[E2EE] Could not recover AES key for $key');
        return null;
      }

      // 2) Download encrypted bytes
      final response = await Dio().get<List<int>>(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) return null;
      final encryptedBytes = Uint8List.fromList(response.data!);

      // 3) Decrypt
      final decrypted = await crypto.decryptFile(encryptedBytes, aesKey);
      if (decrypted != null) {
        _bytesCache[key] = decrypted;
      }
      return decrypted;
    } catch (e) {
      debugPrint('[E2EE] Media decrypt error for $key: $e');
      return null;
    }
  }

  /// Decrypt and save to temp file. Returns file path.
  static Future<String?> getOrDecryptToFile({
    required String messageId,
    required String clientMessageId,
    required String fileUrl,
    required String senderId,
    required String? encryptedFileKey,
    required String? fileIv,
    required bool isMine,
    required String extension,
    String? groupId,
  }) async {
    final key = messageId.isNotEmpty ? messageId : clientMessageId;

    final cachedPath = _filePathCache[key] ?? _filePathCache[clientMessageId];
    if (cachedPath != null && File(cachedPath).existsSync()) return cachedPath;

    final bytes = await getOrDecrypt(
      messageId: messageId,
      clientMessageId: clientMessageId,
      fileUrl: fileUrl,
      senderId: senderId,
      encryptedFileKey: encryptedFileKey,
      fileIv: fileIv,
      isMine: isMine,
      groupId: groupId,
    );
    if (bytes == null) return null;

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/e2ee_$key.$extension';
      await File(filePath).writeAsBytes(bytes);
      _filePathCache[key] = filePath;
      return filePath;
    } catch (e) {
      debugPrint('[E2EE] Failed to write temp file: $e');
      return null;
    }
  }
}
