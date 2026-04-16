package com.messenger.common.security;

import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

import java.security.Principal;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class WebSocketAuthInterceptor implements ChannelInterceptor {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        
        if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
            String authHeader = accessor.getFirstNativeHeader("Authorization");
            
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String token = authHeader.substring(7);
                
                try {
                    if (jwtService.isTokenValid(token)) {
                        String userId = jwtService.extractUserId(token);
                        String deviceId = jwtService.extractDeviceId(token);
                        
                        // Check if this device is still active
                        User user = userRepository.findById(UUID.fromString(userId)).orElse(null);
                        if (user != null && deviceId != null) {
                            if (!deviceId.equals(user.getActiveDeviceId())) {
                                log.warn("Device {} for user {} is no longer active. Active device: {}", 
                                        deviceId, userId, user.getActiveDeviceId());
                                // Reject connection from old device
                                return null;
                            }
                        }
                        
                        accessor.setUser(new StompPrincipal(userId));
                    }
                } catch (Exception e) {
                    log.error("WebSocket auth error", e);
                    return null;
                }
            }
        }
        
        return message;
    }

    private record StompPrincipal(String name) implements Principal {
        @Override
        public String getName() {
            return name;
        }
    }
}
