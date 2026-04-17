package com.messenger.chat;

import com.messenger.chat.dto.ConversationResponse;
import com.messenger.chat.dto.MessageResponse;
import com.messenger.chat.dto.SendMessageRequest;
import com.messenger.common.exception.AppException;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
class ChatServiceTest {

    @Autowired
    private ChatService chatService;

    @Autowired
    private UserRepository userRepository;

    private User createUser(String phone, String name) {
        User user = new User();
        user.setPhone(phone);
        user.setName(name);
        user.setPasswordHash("$2a$12$dummyhash000000000000000000000000000000000000000000");
        return userRepository.save(user);
    }

    @Test
    void createConversation_shouldCreateNewConversation() {
        User user1 = createUser("+71111111111", "User One");
        User user2 = createUser("+72222222222", "User Two");

        ConversationResponse response = chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");

        assertNotNull(response);
        assertNotNull(response.id());
        assertEquals(user2.getId().toString(), response.participant().id());
        assertEquals("User Two", response.participant().name());
        assertEquals(0, response.unreadCount());
    }

    @Test
    void createConversation_existingConversation_shouldReturnSame() {
        User user1 = createUser("+73333333333", "User Three");
        User user2 = createUser("+74444444444", "User Four");

        ConversationResponse first = chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");
        ConversationResponse second = chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");

        assertEquals(first.id(), second.id());
    }

    @Test
    void createConversation_withSelf_shouldThrow() {
        User user = createUser("+75555555555", "User Five");

        assertThrows(AppException.class, () ->
                chatService.createOrGetConversation(user.getId(), user.getId(), "test"));
    }

    @Test
    void sendMessage_idempotent() {
        User user1 = createUser("+76666666666", "User Six");
        User user2 = createUser("+77777777777", "User Seven");

        ConversationResponse conv = chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");
        UUID convId = UUID.fromString(conv.id());

        String clientMsgId = UUID.randomUUID().toString();
        SendMessageRequest request = new SendMessageRequest(
                convId, "Hello", null, null, clientMsgId,
                null, null, null, null, null, null, null, null);

        MessageResponse first = chatService.sendMessage(user1.getId(), request);
        MessageResponse second = chatService.sendMessage(user1.getId(), request);

        assertEquals(first.id(), second.id());
        assertEquals("Hello", first.text());
    }

    @Test
    void getConversations_shouldReturnUserConversations() {
        User user1 = createUser("+78888888888", "User Eight");
        User user2 = createUser("+79999999999", "User Nine");

        chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");

        List<ConversationResponse> conversations = chatService.getConversations(user1.getId());
        assertFalse(conversations.isEmpty());
    }

    @Test
    void getMessages_notParticipant_shouldThrow() {
        User user1 = createUser("+70001111111", "User A");
        User user2 = createUser("+70002222222", "User B");
        User user3 = createUser("+70003333333", "User C");

        ConversationResponse conv = chatService.createOrGetConversation(user1.getId(), user2.getId(), "test");
        UUID convId = UUID.fromString(conv.id());

        assertThrows(AppException.class, () ->
                chatService.getMessages(convId, null, 30, user3.getId()));
    }
}
