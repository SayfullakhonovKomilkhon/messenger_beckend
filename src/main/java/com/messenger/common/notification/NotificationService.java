package com.messenger.common.notification;

import com.messenger.chat.ConversationRepository;
import com.messenger.chat.ParticipantRepository;
import com.messenger.chat.entity.Conversation;
import com.messenger.chat.entity.ConversationParticipant;
import com.messenger.chat.entity.ConversationType;
import com.messenger.user.SettingsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final SimpMessagingTemplate messagingTemplate;
    private final PushNotificationService pushService;
    private final SettingsService settingsService;
    private final ConversationRepository conversationRepository;
    private final ParticipantRepository participantRepository;

    public NotificationService(SimpMessagingTemplate messagingTemplate,
                                PushNotificationService pushService,
                                SettingsService settingsService,
                                ConversationRepository conversationRepository,
                                ParticipantRepository participantRepository) {
        this.messagingTemplate = messagingTemplate;
        this.pushService = pushService;
        this.settingsService = settingsService;
        this.conversationRepository = conversationRepository;
        this.participantRepository = participantRepository;
    }

    public void sendToUser(UUID userId, String destination, Object payload) {
        // Flutter subscribes to /user/{userId}/queue/* as plain broker topics.
        // We send directly to the same path without user-destination routing.
        messagingTemplate.convertAndSend("/user/" + userId + destination, payload);
    }

    public void sendToUsers(List<UUID> userIds, String destination, Object payload) {
        for (UUID userId : userIds) {
            sendToUser(userId, destination, payload);
        }
    }

    public void sendMessageNotification(UUID recipientId, UUID senderId,
                                         String senderName, String messageText,
                                         Object wsPayload, UUID conversationId) {
        sendToUser(recipientId, "/queue/messages", wsPayload);

        Map<String, Object> settings = settingsService.getSettings(recipientId);
        Map<String, Object> notifications = (Map<String, Object>) settings.get("notifications");
        boolean fastMode = notifications == null || !Boolean.FALSE.equals(notifications.get("fastMode"));
        if (!fastMode) {
            log.info("[FCM] Push skipped for user {} (fastMode off)", recipientId);
            return;
        }

        Optional<ConversationParticipant> participantOpt =
                conversationRepository.findParticipant(conversationId, recipientId);

        boolean isMessageRequest = false;
        if (participantOpt.isPresent()) {
            ConversationParticipant cp = participantOpt.get();
            if (Boolean.TRUE.equals(cp.getIsMuted()) ||
                    Boolean.FALSE.equals(cp.getIsNotificationsEnabled())) {
                log.info("[FCM] Push skipped for user {} (conversation muted or notifications disabled)", recipientId);
                return;
            }
            isMessageRequest = "PENDING".equals(cp.getStatus());
        }

        String contentMode = notifications != null && notifications.get("notificationContent") != null
                ? notifications.get("notificationContent").toString()
                : "name_and_text";

        boolean isGroup = false;
        String groupTitle = null;
        Conversation conversation = conversationRepository.findById(conversationId).orElse(null);
        if (conversation != null && conversation.getType() == ConversationType.GROUP) {
            isGroup = true;
            groupTitle = conversation.getTitle();
        }

        String title;
        String body;

        if (isMessageRequest) {
            title = senderName;
            String preview = messageText != null ? messageText : "Вложение";
            if (preview.length() > 80) preview = preview.substring(0, 77) + "...";
            body = "Хочет отправить вам сообщение: " + preview;
        } else if (isGroup) {
            switch (contentMode) {
                case "name_only" -> {
                    title = groupTitle != null ? groupTitle : "Группа";
                    body = senderName + ": Новое сообщение";
                }
                case "hidden" -> {
                    title = "Новое сообщение";
                    body = "";
                }
                default -> {
                    title = groupTitle != null ? groupTitle : "Группа";
                    String text = messageText != null ? messageText : "Вложение";
                    if (text.length() > 80) text = text.substring(0, 77) + "...";
                    body = senderName + ": " + text;
                }
            }
        } else {
            switch (contentMode) {
                case "name_only" -> {
                    title = senderName;
                    body = "Новое сообщение";
                }
                case "hidden" -> {
                    title = "Новое сообщение";
                    body = "";
                }
                default -> {
                    title = senderName;
                    body = messageText != null ? messageText : "Вложение";
                    if (body.length() > 100) body = body.substring(0, 97) + "...";
                }
            }
        }

        String pushType = isMessageRequest ? "MESSAGE_REQUEST" : "NEW_MESSAGE";
        pushService.sendPush(recipientId, title, body, Map.of(
                "type", pushType,
                "senderId", senderId.toString(),
                "conversationId", conversationId.toString()
        ));
    }

    public void sendCallNotification(UUID recipientId, String callerName,
                                      String callType, String callId,
                                      String callerId,
                                      Object wsPayload) {
        sendToUser(recipientId, "/queue/call", wsPayload);

        String body = "VIDEO".equals(callType) ? "Incoming video call" : "Incoming audio call";
        pushService.sendPush(recipientId, callerName, body, Map.of(
                "type", "INCOMING_CALL",
                "callId", callId,
                "callType", callType,
                "callerId", callerId
        ));
    }

    public void sendStatusEvent(UUID userId, Object statusPayload) {
        sendToUser(userId, "/queue/status", statusPayload);
    }

    public void broadcastPresenceToContacts(UUID userId, boolean online) {
        try {
            List<UUID> contactIds = participantRepository.findContactIds(userId);
            Map<String, Object> payload = Map.of(
                    "type", online ? "USER_ONLINE" : "USER_OFFLINE",
                    "userId", userId.toString()
            );
            for (UUID contactId : contactIds) {
                sendToUser(contactId, "/queue/presence", payload);
            }
        } catch (Exception e) {
            log.warn("Failed to broadcast presence for user {}: {}", userId, e.getMessage());
        }
    }

    public void sendTypingEvent(UUID userId, Object typingPayload) {
        sendToUser(userId, "/queue/typing", typingPayload);
    }

    public void sendCallEvent(UUID userId, Object callPayload) {
        sendToUser(userId, "/queue/call", callPayload);
    }
}
