# Active Context

## Current State
Этап 1 backend полностью реализован. Все модули созданы.

## Completed
- Инфраструктура монорепо (docker-compose, .env, .gitignore, README)
- Common layer (CacheService, GlobalExceptionHandler, JWT, Security)
- Auth module (register, login, refresh, logout + rate limiting)
- User module (search, FCM token)
- File module (R2 upload с Tika MIME detection)
- Chat module (conversations, messages, WebSocket STOMP)
- Call module (WebRTC signaling, history)
- Tests (AuthControllerTest, ChatServiceTest)

## Next Steps
- Тестирование через docker-compose up
- Этап 2: Flutter мобильное приложение (mobile/)
- Этап 2 документа: настройки, профиль, группы, боты

## Recently Completed
- **Запросы сообщений (Message Requests)** — при создании диалога инициатор получает ACTIVE, получатель — PENDING. Запросы отображаются в Настройки → Конфиденциальность → Запросы сообщений. Действия: Принять, Отклонить (с опцией «заблокировать»), Очистить все. Backend: V3 миграция (status в conversation_participants), ChatService + BlockService, endpoints GET/POST/DELETE /conversations/requests.

## To Revisit Later
- **Безопасность экрана (blockApp)** — блокировка приложения при возврате из фона (Touch ID / Face ID / пароль устройства). Реализовано: LocalStorage + LocalAuth, AppLockWrapper, блокировка через 5 сек в фоне. Нужно продумать и доработать (возможно: настраиваемый таймаут, улучшение UX, обработка edge cases).
