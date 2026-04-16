import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../network/api_client.dart';
import 'signal_store.dart';

/// Manages Signal Protocol key lifecycle: generation, upload, and replenishment.
class E2eeKeyManager {
  static const int _preKeyBatchSize = 100;
  static const int _preKeyReplenishThreshold = 20;

  static E2eeKeyManager? _instance;
  PersistentSignalProtocolStore? _store;

  E2eeKeyManager._();
  factory E2eeKeyManager() => _instance ??= E2eeKeyManager._();

  PersistentSignalProtocolStore? get store => _store;
  bool get isInitialized => _store != null;

  /// Initialize the key manager. Loads existing keys or generates new ones.
  Future<void> initialize() async {
    _store = await PersistentSignalProtocolStore.load();
    if (_store != null) {
      debugPrint('[E2EE] Loaded existing identity keys');
      await _ensureKeysOnServer();
      await replenishPreKeysIfNeeded();
      return;
    }

    debugPrint('[E2EE] No keys found, generating new identity...');
    await _generateAndRegisterKeys();
  }

  /// Verify keys exist on server; re-upload existing local keys if missing.
  Future<void> _ensureKeysOnServer() async {
    if (_store == null) return;

    bool keysExist = false;
    try {
      final res = await ApiClient().dio.get('/keys/count');
      final count = res.data['count'] as int? ?? 0;
      if (count > 0) {
        keysExist = true;
        debugPrint('[E2EE] Keys confirmed on server (pre-keys: $count)');
      }
    } catch (_) {}

    if (keysExist) return;

    debugPrint('[E2EE] Keys missing on server, clearing local state and regenerating...');
    await PersistentSignalProtocolStore.clearAll();
    _store = null;
    await _generateAndRegisterKeys();
  }

  /// Generate fresh identity + pre-keys and register them with the server.
  Future<void> _generateAndRegisterKeys() async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);

    _store = await PersistentSignalProtocolStore.create(identityKeyPair, registrationId);

    final signedPreKey = generateSignedPreKey(identityKeyPair, 0);
    await _store!.storeSignedPreKey(signedPreKey.id, signedPreKey);

    final preKeys = generatePreKeys(0, _preKeyBatchSize);
    for (final pk in preKeys) {
      await _store!.storePreKey(pk.id, pk);
    }

    final preKeyDataList = preKeys.map((pk) => {
      'keyId': pk.id,
      'publicKey': base64Encode(pk.getKeyPair().publicKey.serialize()),
    }).toList();

    try {
      await ApiClient().dio.post('/keys/register', data: {
        'registrationId': registrationId,
        'identityPublicKey': base64Encode(identityKeyPair.getPublicKey().serialize()),
        'signedPreKey': {
          'keyId': signedPreKey.id,
          'publicKey': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
          'signature': base64Encode(signedPreKey.signature),
        },
        'preKeys': preKeyDataList,
      });
      debugPrint('[E2EE] Keys registered on server: $registrationId');
    } catch (e) {
      debugPrint('[E2EE] Failed to register keys on server: $e');
    }
  }

  /// Check the server for remaining pre-keys and upload more if below threshold.
  Future<void> replenishPreKeysIfNeeded() async {
    if (_store == null) return;
    try {
      final res = await ApiClient().dio.get('/keys/count');
      final count = res.data['count'] as int? ?? 0;
      debugPrint('[E2EE] Server pre-key count: $count');

      if (count < _preKeyReplenishThreshold) {
        final nextId = count + 1;
        final newPreKeys = generatePreKeys(nextId, _preKeyBatchSize);
        for (final pk in newPreKeys) {
          await _store!.storePreKey(pk.id, pk);
        }

        final preKeyDataList = newPreKeys.map((pk) => {
          'keyId': pk.id,
          'publicKey': base64Encode(pk.getKeyPair().publicKey.serialize()),
        }).toList();

        await ApiClient().dio.post('/keys/prekeys', data: {
          'preKeys': preKeyDataList,
        });
        debugPrint('[E2EE] Replenished ${newPreKeys.length} pre-keys');
      }
    } catch (e) {
      debugPrint('[E2EE] Failed to replenish pre-keys: $e');
    }
  }

  /// Fetch a pre-key bundle for the given user from the server.
  Future<PreKeyBundle?> fetchPreKeyBundle(String userId) async {
    try {
      final res = await ApiClient().dio.get('/keys/bundle/$userId');
      final data = res.data as Map<String, dynamic>;

      final registrationId = data['registrationId'] as int;
      final identityKeyBytes = base64Decode(data['identityPublicKey'] as String);
      final identityKey = IdentityKey.fromBytes(Uint8List.fromList(identityKeyBytes), 0);

      final signedPreKeyId = data['signedPreKeyId'] as int;
      final signedPreKeyPublic = Curve.decodePoint(
        Uint8List.fromList(base64Decode(data['signedPreKeyPublic'] as String)), 0,
      );
      final signedPreKeySignature = Uint8List.fromList(
        base64Decode(data['signedPreKeySignature'] as String),
      );

      ECPublicKey? preKeyPublic;
      int preKeyId = 0;
      if (data['preKeyId'] != null && data['preKeyPublic'] != null) {
        preKeyId = data['preKeyId'] as int;
        preKeyPublic = Curve.decodePoint(
          Uint8List.fromList(base64Decode(data['preKeyPublic'] as String)), 0,
        );
      }

      return PreKeyBundle(
        registrationId,
        1, // deviceId
        preKeyId,
        preKeyPublic,
        signedPreKeyId,
        signedPreKeyPublic,
        signedPreKeySignature,
        identityKey,
      );
    } catch (e) {
      debugPrint('[E2EE] Failed to fetch pre-key bundle for $userId: $e');
      return null;
    }
  }

  /// Check if a remote user has E2EE keys registered.
  Future<bool> checkUserHasKeys(String userId) async {
    try {
      final res = await ApiClient().dio.get('/keys/check/$userId');
      return res.data == true;
    } catch (e) {
      debugPrint('[E2EE] Failed to check keys for $userId: $e');
      return false;
    }
  }

  /// Delete session for a specific user (useful when session is corrupted).
  Future<void> deleteSession(String userId) async {
    if (_store == null) return;
    final address = SignalProtocolAddress(userId, 1);
    await _store!.deleteSession(address);
    debugPrint('[E2EE] Session deleted for $userId');
  }

  /// Reset all E2EE state (useful on logout).
  Future<void> reset() async {
    await PersistentSignalProtocolStore.clearAll();
    _store = null;
    debugPrint('[E2EE] All keys cleared');
  }
}
