package com.messenger.chat.dto;

import java.time.LocalDateTime;

public record MessageResponse(
        String id,
        String conversationId,
        String senderId,
        String senderName,
        String senderAvatar,
        String text,
        String fileUrl,
        String mimeType,
        String clientMessageId,
        String status,
        LocalDateTime createdAt,
        Boolean isVoiceMessage,
        Integer voiceDuration,
        String voiceWaveform,
        String replyToId,
        String forwardedFromId,
        String forwardedFromName,
        Boolean isPinned,
        Boolean isEdited,
        Boolean isDeleted,
        LocalDateTime editedAt,
        Boolean encrypted,
        String encryptedFileKey,
        String fileIv,
        String mediaGroupId
) {}
