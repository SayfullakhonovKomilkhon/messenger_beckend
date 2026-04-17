package com.messenger.e2ee.repository;

import com.messenger.e2ee.entity.PreKeyEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;
import java.util.UUID;

public interface PreKeyRepository extends JpaRepository<PreKeyEntity, UUID> {
    Optional<PreKeyEntity> findFirstByUserIdAndUsedFalse(UUID userId);
    long countByUserIdAndUsedFalse(UUID userId);

    /**
     * Force immediate DELETE flush so a follow-up INSERT with the same
     * (user_id, key_id) does not violate the unique constraint — JPA's
     * default action ordering flushes inserts before deletes otherwise.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM PreKeyEntity p WHERE p.userId = :userId")
    void deleteAllByUserId(UUID userId);
}
