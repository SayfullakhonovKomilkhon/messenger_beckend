package com.messenger.common.notification;

import com.messenger.chat.ConversationRepository;
import com.messenger.chat.entity.ConversationParticipant;
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

    public NotificationService(SimpMessagingTemplate messagingTemplate,
                                PushNotificationService pushService,
                                SettingsService settingsService,
                                ConversationRepository conversationRepository) {
        this.messagingTemplate = messagingTemplate;
        this.pushService = pushService;
        this.settingsService = settingsService;
        this.conversationRepository = conversationRepository;
    }

    public void sendToUser(UUID userId, String destination, Object payload) {
        messagingTemplate.convertAndSendToUser(userId.toString(), destination, payload);
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

        // Push: проверяем настройки и стратегию
        Map<String, Object> settings = settingsService.getSettings(recipientId);
        Map<String, Object> notifications = (Map<String, Object>) settings.get("notifications");
        boolean fastMode = notifications == null || !Boolean.FALSE.equals(notifications.get("fastMode"));
        if (!fastMode) {
            log.info("[FCM] Push skipped for user {} (fastMode off)", recipientId);
            return;
        }

        Optional<ConversationParticipant> participantOpt =
                conversationRepository.findParticipant(conversationId, recipientId);
        if (participantOpt.isPresent()) {
            ConversationParticipant cp = participantOpt.get();
            if (Boolean.TRUE.equals(cp.getIsMuted()) ||
                    Boolean.FALSE.equals(cp.getIsNotificationsEnabled())) {
                log.info("[FCM] Push skipped for user {} (conversation muted or notifications disabled)", recipientId);
                return;
            }
        }

        String contentMode = notifications != null && notifications.get("notificationContent") != null
                ? notifications.get("notificationContent").toString()
                : "name_and_text";

        String title;
        String body;
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

        pushService.sendPush(recipientId, title, body, Map.of(
                "type", "NEW_MESSAGE",
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

    public void sendTypingEvent(UUID userId, Object typingPayload) {
        sendToUser(userId, "/queue/typing", typingPayload);
    }

    public void sendCallEvent(UUID userId, Object callPayload) {
        sendToUser(userId, "/queue/call", callPayload);
    }
}
