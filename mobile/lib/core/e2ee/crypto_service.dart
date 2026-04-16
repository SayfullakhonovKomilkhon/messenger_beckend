import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'group_sender_key_store.dart';
import 'key_manager.dart';

/// Result of encrypting a message via Signal Protocol.
class EncryptedMessageResult {
  final String ciphertextBase64;
  final int messageType; // CiphertextMessage.prekeyType or CiphertextMessage.whisperType

  EncryptedMessageResult(this.ciphertextBase64, this.messageType);
}

/// Result of encrypting a file with AES-256-GCM.
class EncryptedFileResult {
  final Uint8List encryptedBytes;
  final Uint8List aesKey;
  final Uint8List iv;

  EncryptedFileResult(this.encryptedBytes, this.aesKey, this.iv);
}

/// High-level encryption service wrapping Signal Protocol + AES-GCM.
class E2eeCryptoService {
  static E2eeCryptoService? _instance;
  E2eeCryptoService._();
  factory E2eeCryptoService() => _instance ??= E2eeCryptoService._();

  final _keyManager = E2eeKeyManager();
  final Map<String, DateTime> _lastSessionRecoveryAttempt = {};

  /// Encrypt a plaintext message for a recipient.
  /// Establishes a session if one doesn't exist yet.
  Future<EncryptedMessageResult?> encryptMessage(String recipientId, String plaintext) async {
    final store = _keyManager.store;
    if (store == null) {
      debugPrint('[E2EE] Store not initialized');
      return null;
    }

    final address = SignalProtocolAddress(recipientId, 1);

    try {
      final hasSession = await store.containsSession(address);
      if (!hasSession) {
        await _establishSession(store, address, recipientId);
      }

      final cipher = SessionCipher(store, store, store, store, address);
      final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));

      return EncryptedMessageResult(
        base64Encode(ciphertext.serialize()),
        ciphertext.getType(),
      );
    } on UntrustedIdentityException {
      debugPrint('[E2EE] UntrustedIdentity for $recipientId during encrypt, resetting session...');
      try {
        await store.deleteSession(address);
        await _establishSession(store, address, recipientId);

        final cipher = SessionCipher(store, store, store, store, address);
        final ciphertext = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
        return EncryptedMessageResult(
          base64Encode(ciphertext.serialize()),
          ciphertext.getType(),
        );
      } catch (retryErr) {
        debugPrint('[E2EE] Retry encrypt failed for $recipientId: $retryErr');
        return null;
      }
    } catch (e) {
      debugPrint('[E2EE] Encryption failed for $recipientId: $e');
      return null;
    }
  }

  Future<void> _establishSession(
    InMemorySignalProtocolStore store,
    SignalProtocolAddress address,
    String recipientId,
    {bool allowIdentityOverride = false}
  ) async {
    final bundle = await _keyManager.fetchPreKeyBundle(recipientId);
    if (bundle == null) {
      throw Exception('No pre-key bundle for $recipientId');
    }
    final sessionBuilder = SessionBuilder(store, store, store, store, address);
    try {
      await sessionBuilder.processPreKeyBundle(bundle);
    } on UntrustedIdentityException {
      if (!allowIdentityOverride) rethrow;
      // Recovery mode: remote identity changed, trust the current bundle identity
      // and rebuild the session to avoid permanent undecryptable state.
      await store.saveIdentity(address, bundle.getIdentityKey());
      await sessionBuilder.processPreKeyBundle(bundle);
    }
    debugPrint('[E2EE] Session established with $recipientId');
  }

  /// Decrypt an incoming ciphertext from a sender.
  Future<String?> decryptMessage(String senderId, String ciphertextBase64, int messageType) async {
    final store = _keyManager.store;
    if (store == null) {
      debugPrint('[E2EE] Store not initialized');
      return null;
    }

    try {
      final address = SignalProtocolAddress(senderId, 1);
      final ciphertextBytes = Uint8List.fromList(base64Decode(ciphertextBase64));

      return await _attemptDecrypt(store, address, ciphertextBytes, messageType);
    } on UntrustedIdentityException catch (e) {
      debugPrint('[E2EE] UntrustedIdentity from $senderId, updating trust and retrying...');
      try {
        final address = SignalProtocolAddress(senderId, 1);
        if (e.key != null) {
          await store.saveIdentity(address, e.key);
        }
        final ciphertextBytes = Uint8List.fromList(base64Decode(ciphertextBase64));
        return await _attemptDecrypt(store, address, ciphertextBytes, messageType);
      } catch (retryErr) {
        debugPrint('[E2EE] Retry decryption failed from $senderId: $retryErr');
        return null;
      }
    } catch (e) {
      if (_isRecoverableSessionError(e) &&
          await _tryRecoverSession(store, senderId)) {
        try {
          final address = SignalProtocolAddress(senderId, 1);
          final ciphertextBytes = Uint8List.fromList(base64Decode(ciphertextBase64));

          // Retry with requested message type first
          final retried = await _attemptDecrypt(
              store, address, ciphertextBytes, messageType);
          debugPrint('[E2EE] Decryption recovered for $senderId');
          return retried;
        } catch (_) {
          // Some peers may send different envelope type, try alternate parser once.
          try {
            final address = SignalProtocolAddress(senderId, 1);
            final ciphertextBytes = Uint8List.fromList(base64Decode(ciphertextBase64));
            final alternateType = messageType == CiphertextMessage.prekeyType
                ? CiphertextMessage.whisperType
                : CiphertextMessage.prekeyType;
            final retriedAlt = await _attemptDecrypt(
                store, address, ciphertextBytes, alternateType);
            debugPrint('[E2EE] Decryption recovered for $senderId (alt type)');
            return retriedAlt;
          } catch (_) {}
        }
      }
      debugPrint('[E2EE] Decryption failed from $senderId: $e');
      return null;
    }
  }

  bool _isRecoverableSessionError(Object error) {
    final s = error.toString();
    return s.contains('NoSessionException') ||
        s.contains('Bad Mac') ||
        s.contains('No valid sessions') ||
        s.contains('InvalidProtocolBufferException') ||
        s.contains('invalid tag');
  }

  Future<bool> _tryRecoverSession(
    InMemorySignalProtocolStore store,
    String senderId,
  ) async {
    final now = DateTime.now();
    final lastAttempt = _lastSessionRecoveryAttempt[senderId];
    if (lastAttempt != null &&
        now.difference(lastAttempt).inSeconds < 10) {
      return false;
    }
    _lastSessionRecoveryAttempt[senderId] = now;

    try {
      final address = SignalProtocolAddress(senderId, 1);
      await store.deleteSession(address);
      await _establishSession(
        store,
        address,
        senderId,
        allowIdentityOverride: true,
      );
      debugPrint('[E2EE] Session recovered with $senderId');
      return true;
    } catch (e) {
      debugPrint('[E2EE] Session recovery failed with $senderId: $e');
      return false;
    }
  }

  Future<String> _attemptDecrypt(
    InMemorySignalProtocolStore store,
    SignalProtocolAddress address,
    Uint8List ciphertextBytes,
    int messageType,
  ) async {
    final cipher = SessionCipher(store, store, store, store, address);

    Uint8List plaintext;
    if (messageType == CiphertextMessage.prekeyType) {
      final preKeyMessage = PreKeySignalMessage(ciphertextBytes);
      plaintext = await cipher.decrypt(preKeyMessage);
    } else {
      final signalMessage = SignalMessage.fromSerialized(ciphertextBytes);
      plaintext = await cipher.decryptFromSignal(signalMessage);
    }

    return utf8.decode(plaintext);
  }

  /// Encrypt file bytes with AES-256-GCM. Returns encrypted bytes + random key + IV.
  Future<EncryptedFileResult> encryptFile(Uint8List fileBytes) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    final nonce = algorithm.newNonce();

    final secretBox = await algorithm.encrypt(
      fileBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final encryptedBytes = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    final keyBytes = await secretKey.extractBytes();

    return EncryptedFileResult(
      encryptedBytes,
      Uint8List.fromList(keyBytes),
      Uint8List.fromList(nonce),
    );
  }

  /// Decrypt file bytes with AES-256-GCM using the provided key.
  Future<Uint8List?> decryptFile(Uint8List encryptedBytes, Uint8List aesKey) async {
    try {
      final algorithm = crypto.AesGcm.with256bits();

      final nonceLength = 12;
      final macLength = 16;

      if (encryptedBytes.length < nonceLength + macLength) return null;

      final nonce = encryptedBytes.sublist(0, nonceLength);
      final ciphertext = encryptedBytes.sublist(nonceLength, encryptedBytes.length - macLength);
      final mac = encryptedBytes.sublist(encryptedBytes.length - macLength);

      final secretKey = await algorithm.newSecretKeyFromBytes(aesKey);

      final secretBox = crypto.SecretBox(
        ciphertext,
        nonce: nonce,
        mac: crypto.Mac(mac),
      );

      final plaintext = await algorithm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(plaintext);
    } catch (e) {
      debugPrint('[E2EE] File decryption failed: $e');
      return null;
    }
  }

  /// Encrypt an AES file key using Signal session cipher (for inclusion in the message).
  Future<String?> encryptFileKey(String recipientId, Uint8List aesKey) async {
    final result = await encryptMessage(recipientId, base64Encode(aesKey));
    return result?.ciphertextBase64;
  }

  /// Decrypt an AES file key received in a message.
  Future<Uint8List?> decryptFileKey(String senderId, String encryptedKeyBase64, int messageType) async {
    final keyStr = await decryptMessage(senderId, encryptedKeyBase64, messageType);
    if (keyStr == null) return null;
    return Uint8List.fromList(base64Decode(keyStr));
  }

  /// Get the safety number (fingerprint) for verifying identity with a contact.
  Future<String?> getSafetyNumber(String localUserId, String remoteUserId) async {
    final store = _keyManager.store;
    if (store == null) return null;

    try {
      final localIdentity = await store.getIdentityKeyPair();
      final remoteAddress = SignalProtocolAddress(remoteUserId, 1);
      final remoteIdentity = await store.getIdentity(remoteAddress);
      if (remoteIdentity == null) return null;

      final generator = NumericFingerprintGenerator(5200);
      final fingerprint = generator.createFor(
        0,
        Uint8List.fromList(utf8.encode(localUserId)),
        localIdentity.getPublicKey(),
        Uint8List.fromList(utf8.encode(remoteUserId)),
        remoteIdentity,
      );

      return fingerprint.displayableFingerprint.getDisplayText();
    } catch (e) {
      debugPrint('[E2EE] Failed to generate safety number: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Group E2EE (Sender Keys Protocol)
  // ─────────────────────────────────────────────

  final _senderKeyStore = PersistentSenderKeyStore();

  /// Encrypt a plaintext message for a group using GroupCipher.
  Future<Uint8List?> encryptGroupMessage(
      String groupId, String myUserId, String plaintext) async {
    try {
      final senderKeyName = SenderKeyName(
        groupId,
        SignalProtocolAddress(myUserId, 1),
      );
      final cipher = GroupCipher(_senderKeyStore, senderKeyName);
      final encrypted = await cipher.encrypt(
          Uint8List.fromList(utf8.encode(plaintext)));
      debugPrint('[E2EE-Group] Encrypted message for group $groupId');
      return encrypted;
    } catch (e) {
      debugPrint('[E2EE-Group] Encrypt failed: $e');
      return null;
    }
  }

  /// Decrypt a group message from a specific sender.
  Future<String?> decryptGroupMessage(
      String groupId, String senderId, Uint8List ciphertext) async {
    try {
      final senderKeyName = SenderKeyName(
        groupId,
        SignalProtocolAddress(senderId, 1),
      );
      final cipher = GroupCipher(_senderKeyStore, senderKeyName);
      final plaintext = await cipher.decrypt(ciphertext);
      return utf8.decode(plaintext);
    } catch (e) {
      debugPrint('[E2EE-Group] Decrypt failed from $senderId in $groupId: $e');
      return null;
    }
  }

  /// Encrypt an AES file key using GroupCipher for a group.
  Future<String?> encryptGroupFileKey(
      String groupId, String myUserId, Uint8List aesKey) async {
    final encrypted =
        await encryptGroupMessage(groupId, myUserId, base64Encode(aesKey));
    if (encrypted == null) return null;
    return base64Encode(encrypted);
  }

  /// Decrypt an AES file key received in a group message.
  Future<Uint8List?> decryptGroupFileKey(
      String groupId, String senderId, String encryptedKeyBase64) async {
    final ciphertext = base64Decode(encryptedKeyBase64);
    final keyStr = await decryptGroupMessage(
        groupId, senderId, Uint8List.fromList(ciphertext));
    if (keyStr == null) return null;
    return Uint8List.fromList(base64Decode(keyStr));
  }
}
