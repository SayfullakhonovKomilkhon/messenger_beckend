import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../network/api_client.dart';
import 'crypto_service.dart';
import 'group_sender_key_store.dart';
import 'key_manager.dart';

class GroupKeyManager {
  static GroupKeyManager? _instance;
  GroupKeyManager._();
  factory GroupKeyManager() => _instance ??= GroupKeyManager._();

  final _senderKeyStore = PersistentSenderKeyStore();
  final _keyManager = E2eeKeyManager();
  final _cryptoService = E2eeCryptoService();
  final _api = ApiClient();

  PersistentSenderKeyStore get senderKeyStore => _senderKeyStore;

  /// Initialize sender key session for current user in a group.
  /// Creates our own SenderKey if one doesn't exist yet.
  Future<SenderKeyDistributionMessageWrapper?> initGroupSession(
      String groupId, String myUserId) async {
    try {
      final senderKeyName = SenderKeyName(
        groupId,
        SignalProtocolAddress(myUserId, 1),
      );

      final builder = GroupSessionBuilder(_senderKeyStore);
      final skdm = await builder.create(senderKeyName);
      debugPrint('[E2EE-Group] Initialized sender key session for group $groupId');
      return skdm;
    } catch (e) {
      debugPrint('[E2EE-Group] Failed to init group session: $e');
      return null;
    }
  }

  /// Distribute our SenderKeyDistributionMessage to all group members.
  /// Each SKDM is encrypted via the existing 1:1 Signal session.
  Future<bool> distributeKeys(
      String groupId, String myUserId, List<String> memberIds) async {
    try {
      final skdm = await initGroupSession(groupId, myUserId);
      if (skdm == null) return false;

      final skdmBytes = base64Encode(skdm.serialize());
      final distributions = <Map<String, String>>[];

      for (final memberId in memberIds) {
        if (memberId == myUserId) continue;

        final encrypted = await _cryptoService.encryptMessage(memberId, skdmBytes);
        if (encrypted == null) {
          debugPrint('[E2EE-Group] Failed to encrypt SKDM for $memberId');
          continue;
        }

        distributions.add({
          'recipientId': memberId,
          'encryptedSkdm': '${encrypted.messageType}:${encrypted.ciphertextBase64}',
        });
      }

      if (distributions.isEmpty) {
        debugPrint('[E2EE-Group] No distributions to send');
        return true;
      }

      await _api.dio.post('/groups/sender-keys/distribute', data: {
        'groupId': groupId,
        'distributions': distributions,
      });

      debugPrint(
          '[E2EE-Group] Distributed sender keys to ${distributions.length} members in group $groupId');
      return true;
    } catch (e) {
      debugPrint('[E2EE-Group] Failed to distribute keys: $e');
      return false;
    }
  }

  /// Fetch and process pending SenderKeyDistributionMessages from the server.
  Future<void> processPendingKeys({String? groupId}) async {
    try {
      final queryParams = groupId != null ? '?groupId=$groupId' : '';
      final res = await _api.dio.get('/groups/sender-keys/pending$queryParams');
      final List pending = res.data is List ? res.data : [];

      if (pending.isEmpty) {
        debugPrint('[E2EE-Group] No pending sender keys');
        return;
      }

      for (final item in pending) {
        final gId = item['groupId'] as String;
        final senderId = item['senderId'] as String;
        final encryptedSkdm = item['encryptedSkdm'] as String;

        try {
          final separatorIdx = encryptedSkdm.indexOf(':');
          if (separatorIdx == -1) continue;

          final messageType = int.parse(encryptedSkdm.substring(0, separatorIdx));
          final ciphertext = encryptedSkdm.substring(separatorIdx + 1);

          final skdmBase64 = await _cryptoService.decryptMessage(
              senderId, ciphertext, messageType);
          if (skdmBase64 == null) {
            debugPrint('[E2EE-Group] Failed to decrypt SKDM from $senderId');
            continue;
          }

          final skdmBytes = base64Decode(skdmBase64);
          final skdm = SenderKeyDistributionMessageWrapper.fromSerialized(
              Uint8List.fromList(skdmBytes));

          final senderKeyName = SenderKeyName(
            gId,
            SignalProtocolAddress(senderId, 1),
          );

          final builder = GroupSessionBuilder(_senderKeyStore);
          await builder.process(senderKeyName, skdm);

          await _api.dio.post('/groups/sender-keys/consumed', data: {
            'groupId': gId,
            'senderId': senderId,
          });

          debugPrint('[E2EE-Group] Processed sender key from $senderId for group $gId');
        } catch (e) {
          debugPrint('[E2EE-Group] Error processing pending key from ${item['senderId']}: $e');
        }
      }
    } catch (e) {
      debugPrint('[E2EE-Group] Failed to fetch pending keys: $e');
    }
  }

  /// Rotate sender keys for a group (e.g., after a member is removed).
  /// Deletes old keys and redistributes new ones.
  Future<void> rotateKeys(
      String groupId, String myUserId, List<String> memberIds) async {
    try {
      await _senderKeyStore.removeAllForGroup(groupId);

      try {
        await _api.dio.delete('/groups/sender-keys/$groupId');
      } catch (_) {}

      await distributeKeys(groupId, myUserId, memberIds);
      debugPrint('[E2EE-Group] Rotated sender keys for group $groupId');
    } catch (e) {
      debugPrint('[E2EE-Group] Failed to rotate keys: $e');
    }
  }

  /// Clean up all sender keys for a group (e.g., when leaving).
  Future<void> cleanupGroup(String groupId) async {
    await _senderKeyStore.removeAllForGroup(groupId);
    try {
      await _api.dio.delete('/groups/sender-keys/$groupId');
    } catch (_) {}
    debugPrint('[E2EE-Group] Cleaned up group $groupId');
  }

  /// Check if we have a sender key session for a specific sender in a group.
  Future<bool> hasSenderKey(String groupId, String senderId) async {
    final skn = SenderKeyName(groupId, SignalProtocolAddress(senderId, 1));
    final record = await _senderKeyStore.loadSenderKey(skn);
    return !record.isEmpty;
  }
}
