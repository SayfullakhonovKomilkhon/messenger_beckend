package com.messenger.chat;

import com.messenger.chat.dto.ConversationResponse;
import com.messenger.chat.dto.CreateConversationRequest;
import com.messenger.chat.dto.MessageResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/conversations")
@Tag(name = "Chat", description = "Диалоги и сообщения")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @Operation(summary = "Список диалогов", description = "Возвращает все диалоги текущего пользователя.")
    @GetMapping
    public ResponseEntity<List<ConversationResponse>> getConversations(Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(chatService.getConversations(userId));
    }

    @Operation(summary = "Сообщения диалога", description = "Получить сообщения. Поддержка cursor-пагинации через параметр before.")
    @GetMapping("/{id}/messages")
    public ResponseEntity<List<MessageResponse>> getMessages(
            @PathVariable UUID id,
            @RequestParam(required = false) UUID before,
            @RequestParam(defaultValue = "30") int limit,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(chatService.getMessages(id, before, limit, userId));
    }

    @Operation(summary = "Создать диалог", description = "Создать новый диалог с пользователем или вернуть существующий.")
    @PostMapping
    public ResponseEntity<ConversationResponse> createConversation(
            @RequestBody @Valid CreateConversationRequest request,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(chatService.createOrGetConversation(userId, request.participantId()));
    }

    @Operation(summary = "Закрепить/открепить диалог")
    @PatchMapping("/{id}/pin")
    public ResponseEntity<Map<String, Boolean>> pinConversation(
            @PathVariable UUID id,
            @RequestParam boolean pinned,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.pinConversation(id, userId, pinned);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Включить/выключить звук диалога")
    @PatchMapping("/{id}/mute")
    public ResponseEntity<Map<String, Boolean>> muteConversation(
            @PathVariable UUID id,
            @RequestParam boolean muted,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.muteConversation(id, userId, muted);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Удалить диалог")
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Boolean>> deleteConversation(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.deleteConversation(id, userId);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Очистить историю сообщений")
    @DeleteMapping("/{id}/messages")
    public ResponseEntity<Map<String, Boolean>> clearHistory(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.clearHistory(id, userId);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Пометить диалог прочитанным")
    @PostMapping("/{id}/read")
    public ResponseEntity<Map<String, Boolean>> markRead(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.markConversationRead(id, userId);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Закрепленные сообщения")
    @GetMapping("/{id}/pinned")
    public ResponseEntity<List<MessageResponse>> getPinnedMessages(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(chatService.getPinnedMessages(id, userId));
    }

    @Operation(summary = "Список запросов сообщений")
    @GetMapping("/requests")
    public ResponseEntity<List<ConversationResponse>> getMessageRequests(Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(chatService.getMessageRequests(userId));
    }

    @Operation(summary = "Принять запрос сообщения")
    @PostMapping("/{id}/accept-request")
    public ResponseEntity<Map<String, Boolean>> acceptMessageRequest(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.acceptMessageRequest(id, userId);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Отклонить запрос сообщения")
    @PostMapping("/{id}/decline-request")
    public ResponseEntity<Map<String, Boolean>> declineMessageRequest(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "false") boolean block,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.declineMessageRequest(id, userId, block);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @Operation(summary = "Отклонить все запросы сообщений")
    @DeleteMapping("/requests")
    public ResponseEntity<Map<String, Boolean>> declineAllMessageRequests(Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        chatService.declineAllMessageRequests(userId);
        return ResponseEntity.ok(Map.of("success", true));
    }
}
