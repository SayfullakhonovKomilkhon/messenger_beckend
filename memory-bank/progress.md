# Progress

## What Works
- [x] Monorepo structure (messenger/, backend/, mobile/)
- [x] Docker Compose (postgres, redis, coturn, backend)
- [x] Flyway migration V1__init.sql (6 tables, 8 indexes)
- [x] JWT auth (access + refresh tokens, HS256, blacklist)
- [x] Rate limiting (Bucket4j, 5 req/min per IP)
- [x] CORS configuration for mobile clients
- [x] WebSocket STOMP endpoint /ws with JWT auth
- [x] Chat: conversations CRUD, messages with idempotency
- [x] Message Requests: PENDING/ACTIVE status, accept/decline, block on decline
- [x] Call: WebRTC signaling (init, accept, reject, end, SDP, ICE)
- [x] File upload to Cloudflare R2 with MIME validation
- [x] User search by name/username
- [x] FCM token update endpoint

## What's Left (Этап 2)
- [ ] Flutter mobile app
- [ ] Settings & profile management
- [ ] Group chats
- [ ] Bots

## Known Considerations
- Tests require running PostgreSQL and Redis (integration tests)
- R2 credentials needed for file upload functionality
- FCM push sending logic not implemented (only token storage)
