package com.messenger.bot;

import com.messenger.bot.entity.Bot;
import com.messenger.chat.ParticipantProfileResolver;
import com.messenger.user.entity.User;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * {@link ParticipantProfileResolver} that overlays the {@code bots} table on
 * top of the base {@code users} table so callers (e.g. ChatService) see the
 * friendly bot name/avatar for any participant flagged as a bot. Registered
 * with {@code @Primary} so it wins over
 * {@link com.messenger.user.DefaultParticipantProfileResolver} when the bot
 * module is on the classpath.
 */
@Component
@Primary
public class BotAwareParticipantProfileResolver implements ParticipantProfileResolver {

    private final BotRepository botRepository;

    public BotAwareParticipantProfileResolver(BotRepository botRepository) {
        this.botRepository = botRepository;
    }

    @Override
    public Profile resolve(User user) {
        if (!Boolean.TRUE.equals(user.getIsBot())) {
            return new Profile(user.getName(), user.getAvatarUrl(), false);
        }
        Optional<Bot> linked = botRepository.findByUserId(user.getId());
        String name = linked.map(Bot::getName).orElse(user.getName());
        String avatar = linked.map(Bot::getAvatarUrl).orElse(user.getAvatarUrl());
        return new Profile(name, avatar, true);
    }
}
