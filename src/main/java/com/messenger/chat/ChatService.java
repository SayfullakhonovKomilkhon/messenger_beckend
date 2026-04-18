package com.messenger.chat;

import com.messenger.chat.dto.*;
import com.messenger.chat.entity.Conversation;
import com.messenger.chat.entity.ConversationParticipant;
import com.messenger.chat.entity.ConversationType;
import com.messenger.chat.entity.GroupRole;
import com.messenger.chat.entity.Message;
import com.messenger.chat.event.MessageSentEvent;
import com.messenger.common.exception.AppException;
import com.messenger.common.notification.NotificationService;
import com.messenger.user.BlockService;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
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
    private static final Comparator<ConversationResponse> BY_UPDATED_DESC = (a, b) -> {
        if (a.updatedAt() == null) return 1;
        if (b.updatedAt() == null) return -1;
        return b.updatedAt().compareTo(a.updatedAt());
    };

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final BlockService blockService;
    private final ApplicationEventPublisher eventPublisher;
    private final ParticipantProfileResolver profileResolver;

    public ChatService(ConversationRepository conversationRepository,
                       MessageRepository messageRepository,
                       ParticipantRepository participantRepository,
                       UserRepository userRepository,
                       NotificationService notificationService,
                       BlockService blockService,
                       ApplicationEventPublisher eventPublisher,
                       ParticipantProfileResolver profileResolver) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.participantRepository = participantRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
        this.blockService = blockService;
        this.eventPublisher = eventPublisher;
        this.profileResolver = profileResolver;
    }

    @Transactional(readOnly = true)
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
            if ("PENDING".equals(myParticipation.getStatus())) continue;

            Conversation conv = myParticipation.getConversation();
            ConversationType type = conv.getType() != null ? conv.getType() : ConversationType.DIRECT;

            ConversationResponse.LastMessageInfo lastMessageInfo = buildLastMessageInfo(lastMessages.get(convId));

            if (type == ConversationType.GROUP) {
                result.add(buildGroupConversationResponse(conv, participants, myParticipation, lastMessageInfo));
            } else {
                ConversationParticipant otherParticipation = participants.stream()
                        .filter(cp -> !cp.getUser().getId().equals(userId))
                        .findFirst().orElse(null);
                if (otherParticipation == null) continue;

                result.add(buildDirectConversationResponse(convId, conv, myParticipation, otherParticipation, lastMessageInfo));
            }
        }

        result.sort(BY_UPDATED_DESC);

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
    public ConversationResponse createOrGetConversation(UUID userId, UUID participantId, String searchMethod) {
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
            ConversationParticipant myCp = conversationRepository.findParticipant(conv.getId(), userId)
                    .orElse(null);
            ConversationParticipant otherCp = conversationRepository.findParticipant(conv.getId(), participantId)
                    .orElse(null);
            return buildDirectConversationResponse(conv.getId(), conv, myCp, otherCp, null);
        }

        Conversation conversation = new Conversation();
        conversation.setType(ConversationType.DIRECT);
        conversation = conversationRepository.save(conversation);

        ConversationParticipant cp1 = new ConversationParticipant();
        cp1.setConversation(conversation);
        cp1.setUser(currentUser);
        cp1.setStatus("ACTIVE");
        cp1.setTrustStatus("PENDING");
        cp1.setSearchMethod(searchMethod);
        participantRepository.save(cp1);

        ConversationParticipant cp2 = new ConversationParticipant();
        cp2.setConversation(conversation);
        cp2.setUser(participant);
        cp2.setStatus("PENDING");
        cp2.setTrustStatus("PENDING");
        participantRepository.save(cp2);

        log.info("Conversation created between {} and {} (recipient PENDING)", userId, participantId);

        return buildDirectConversationResponse(conversation.getId(), conversation, cp1, cp2, null);
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
        if (Boolean.TRUE.equals(request.encrypted())) {
            message.setEncrypted(true);
            message.setEncryptedFileKey(request.encryptedFileKey());
            message.setFileIv(request.fileIv());
        }
        if (request.mediaGroupId() != null) {
            message.setMediaGroupId(request.mediaGroupId());
        }
        message = messageRepository.save(message);

        Conversation conv = conversationRepository.findById(request.conversationId())
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        conv.setUpdatedAt(LocalDateTime.now());
        conversationRepository.save(conv);

        List<ConversationParticipant> participants =
                conversationRepository.findParticipants(request.conversationId());

        if (conv.getType() == ConversationType.DIRECT) {
            List<ConversationParticipant> others = participants.stream()
                    .filter(cp -> !cp.getUser().getId().equals(senderId))
                    .toList();
            if (others.size() == 1 && Boolean.TRUE.equals(others.get(0).getUser().getIsBot())) {
                message.setStatus("READ");
                message = messageRepository.save(message);
            }
        }

        for (ConversationParticipant cp : participants) {
            if (cp.getUser().getId().equals(senderId)) {
                continue;
            }
            // Bots "read" instantly (message marked READ above); do not bump their unread counter.
            if (Boolean.TRUE.equals(cp.getUser().getIsBot())) {
                continue;
            }
            cp.setUnreadCount(cp.getUnreadCount() != null ? cp.getUnreadCount() + 1 : 1);
            participantRepository.save(cp);
        }

        log.debug("Message sent in conversation {}", request.conversationId());
        return toMessageResponse(message);
    }

    @Transactional
    public MessageResponse sendAndNotify(UUID senderId, SendMessageRequest request) {
        MessageResponse response = sendMessage(senderId, request);

        User sender = userRepository.findById(senderId).orElse(null);
        String senderName = sender != null ? resolveUserDisplayName(sender) : "Unknown";

        notificationService.sendToUser(senderId, "/queue/messages", response);

        if ("READ".equals(response.status())) {
            List<UUID> otherIdsForRead = getOtherParticipantIds(request.conversationId(), senderId);
            Map<String, Object> statusEvent = new LinkedHashMap<>();
            statusEvent.put("type", "READ");
            statusEvent.put("messageId", response.id());
            statusEvent.put("conversationId", response.conversationId());
            if (otherIdsForRead.size() == 1) {
                statusEvent.put("readBy", otherIdsForRead.get(0).toString());
            }
            notificationService.sendStatusEvent(senderId, statusEvent);
        }

        String pushText = Boolean.TRUE.equals(request.encrypted())
                ? "Новое сообщение"
                : request.text();

        List<UUID> recipientIds = getOtherParticipantIds(request.conversationId(), senderId);
        for (UUID recipientId : recipientIds) {
            notificationService.sendMessageNotification(
                    recipientId, senderId, senderName, pushText, response,
                    request.conversationId()
            );
        }

        List<UUID> allParticipantIds = new ArrayList<>(recipientIds);
        allParticipantIds.add(senderId);
        eventPublisher.publishEvent(new MessageSentEvent(this, response, allParticipantIds));
        return response;
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

    /**
     * Forwards a session-reset notification from {@code requesterId} to {@code peerId}.
     * Sent by a receiver whose Signal decryption permanently failed. The peer (sender of
     * the undecryptable message) should drop their cached Signal session for requesterId
     * so the next message is sent as a fresh PreKeyMessage. This happens naturally when
     * a client rotates their identity (e.g. app reinstall wipes the local keystore).
     */
    public void notifySessionReset(UUID requesterId, SessionResetRequest request) {
        UUID peerId = request.peerId();
        if (peerId == null || peerId.equals(requesterId)) return;

        Map<String, Object> event = Map.of(
                "type", "session_reset",
                "peerId", requesterId.toString()
        );
        notificationService.sendToUser(peerId, "/queue/session-reset", event);
        log.info("Session reset requested by {} -> {}", requesterId, peerId);
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
    public void updateTrustStatus(UUID conversationId, UUID userId, String status) {
        if (!"TRUSTED".equals(status) && !"DECLINED".equals(status)) {
            throw new AppException("Invalid trust status", HttpStatus.BAD_REQUEST);
        }
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));
        cp.setTrustStatus(status);
        participantRepository.save(cp);
        log.info("User {} set trust={} for conversation {}", userId, status, conversationId);

        List<UUID> otherIds = getOtherParticipantIds(conversationId, userId);
        Map<String, Object> trustEvent = Map.of(
                "type", "trust_updated",
                "conversationId", conversationId.toString(),
                "userId", userId.toString(),
                "trustStatus", status
        );
        for (UUID otherId : otherIds) {
            notificationService.sendToUser(otherId, "/queue/messages", trustEvent);
        }
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

        Conversation conv = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        if (conv.getType() == ConversationType.GROUP) {
            throw new AppException("Use /groups/{id} endpoint to delete a group", HttpStatus.BAD_REQUEST);
        }

        messageRepository.deleteAllByConversationId(conversationId);
        conversationRepository.deleteById(conversationId);
    }

    @Transactional
    public void clearHistory(UUID conversationId, UUID userId) {
        ConversationParticipant cp = conversationRepository.findParticipant(conversationId, userId)
                .orElseThrow(() -> new AppException("Not a participant", HttpStatus.FORBIDDEN));

        Conversation conv = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new AppException("Conversation not found", HttpStatus.NOT_FOUND));
        if (conv.getType() == ConversationType.GROUP && (cp.getRole() == null || !cp.getRole().isAtLeast(GroupRole.ADMIN))) {
            throw new AppException("Only admins can clear group history", HttpStatus.FORBIDDEN);
        }

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

            ConversationResponse.LastMessageInfo lmi = buildLastMessageInfo(lastMessages.get(convId));
            result.add(buildDirectConversationResponse(convId, myParticipation.getConversation(),
                    myParticipation, otherParticipation, lmi));
        }

        result.sort(BY_UPDATED_DESC);

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

        Message systemMsg = new Message();
        systemMsg.setConversationId(conversationId);
        systemMsg.setSenderId(userId);
        systemMsg.setText("Запрос отклонён");
        systemMsg.setClientMessageId("sys-" + UUID.randomUUID().toString().substring(0, 32));
        systemMsg.setStatus("SENT");
        messageRepository.save(systemMsg);

        if (senderId != null) {
            MessageResponse msgResponse = toMessageResponse(systemMsg);
            notificationService.sendToUser(senderId, "/queue/messages", msgResponse);
        }

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

    // --- Private helpers ---

    private ConversationResponse.LastMessageInfo buildLastMessageInfo(Message lastMsg) {
        if (lastMsg == null) return null;
        return new ConversationResponse.LastMessageInfo(
                lastMsg.getId().toString(),
                lastMsg.getText(), lastMsg.getCreatedAt(), lastMsg.getStatus(),
                lastMsg.getFileUrl(), lastMsg.getMimeType(), lastMsg.getIsVoiceMessage(),
                lastMsg.getEncrypted()
        );
    }

    private ConversationResponse buildDirectConversationResponse(
            UUID convId, Conversation conv, ConversationParticipant myCp,
            ConversationParticipant otherCp, ConversationResponse.LastMessageInfo lastMsg) {
        User other = otherCp.getUser();
        boolean mutualTrust = "TRUSTED".equals(myCp.getTrustStatus())
                && "TRUSTED".equals(otherCp.getTrustStatus());

        String sm = myCp.getSearchMethod();
        if (sm == null) sm = otherCp.getSearchMethod();

        ParticipantProfileResolver.Profile otherProfile = profileResolver.resolve(other);
        boolean isBot = otherProfile.isBot();
        String displayName = otherProfile.displayName();
        String displayAvatar = otherProfile.avatarUrl();

        ConversationResponse.ParticipantInfo pInfo;
        if (mutualTrust) {
            pInfo = new ConversationResponse.ParticipantInfo(
                    other.getId().toString(),
                    other.getPublicId(),
                    displayName,
                    other.getAiName(),
                    displayAvatar,
                    other.getIsOnline(),
                    isBot
            );
        } else {
            String visibleName = null;
            if ("name".equals(sm)) {
                visibleName = displayName;
            }
            pInfo = new ConversationResponse.ParticipantInfo(
                    other.getId().toString(),
                    "publicId".equals(sm) ? other.getPublicId() : null,
                    visibleName,
                    "aiName".equals(sm) ? other.getAiName() : null,
                    null,
                    other.getIsOnline(),
                    isBot
            );
        }

        String effectiveSm = myCp.getSearchMethod();
        if (effectiveSm == null) effectiveSm = otherCp.getSearchMethod();

        return new ConversationResponse(
                convId.toString(),
                conv.getUpdatedAt(),
                pInfo,
                lastMsg,
                myCp.getUnreadCount() != null ? myCp.getUnreadCount() : 0,
                Boolean.TRUE.equals(myCp.getIsPinned()),
                Boolean.TRUE.equals(myCp.getIsMuted()),
                myCp.getTrustStatus(),
                otherCp.getTrustStatus(),
                effectiveSm
        );
    }

    private ConversationResponse buildGroupConversationResponse(
            Conversation conv, List<ConversationParticipant> participants,
            ConversationParticipant myCp, ConversationResponse.LastMessageInfo lastMsg) {

        List<ConversationResponse.GroupMemberInfo> memberInfos = participants.stream()
                .map(cp -> {
                    User u = cp.getUser();
                    ParticipantProfileResolver.Profile p = profileResolver.resolve(u);
                    String nm = p.displayName();
                    String av = p.avatarUrl();
                    return new ConversationResponse.GroupMemberInfo(
                            u.getId().toString(),
                            nm,
                            av,
                            u.getIsOnline(),
                            cp.getRole() != null ? cp.getRole().name() : "MEMBER",
                            cp.getJoinedAt()
                    );
                })
                .toList();

        ConversationResponse.GroupInfo groupInfo = new ConversationResponse.GroupInfo(
                conv.getTitle(),
                conv.getDescription(),
                conv.getAvatarUrl(),
                participants.size(),
                myCp.getRole() != null ? myCp.getRole().name() : "MEMBER",
                conv.getCreatedBy() != null ? conv.getCreatedBy().toString() : null,
                memberInfos
        );

        return new ConversationResponse(
                conv.getId().toString(),
                "GROUP",
                conv.getUpdatedAt(),
                null,
                groupInfo,
                lastMsg,
                myCp.getUnreadCount() != null ? myCp.getUnreadCount() : 0,
                Boolean.TRUE.equals(myCp.getIsPinned()),
                Boolean.TRUE.equals(myCp.getIsMuted()),
                null, null, null
        );
    }

    private String resolveUserDisplayName(User user) {
        return profileResolver.resolve(user).displayName();
    }

    private MessageResponse toMessageResponse(Message message) {
        String senderName = null;
        String senderAvatar = null;
        User sender = userRepository.findById(message.getSenderId()).orElse(null);
        if (sender != null) {
            ParticipantProfileResolver.Profile p = profileResolver.resolve(sender);
            senderName = p.displayName();
            senderAvatar = p.avatarUrl();
        }

        String forwardedFromName = null;
        if (message.getForwardedFromId() != null) {
            Message originalMsg = messageRepository.findById(message.getForwardedFromId()).orElse(null);
            if (originalMsg != null) {
                User originalSender = userRepository.findById(originalMsg.getSenderId()).orElse(null);
                if (originalSender != null) {
                    forwardedFromName = profileResolver.resolve(originalSender).displayName();
                }
            }
        }

        return new MessageResponse(
                message.getId().toString(),
                message.getConversationId().toString(),
                message.getSenderId().toString(),
                senderName,
                senderAvatar,
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
                forwardedFromName,
                message.getIsPinned(),
                message.getIsEdited(),
                message.getIsDeleted(),
                message.getEditedAt(),
                message.getEncrypted(),
                message.getEncryptedFileKey(),
                message.getFileIv(),
                message.getMediaGroupId() != null ? message.getMediaGroupId().toString() : null
        );
    }
}
