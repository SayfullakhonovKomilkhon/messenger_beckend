package com.messenger.chat;

import com.messenger.chat.dto.*;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.UUID;

@Controller
public class ChatWebSocketHandler {

    private final ChatService chatService;

    public ChatWebSocketHandler(ChatService chatService) {
        this.chatService = chatService;
    }

    @MessageMapping("/chat.send")
    public void sendMessage(SendMessageRequest request, Principal principal) {
        UUID senderId = UUID.fromString(principal.getName());
        chatService.sendAndNotify(senderId, request);
    }

    @MessageMapping("/chat.read")
    public void readMessage(ReadMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.markAsReadAndNotify(userId, request);
    }

    @MessageMapping("/chat.typing")
    public void typing(TypingRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.notifyTyping(userId, request);
    }

    @MessageMapping("/chat.edit")
    public void editMessage(EditMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.editMessageAndNotify(userId, request);
    }

    @MessageMapping("/chat.delete")
    public void deleteMessage(DeleteMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.deleteMessageAndNotify(userId, request);
    }

    @MessageMapping("/chat.forward")
    public void forwardMessage(ForwardMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.forwardMessageAndNotify(userId, request);
    }

    @MessageMapping("/chat.pin")
    public void pinMessage(PinMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.pinMessageAndNotify(userId, request);
    }

    @MessageMapping("/chat.unpin")
    public void unpinMessage(PinMessageRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.unpinMessageAndNotify(userId, request);
    }

    /**
     * Used by a receiver whose Signal decryption from a peer permanently failed
     * (peer rotated identity, e.g. via reinstall). Backend forwards the event to the
     * peer so they drop their stale Signal session before sending the next message.
     */
    @MessageMapping("/chat.session.reset")
    public void sessionReset(SessionResetRequest request, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.notifySessionReset(userId, request);
    }
}
