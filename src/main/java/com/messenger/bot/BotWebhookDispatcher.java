package com.messenger.bot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.messenger.bot.entity.Bot;
import com.messenger.chat.ChatService;
import com.messenger.chat.dto.MessageResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/**
 * Dispatches incoming messages to bot webhook URLs on a bounded thread pool
 * ({@link BotWebhookConfig#EXECUTOR_BEAN_NAME}) so a slow webhook can never
 * exhaust the JVM. Each payload is signed with HMAC-SHA256 of the bot's token
 * so receivers can verify authenticity — mirrors the pattern used by GitHub
 * / Telegram / Stripe webhooks.
 */
@Component
public class BotWebhookDispatcher {

    private static final Logger log = LoggerFactory.getLogger(BotWebhookDispatcher.class);
    private static final String HMAC_ALGO = "HmacSHA256";

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final ChatService chatService;

    // Lightweight scheduler that keeps the "bot is typing" indicator alive
    // while a webhook is being processed. The client-side indicator auto-hides
    // after 3s, so a 2s refresh interval gives us a comfortable safety margin
    // without flooding WebSocket subscribers.
    private final ScheduledExecutorService typingRefresher =
            new ScheduledThreadPoolExecutor(1, r -> {
                Thread t = new Thread(r, "bot-typing-refresher");
                t.setDaemon(true);
                return t;
            });

    public BotWebhookDispatcher(@Qualifier("botWebhookRestTemplate") RestTemplate restTemplate,
                                ObjectMapper objectMapper,
                                ChatService chatService) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.chatService = chatService;
    }

    @Async(BotWebhookConfig.EXECUTOR_BEAN_NAME)
    public void dispatch(Bot bot, MessageResponse message) {
        String webhookUrl = bot.getWebhookUrl();
        if (webhookUrl == null || webhookUrl.isBlank()) {
            return;
        }

        // Best-effort "typing" signal for the entire duration of the webhook
        // round-trip, so the sender sees "печатает" instead of a frozen chat.
        // We fire immediately and then refresh every 2s until the HTTP call
        // completes — or until a 10s hard cap to avoid leaking a ghost
        // indicator if the remote server hangs longer than our read timeout.
        UUID convId = parseUuid(message.conversationId());
        final java.util.concurrent.ScheduledFuture<?>[] refresherHolder =
                new java.util.concurrent.ScheduledFuture<?>[1];
        if (convId != null && bot.getUserId() != null) {
            safeNotifyTyping(bot.getUserId(), convId);
            refresherHolder[0] = typingRefresher.scheduleAtFixedRate(
                    () -> safeNotifyTyping(bot.getUserId(), convId),
                    2, 2, TimeUnit.SECONDS);
            // Hard stop after 10s so we never out-live a hung webhook.
            typingRefresher.schedule(() -> {
                if (refresherHolder[0] != null) refresherHolder[0].cancel(false);
            }, 10, TimeUnit.SECONDS);
        }

        try {
            Map<String, Object> msgMap = new LinkedHashMap<>();
            msgMap.put("id", message.id() != null ? message.id() : "");
            msgMap.put("conversationId", message.conversationId());
            msgMap.put("senderId", message.senderId());
            msgMap.put("text", message.text() != null ? message.text() : "");
            msgMap.put("fileUrl", message.fileUrl() != null ? message.fileUrl() : "");
            msgMap.put("mimeType", message.mimeType() != null ? message.mimeType() : "");
            msgMap.put("createdAt", message.createdAt() != null ? message.createdAt().toString() : "");

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("update_type", "message");
            payload.put("bot_id", bot.getId().toString());
            payload.put("message", msgMap);

            // Serialize once so the body we sign is byte-identical to what we send.
            byte[] body = objectMapper.writeValueAsBytes(payload);
            String timestamp = Long.toString(Instant.now().getEpochSecond());
            String signature = sign(bot.getToken(), timestamp, body);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            // t=<unix>,v1=<hex> — same shape as Stripe, makes rotation easy.
            headers.add("X-Bot-Signature", "t=" + timestamp + ",v1=" + signature);
            headers.add("X-Bot-Id", bot.getId().toString());

            restTemplate.postForEntity(webhookUrl, new HttpEntity<>(body, headers), Void.class);
            log.info("Webhook delivered to bot {} at {}", bot.getId(), webhookUrl);
        } catch (JsonProcessingException e) {
            log.error("Webhook payload serialisation failed for bot {}: {}", bot.getId(), e.getMessage());
        } catch (Exception e) {
            log.warn("Webhook failed for bot {} at {}: {}", bot.getId(), webhookUrl, e.getMessage());
        } finally {
            if (refresherHolder[0] != null) refresherHolder[0].cancel(false);
        }
    }

    private void safeNotifyTyping(UUID botUserId, UUID conversationId) {
        try {
            chatService.notifyBotTyping(botUserId, conversationId);
        } catch (Exception e) {
            log.debug("Bot typing broadcast failed: {}", e.getMessage());
        }
    }

    private UUID parseUuid(String raw) {
        if (raw == null || raw.isBlank()) return null;
        try {
            return UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /**
     * Signs "{timestamp}.{body}" with HMAC-SHA256 keyed on the bot's secret
     * token. Receivers reconstruct the same string and compare in constant
     * time. The timestamp is part of the signed payload so an attacker can't
     * replay an old signature against a different body.
     */
    private String sign(String secret, String timestamp, byte[] body) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGO);
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), HMAC_ALGO));
            mac.update(timestamp.getBytes(StandardCharsets.UTF_8));
            mac.update((byte) '.');
            mac.update(body);
            return HexFormat.of().formatHex(mac.doFinal());
        } catch (Exception e) {
            throw new IllegalStateException("Failed to sign webhook payload", e);
        }
    }
}
