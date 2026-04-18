package com.messenger.bot;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.UUID;

/**
 * Fixed-window rate limiter for bot write endpoints. Keeps a per-bot counter
 * in Redis ({@code bot:rl:<botId>:<window>}) with a TTL equal to the window
 * length — no background cleanup needed.
 *
 * <p>Fixed window is intentional: it's cheap (one INCR per request), survives
 * backend restarts, and the typical abuse we're protecting against (a bot
 * flooding users because of a buggy webhook loop) is caught just as well as
 * with sliding-window. For more precise limits we can swap in a Lua script
 * without touching the callers.
 */
@Component
public class BotRateLimiter {

    private static final Logger log = LoggerFactory.getLogger(BotRateLimiter.class);

    private final StringRedisTemplate redis;
    private final int perSecond;
    private final int perMinute;

    public BotRateLimiter(
            StringRedisTemplate redis,
            @Value("${bot.ratelimit.send.per-second:5}") int perSecond,
            @Value("${bot.ratelimit.send.per-minute:60}") int perMinute
    ) {
        this.redis = redis;
        this.perSecond = perSecond;
        this.perMinute = perMinute;
    }

    /**
     * Rate-limit a bot's message sending. Throws {@link BotRateLimitExceededException}
     * when either the per-second or per-minute budget is exhausted.
     */
    public void checkSendMessage(UUID botId) {
        if (botId == null) return;

        long nowSec = System.currentTimeMillis() / 1000L;
        String secKey = "bot:rl:" + botId + ":s:" + nowSec;
        String minKey = "bot:rl:" + botId + ":m:" + (nowSec / 60L);

        long secCount = increment(secKey, Duration.ofSeconds(2));
        if (secCount > perSecond) {
            throw new BotRateLimitExceededException(
                    "Rate limit exceeded: max " + perSecond + " messages/second per bot", 1);
        }

        long minCount = increment(minKey, Duration.ofSeconds(65));
        if (minCount > perMinute) {
            throw new BotRateLimitExceededException(
                    "Rate limit exceeded: max " + perMinute + " messages/minute per bot", 60);
        }
    }

    private long increment(String key, Duration ttl) {
        try {
            Long c = redis.opsForValue().increment(key);
            if (c != null && c == 1L) {
                // Only set the TTL on the first hit of the window so we don't
                // keep refreshing it and leak slots across windows.
                redis.expire(key, ttl);
            }
            return c != null ? c : 0L;
        } catch (Exception e) {
            // Fail-open: if Redis is down we don't want to block bots. Logged
            // at WARN so it surfaces in monitoring.
            log.warn("Rate-limit check fell through (Redis unavailable?): {}", e.getMessage());
            return 0L;
        }
    }
}
