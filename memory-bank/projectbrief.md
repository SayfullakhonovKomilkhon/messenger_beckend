# Project Brief: Messenger

## Overview
Монорепозиторий мессенджера с двумя компонентами:
- **backend/** — Java 17 + Spring Boot 3 (Этап 1 — реализован)
- **mobile/** — Flutter (Этап 2 — реализуется отдельно)

## Core Requirements (Этап 1)
1. JWT-авторизация (Access + Refresh Token) с rate limiting
2. Личные чаты через WebSocket STOMP с idempotency
3. WebRTC-звонки (аудио/видео) с signaling через STOMP
4. Загрузка файлов в Cloudflare R2 с MIME-валидацией через Apache Tika
5. Поиск пользователей по имени/username
6. FCM push-уведомления (сохранение токена)

## Out of Scope (Этап 2)
- Настройки, профиль пользователя
- Групповые чаты
- Боты
- Flutter мобильное приложение
