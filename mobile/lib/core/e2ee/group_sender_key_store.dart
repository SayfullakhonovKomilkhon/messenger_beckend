import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class PersistentSenderKeyStore implements SenderKeyStore {
  static const _storage = FlutterSecureStorage();
  static const _nsPrefix = 'signal_sender_key';
  static const _indexKey = '${_nsPrefix}_index';

  @override
  Future<void> storeSenderKey(
      SenderKeyName senderKeyName, SenderKeyRecord record) async {
    final key = _storageKey(senderKeyName);
    await _storage.write(key: key, value: base64Encode(record.serialize()));
    await _addToIndex(key);
    debugPrint('[E2EE-Group] Stored sender key: ${senderKeyName.serialize()}');
  }

  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    final key = _storageKey(senderKeyName);
    final data = await _storage.read(key: key);
    if (data == null) {
      return SenderKeyRecord();
    }
    return SenderKeyRecord.fromSerialized(
        Uint8List.fromList(base64Decode(data)));
  }

  Future<void> removeSenderKey(SenderKeyName senderKeyName) async {
    final key = _storageKey(senderKeyName);
    await _storage.delete(key: key);
    await _removeFromIndex(key);
  }

  Future<void> removeAllForGroup(String groupId) async {
    final allKeys = await _getIndex();
    final prefix = '${_nsPrefix}_${groupId}_';
    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        await _storage.delete(key: key);
      }
    }
    final remaining = allKeys.where((k) => !k.startsWith(prefix)).toList();
    await _storage.write(key: _indexKey, value: remaining.join(','));
    debugPrint('[E2EE-Group] Removed all sender keys for group $groupId');
  }

  static Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_nsPrefix)) {
        await _storage.delete(key: key);
      }
    }
    debugPrint('[E2EE-Group] Cleared all sender keys');
  }

  String _storageKey(SenderKeyName skn) =>
      '${_nsPrefix}_${skn.groupId}_${skn.sender.getName()}_${skn.sender.getDeviceId()}';

  Future<List<String>> _getIndex() async {
    final raw = await _storage.read(key: _indexKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  Future<void> _addToIndex(String key) async {
    final idx = await _getIndex();
    if (!idx.contains(key)) {
      idx.add(key);
      await _storage.write(key: _indexKey, value: idx.join(','));
    }
  }

  Future<void> _removeFromIndex(String key) async {
    final idx = await _getIndex();
    idx.remove(key);
    await _storage.write(key: _indexKey, value: idx.join(','));
  }
}
