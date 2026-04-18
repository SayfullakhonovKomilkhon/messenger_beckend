package com.messenger.bot;

import com.messenger.bot.dto.BotSendMessageRequest;
import com.messenger.bot.dto.BotSetWebhookRequest;
import com.messenger.bot.entity.Bot;
import com.messenger.chat.dto.ConversationResponse;
import com.messenger.chat.dto.MessageResponse;
import com.messenger.common.exception.AppException;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Bot execution API on core — only reachable from bot-gateway with X-Internal-Bot-Key.
 * External clients use bot-gateway /api/v1/bot/* (same paths, no internal header).
 */
@RestController
@RequestMapping("/internal/v1/bot")
public class InternalBotController {

    private final BotService botService;
    private final BotMessagingFacade messagingFacade;
    private final BotRateLimiter rateLimiter;

    public InternalBotController(BotService botService,
                                 BotMessagingFacade messagingFacade,
                                 BotRateLimiter rateLimiter) {
        this.botService = botService;
        this.messagingFacade = messagingFacade;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/sendMessage")
    public ResponseEntity<MessageResponse> sendMessage(
            @RequestHeader("Authorization") String authHeader,
            @Valid @RequestBody BotSendMessageRequest request) {
        Bot bot = resolveBot(authHeader);
        rateLimiter.checkSendMessage(bot.getId());
        return ResponseEntity.ok(messagingFacade.sendMessage(bot, request));
    }

    @GetMapping("/getConversations")
    public ResponseEntity<List<ConversationResponse>> getConversations(
            @RequestHeader("Authorization") String authHeader) {
        Bot bot = resolveBot(authHeader);
        return ResponseEntity.ok(messagingFacade.getConversations(bot));
    }

    @GetMapping("/getMessages")
    public ResponseEntity<List<MessageResponse>> getMessages(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam UUID conversationId,
            @RequestParam(required = false) UUID before,
            @RequestParam(defaultValue = "30") int limit) {
        Bot bot = resolveBot(authHeader);
        return ResponseEntity.ok(messagingFacade.getMessages(bot, conversationId, before, limit));
    }

    @PostMapping("/startConversation")
    public ResponseEntity<ConversationResponse> startConversation(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam UUID userId) {
        Bot bot = resolveBot(authHeader);
        return ResponseEntity.ok(messagingFacade.startConversation(bot, userId));
    }

    @PostMapping("/setWebhook")
    public ResponseEntity<Map<String, String>> setWebhook(
            @RequestHeader("Authorization") String authHeader,
            @Valid @RequestBody BotSetWebhookRequest request) {
        Bot bot = resolveBot(authHeader);
        botService.updateBotWebhook(bot, request.url());
        String saved = request.url() != null ? request.url() : "";
        return ResponseEntity.ok(Map.of("status", "ok", "webhook_url", saved));
    }

    @DeleteMapping("/webhook")
    public ResponseEntity<Map<String, String>> deleteWebhook(
            @RequestHeader("Authorization") String authHeader) {
        Bot bot = resolveBot(authHeader);
        botService.updateBotWebhook(bot, null);
        return ResponseEntity.ok(Map.of("status", "ok", "webhook_url", ""));
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getMe(
            @RequestHeader("Authorization") String authHeader) {
        Bot bot = resolveBot(authHeader);
        return ResponseEntity.ok(Map.of(
                "id", bot.getId().toString(),
                "user_id", bot.getUserId().toString(),
                "name", bot.getName(),
                "username", bot.getUsername() != null ? bot.getUsername() : "",
                "is_active", Boolean.TRUE.equals(bot.getIsActive())
        ));
    }

    private Bot resolveBot(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bot ")) {
            throw new AppException("Authorization header must be: Bot <token>", HttpStatus.UNAUTHORIZED);
        }
        String token = authHeader.substring(4).trim();
        return botService.findByToken(token);
    }
}
