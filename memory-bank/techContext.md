# Tech Context

## Stack
- Java 17, Spring Boot 3.2.5, Spring Security 6
- Spring Data JPA (Hibernate), PostgreSQL 16
- Spring WebSocket (STOMP), Redis 7
- Flyway (миграции), Gradle
- Docker + Docker Compose
- jjwt 0.12.5 (HS256), Bucket4j (rate limiting)
- Apache Tika (MIME detection), AWS SDK v2 (Cloudflare R2)

## Infrastructure
- PostgreSQL: порт 5432
- Redis: порт 6379
- TURN (coturn): host mode
- Backend: порт 3000

## Configuration
- Все секреты через переменные среды (application.yml → ${VAR})
- .env в корне монорепо (не коммитится)
- .env.example с пустыми значениями

## Key Libraries
- io.jsonwebtoken:jjwt-api:0.12.5
- com.bucket4j:bucket4j-core:8.10.1
- org.apache.tika:tika-core:2.9.2
- software.amazon.awssdk:s3 (BOM 2.25.27)
