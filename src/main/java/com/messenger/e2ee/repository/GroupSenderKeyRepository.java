package com.messenger.e2ee.repository;

import com.messenger.e2ee.entity.GroupSenderKeyEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface GroupSenderKeyRepository extends JpaRepository<GroupSenderKeyEntity, UUID> {

    List<GroupSenderKeyEntity> findByRecipientIdAndConsumedFalse(UUID recipientId);

    List<GroupSenderKeyEntity> findByGroupIdAndRecipientIdAndConsumedFalse(UUID groupId, UUID recipientId);

    @Modifying
    @Query("UPDATE GroupSenderKeyEntity g SET g.consumed = true " +
           "WHERE g.recipientId = :recipientId AND g.groupId = :groupId AND g.senderId = :senderId")
    void markConsumed(UUID recipientId, UUID groupId, UUID senderId);

    @Modifying
    @Query("DELETE FROM GroupSenderKeyEntity g WHERE g.groupId = :groupId AND g.senderId = :userId")
    void deleteBySenderInGroup(UUID groupId, UUID userId);

    @Modifying
    @Query("DELETE FROM GroupSenderKeyEntity g WHERE g.groupId = :groupId AND g.recipientId = :userId")
    void deleteByRecipientInGroup(UUID groupId, UUID userId);

    @Modifying
    @Query("DELETE FROM GroupSenderKeyEntity g WHERE g.groupId = :groupId")
    void deleteAllByGroupId(UUID groupId);

    @Modifying
    @Query("DELETE FROM GroupSenderKeyEntity g WHERE g.senderId = :userId")
    void deleteAllBySender(UUID userId);

    @Modifying
    @Query("DELETE FROM GroupSenderKeyEntity g WHERE g.recipientId = :userId")
    void deleteAllByRecipient(UUID userId);
}
