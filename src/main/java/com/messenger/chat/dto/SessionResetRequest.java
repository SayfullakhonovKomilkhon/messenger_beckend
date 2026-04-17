package com.messenger.chat.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Receiver-initiated request sent via WebSocket when Signal decryption from {@code peerId}
 * permanently fails (e.g. due to peer reinstalling the app and rotating identity keys).
 * Backend forwards a session-reset event to the peer so they can drop their stale
 * Signal session and rebuild it before sending the next message.
 */
public record SessionResetRequest(
        @NotNull UUID peerId
) {}
