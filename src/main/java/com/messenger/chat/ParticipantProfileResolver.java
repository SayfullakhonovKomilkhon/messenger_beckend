package com.messenger.chat;

import com.messenger.user.entity.User;

/**
 * Resolves the display-facing profile (name / avatar / bot-flag) for a given
 * {@link User} without forcing the chat module to know about bots, AI-users or
 * any other specialised account kind.
 *
 * <p>The default implementation lives in the {@code user} module and simply
 * returns the raw {@code User} fields. The {@code bot} module registers a
 * {@link org.springframework.context.annotation.Primary @Primary} replacement
 * that transparently overlays the {@code bots} table on top of the default —
 * this keeps {@link ChatService} free of any bot-specific imports (requirement:
 * "логика ботов не смешана с основной логикой чата").
 */
public interface ParticipantProfileResolver {

    record Profile(String displayName, String avatarUrl, boolean isBot) {}

    Profile resolve(User user);
}
