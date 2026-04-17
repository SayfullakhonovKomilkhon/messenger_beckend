# E2EE Production Readiness Plan

План подготовки E2EE-слоя мессенджера к публичному релизу на App Store / Google Play. Составлен после исправления критического бага с ротацией identity (reinstall/relogin) и включает долгосрочную стратегию устойчивости шифрования.

**Статус:** draft, ожидает старта работ
**Последнее обновление:** 2026-04-17
**Owner:** команда backend + mobile

---

## Содержание

- [Текущее состояние E2EE (baseline)](#текущее-состояние-e2ee-baseline)
- [Спринт 1 (неделя 1) — блокеры релиза](#спринт-1-неделя-1--блокеры-релиза)
- [Спринт 2 (неделя 2) — стабильность и главный UX-fix](#спринт-2-неделя-2--стабильность-и-главный-ux-fix)
- [Пост-релиз (v2 и далее)](#пост-релиз-v2-и-далее)
- [Порядок работ и зависимости](#порядок-работ-и-зависимости)
- [Метрики успеха](#метрики-успеха)

---

## Текущее состояние E2EE (baseline)

### Что уже работает
- Signal Protocol (X3DH + Double Ratchet) для 1:1 чатов через `libsignal_protocol_dart`
- Sender Keys Protocol для групп
- AES-256-GCM для медиа-файлов
- `FlutterSecureStorage` (Keychain / Keystore) для хранения приватных ключей
- Backend endpoints: `/keys/register`, `/keys/bundle/{userId}`, `/keys/identity/{userId}`, `/keys/count`, `/keys/prekeys`, `/keys/check/{userId}`
- Трёхуровневая защита от сбоев при ротации identity:
  1. Идемпотентный `registerKeys` (удаляет старые prekeys / signed prekeys / group sender-keys перед вставкой, `@Modifying(flushAutomatically)`)
  2. Sender-side proactive identity-check (`_verifyRemoteIdentityAndResetIfChanged`, кеш 10 мин)
  3. Receiver-side session-reset сигнал по WS (`/app/chat.session.reset`) с debounce 30 сек
- Self-heal при старте (`_ensureKeysOnServer` сверяет локальный identity с серверным)
- **E2EE для 1:1 WebRTC-звонков:**
  - Сигналинг (SDP offer/answer, ICE candidates) шифруется через Signal Protocol — backend не может сделать MITM и подменить DTLS fingerprint
  - Медиа-поток защищён DTLS-SRTP автоматически; TURN-сервер (`31.130.150.246:3478`) работает в relay-режиме и видит только зашифрованный трафик
  - UI-индикатор `_isE2eeActive` и `_showE2eeInfo` с safety number для голосовой верификации во время звонка

### Что сломается / выглядит плохо в продакшене
- Нет UI для верификации identity (safety number / QR) в чатах → невозможно отличить легитимный reinstall от MITM (в звонках safety number UI уже есть)
- Переустановка = безвозвратная потеря истории сообщений
- `/keys/identity/{userId}` без rate-limit → enumeration всех пользователей системы
- `signedPreKey` не ротируется (живёт вечно после регистрации) → нарушение Signal best practices
- `spring.jpa.open-in-view` enabled, `generated security password` в логах
- ~~JWT access `60s`~~ — реально 1 час (3600s), теперь снижено до **15 мин (900s)** + защита от параллельных refresh в `api_client.dart` (single-flight lock, рotation-safe)
- Нет системных сообщений «ключи изменились» — пользователь не понимает почему сообщения вдруг перестали читаться
- Нет observability: метрик decrypt failures, rate of session resets, healthcheck endpoint
- Один user = одно устройство (iCloud не синхронизирует FlutterSecureStorage между iPhone и iPad)
- **Групповые звонки не реализованы** — когда/если появятся, потребуют отдельный E2EE-механизм (SFrame / WebRTC Insertable Streams через SFU)

---

## Спринт 1 (неделя 1) — блокеры релиза

### Задача 1.1 — Быстрые хардeнинг-wins

**Приоритет:** P0
**Оценка:** 4 часа
**Зависимости:** нет
**Можно делать параллельно с 1.2**

#### Scope

1. Отключить `spring.jpa.open-in-view`
2. Убрать автогенерируемый security password
3. ~~Увеличить JWT access token TTL до 15 минут, refresh до 30 дней~~ — **сделано:** 900/2592000 в `application.yml` + `docker-compose.yml` + `.env`, client single-flight refresh lock в `api_client.dart`
4. Добавить `GET /api/v1/health` с проверкой db / redis / firebase
5. Добавить Docker healthcheck в `docker-compose.yml`
6. Вынести секреты из `docker-compose.yml` в `.env` + создать `.env.example`

#### Файлы

- `src/main/resources/application.yml`
- `src/main/java/com/messenger/common/security/SecurityConfig.java`
- `src/main/java/com/messenger/common/health/HealthController.java` (новый)
- `docker-compose.yml`
- `.env.example` (новый)
- `.gitignore` (проверить что `.env` в игноре)

#### Acceptance

- `docker compose logs backend` — нет warning про `open-in-view` и `Using generated security password`
- `curl http://vps:3000/api/v1/health` → `{"status":"UP","db":"UP","redis":"UP","firebase":"UP"}`
- `docker compose ps` показывает `healthy` статус для backend-контейнера
- Repo не содержит секретов: `git log -p | grep -iE 'password|secret|key' | grep -v example` — пусто

---

### Задача 1.2 — Rate limiting на E2EE endpoints

**Приоритет:** P0
**Оценка:** 4 часа
**Зависимости:** нет
**Можно делать параллельно с 1.1**

#### Scope

1. `RateLimitInterceptor` на базе Redis (`INCR` + `EXPIRE` атомарно через Lua-скрипт)
2. Аннотация `@RateLimit(requests=100, perMinute=1)` или путь-конфиг
3. Применить к:
   - `GET /keys/identity/{userId}` — 100 rpm
   - `GET /keys/bundle/{userId}` — 50 rpm
   - `GET /keys/check/{userId}` — 200 rpm
4. При превышении — 429 с заголовком `Retry-After`
5. Доп. guard на `getIdentity`: доступ только если между `authUser` и `target` есть запись в `conversation_participants` или `target` в контактах / unblocked

#### Файлы

- `src/main/java/com/messenger/common/security/RateLimitInterceptor.java` (новый)
- `src/main/java/com/messenger/common/security/RateLimit.java` (annotation, новый)
- `src/main/java/com/messenger/common/config/WebConfig.java` (регистрация interceptor)
- `src/main/java/com/messenger/e2ee/E2eeKeyController.java` (аннотации)
- `src/main/java/com/messenger/e2ee/E2eeKeyService.getIdentity` — добавить guard-проверку

#### Acceptance

- `for i in $(seq 1 200); do curl -s -o /dev/null -w "%{http_code}\n" http://vps/keys/identity/X; done | sort | uniq -c` → 100×`200`, 100×`429`
- Пользователь A не может получить identity пользователя B если у них нет общего чата: 403 `FORBIDDEN`
- Redis-ключи имеют корректный TTL: `redis-cli TTL ratelimit:user:X:identity:*` < 60

---

### Задача 1.3 — Safety number UI + identity-change warning

**Приоритет:** P0
**Оценка:** 2 дня
**Зависимости:** нет (mobile-only)

#### Scope

1. **Экран `SafetyNumberScreen`**
   - 60-значный fingerprint из `E2eeCryptoService.getSafetyNumber` (уже реализован) по 5 групп
   - QR-код с тем же fingerprint (`qr_flutter` package)
   - Сканер QR (`mobile_scanner` package)
   - При сканировании — если совпадает, пометить `identity_verified_{peerId} = fingerprint` в `LocalStorage`
   - Кнопка «Отметить как проверено» (для верификации голосом без камеры)
   - Кнопка «Сбросить верификацию»

2. **Identity change event stream в `E2eeCryptoService`**
   ```dart
   final _identityChangeController = StreamController<IdentityChangeEvent>.broadcast();
   Stream<IdentityChangeEvent> get onIdentityChange => _identityChangeController.stream;
   ```
   Событие: `{peerId, wasVerified, oldFingerprint, newFingerprint, detectedAt}`. Триггерится внутри `_verifyRemoteIdentityAndResetIfChanged` при обнаружении ротации.

3. **UI в `ConversationScreen`**
   - Иконка замка 🔒 / 🔓 в AppBar рядом с именем (зелёный для verified, жёлтый для known-but-unverified, красный для changed-after-verification)
   - Тап по иконке → `SafetyNumberScreen`
   - Подписка на `onIdentityChange`: если `wasVerified == true` — показать красный persistent-баннер «⚠ Ключ безопасности @name изменился. Возможно, собеседник переустановил приложение, либо это попытка взлома. Проверьте заново.» с кнопкой «Проверить»

#### Файлы

- `mobile/lib/features/settings/safety_number_screen.dart` (новый)
- `mobile/lib/features/conversation/conversation_screen.dart` (AppBar + баннер)
- `mobile/lib/core/e2ee/crypto_service.dart` (event stream)
- `mobile/lib/core/storage/local_storage.dart` (методы `markIdentityVerified`, `isIdentityVerified`, `getVerifiedFingerprint`)
- `mobile/pubspec.yaml` (+qr_flutter, +mobile_scanner)

#### Acceptance

- Тап на имя собеседника → экран с fingerprint + QR
- Отсканировал QR у собеседника, совпало → замок зелёный, в локалсторадже флаг verified
- Собеседник переустановил приложение → при следующем сообщении появляется красный баннер
- Тап «Проверить» открывает `SafetyNumberScreen` с уже новым fingerprint, который можно переотсканировать

---

### Задача 1.4 — Системные сообщения в чате

**Приоритет:** P0
**Оценка:** 1 день
**Зависимости:** желательно после 1.3 (один общий рефакторинг `ConversationScreen`)

#### Scope

1. **Backend**
   - `V12__system_message_types.sql`: расширить `messages.message_type` enum значениями `SYSTEM_IDENTITY_ROTATED`, `SYSTEM_SESSION_RESET`, `SYSTEM_DECRYPT_FAILED`
   - Метод `ChatService.postSystemMessage(conversationId, type, metadata)` — создаёт сообщение с `senderId = null`, `encrypted = false`, `text` — ключ для i18n на клиенте
   - Endpoint `POST /api/v1/conversations/{id}/system-message` (internal, только для клиентов этого диалога)

2. **Mobile**
   - В `MessageBubble` отдельный рендер для system-сообщений: центрированный серый текст в pill-контейнере
   - `l10n/app_ru.arb` / `app_en.arb`:
     - `systemIdentityRotated`: «🔐 Собеседник обновил ключи шифрования. Предыдущие сообщения недоступны.»
     - `systemDecryptFailed`: «⚠ Не удалось расшифровать часть сообщений. Попросите собеседника переслать их.»
     - `systemSessionReset`: «Сессия шифрования восстановлена.»
   - `E2eeCryptoService._verifyRemoteIdentityAndResetIfChanged`: после rebuild — вызов `postSystemMessage(SYSTEM_IDENTITY_ROTATED)`
   - После 3 подряд `Bad Mac!` за 60 сек — `postSystemMessage(SYSTEM_DECRYPT_FAILED)` (debounce на peer)

#### Файлы

- `src/main/resources/db/migration/V12__system_message_types.sql` (новая)
- `src/main/java/com/messenger/chat/ChatService.java`
- `src/main/java/com/messenger/chat/ChatController.java`
- `src/main/java/com/messenger/chat/entity/MessageEntity.java`
- `mobile/lib/features/conversation/widgets/message_bubble.dart`
- `mobile/lib/core/e2ee/crypto_service.dart`
- `mobile/lib/l10n/app_*.arb`

#### Acceptance

- Переустановка собеседника → в обеих историях через 1–2 сообщения появляется плашка `systemIdentityRotated`
- Три неудачные дешифровки подряд → плашка `systemDecryptFailed` (не более одного раза в минуту на peer)
- Системные сообщения не показываются как `unreadCount`

---

## Спринт 2 (неделя 2) — стабильность и главный UX-fix

### Задача 2.1 — Ротация signedPreKey

**Приоритет:** P1
**Оценка:** 1 день
**Зависимости:** 1.1

#### Scope

**Backend:**
- `POST /api/v1/keys/signed-prekey/rotate` с payload `{keyId, publicKey, signature}`
- `E2eeKeyService.rotateSignedPreKey(userId, request)`:
  - `signedPreKeyRepo.deleteAllByUserId(userId)` (уже `@Modifying(flushAutomatically)`)
  - Вставить новый
  - НЕ трогать identity и one-time pre-keys
- В `E2eeKeyController` аннотация `@RateLimit` (используем из 1.2)

**Mobile:**
- В `E2eeKeyManager`:
  ```dart
  static const Duration _signedPreKeyMaxAge = Duration(days: 30);

  Future<void> rotateSignedPreKeyIfNeeded() async {
    final storedAt = await _storage.read(key: 'signed_prekey_generated_at');
    if (storedAt != null &&
        DateTime.now().difference(DateTime.parse(storedAt)) < _signedPreKeyMaxAge) {
      return;
    }
    final newId = await _nextSignedPreKeyId();
    final newSpk = generateSignedPreKey(identityKeyPair, newId);
    await _store.storeSignedPreKey(newSpk.id, newSpk);
    await api.post('/keys/signed-prekey/rotate', data: {
      'keyId': newSpk.id,
      'publicKey': base64Encode(newSpk.getKeyPair().publicKey.serialize()),
      'signature': base64Encode(newSpk.signature),
    });
    await _storage.write(
      key: 'signed_prekey_generated_at',
      value: DateTime.now().toIso8601String(),
    );
  }
  ```
- Вызывать из `initialize()` после `replenishPreKeysIfNeeded`

#### Файлы

- `src/main/java/com/messenger/e2ee/E2eeKeyController.java`
- `src/main/java/com/messenger/e2ee/E2eeKeyService.java`
- `src/main/java/com/messenger/e2ee/dto/RotateSignedPreKeyRequest.java` (новый)
- `mobile/lib/core/e2ee/key_manager.dart`

#### Acceptance

- В БД `e2ee_signed_pre_keys.created_at` обновляется раз в 30 дней без изменения identity
- Существующие Signal-сессии продолжают работать (Double Ratchet не зависит от ротации signed pre-key для уже установленных сессий)
- Новые собеседники получают свежий `signedPreKey` в bundle

---

### Задача 2.2 — Метрики E2EE-ошибок

**Приоритет:** P1
**Оценка:** 1 день
**Зависимости:** 1.1

#### Scope

**Backend:**
- Подключить `io.micrometer:micrometer-registry-prometheus` (входит в spring-boot-actuator)
- `GET /api/v1/actuator/prometheus` защищён HTTP Basic: `METRICS_USER` / `METRICS_PASSWORD` из env
- Кастомные счётчики:
  - `e2ee_decrypt_failures_total{reason, platform}`
  - `e2ee_session_resets_total`
  - `e2ee_keys_rotated_total`
  - `e2ee_identity_mismatch_total` (в `_ensureKeysOnServer` срабатывании)
- Endpoint `POST /api/v1/e2ee/report` — `{messageId, errorType, errorDetail, platform}`
- Таблица `V13__e2ee_error_reports.sql` для агрегации (TTL 30 дней через pg_cron)

**Mobile:**
- `E2eeCryptoService.decryptMessage` при финальном провале вызывает `api.post('/e2ee/report', ...)` (fire-and-forget, не блокирует UI)
- Debounce 1 раз в 30 сек на peer

#### Файлы

- `src/main/java/com/messenger/e2ee/metrics/E2eeMetrics.java` (новый)
- `src/main/java/com/messenger/e2ee/ReportController.java` (новый)
- `src/main/resources/db/migration/V13__e2ee_error_reports.sql` (новая)
- `src/main/java/com/messenger/common/security/SecurityConfig.java` (Basic auth для `/actuator`)
- `build.gradle` (+ `io.micrometer:micrometer-registry-prometheus`)
- `mobile/lib/core/e2ee/crypto_service.dart`

#### Acceptance

- `curl -u metrics:pass http://vps/actuator/prometheus | grep e2ee_` → счётчики с ненулевыми значениями
- Искусственный decrypt-fail на mobile → за ≤5 сек `e2ee_decrypt_failures_total` инкрементится
- Таблица `e2ee_error_reports` растёт, но автоочистка через pg_cron работает (ряды старше 30 дней удаляются)

---

### Задача 2.3 — Encrypted backup identity keyPair под PIN (главный UX-fix)

**Приоритет:** P0 для релиза
**Оценка:** 3–4 дня
**Зависимости:** 1.2 (нужен rate-limit на brute-force попытки)

#### Концепция

Пользователь опционально задаёт 6-значный PIN. Identity keyPair + список trusted-identity peer-ов шифруется AES-256-GCM, ключ деривится из PIN через Argon2id. Зашифрованный blob лежит на сервере. При переустановке — ввод PIN → восстановление identity → собеседники не видят warning «ключи изменились», старые сообщения продолжают читаться.

**Сессии (Signal sessions) не бэкапим** — они рестартуют сами через proactive identity check (уже работает), но ключевой identity сохраняется и этого достаточно для preservation of safety number.

#### Scope

**Backend:**

1. Миграция `V14__e2ee_identity_backup.sql`:
   ```sql
   CREATE TABLE e2ee_identity_backups (
       user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
       ciphertext BYTEA NOT NULL,
       argon2_salt BYTEA NOT NULL,
       argon2_params VARCHAR(64) NOT NULL,  -- "m=65536,t=3,p=4,v=19"
       derived_key_hmac BYTEA NOT NULL,      -- HMAC-SHA256(derivedKey, "backup-verify")
       version INT NOT NULL DEFAULT 1,
       updated_at TIMESTAMP NOT NULL,
       failed_attempts INT NOT NULL DEFAULT 0,
       locked_until TIMESTAMP
   );
   ```

2. Endpoints (`/api/v1/e2ee/backup`):
   - `POST /` — `{ciphertext, salt, params, derivedKeyHmac}` — создать или заменить backup
   - `GET /meta` — вернуть `{salt, params, failedAttempts, lockedUntil, updatedAt}` (без ciphertext, чтобы offline-brute-force требовал доступа к БД)
   - `POST /verify` — `{derivedKeyHmac}`:
     - Если `locked_until > now()` → 423 LOCKED
     - Если совпало — вернуть `{ciphertext}`, сбросить `failed_attempts`
     - Если нет — `failed_attempts++`; при `>= 5` → `locked_until = now() + exponential(1h, 24h, 7d, ...)`
   - `DELETE /` — удалить backup (paranoid mode)

3. Rate limit: `/verify` — 10 rpm на IP, 20 в час на user_id

**Mobile:**

1. Добавить в `pubspec.yaml`:
   ```yaml
   dependencies:
     pointycastle: ^3.7.0  # Argon2id
     cryptography: ^2.7.0  # AES-GCM (уже есть)
   ```

2. `core/e2ee/identity_backup_service.dart` (новый):
   ```dart
   class IdentityBackupService {
     Future<void> createBackup(String pin) async {
       final salt = _secureRandom(32);
       final derivedKey = await _argon2id(pin, salt, m: 65536, t: 3, p: 4, length: 32);
       final identityBlob = jsonEncode({
         'version': 1,
         'identityKeyPair': base64Encode(store.identityKeyPair.serialize()),
         'registrationId': store.localRegistrationId,
         'trustedIdentities': await _collectTrustedIdentities(),
       });
       final ciphertext = await _aesGcmEncrypt(derivedKey, utf8.encode(identityBlob));
       final verifyHmac = await _hmacSha256(derivedKey, utf8.encode('backup-verify'));
       await api.post('/e2ee/backup', data: {
         'ciphertext': base64Encode(ciphertext),
         'salt': base64Encode(salt),
         'params': 'm=65536,t=3,p=4,v=19',
         'derivedKeyHmac': base64Encode(verifyHmac),
       });
     }

     Future<RestoreResult> restoreFromBackup(String pin) async {
       final meta = await api.get('/e2ee/backup/meta');
       if (meta.lockedUntil != null) return RestoreResult.locked(meta.lockedUntil);

       final derivedKey = await _argon2id(pin, meta.salt, m: meta.params.m, ...);
       final verifyHmac = await _hmacSha256(derivedKey, utf8.encode('backup-verify'));
       final res = await api.post('/e2ee/backup/verify', data: {
         'derivedKeyHmac': base64Encode(verifyHmac),
       });
       if (res.statusCode == 401) return RestoreResult.wrongPin(res.data['attemptsLeft']);

       final plaintext = await _aesGcmDecrypt(derivedKey, base64Decode(res.data['ciphertext']));
       final blob = jsonDecode(utf8.decode(plaintext));
       await _restoreStore(blob);
       await _reRegisterKeysOnServer();
       return RestoreResult.success();
     }
   }
   ```

3. UI-экраны:
   - `EnableBackupScreen` — explainer + ввод PIN + подтверждение PIN + кнопка «Включить восстановление»
   - `ChangeBackupPinScreen` — старый PIN + новый PIN + подтверждение
   - `RestoreBackupScreen` — показывается сразу после логина на чистом устройстве если `GET /backup/meta` возвращает существующий backup: «У вас есть резервная копия ключей шифрования. Восстановить старые чаты?»
   - Настройка в `SettingsScreen`: «Восстановление чатов через PIN» с toggle и «Сменить PIN» / «Удалить резервную копию»

4. Безопасность:
   - Запуск `_argon2id` в `compute()` (isolate) чтобы не блокировать UI ~1 сек
   - PIN нигде не логируется, не кешируется, обнуляется из памяти (`pin.fillCharsWithZero()` после derive)
   - На iOS: `FlutterSecureStorage` с `accessibility: first_unlock_this_device_only` для флага «backup включён»

#### Файлы

- `src/main/resources/db/migration/V14__e2ee_identity_backup.sql` (новая)
- `src/main/java/com/messenger/e2ee/backup/IdentityBackupController.java` (новый)
- `src/main/java/com/messenger/e2ee/backup/IdentityBackupService.java` (новый)
- `src/main/java/com/messenger/e2ee/backup/entity/IdentityBackupEntity.java` (новый)
- `src/main/java/com/messenger/e2ee/backup/dto/*.java` (новые)
- `mobile/lib/core/e2ee/identity_backup_service.dart` (новый)
- `mobile/lib/features/settings/enable_backup_screen.dart` (новый)
- `mobile/lib/features/settings/change_backup_pin_screen.dart` (новый)
- `mobile/lib/features/auth/restore_backup_screen.dart` (новый)
- `mobile/pubspec.yaml` (+pointycastle)

#### Acceptance

- Включил backup с PIN `123456` — в БД появился blob
- Удалил приложение, переустановил, залогинился
- Диалог «Восстановить зашифрованные чаты?» → ввёл `123456`
- Все старые диалоги открываются, сообщения расшифровываются
- У собеседников **НЕ** появляется warning о смене identity (safety number сохранился)
- 5 неверных PIN подряд → блокировка на 1 час, кнопка `Restore` disabled
- Запуск `argon2id` не замораживает UI (проверить Android на слабом устройстве)

---

## Пост-релиз (v2 и далее)

### Задача 3.1 — Group rekey lifecycle

**Приоритет:** P1
**Оценка:** 3–5 дней

- При `leaveGroup` / `kickMember`: помечаем `e2ee_group_sender_keys` удалённого участника как revoked
- WS-событие `/user/{memberId}/queue/group.rekey {groupId}` всем оставшимся → они ротируют свои sender-keys и рассылают distributions
- При добавлении нового участника: рассылка sender-key distribution от всех существующих членов
- Тест: удалённый пользователь не может расшифровать новые сообщения группы

### Задача 3.2 — Multi-device support

**Приоритет:** P2
**Оценка:** 2–3 недели

- Схема `user_devices (id, user_id, name, registration_id, identity_public_key, created_at, last_seen_at, platform, device_info)`
- Signal address: `(userId, deviceId)` вместо `(userId, 1)`
- Pairing через QR: главное устройство показывает QR с session-key и identity, второе сканирует → шифрованный канал для трансфера identity keyPair
- `/keys/bundle/{userId}` возвращает bundles для всех активных устройств
- Отправка шифрует N раз (fan-out по device-ам)
- UI «Активные устройства» в настройках: список, last seen, кнопка «Отключить устройство»
- Разлогин одного устройства не должен инвалидировать сессии на других

### Задача 3.3 — E2EE для групповых звонков (когда появятся)

**Приоритет:** P3 (функция не реализована сейчас)
**Оценка:** 1–2 недели **после** появления групповых звонков

> **Статус для 1:1 звонков:** УЖЕ РЕАЛИЗОВАНО в `call_screen.dart` — сигналинг
> (SDP, ICE) шифруется через Signal Protocol, медиа-поток защищён DTLS-SRTP,
> есть UI safety number. Модель безопасности эквивалентна Signal/WhatsApp 1:1.
> Дополнительных действий для 1:1 звонков не требуется.

Этот пункт становится актуальным **только** если будут добавлены групповые
звонки через SFU-сервер, потому что SFU расшифровывает медиа для переадресации
→ он должен быть в trust model. Решение:

- WebRTC Insertable Streams API на mobile (поверх существующего WebRTC стека)
- SFrame (RFC draft) или кастомный AES-GCM на media frames — key неизвестен SFU
- Обмен group media-key через Sender Keys Protocol (тот же механизм, что для групповых чатов)
- Ротация key при add/remove участника
- Fallback на нешифрованный SFU-режим для legacy-клиентов (с warning в UI)

**Альтернатива:** не добавлять групповые звонки вообще и остаться на 1:1 P2P,
где текущая защита достаточна.

### Задача 3.4 — Автотесты E2EE

**Приоритет:** P2
**Оценка:** 1 неделя

- Testcontainers (PostgreSQL + Redis) для backend integration-тестов
- `flutter integration_test/` с двумя эмуляторами
- Сценарии:
  - Базовая отправка 1:1
  - Reinstall одной стороны → новое сообщение расшифровано
  - Одновременная отправка с обеих сторон (out-of-order)
  - Группа из 3 человек, один leave → остальные общаются, покинувший не видит
  - PIN-backup: reinstall → restore → открытие старого чата
  - Бэкфилл неотправленных при reconnect WS

---

## Порядок работ и зависимости

```
Спринт 1:
┌── 1.1 (hardening, 4h) ───────────────────┐
│                                           ├──► 2.1 (spk rotation) ──┐
├── 1.2 (rate limit, 4h) ─────────────┬────┤                          │
│                                      │    ├──► 2.2 (metrics)────────┤
└── 1.3 (safety UI, 2d) ──► 1.4 (system msgs, 1d)                     │
                                       │                               │
                                       └──► 2.3 (PIN backup, 3-4d) ◄──┘
                                                      │
                                                ┌─────┴─────┐
                                                ▼           ▼
                                             РЕЛИЗ       v2 планирование
```

- **1.1 и 1.2** — параллельно, независимы
- **1.3 → 1.4** — последовательно, один общий рефакторинг UI
- **2.1 и 2.2** — параллельно, оба зависят только от 1.1
- **2.3** — отдельная крупная задача, но требует 1.2 (rate limit на `/verify`)
- Пост-релизные (3.x) — после сбора телеметрии из 2.2 для приоритизации

---

## Метрики успеха

Измеряем **через две недели после релиза** (по данным 2.2):

| Метрика | Baseline (сейчас) | Цель |
|---|---|---|
| `e2ee_decrypt_failures_total` / total messages | ? (нет данных) | < 0.5% |
| `e2ee_session_resets_total` / DAU | ? | < 5% |
| Пользователей с включённым PIN-backup | 0% | > 40% |
| User retention после reinstall (восстановили чаты) | 0% | > 80% (из тех, у кого есть backup) |
| 429 rate на `/keys/identity` | нет rate-limit | < 0.1% легитимных запросов |
| App Store rating (без «потерял все чаты») | — | > 4.5 |

---

## Риски и open questions

1. **Argon2id производительность на Android-low-end** — нужен профайлинг до финальных параметров (может пойдём на `m=32768, t=3` для low-end)
2. **Совместимость libsignal_protocol_dart версий** — если апнем pubspec, старые клиенты могут получить несовместимый protocol. План: lazy upgrade через version field в RegisterKeysRequest
3. **Миграция существующих пользователей** — как предложить им включить PIN backup? Push-уведомление через месяц после релиза? In-app banner?
4. **iOS App Store review** — E2EE-мессенджеры иногда застревают в review. Подготовить demo-аккаунт с sample-данными и документ «как работает шифрование» на случай вопросов

---

## Changelog

- 2026-04-17 — инициальная версия плана, составлена после багфикса identity rotation (commits `ea00d6c`, `b593768`)
