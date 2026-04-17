package com.messenger.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record SendMessageRequest(
        @NotNull UUID conversationId,
        String text,
        String fileUrl,
        String mimeType,
        @NotBlank String clientMessageId,
        Boolean isVoiceMessage,
        Integer voiceDuration,
        String voiceWaveform,
        UUID replyToId,
        Boolean encrypted,
        String encryptedFileKey,
        String fileIv,
        UUID mediaGroupId
) {}
