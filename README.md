# Demos Messenger — Backend

<p align="center">
  <b>REST API + WebSocket server for the Demos Messenger platform</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Java-17-ED8B00?logo=openjdk" alt="Java 17"/>
  <img src="https://img.shields.io/badge/Spring%20Boot-3.2.5-6DB33F?logo=spring-boot" alt="Spring Boot"/>
  <img src="https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/Redis-7-DC382D?logo=redis" alt="Redis"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker" alt="Docker"/>
</p>

---

## Overview

Java backend powering the Demos Messenger mobile app. Provides REST API, real-time messaging via WebSocket (STOMP), voice/video call signaling (WebRTC), end-to-end encryption key exchange (Signal Protocol), bot platform, and push notifications (FCM).

## Features

| Module | Description |
|--------|-------------|
| **Auth** | Register, login, JWT access + refresh tokens, logout |
| **Chat** | 1-on-1 and group conversations, send/edit/delete/forward/pin messages, read receipts, typing indicators |
| **Groups** | Create/update/delete groups, manage members, roles (owner/admin/member), invite links |
| **Calls** | WebRTC signaling — initiate, answer, reject, ICE candidates, SDP exchange, call history |
| **E2EE** | Signal Protocol key management — register identity/signed/pre-keys, fetch bundles, group sender keys |
| **Files** | Upload/download files (local storage or Cloudflare R2), MIME detection via Apache Tika |
| **Users** | Profile CRUD, search by public ID / AI name, unique nickname enforcement, privacy-aware results |
| **Blocking** | Block/unblock users, blocked list |
| **Settings** | Per-user notification, privacy, and conversation settings |
| **Bots** | Create bots, send messages via bot API, webhook dispatch |
| **Push** | Firebase Cloud Messaging integration for offline notifications |
| **i18n** | Localized error messages (RU/EN) via `Accept-Language` header |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Java 17 |
| Framework | Spring Boot 3.2.5 |
| Database | PostgreSQL 16 |
| Cache | Redis 7 |
| ORM | Spring Data JPA (Hibernate) |
| Migrations | Flyway |
| Auth | JWT (jjwt 0.12) |
| WebSocket | Spring WebSocket (STOMP) |
| Push | Firebase Admin SDK 9.2 |
| Storage | Local filesystem / Cloudflare R2 (AWS S3 SDK) |
| API Docs | SpringDoc OpenAPI (Swagger UI) |
| Build | Gradle |
| Container | Docker (multi-stage build) |

## API Endpoints

### Auth `/api/v1/auth`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/register` | Create new account |
| POST | `/login` | Authenticate, receive tokens |
| POST | `/refresh` | Refresh access token |
| POST | `/logout` | Revoke refresh token |

### Conversations `/api/v1/conversations`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | List user's conversations |
| POST | `/` | Create conversation |
| GET | `/{id}/messages` | Get messages (paginated) |
| POST | `/{id}/read` | Mark messages as read |
| GET | `/{id}/pinned` | Get pinned messages |
| PATCH | `/{id}/pin` | Pin/unpin conversation |
| PATCH | `/{id}/mute` | Mute/unmute conversation |
| PATCH | `/{id}/trust` | Update trust level |
| DELETE | `/{id}` | Delete conversation |
| DELETE | `/{id}/messages` | Clear message history |
| GET | `/requests` | List message requests |
| POST | `/{id}/accept-request` | Accept message request |
| POST | `/{id}/decline-request` | Decline message request |

### Groups `/api/v1/groups`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/` | Create group |
| GET | `/{id}` | Get group info |
| PATCH | `/{id}` | Update group |
| DELETE | `/{id}` | Delete group |
| GET | `/{id}/members` | List members |
| POST | `/{id}/members` | Add members |
| DELETE | `/{id}/members/{memberId}` | Remove member |
| PATCH | `/{id}/roles` | Change member role |
| POST | `/{id}/leave` | Leave group |
| POST | `/join/{inviteLink}` | Join via invite link |

### Users `/api/v1/users`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/me` | Get own profile |
| PATCH | `/me` | Update profile |
| DELETE | `/me` | Delete account |
| GET | `/{id}` | Get user profile |
| GET | `/search` | Search users (by publicId or aiName) |
| PATCH | `/me/fcm-token` | Register push token |
| POST | `/{id}/block` | Block user |
| DELETE | `/{id}/block` | Unblock user |
| GET | `/me/blocked` | List blocked users |
| GET | `/me/settings` | Get user settings |
| PATCH | `/me/settings` | Update settings |

### E2EE Keys `/api/v1/keys`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/register` | Register identity + signed + pre-keys |
| POST | `/prekeys` | Replenish one-time pre-keys |
| GET | `/bundle/{userId}` | Fetch pre-key bundle for session |
| GET | `/count` | Get remaining pre-key count |
| GET | `/check/{userId}` | Check if user has keys |

### Group Sender Keys `/api/v1/groups/sender-keys`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/distribute` | Distribute sender key to group |
| GET | `/pending` | Fetch pending sender keys |
| POST | `/consumed` | Mark sender keys as consumed |
| DELETE | `/{groupId}` | Clear group sender keys |

### Files
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/files/upload` | Upload file |
| GET | `/uploads/{filename}` | Download file |

### Calls `/api/v1/calls`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/history` | Call history |

### Bots `/api/v1/bots` & `/api/v1/bot`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/bots` | Create bot |
| GET | `/bots` | List bots |
| PATCH | `/bots/{id}` | Update bot |
| DELETE | `/bots/{id}` | Delete bot |
| POST | `/bot/sendMessage` | Send message as bot |
| POST | `/bot/setWebhook` | Set bot webhook URL |

### WebSocket
| Endpoint | Protocol | Description |
|----------|----------|-------------|
| `/ws` | STOMP over WebSocket | Real-time messaging, typing, call signaling |

### Swagger UI
Available at `/swagger-ui.html` when server is running.

## Project Structure

```
src/main/java/com/messenger/
├── auth/                  # Authentication (JWT, register, login)
├── bot/                   # Bot platform (CRUD, API, webhooks)
├── call/                  # WebRTC call signaling & history
├── chat/                  # Conversations, messages, groups
├── common/
│   ├── cache/             # Redis cache service
│   ├── exception/         # Global error handling
│   ├── notification/      # Firebase push notifications
│   └── security/          # JWT filter, SecurityConfig, WebSocket config
├── e2ee/                  # E2EE key management (Signal Protocol)
├── file/                  # File upload/download (local + R2)
└── user/                  # Profiles, search, settings, blocking

src/main/resources/
├── application.yml        # Configuration
├── messages_ru.properties # Russian error messages
├── messages_en.properties # English error messages
└── db/migration/          # Flyway SQL migrations (V1–V10)
```

## Database Migrations

| Version | Description |
|---------|-------------|
| V1 | Initial schema (users, conversations, messages, participants) |
| V2 | Features (settings, avatars, message types) |
| V3 | Message requests system |
| V4 | Group chats (roles, invite links) |
| V5 | Bot platform |
| V6 | E2EE keys (identity, signed, pre-keys) |
| V7 | Group sender keys |
| V8 | User public ID and AI name |
| V9 | Trust system |
| V10 | Unique nickname constraint |

## Getting Started

### Prerequisites

- Java 17+
- Docker & Docker Compose
- (Optional) Gradle 8+ if running without Docker

### Quick Start with Docker

```bash
# Clone the repository
git clone https://github.com/SayfullakhonovKomilkhon/messenger_java.git
cd messenger_java

# Start all services (PostgreSQL + Redis + Backend)
docker compose up --build
```

The server will be available at:
- **HTTP API**: `http://localhost:3000/api/v1`
- **WebSocket**: `ws://localhost:3000/ws`
- **Swagger UI**: `http://localhost:3000/swagger-ui.html`

### Local Development (without Docker)

```bash
# Start PostgreSQL and Redis manually, then:
export DATABASE_JDBC_URL=jdbc:postgresql://localhost:5432/messenger
export PGUSER=messenger
export PGPASSWORD=yourpassword
export REDIS_URL=redis://localhost:6379
export JWT_SECRET=your-256-bit-secret-key

./gradlew bootRun
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `3000` | Server port |
| `DATABASE_JDBC_URL` | Yes | — | PostgreSQL JDBC URL |
| `PGUSER` | Yes | — | Database username |
| `PGPASSWORD` | Yes | — | Database password |
| `REDIS_URL` | Yes | — | Redis connection URL |
| `JWT_SECRET` | Yes | — | JWT signing secret (256-bit) |
| `JWT_ACCESS_EXPIRES` | No | `900` | Access token TTL (seconds, 15 min) |
| `JWT_REFRESH_EXPIRES` | No | `2592000` | Refresh token TTL (seconds, 30 days) |
| `FILE_UPLOAD_DIR` | No | `uploads` | File storage path |
| `FILE_PUBLIC_BASE_URL` | No | `http://localhost:3000/uploads` | Public URL for files |
| `FCM_SERVICE_ACCOUNT_FILE` | No | — | Path to Firebase service account JSON |
| `R2_ENDPOINT` | No | — | Cloudflare R2 endpoint (optional) |
| `R2_ACCESS_KEY_ID` | No | — | R2 access key |
| `R2_SECRET_ACCESS_KEY` | No | — | R2 secret key |
| `R2_BUCKET_NAME` | No | — | R2 bucket name |

## Docker Services

| Service | Port | Description |
|---------|------|-------------|
| `backend` | 3000 | Spring Boot API server |
| `postgres` | 5432 | PostgreSQL 16 database |
| `redis` | 6379 | Redis 7 cache & sessions |

## Build

```bash
# Build JAR (skip tests)
./gradlew bootJar -x test

# Build Docker image
docker build -t messenger-backend .
```
