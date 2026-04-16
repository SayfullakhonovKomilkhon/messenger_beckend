import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// Persistent implementation of Signal Protocol stores backed by FlutterSecureStorage.
/// Keys are namespaced to avoid collision with other stored data.
class PersistentSignalProtocolStore extends InMemorySignalProtocolStore {
  static const _storage = FlutterSecureStorage();

  static const _nsIdentity = 'signal_identity';
  static const _nsSession = 'signal_session';
  static const _nsPreKey = 'signal_prekey';
  static const _nsSignedPreKey = 'signal_signed_prekey';
  static const _nsRegistrationId = 'signal_registration_id';
  static const _nsIdentityKeyPair = 'signal_identity_key_pair';

  PersistentSignalProtocolStore._(
    IdentityKeyPair identityKeyPair,
    int registrationId,
  ) : super(identityKeyPair, registrationId);

  /// Load or create the store. Returns null if no keys exist yet.
  static Future<PersistentSignalProtocolStore?> load() async {
    final ikpStr = await _storage.read(key: _nsIdentityKeyPair);
    final regStr = await _storage.read(key: _nsRegistrationId);
    if (ikpStr == null || regStr == null) return null;

    final ikpBytes = base64Decode(ikpStr);
    final identityKeyPair = IdentityKeyPair.fromSerialized(Uint8List.fromList(ikpBytes));
    final registrationId = int.parse(regStr);

    final store = PersistentSignalProtocolStore._(identityKeyPair, registrationId);
    await store._loadSessions();
    await store._loadPreKeys();
    await store._loadSignedPreKeys();
    await store._loadTrustedIdentities();
    return store;
  }

  /// Create a new store with freshly generated keys.
  static Future<PersistentSignalProtocolStore> create(
    IdentityKeyPair identityKeyPair,
    int registrationId,
  ) async {
    await _storage.write(
      key: _nsIdentityKeyPair,
      value: base64Encode(identityKeyPair.serialize()),
    );
    await _storage.write(key: _nsRegistrationId, value: registrationId.toString());

    return PersistentSignalProtocolStore._(identityKeyPair, registrationId);
  }

  // --- Session persistence ---

  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async {
    await super.storeSession(address, record);
    await _persistSession(address, record);
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    await super.deleteSession(address);
    await _storage.delete(key: _sessionKey(address));
    await _removeFromIndex(_nsSession, _sessionKey(address));
  }

  // --- PreKey persistence ---

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await super.storePreKey(preKeyId, record);
    await _persistPreKey(preKeyId, record);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await super.removePreKey(preKeyId);
    final key = '${_nsPreKey}_$preKeyId';
    await _storage.delete(key: key);
    await _removeFromIndex(_nsPreKey, key);
  }

  // --- SignedPreKey persistence ---

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    await super.storeSignedPreKey(signedPreKeyId, record);
    await _persistSignedPreKey(signedPreKeyId, record);
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await super.removeSignedPreKey(signedPreKeyId);
    final key = '${_nsSignedPreKey}_$signedPreKeyId';
    await _storage.delete(key: key);
    await _removeFromIndex(_nsSignedPreKey, key);
  }

  // --- Identity persistence ---

  @override
  Future<bool> saveIdentity(SignalProtocolAddress address, IdentityKey? identityKey) async {
    final result = await super.saveIdentity(address, identityKey);
    if (identityKey != null) {
      final key = '${_nsIdentity}_${address.getName()}';
      await _storage.write(key: key, value: base64Encode(identityKey.serialize()));
      await _addToIndex(_nsIdentity, key);
    }
    return result;
  }

  // --- Persistence helpers ---

  Future<void> _persistSession(SignalProtocolAddress address, SessionRecord record) async {
    final key = _sessionKey(address);
    await _storage.write(key: key, value: base64Encode(record.serialize()));
    await _addToIndex(_nsSession, key);
  }

  Future<void> _persistPreKey(int preKeyId, PreKeyRecord record) async {
    final key = '${_nsPreKey}_$preKeyId';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
    await _addToIndex(_nsPreKey, key);
  }

  Future<void> _persistSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    final key = '${_nsSignedPreKey}_$signedPreKeyId';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
    await _addToIndex(_nsSignedPreKey, key);
  }

  String _sessionKey(SignalProtocolAddress address) =>
      '${_nsSession}_${address.getName()}_${address.getDeviceId()}';

  // --- Loading from storage ---

  Future<void> _loadSessions() async {
    final keys = await _getIndex(_nsSession);
    for (final key in keys) {
      final data = await _storage.read(key: key);
      if (data == null) continue;
      final parts = key.replaceFirst('${_nsSession}_', '').split('_');
      if (parts.length < 2) continue;
      final deviceId = int.tryParse(parts.last) ?? 1;
      final name = parts.sublist(0, parts.length - 1).join('_');
      final address = SignalProtocolAddress(name, deviceId);
      final record = SessionRecord.fromSerialized(Uint8List.fromList(base64Decode(data)));
      await super.storeSession(address, record);
    }
  }

  Future<void> _loadPreKeys() async {
    final keys = await _getIndex(_nsPreKey);
    for (final key in keys) {
      final data = await _storage.read(key: key);
      if (data == null) continue;
      final idStr = key.replaceFirst('${_nsPreKey}_', '');
      final id = int.tryParse(idStr);
      if (id == null) continue;
      final record = PreKeyRecord.fromBuffer(Uint8List.fromList(base64Decode(data)));
      await super.storePreKey(id, record);
    }
  }

  Future<void> _loadSignedPreKeys() async {
    final keys = await _getIndex(_nsSignedPreKey);
    for (final key in keys) {
      final data = await _storage.read(key: key);
      if (data == null) continue;
      final idStr = key.replaceFirst('${_nsSignedPreKey}_', '');
      final id = int.tryParse(idStr);
      if (id == null) continue;
      final record = SignedPreKeyRecord.fromSerialized(Uint8List.fromList(base64Decode(data)));
      await super.storeSignedPreKey(id, record);
    }
  }

  Future<void> _loadTrustedIdentities() async {
    final keys = await _getIndex(_nsIdentity);
    for (final key in keys) {
      final data = await _storage.read(key: key);
      if (data == null) continue;
      final name = key.replaceFirst('${_nsIdentity}_', '');
      final address = SignalProtocolAddress(name, 1);
      final identityKey = IdentityKey.fromBytes(Uint8List.fromList(base64Decode(data)), 0);
      await super.saveIdentity(address, identityKey);
    }
  }

  // --- Index management (tracks which keys exist per namespace) ---

  Future<List<String>> _getIndex(String ns) async {
    final raw = await _storage.read(key: '${ns}_index');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  Future<void> _addToIndex(String ns, String key) async {
    final idx = await _getIndex(ns);
    if (!idx.contains(key)) {
      idx.add(key);
      await _storage.write(key: '${ns}_index', value: idx.join(','));
    }
  }

  Future<void> _removeFromIndex(String ns, String key) async {
    final idx = await _getIndex(ns);
    idx.remove(key);
    await _storage.write(key: '${ns}_index', value: idx.join(','));
  }

  /// Wipe all E2EE data from secure storage.
  static Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith('signal_')) {
        await _storage.delete(key: key);
      }
    }
  }
}
