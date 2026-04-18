package com.messenger.chat;

import com.messenger.chat.dto.*;
import com.messenger.chat.entity.*;
import com.messenger.common.exception.AppException;
import com.messenger.common.notification.NotificationService;
import com.messenger.e2ee.GroupSenderKeyService;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class GroupService {

    private static final Logger log = LoggerFactory.getLogger(GroupService.class);

    private final ConversationRepository conversationRepository;
    private final ParticipantRepository participantRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final GroupSenderKeyService groupSenderKeyService;
    private final ParticipantProfileResolver profileResolver;

    public GroupService(ConversationRepository conversationRepository,
                        ParticipantRepository participantRepository,
                        MessageRepository messageRepository,
                        UserRepository userRepository,
                        NotificationService notificationService,
                        GroupSenderKeyService groupSenderKeyService,
                        ParticipantProfileResolver profileResolver) {
        this.conversationRepository = conversationRepository;
        this.participantRepository = participantRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
        this.groupSenderKeyService = groupSenderKeyService;
        this.profileResolver = profileResolver;
    }

    @Transactional
    public ConversationResponse createGroup(UUID creatorId, CreateGroupRequest request) {
        User creator = userRepository.findById(creatorId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        Conversation conversation = new Conversation();
        conversation.setType(ConversationType.GROUP);
        conversation.setTitle(request.title());
        conversation.setDescription(request.description());
        conversation.setAvatarUrl(request.avatarUrl());
        conversation.setCreatedBy(creatorId);
        conversation.setInviteLink(generateInviteLink());
        conversation = conversationRepository.save(conversation);

        ConversationParticipant ownerCp = new ConversationParticipant();
        ownerCp.setConversation(conversation);
        ownerCp.setUser(creator);
        ownerCp.setRole(GroupRole.OWNER);
        ownerCp.setStatus("ACTIVE");
        // The group creator is implicitly opted-in — they built the group,
        // so hiding their name/avatar makes no sense.
        ownerCp.setTrustStatus("TRUSTED");
        participantRepository.save(ownerCp);

        if (request.memberIds() != null) {
            int addedCount = 1; // owner already added
            for (UUID memberId : request.memberIds()) {
                if (memberId.equals(creatorId)) continue;
                if (addedCount >= conversation.getMaxMembers()) break;
                User member = userRepository.findById(memberId).orElse(null);
                if (member == null) continue;

                ConversationParticipant memberCp = new ConversationParticipant();
                memberCp.setConversation(conversation);
                memberCp.setUser(member);
                memberCp.setRole(GroupRole.MEMBER);
                memberCp.setStatus("ACTIVE");
                // Added-by-someone-else: hide their identity until they
                // explicitly reveal themselves in the group.
                memberCp.setTrustStatus("PENDING");
                participantRepository.save(memberCp);
                addedCount++;

                notificationService.sendToUser(memberId, "/queue/messages", Map.of(
                        "type", "group_member_added",
                        "conversationId", conversation.getId().toString(),
                        "groupTitle", request.title() != null ? request.title() : "Группа"
                ));
            }
        }

        log.info("Group '{}' created by user {}", request.title(), creatorId);
        return toGroupResponse(conversation, creatorId);
    }

    public ConversationResponse getGroup(UUID groupId, UUID userId) {
        Conversation conversation = findGroupConversation(groupId);
        requireParticipant(groupId, userId);
        return toGroupResponse(conversation, userId);
    }

    @Transactional
    public ConversationResponse updateGroup(UUID groupId, UUID userId, UpdateGroupRequest request) {
        Conversation conversation = findGroupConversation(groupId);

        if (request.title() != null) {
            conversation.setTitle(request.title());
        }
        if (request.description() != null) {
            conversation.setDescription(request.description());
        }
        if (request.avatarUrl() != null) {
            conversation.setAvatarUrl(request.avatarUrl());
        }

        conversationRepository.save(conversation);
        log.info("Group {} updated by user {}", groupId, userId);
        return toGroupResponse(conversation, userId);
    }

    @Transactional
    public void deleteGroup(UUID groupId, UUID userId) {
        Conversation conversation = findGroupConversation(groupId);

        ConversationParticipant cp = requireParticipant(groupId, userId);
        if (cp.getRole() != GroupRole.OWNER) {
            throw new AppException("Only the owner can delete a group", HttpStatus.FORBIDDEN);
        }

        groupSenderKeyService.deleteAllForGroup(groupId);
        messageRepository.deleteAllByConversationId(groupId);
        List<ConversationParticipant> members = participantRepository.findAllByConversationId(groupId);
        participantRepository.deleteAll(members);
        conversationRepository.delete(conversation);

        log.info("Group {} deleted by owner {}", groupId, userId);
    }

    @Transactional
    public void addMember(UUID groupId, UUID actorId, UUID newMemberId) {
        Conversation conversation = findGroupConversation(groupId);

        if (participantRepository.findByConversationIdAndUserId(groupId, newMemberId).isPresent()) {
            throw new AppException("User is already a member", HttpStatus.CONFLICT);
        }

        long memberCount = participantRepository.countByConversationId(groupId);
        if (memberCount >= conversation.getMaxMembers()) {
            throw new AppException("Group is full", HttpStatus.BAD_REQUEST);
        }

        User newMember = userRepository.findById(newMemberId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        ConversationParticipant cp = new ConversationParticipant();
        cp.setConversation(conversation);
        cp.setUser(newMember);
        cp.setRole(GroupRole.MEMBER);
        cp.setStatus("ACTIVE");
        // Added-by-someone-else: hide their identity until they explicitly
        // press "Reveal me" in the group.
        cp.setTrustStatus("PENDING");
        participantRepository.save(cp);

        notificationService.sendToUser(newMemberId, "/queue/messages", Map.of(
                "type", "group_member_added",
                "conversationId", groupId.toString(),
                "groupTitle", conversation.getTitle() != null ? conversation.getTitle() : "Группа"
        ));

        List<ConversationParticipant> allMembers = participantRepository.findAllByConversationId(groupId);
        for (ConversationParticipant member : allMembers) {
            UUID memberId = member.getUser().getId();
            if (!memberId.equals(newMemberId)) {
                notificationService.sendToUser(memberId, "/queue/messages", Map.of(
                        "type", "group_member_added",
                        "conversationId", groupId.toString(),
                        "newMemberId", newMemberId.toString(),
                        "groupTitle", conversation.getTitle() != null ? conversation.getTitle() : "Группа"
                ));
            }
        }

        log.info("User {} added to group {} by {}", newMemberId, groupId, actorId);
    }

    @Transactional
    public void removeMember(UUID groupId, UUID actorId, UUID memberId) {
        ConversationParticipant actorCp = requireParticipant(groupId, actorId);
        ConversationParticipant memberCp = requireParticipant(groupId, memberId);

        if (memberCp.getRole() == GroupRole.OWNER) {
            throw new AppException("Cannot remove the group owner", HttpStatus.FORBIDDEN);
        }

        if (!actorCp.getRole().isAtLeast(GroupRole.ADMIN)) {
            throw new AppException("Insufficient permissions", HttpStatus.FORBIDDEN);
        }

        if (actorCp.getRole() == GroupRole.ADMIN && memberCp.getRole() == GroupRole.ADMIN) {
            throw new AppException("Admins cannot remove other admins", HttpStatus.FORBIDDEN);
        }

        participantRepository.delete(memberCp);
        groupSenderKeyService.deleteForUser(groupId, memberId);

        Conversation conversation = findGroupConversation(groupId);
        notificationService.sendToUser(memberId, "/queue/messages", Map.of(
                "type", "group_member_removed",
                "conversationId", groupId.toString(),
                "groupTitle", conversation.getTitle() != null ? conversation.getTitle() : "Группа"
        ));

        List<ConversationParticipant> remaining = participantRepository.findAllByConversationId(groupId);
        for (ConversationParticipant rm : remaining) {
            notificationService.sendToUser(rm.getUser().getId(), "/queue/messages", Map.of(
                    "type", "sender_key_rotation_needed",
                    "conversationId", groupId.toString(),
                    "removedMemberId", memberId.toString()
            ));
        }

        log.info("User {} removed from group {} by {}", memberId, groupId, actorId);
    }

    @Transactional
    public void changeRole(UUID groupId, UUID actorId, ChangeRoleRequest request) {
        if (actorId.equals(request.userId())) {
            throw new AppException("Cannot change your own role", HttpStatus.BAD_REQUEST);
        }

        ConversationParticipant actorCp = requireParticipant(groupId, actorId);
        ConversationParticipant targetCp = requireParticipant(groupId, request.userId());

        if (request.role() == GroupRole.OWNER) {
            if (actorCp.getRole() != GroupRole.OWNER) {
                throw new AppException("Only the owner can transfer ownership", HttpStatus.FORBIDDEN);
            }
            actorCp.setRole(GroupRole.ADMIN);
            participantRepository.save(actorCp);
            targetCp.setRole(GroupRole.OWNER);
            participantRepository.save(targetCp);
            log.info("Ownership of group {} transferred from {} to {}", groupId, actorId, request.userId());
            return;
        }

        if (!actorCp.getRole().isAtLeast(GroupRole.OWNER)) {
            throw new AppException("Only the owner can change roles", HttpStatus.FORBIDDEN);
        }

        targetCp.setRole(request.role());
        participantRepository.save(targetCp);
        log.info("User {} role in group {} changed to {} by {}", request.userId(), groupId, request.role(), actorId);
    }

    @Transactional
    public void leaveGroup(UUID groupId, UUID userId) {
        ConversationParticipant cp = requireParticipant(groupId, userId);

        if (cp.getRole() == GroupRole.OWNER) {
            List<ConversationParticipant> members = participantRepository.findAllByConversationId(groupId);
            if (members.size() <= 1) {
                messageRepository.deleteAllByConversationId(groupId);
                participantRepository.delete(cp);
                conversationRepository.deleteById(groupId);
                log.info("Group {} deleted — last member {} left", groupId, userId);
                return;
            }

            ConversationParticipant successor = members.stream()
                    .filter(m -> !m.getUser().getId().equals(userId))
                    .filter(m -> m.getRole() == GroupRole.ADMIN)
                    .findFirst()
                    .orElse(members.stream()
                            .filter(m -> !m.getUser().getId().equals(userId))
                            .findFirst()
                            .orElse(null));

            if (successor != null) {
                successor.setRole(GroupRole.OWNER);
                participantRepository.save(successor);
                log.info("Ownership of group {} auto-transferred to {}", groupId, successor.getUser().getId());
            }
        }

        participantRepository.delete(cp);
        groupSenderKeyService.deleteForUser(groupId, userId);

        List<ConversationParticipant> remaining = participantRepository.findAllByConversationId(groupId);
        for (ConversationParticipant rm : remaining) {
            notificationService.sendToUser(rm.getUser().getId(), "/queue/messages", Map.of(
                    "type", "sender_key_rotation_needed",
                    "conversationId", groupId.toString(),
                    "removedMemberId", userId.toString()
            ));
        }

        log.info("User {} left group {}", userId, groupId);
    }

    public ConversationResponse joinByInviteLink(String inviteLink, UUID userId) {
        Conversation conversation = conversationRepository.findByInviteLink(inviteLink)
                .orElseThrow(() -> new AppException("Invalid invite link", HttpStatus.NOT_FOUND));

        if (conversation.getType() != ConversationType.GROUP) {
            throw new AppException("Not a group conversation", HttpStatus.BAD_REQUEST);
        }

        if (participantRepository.findByConversationIdAndUserId(conversation.getId(), userId).isPresent()) {
            return toGroupResponse(conversation, userId);
        }

        long memberCount = participantRepository.countByConversationId(conversation.getId());
        if (memberCount >= conversation.getMaxMembers()) {
            throw new AppException("Group is full", HttpStatus.BAD_REQUEST);
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));

        ConversationParticipant cp = new ConversationParticipant();
        cp.setConversation(conversation);
        cp.setUser(user);
        cp.setRole(GroupRole.MEMBER);
        cp.setStatus("ACTIVE");
        // Join-by-link is a self-initiated action, but we still start
        // hidden so the user sees the "Reveal me" banner and makes an
        // explicit choice — let them opt in deliberately.
        cp.setTrustStatus("PENDING");
        participantRepository.save(cp);

        log.info("User {} joined group {} via invite link", userId, conversation.getId());
        return toGroupResponse(conversation, userId);
    }

    public List<ConversationResponse.GroupMemberInfo> getMembers(UUID groupId, UUID userId) {
        requireParticipant(groupId, userId);
        return participantRepository.findAllByConversationId(groupId).stream()
                .map(this::toMemberInfo)
                .toList();
    }

    // --- Helpers ---

    private Conversation findGroupConversation(UUID groupId) {
        Conversation conversation = conversationRepository.findById(groupId)
                .orElseThrow(() -> new AppException("Group not found", HttpStatus.NOT_FOUND));
        if (conversation.getType() != ConversationType.GROUP) {
            throw new AppException("Not a group conversation", HttpStatus.BAD_REQUEST);
        }
        return conversation;
    }

    private ConversationParticipant requireParticipant(UUID groupId, UUID userId) {
        return participantRepository.findByConversationIdAndUserId(groupId, userId)
                .orElseThrow(() -> new AppException("You are not a member of this group", HttpStatus.FORBIDDEN));
    }

    private String generateInviteLink() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    private ConversationResponse toGroupResponse(Conversation conversation, UUID currentUserId) {
        List<ConversationParticipant> members = participantRepository.findAllByConversationId(conversation.getId());

        ConversationParticipant myCp = members.stream()
                .filter(cp -> cp.getUser().getId().equals(currentUserId))
                .findFirst().orElse(null);

        Message lastMsg = messageRepository.findTopByConversationIdOrderByCreatedAtDesc(conversation.getId());

        ConversationResponse.LastMessageInfo lastMessageInfo = null;
        if (lastMsg != null) {
            lastMessageInfo = new ConversationResponse.LastMessageInfo(
                    lastMsg.getId().toString(),
                    lastMsg.getText(), lastMsg.getCreatedAt(), lastMsg.getStatus(),
                    lastMsg.getFileUrl(), lastMsg.getMimeType(), lastMsg.getIsVoiceMessage(),
                    lastMsg.getEncrypted()
            );
        }

        List<ConversationResponse.GroupMemberInfo> memberInfos = members.stream()
                .map(this::toMemberInfo)
                .toList();

        ConversationResponse.GroupInfo groupInfo = new ConversationResponse.GroupInfo(
                conversation.getTitle(),
                conversation.getDescription(),
                conversation.getAvatarUrl(),
                members.size(),
                myCp != null ? myCp.getRole().name() : null,
                conversation.getCreatedBy() != null ? conversation.getCreatedBy().toString() : null,
                memberInfos
        );

        return new ConversationResponse(
                conversation.getId().toString(),
                "GROUP",
                conversation.getUpdatedAt(),
                null,
                groupInfo,
                lastMessageInfo,
                myCp != null && myCp.getUnreadCount() != null ? myCp.getUnreadCount() : 0,
                myCp != null && Boolean.TRUE.equals(myCp.getIsPinned()),
                myCp != null && Boolean.TRUE.equals(myCp.getIsMuted()),
                myCp != null ? myCp.getTrustStatus() : null, null, null
        );
    }

    /**
     * Mirrors {@link ChatService#resolveDisplay} self-reveal logic: a member's
     * real name/avatar/online status is only exposed when their own
     * {@code trust_status} is TRUSTED (or legacy null, or they're a bot).
     * Otherwise we return {@code publicId} as a stable fallback label.
     */
    private ConversationResponse.GroupMemberInfo toMemberInfo(ConversationParticipant cp) {
        User user = cp.getUser();
        ParticipantProfileResolver.Profile profile = profileResolver.resolve(user);
        boolean isBot = profile.isBot();
        String trustStatus = cp.getTrustStatus();
        boolean revealed = isBot
                || trustStatus == null
                || "TRUSTED".equals(trustStatus);

        String name = revealed ? profile.displayName() : null;
        String avatar = revealed ? profile.avatarUrl() : null;
        Boolean online = revealed ? user.getIsOnline() : null;

        return new ConversationResponse.GroupMemberInfo(
                user.getId().toString(),
                name,
                avatar,
                online,
                cp.getRole() != null ? cp.getRole().name() : GroupRole.MEMBER.name(),
                cp.getJoinedAt(),
                user.getPublicId(),
                trustStatus
        );
    }
}
