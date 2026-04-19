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
        UUID mediaGroupId,
        // Set by the client when re-sending a forwarded message. The client
        // decrypts the original locally, re-encrypts for the target chat
        // (so E2EE stays intact), and stamps this field with the original
        // message id so the recipient sees the "forwarded from" header.
        UUID forwardedFromId
) {}
