package com.messenger.bot;

import com.messenger.bot.dto.BotSendMessageRequest;
import com.messenger.bot.entity.Bot;
import com.messenger.chat.ChatService;
import com.messenger.chat.dto.ConversationResponse;
import com.messenger.chat.dto.MessageResponse;
import com.messenger.chat.dto.SendMessageRequest;
import com.messenger.common.exception.AppException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

@Component
public class BotMessagingFacade {

    private static final Logger log = LoggerFactory.getLogger(BotMessagingFacade.class);

    private final ChatService chatService;

    public BotMessagingFacade(ChatService chatService) {
        this.chatService = chatService;
    }

    public MessageResponse sendMessage(Bot bot, BotSendMessageRequest request) {
        ensureActive(bot);

        if (request.text() == null && request.fileUrl() == null) {
            throw new AppException("Message must have text or file", HttpStatus.BAD_REQUEST);
        }

        UUID botUserId = bot.getUserId();
        // DB: client_message_id VARCHAR(36) UNIQUE — must be exactly UUID length, no "bot_" prefix
        String clientMessageId = UUID.randomUUID().toString();

        SendMessageRequest chatRequest = new SendMessageRequest(
                request.conversationId(),
                request.text(),
                request.fileUrl(),
                request.mimeType(),
                clientMessageId,
                null, null, null, null,
                false, null, null, null
        );

        MessageResponse response = chatService.sendAndNotify(botUserId, chatRequest);
        log.debug("Bot {} sent message to conversation {}", bot.getId(), request.conversationId());
        return response;
    }

    public List<ConversationResponse> getConversations(Bot bot) {
        ensureActive(bot);
        return chatService.getConversations(bot.getUserId());
    }

    public List<MessageResponse> getMessages(Bot bot, UUID conversationId, UUID before, int limit) {
        ensureActive(bot);
        return chatService.getMessages(conversationId, before, limit, bot.getUserId());
    }

    public ConversationResponse startConversation(Bot bot, UUID targetUserId) {
        ensureActive(bot);
        return chatService.createOrGetConversation(bot.getUserId(), targetUserId, null);
    }

    private void ensureActive(Bot bot) {
        if (!Boolean.TRUE.equals(bot.getIsActive())) {
            throw new AppException("Bot is deactivated", HttpStatus.FORBIDDEN);
        }
    }
}
