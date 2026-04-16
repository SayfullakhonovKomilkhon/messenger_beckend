# System Patterns

## Architecture
Строго многослойная: Controller → Service → Repository

## Packages
- `common/exception` — GlobalExceptionHandler, AppException, ErrorResponse
- `common/security` — JwtService, JwtFilter, SecurityConfig, WebSocketConfig
- `common/cache` — CacheService (interface), RedisCacheService
- `auth` — регистрация, логин, refresh, logout
- `user` — поиск, FCM токен
- `chat` — диалоги, сообщения, WebSocket STOMP
- `call` — WebRTC signaling, история звонков
- `file` — загрузка в Cloudflare R2

## Key Patterns
1. **DI через конструктор** (не @Autowired на поле)
2. **DTO отделены от Entity** — конвертация только в Service
3. **CacheService абстракция** — единственная точка доступа к Redis
4. **Idempotency** — clientMessageId с UNIQUE constraint
5. **Cursor-based пагинация** для сообщений
6. **Единый формат ошибок** через @ControllerAdvice
7. **Rate limiting** — 5 req/min на IP для auth endpoints
8. **JWT blacklist** в Redis с TTL

## WebSocket Destinations
- Chat: /app/chat.send, /app/chat.read, /app/chat.typing
- Call: /app/call.init, /app/call.accept, /app/call.reject, /app/call.end
- Call SDP/ICE: /app/call.sdpOffer, /app/call.sdpAnswer, /app/call.ice
- User queues: /user/{userId}/queue/messages, /queue/status, /queue/typing, /queue/call
