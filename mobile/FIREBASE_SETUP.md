# Подключение Firebase для push-уведомлений

Чтобы push-уведомления работали, нужно настроить Firebase в трёх местах: **Firebase Console**, **мобильное приложение** и **бекенд (Railway)**.

---

## Шаг 1: Создать проект в Firebase Console

1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Нажмите **«Создать проект»** (или **Add project**)
3. Введите название (например, `messenger`) и следуйте шагам
4. Включите Google Analytics по желанию (можно отключить)

---

## Шаг 2: Добавить Android-приложение

1. В проекте Firebase нажмите **«Добавить приложение»** → иконка Android
2. **Package name:** `com.messenger.messenger` (должен совпадать с `android/app/build.gradle.kts`)
3. **App nickname** и **Debug signing certificate SHA-1** — можно пропустить
4. Нажмите **«Зарегистрировать приложение»**
5. Скачайте **`google-services.json`**
6. Поместите файл в `messenger/mobile/android/app/google-services.json` (замените placeholder)

---

## Шаг 3: Добавить iOS-приложение (если нужен iOS)

1. В том же проекте нажмите **«Добавить приложение»** → иконка iOS
2. **Bundle ID:** `com.messenger.messenger` (или ваш bundle ID из Xcode)
3. Скачайте **`GoogleService-Info.plist`**
4. Добавьте файл в Xcode: `ios/Runner/` (перетащите в проект и отметьте «Copy items if needed»)

---

## Шаг 4: Включить Cloud Messaging

1. В Firebase Console: **Build** → **Cloud Messaging**
2. Cloud Messaging включён по умолчанию для новых проектов
3. При необходимости включите **Cloud Messaging API** в [Google Cloud Console](https://console.cloud.google.com/apis/library/fcm.googleapis.com) для вашего проекта

---

## Шаг 5: Создать сервисный ключ для бекенда

1. В Firebase Console: **Project Settings** (шестерёнка) → вкладка **Service accounts**
2. Нажмите **«Generate new private key»** → **«Generate key»**
3. Скачается JSON-файл с ключом (храните его в безопасности)

Откройте этот JSON и найдите:
- `project_id` → **FCM_PROJECT_ID**
- `client_email` → **FCM_CLIENT_EMAIL**
- `client_id` → **FCM_CLIENT_ID** (число в кавычках)
- `private_key_id` → **FCM_PRIVATE_KEY_ID**
- `private_key` → **FCM_PRIVATE_KEY** (вся строка, включая `-----BEGIN PRIVATE KEY-----` и `-----END PRIVATE KEY-----`)

---

## Шаг 6: Настроить переменные в Railway

1. Откройте ваш проект в [Railway](https://railway.app)
2. Выберите **backend-сервис**
3. Вкладка **Variables** → **Add Variable** (или **Raw Editor**)

### Вариант A (рекомендуется): один JSON

Если возникает ошибка `Invalid PKCS#8 data`, используйте **один** ключ:

| Переменная | Значение |
|------------|----------|
| `FCM_SERVICE_ACCOUNT_JSON` | **Весь** содержимое скачанного JSON-файла. Откройте файл, скопируйте всё (Ctrl+A, Ctrl+C), вставьте в Railway. Можно в одну строку — уберите переносы между `{` и `}`. |

### Вариант B: отдельные переменные

| Переменная       | Значение                                                                 |
|------------------|---------------------------------------------------------------------------|
| `FCM_PROJECT_ID` | `project_id` из JSON                                                     |
| `FCM_CLIENT_EMAIL` | `client_email` из JSON                                                |
| `FCM_CLIENT_ID` | `client_id` из JSON                                                      |
| `FCM_PRIVATE_KEY_ID` | `private_key_id` из JSON                                              |
| `FCM_PRIVATE_KEY` | Вся строка `private_key` с `\n` для переносов. Пример: `"-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"` |

4. Сохраните переменные — Railway перезапустит сервис

---

## Проверка

1. **Мобильное приложение:** запустите приложение, войдите в аккаунт — FCM-токен должен зарегистрироваться на бекенде (см. логи `[FCM] Токен зарегистрирован`)
2. **Бекенд:** в логах Railway должно быть `Firebase initialized for project: your-project-id`
3. **Тест push:** отправьте сообщение в чат с другого аккаунта — должно прийти уведомление

---

## Отладка: push не приходят

### 1. Логи Railway (backend)

После отправки сообщения откройте логи Railway и найдите строки `[FCM]`:

| Сообщение в логах | Значение |
|-------------------|----------|
| `Firebase initialized for project: ...` | Firebase настроен |
| `FCM token updated for user: ...` | Токен получен с устройства |
| `[FCM] Push sent to user ...` | Push отправлен успешно |
| `[FCM] Push skipped: Firebase not configured` | Не заданы `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` |
| `[FCM] Push skipped for user ...: no FCM token` | У получателя нет токена — **залогиньтесь на Android заново** |
| `[FCM] Failed to send push ...` | Ошибка Firebase (проверьте ключ, project_id) |

### 2. Логи Flutter (мобильное приложение)

При запуске и входе в аккаунт смотрите консоль:

| Сообщение | Значение |
|-----------|----------|
| `[FCM] Firebase service инициализирован` | Firebase работает |
| `[FCM] Разрешение: authorized` | Разрешение на уведомления выдано |
| `[FCM] Токен: ...` | Токен получен |
| `[FCM] Токен зарегистрирован на бекенде` | Токен отправлен на сервер |
| `[FCM] Ошибка регистрации токена` | Проверьте `apiBaseUrl` в constants.dart — должен указывать на Railway |

### 3. Чек-лист

- [ ] На **устройстве-получателе (Android)** пользователь залогинен и видит `[FCM] Токен зарегистрирован`
- [ ] В Railway заданы `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`
- [ ] В логах Railway при старте есть `Firebase initialized for project: ...`
- [ ] Чат не в режиме «Без звука»
- [ ] На Android в настройках приложения разрешены уведомления

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| «Firebase недоступен» в приложении | Замените placeholder `google-services.json` на файл из Firebase Console |
| Push не приходят | Проверьте `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` в Railway |
| Ошибка «Invalid private key» | Убедитесь, что `FCM_PRIVATE_KEY` содержит `\n` для переносов строк |
| iOS: уведомления не работают | Добавьте `GoogleService-Info.plist`, включите Push Notifications в Xcode (Signing & Capabilities) |
