package com.messenger.bot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.messenger.bot.entity.Bot;
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

    public BotWebhookDispatcher(@Qualifier("botWebhookRestTemplate") RestTemplate restTemplate,
                                ObjectMapper objectMapper) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
    }

    @Async(BotWebhookConfig.EXECUTOR_BEAN_NAME)
    public void dispatch(Bot bot, MessageResponse message) {
        String webhookUrl = bot.getWebhookUrl();
        if (webhookUrl == null || webhookUrl.isBlank()) {
            return;
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
