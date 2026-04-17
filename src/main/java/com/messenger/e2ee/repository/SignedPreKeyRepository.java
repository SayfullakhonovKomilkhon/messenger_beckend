package com.messenger.e2ee.repository;

import com.messenger.e2ee.entity.SignedPreKeyEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;
import java.util.UUID;

public interface SignedPreKeyRepository extends JpaRepository<SignedPreKeyEntity, UUID> {
    Optional<SignedPreKeyEntity> findTopByUserIdOrderByCreatedAtDesc(UUID userId);

    /**
     * Force immediate DELETE flush + persistence context clear so a follow-up
     * INSERT of a row with the same (user_id, key_id) does not race against
     * Hibernate's action-queue reordering (inserts-before-deletes default),
     * which previously caused
     * {@code duplicate key value violates unique constraint "e2ee_signed_pre_keys_user_id_key_id_key"}
     * during key rotation.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM SignedPreKeyEntity s WHERE s.userId = :userId")
    void deleteAllByUserId(UUID userId);
}
