package com.messenger.user;

import com.messenger.chat.ParticipantProfileResolver;
import com.messenger.user.entity.User;
import org.springframework.stereotype.Component;

/**
 * Baseline resolver that simply exposes the raw User fields. The bot module
 * overrides this bean with a {@code @Primary} implementation that overlays the
 * {@code bots} table on top of these defaults. Keeping the default here means
 * {@link ChatService} can depend on the interface even in test profiles where
 * the bot module isn't loaded.
 */
@Component
public class DefaultParticipantProfileResolver implements ParticipantProfileResolver {

    @Override
    public Profile resolve(User user) {
        boolean isBot = Boolean.TRUE.equals(user.getIsBot());
        return new Profile(user.getName(), user.getAvatarUrl(), isBot);
    }
}
