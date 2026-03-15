package com.messenger.chat;

import com.messenger.chat.dto.*;
import com.messenger.chat.entity.Conversation;
import com.messenger.chat.entity.ConversationParticipant;
import com.messenger.chat.entity.Message;
import com.messenger.common.exception.AppException;
import com.messenger.common.notification.NotificationService;
import com.messenger.user.BlockService;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final BlockService blockService;

    public ChatService(ConversationRepository conversationRepository,
                       MessageRepository messageRepository,
                       ParticipantRepository participantRepository,
                       UserRepository userRepository,
                       NotificationService notificationService,
                       BlockService blockService) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.participantRepository = participantRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
        this.blockService = blockService;
    }

    public List<ConversationResponse> getConversations(UUID userId) {
        List<ConversationParticipant> allParticipants =
                conversationRepository.findAllParticipantsByUserConversations(userId);

        Map<UUID, List<ConversationParticipant>> byConversation = allParticipants.stream()
                .collect(Collectors.groupingBy(cp -> cp.getConversation().getId()));

        Map<UUID, Message> lastMessages = byConversation.isEmpty()
                ? Map.of()
                : messageRepository.findLastMessagesByConversationIds(byConversation.keySet())
                        .stream()
                        .collect(Collectors.toMap(Message::getConversationId, m -> m));

        List<ConversationResponse> result = new ArrayList<>();

        for (Map.Entry<UUID, List<ConversationParticipant>> entry : byConversation.entrySet()) {
            UUID convId = entry.getKey();
            List<ConversationParticipant> participants = entry.getValue();

            ConversationParticipant myParticipation = participants.stream()
                    .filter(cp -> cp.getUser().getId().equals(userId))
                    .findFirst().orElse(null);
            if (myParticipation == null) continue;
            // Только ACTIVE — PENDING идут в «Запросы сообщений»
            if ("PENDING".equals(myParticipation.getStatus())) continue;

            ConversationParticipant otherParticipation = participants.stream()
                    .filter(cp -> !cp.getUser().getId().equals(userId))
                    .findFirst().orElse(null);
            if (otherParticipation == null) continue;

            User other = otherParticipation.getUser();
            ConversationResponse.ParticipantInfo participantInfo = new ConversationResponse.ParticipantInfo(
                    other.getId().toString(),
                    other.getName(),
                    other.getAvatarUrl(),
                    other.getIsOnline()
            );

            ConversationResponse.LastMessageInfo lastMessageInfo = null;
            Message lastMsg = lastMessages.get(convId);
            if (lastMsg != null) {
                lastMessageInfo = new ConversationResponse.LastMessageInfo(
                        lastMsg.getText(), lastMsg.getCreatedAt(), lastMsg.getStatus()
                );
            }

            result.add(new ConversationResponse(
                    convId.toString(),
                    myParticipation.getConversation().getUpdatedAt(),
                    participantInfo,
                    lastMessageInfo,
                    myParticipation.getUnreadCount() != null ? myParticipation.getUnreadCount() : 0,
                    Boolean.TRUE.equals(myParticipation.getIsPinned()),
                    Boolean.TRUE.equals(myParticipation.getIsMuted())
            ));
        }

        result.sort((a, b) -> {
            if (a.updatedAt() == null) return 1;
            if (b.updatedAt() == null) return -1;
            return b.updatedAt().compareTo(a.updatedAt());
        });

        return result;
    }

    public List<MessageResponse> getMessages(UUID conversationId, UUID messageBeforeId, int limit, UUID userId) {
        conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant of this conversation", HttpStatus.FORBIDDEN));

        List<Message> messages;
        if (messageBeforeId != null) {
            Message beforeMessage = messageRepository.findById(messageBeforeId)
                    .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));
            messages = messageRepository.findByConversationIdBeforeCursor(
                    conversationId, beforeMessage.getCreatedAt(), PageRequest.of(0, limit));
        } else {
            messages = messageRepository.findByConversationIdOrderByCreatedAtDesc(
                    conversationId, PageRequest.of(0, limit));
        }

        return messages.stream().map(this::toMessageResponse).toList();
    }

    @Transactional
    public ConversationResponse createOrGetConversation(UUID userId, UUID participantId) {
        if (userId.equals(participantId)) {
            throw new AppException("Cannot create conversation with yourself", HttpStatus.BAD_REQUEST);
        }

        if (blockService.isBlocked(participantId, userId)) {
            throw new AppException("User has blocked you", HttpStatus.FORBIDDEN);
        }
        if (blockService.isBlocked(userId, participantId)) {
            throw new AppException("You have blocked this user", HttpStatus.FORBIDDEN);
        }

        User participant = userRepository.findById(participantId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        User currentUser = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        Optional<Conversation> existing = conversationRepository.findDirectConversation(userId, participantId);
        if (existing.isPresent()) {
            Conversation conv = existing.get();
            ConversationParticipant myParticipant = conversationRepository.findParticipant(conv.getId(), userId)
                    .orElse(null);
            int unread = myParticipant != null && myParticipant.getUnreadCount() != null
                    ? myParticipant.getUnreadCount() : 0;

            return new ConversationResponse(
                    conv.getId().toString(),
                    conv.getUpdatedAt(),
                    new ConversationResponse.ParticipantInfo(
                            participant.getId().toString(),
                            participant.getName(),
                            participant.getAvatarUrl(),
                            participant.getIsOnline()
                    ),
                    null,
                    unread,
                    myParticipant != null && Boolean.TRUE.equals(myParticipant.getIsPinned()),
                    myParticipant != null && Boolean.TRUE.equals(myParticipant.getIsMuted())
            );
        }

        Conversation conversation = new Conversation();
        conversation = conversationRepository.save(conversation);

        ConversationParticipant cp1 = new ConversationParticipant();
        cp1.setConversation(conversation);
        cp1.setUser(currentUser);
        cp1.setStatus("ACTIVE");
        participantRepository.save(cp1);

        ConversationParticipant cp2 = new ConversationParticipant();
        cp2.setConversation(conversation);
        cp2.setUser(participant);
        cp2.setStatus("PENDING"); // Получатель должен принять запрос
        participantRepository.save(cp2);

        log.info("Conversation created between {} and {} (recipient PENDING)", userId, participantId);

        return new ConversationResponse(
                conversation.getId().toString(),
                conversation.getUpdatedAt(),
                new ConversationResponse.ParticipantInfo(
                        participant.getId().toString(),
                        participant.getName(),
                        participant.getAvatarUrl(),
                        participant.getIsOnline()
                ),
                null,
                0,
                false,
                false
        );
    }

    @Transactional
    public MessageResponse sendMessage(UUID senderId, SendMessageRequest request) {
        Optional<Message> existing = messageRepository.findByClientMessageId(request.clientMessageId());
        if (existing.isPresent()) {
            return toMessageResponse(existing.get());
        }

        conversationRepository.findParticipant(request.conversationId(), senderId)
                .orElseThrow(() -> new AppException("Not a participant of this conversation", HttpStatus.FORBIDDEN));

        Message message = new Message();
        message.setConversationId(request.conversationId());
        message.setSenderId(senderId);
        message.setText(request.text());
        message.setFileUrl(request.fileUrl());
        message.setMimeType(request.mimeType());
        message.setClientMessageId(request.clientMessageId());
        message.setStatus("SENT");
        if (Boolean.TRUE.equals(request.isVoiceMessage())) {
            message.setIsVoiceMessage(true);
            message.setVoiceDuration(request.voiceDuration());
            message.setVoiceWaveform(request.voiceWaveform());
        }
        if (request.replyToId() != null) {
            message.setReplyToId(request.replyToId());
        }
        message = messageRepository.save(message);

        Conversation conv = conversationRepository.findById(request.conversationId())
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        conv.setUpdatedAt(LocalDateTime.now());
        conversationRepository.save(conv);

        List<ConversationParticipant> participants =
                conversationRepository.findParticipants(request.conversationId());
        for (ConversationParticipant cp : participants) {
            if (!cp.getUser().getId().equals(senderId)) {
                cp.setUnreadCount(cp.getUnreadCount() != null ? cp.getUnreadCount() + 1 : 1);
                participantRepository.save(cp);
            }
        }

        log.debug("Message sent in conversation {}", request.conversationId());
        return toMessageResponse(message);
    }

    @Transactional
    public void sendAndNotify(UUID senderId, SendMessageRequest request) {
        MessageResponse response = sendMessage(senderId, request);

        User sender = userRepository.findById(senderId).orElse(null);
        String senderName = sender != null ? sender.getName() : "Unknown";

        notificationService.sendToUser(senderId, "/queue/messages", response);

        List<UUID> recipientIds = getOtherParticipantIds(request.conversationId(), senderId);
        for (UUID recipientId : recipientIds) {
            notificationService.sendMessageNotification(
                    recipientId, senderId, senderName, request.text(), response
            );
        }
    }

    @Transactional
    public void markConversationRead(UUID conversationId, UUID userId) {
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));

        cp.setUnreadCount(0);
        cp.setLastReadAt(LocalDateTime.now());
        participantRepository.save(cp);
    }

    @Transactional
    public void markAsRead(UUID userId, ReadMessageRequest request) {
        ConversationParticipant cp = conversationRepository.findParticipant(request.conversationId(), userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));

        cp.setUnreadCount(0);
        cp.setLastReadAt(LocalDateTime.now());
        participantRepository.save(cp);

        Message message = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));

        if (!message.getSenderId().equals(userId) && !"READ".equals(message.getStatus())) {
            message.setStatus("READ");
            messageRepository.save(message);
        }
    }

    @Transactional
    public void markAsReadAndNotify(UUID userId, ReadMessageRequest request) {
        markAsRead(userId, request);

        Map<String, Object> statusEvent = Map.of(
                "type", "READ",
                "messageId", request.messageId().toString(),
                "conversationId", request.conversationId().toString(),
                "readBy", userId.toString()
        );

        List<UUID> otherIds = getOtherParticipantIds(request.conversationId(), userId);
        for (UUID otherId : otherIds) {
            notificationService.sendStatusEvent(otherId, statusEvent);
        }
    }

    public void notifyTyping(UUID userId, TypingRequest request) {
        Map<String, Object> typingEvent = Map.of(
                "conversationId", request.conversationId().toString(),
                "userId", userId.toString()
        );

        List<UUID> otherIds = getOtherParticipantIds(request.conversationId(), userId);
        for (UUID otherId : otherIds) {
            notificationService.sendTypingEvent(otherId, typingEvent);
        }
    }

    @Transactional
    public void editMessageAndNotify(UUID userId, EditMessageRequest request) {
        Message message = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));
        if (!message.getSenderId().equals(userId)) {
            throw new AppException("Only sender can edit", HttpStatus.FORBIDDEN);
        }

        message.setText(request.text());
        message.setIsEdited(true);
        message.setEditedAt(LocalDateTime.now());
        messageRepository.save(message);

        Map<String, Object> event = Map.of(
                "type", "message_edited",
                "messageId", message.getId().toString(),
                "conversationId", message.getConversationId().toString(),
                "text", request.text(),
                "editedAt", message.getEditedAt().toString()
        );

        List<UUID> participantIds = getOtherParticipantIds(message.getConversationId(), userId);
        participantIds.forEach(id -> notificationService.sendToUser(id, "/queue/messages", event));
        notificationService.sendToUser(userId, "/queue/messages", event);
    }

    @Transactional
    public void deleteMessageAndNotify(UUID userId, DeleteMessageRequest request) {
        Message message = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));
        if (!message.getSenderId().equals(userId)) {
            throw new AppException("Only sender can delete", HttpStatus.FORBIDDEN);
        }

        message.setIsDeleted(true);
        message.setText(null);
        message.setFileUrl(null);
        messageRepository.save(message);

        Map<String, Object> event = Map.of(
                "type", "message_deleted",
                "messageId", message.getId().toString(),
                "conversationId", message.getConversationId().toString()
        );

        List<UUID> participantIds = getOtherParticipantIds(message.getConversationId(), userId);
        participantIds.forEach(id -> notificationService.sendToUser(id, "/queue/messages", event));
        notificationService.sendToUser(userId, "/queue/messages", event);
    }

    @Transactional
    public void forwardMessageAndNotify(UUID userId, ForwardMessageRequest request) {
        Message original = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));

        for (UUID targetConvId : request.toConversationIds()) {
            conversationRepository.findParticipant(targetConvId, userId)
                    .orElseThrow(() -> new AppException("Not a participant of target conversation", HttpStatus.FORBIDDEN));

            Message forwarded = new Message();
            forwarded.setConversationId(targetConvId);
            forwarded.setSenderId(userId);
            forwarded.setText(original.getText());
            forwarded.setFileUrl(original.getFileUrl());
            forwarded.setMimeType(original.getMimeType());
            forwarded.setClientMessageId(UUID.randomUUID().toString());
            forwarded.setStatus("SENT");
            forwarded.setForwardedFromId(original.getId());
            forwarded.setIsVoiceMessage(original.getIsVoiceMessage());
            forwarded.setVoiceDuration(original.getVoiceDuration());
            forwarded.setVoiceWaveform(original.getVoiceWaveform());
            messageRepository.save(forwarded);

            Conversation conv = conversationRepository.findById(targetConvId)
                    .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
            conv.setUpdatedAt(LocalDateTime.now());
            conversationRepository.save(conv);

            MessageResponse response = toMessageResponse(forwarded);
            notificationService.sendToUser(userId, "/queue/messages", response);
            List<UUID> others = getOtherParticipantIds(targetConvId, userId);
            others.forEach(id -> notificationService.sendToUser(id, "/queue/messages", response));
        }
    }

    @Transactional
    public void pinMessageAndNotify(UUID userId, PinMessageRequest request) {
        Message message = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));
        conversationRepository.findParticipant(message.getConversationId(), userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));

        message.setIsPinned(true);
        messageRepository.save(message);

        Map<String, Object> event = Map.of(
                "type", "message_pinned",
                "messageId", message.getId().toString(),
                "conversationId", message.getConversationId().toString()
        );

        List<UUID> participantIds = getOtherParticipantIds(message.getConversationId(), userId);
        participantIds.forEach(id -> notificationService.sendToUser(id, "/queue/messages", event));
        notificationService.sendToUser(userId, "/queue/messages", event);
    }

    @Transactional
    public void unpinMessageAndNotify(UUID userId, PinMessageRequest request) {
        Message message = messageRepository.findById(request.messageId())
                .orElseThrow(() -> new AppException("Message not found", HttpStatus.NOT_FOUND));
        conversationRepository.findParticipant(message.getConversationId(), userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));

        message.setIsPinned(false);
        messageRepository.save(message);

        Map<String, Object> event = Map.of(
                "type", "message_unpinned",
                "messageId", message.getId().toString(),
                "conversationId", message.getConversationId().toString()
        );

        List<UUID> participantIds = getOtherParticipantIds(message.getConversationId(), userId);
        participantIds.forEach(id -> notificationService.sendToUser(id, "/queue/messages", event));
        notificationService.sendToUser(userId, "/queue/messages", event);
    }

    public List<UUID> getOtherParticipantIds(UUID conversationId, UUID excludeUserId) {
        return conversationRepository.findParticipants(conversationId).stream()
                .map(cp -> cp.getUser().getId())
                .filter(id -> !id.equals(excludeUserId))
                .toList();
    }

    @Transactional
    public void pinConversation(UUID conversationId, UUID userId, boolean pinned) {
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        cp.setIsPinned(pinned);
        participantRepository.save(cp);
    }

    @Transactional
    public void muteConversation(UUID conversationId, UUID userId, boolean muted) {
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        cp.setIsMuted(muted);
        participantRepository.save(cp);
    }

    @Transactional
    public void deleteConversation(UUID conversationId, UUID userId) {
        conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        messageRepository.deleteAllByConversationId(conversationId);
        conversationRepository.deleteById(conversationId);
    }

    @Transactional
    public void clearHistory(UUID conversationId, UUID userId) {
        conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        messageRepository.deleteAllByConversationId(conversationId);
    }

    public List<MessageResponse> getPinnedMessages(UUID conversationId, UUID userId) {
        conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        return messageRepository.findPinnedMessages(conversationId).stream()
                .map(this::toMessageResponse)
                .toList();
    }

    public List<ConversationResponse> getMessageRequests(UUID userId) {
        List<ConversationParticipant> allParticipants =
                conversationRepository.findAllParticipantsByUserConversations(userId);

        Map<UUID, List<ConversationParticipant>> byConversation = allParticipants.stream()
                .collect(Collectors.groupingBy(cp -> cp.getConversation().getId()));

        // Оставляем только диалоги, где у текущего пользователя статус PENDING
        Map<UUID, List<ConversationParticipant>> pendingConversations = new HashMap<>();
        for (Map.Entry<UUID, List<ConversationParticipant>> entry : byConversation.entrySet()) {
            ConversationParticipant myCp = entry.getValue().stream()
                    .filter(cp -> cp.getUser().getId().equals(userId))
                    .findFirst().orElse(null);
            if (myCp != null && "PENDING".equals(myCp.getStatus())) {
                pendingConversations.put(entry.getKey(), entry.getValue());
            }
        }

        if (pendingConversations.isEmpty()) return List.of();

        Map<UUID, Message> lastMessages = messageRepository.findLastMessagesByConversationIds(pendingConversations.keySet())
                .stream()
                .collect(Collectors.toMap(Message::getConversationId, m -> m));

        List<ConversationResponse> result = new ArrayList<>();
        for (Map.Entry<UUID, List<ConversationParticipant>> entry : pendingConversations.entrySet()) {
            UUID convId = entry.getKey();
            List<ConversationParticipant> participants = entry.getValue();

            ConversationParticipant myParticipation = participants.stream()
                    .filter(cp -> cp.getUser().getId().equals(userId))
                    .findFirst().orElse(null);
            if (myParticipation == null) continue;

            ConversationParticipant otherParticipation = participants.stream()
                    .filter(cp -> !cp.getUser().getId().equals(userId))
                    .findFirst().orElse(null);
            if (otherParticipation == null) continue;

            User other = otherParticipation.getUser();
            ConversationResponse.ParticipantInfo participantInfo = new ConversationResponse.ParticipantInfo(
                    other.getId().toString(),
                    other.getName(),
                    other.getAvatarUrl(),
                    other.getIsOnline()
            );

            ConversationResponse.LastMessageInfo lastMessageInfo = null;
            Message lastMsg = lastMessages.get(convId);
            if (lastMsg != null) {
                lastMessageInfo = new ConversationResponse.LastMessageInfo(
                        lastMsg.getText(), lastMsg.getCreatedAt(), lastMsg.getStatus()
                );
            }

            result.add(new ConversationResponse(
                    convId.toString(),
                    myParticipation.getConversation().getUpdatedAt(),
                    participantInfo,
                    lastMessageInfo,
                    myParticipation.getUnreadCount() != null ? myParticipation.getUnreadCount() : 0,
                    Boolean.TRUE.equals(myParticipation.getIsPinned()),
                    Boolean.TRUE.equals(myParticipation.getIsMuted())
            ));
        }

        result.sort((a, b) -> {
            if (a.updatedAt() == null) return 1;
            if (b.updatedAt() == null) return -1;
            return b.updatedAt().compareTo(a.updatedAt());
        });

        return result;
    }

    @Transactional
    public void acceptMessageRequest(UUID conversationId, UUID userId) {
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        if (!"PENDING".equals(cp.getStatus())) {
            throw new AppException("Not a message request", HttpStatus.BAD_REQUEST);
        }
        cp.setStatus("ACTIVE");
        participantRepository.save(cp);
        log.info("User {} accepted message request for conversation {}", userId, conversationId);
    }

    @Transactional
    public void declineMessageRequest(UUID conversationId, UUID userId, boolean blockUser) {
        ConversationParticipant myCp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        if (!"PENDING".equals(myCp.getStatus())) {
            throw new AppException("Not a message request", HttpStatus.BAD_REQUEST);
        }

        List<ConversationParticipant> participants = conversationRepository.findParticipants(conversationId);
        UUID senderId = participants.stream()
                .filter(cp -> !cp.getUser().getId().equals(userId))
                .map(cp -> cp.getUser().getId())
                .findFirst()
                .orElse(null);

        if (blockUser && senderId != null && !blockService.isBlocked(userId, senderId)) {
            blockService.blockUser(userId, senderId);
        }

        participantRepository.delete(myCp);
        log.info("User {} declined message request for conversation {}, block={}", userId, conversationId, blockUser);
    }

    @Transactional
    public void declineAllMessageRequests(UUID userId) {
        List<ConversationParticipant> allParticipants =
                conversationRepository.findAllParticipantsByUserConversations(userId);
        List<ConversationParticipant> pending = allParticipants.stream()
                .filter(cp -> cp.getUser().getId().equals(userId) && "PENDING".equals(cp.getStatus()))
                .toList();
        for (ConversationParticipant cp : pending) {
            participantRepository.delete(cp);
        }
        if (!pending.isEmpty()) {
            log.info("User {} declined {} message requests", userId, pending.size());
        }
    }

    private MessageResponse toMessageResponse(Message message) {
        return new MessageResponse(
                message.getId().toString(),
                message.getConversationId().toString(),
                message.getSenderId().toString(),
                message.getIsDeleted() != null && message.getIsDeleted() ? null : message.getText(),
                message.getIsDeleted() != null && message.getIsDeleted() ? null : message.getFileUrl(),
                message.getMimeType(),
                message.getClientMessageId(),
                message.getStatus(),
                message.getCreatedAt(),
                message.getIsVoiceMessage(),
                message.getVoiceDuration(),
                message.getVoiceWaveform(),
                message.getReplyToId() != null ? message.getReplyToId().toString() : null,
                message.getForwardedFromId() != null ? message.getForwardedFromId().toString() : null,
                message.getIsPinned(),
                message.getIsEdited(),
                message.getIsDeleted(),
                message.getEditedAt()
        );
    }
}
