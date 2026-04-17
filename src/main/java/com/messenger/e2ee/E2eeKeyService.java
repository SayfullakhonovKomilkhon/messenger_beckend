package com.messenger.e2ee;

import com.messenger.common.exception.AppException;
import com.messenger.e2ee.dto.*;
import com.messenger.e2ee.entity.IdentityKeyEntity;
import com.messenger.e2ee.entity.PreKeyEntity;
import com.messenger.e2ee.entity.SignedPreKeyEntity;
import com.messenger.e2ee.repository.IdentityKeyRepository;
import com.messenger.e2ee.repository.PreKeyRepository;
import com.messenger.e2ee.repository.SignedPreKeyRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Base64;
import java.util.UUID;

@Service
public class E2eeKeyService {

    private static final Logger log = LoggerFactory.getLogger(E2eeKeyService.class);

    private final IdentityKeyRepository identityKeyRepo;
    private final SignedPreKeyRepository signedPreKeyRepo;
    private final PreKeyRepository preKeyRepo;

    public E2eeKeyService(IdentityKeyRepository identityKeyRepo,
                          SignedPreKeyRepository signedPreKeyRepo,
                          PreKeyRepository preKeyRepo) {
        this.identityKeyRepo = identityKeyRepo;
        this.signedPreKeyRepo = signedPreKeyRepo;
        this.preKeyRepo = preKeyRepo;
    }

    @Transactional
    public void registerKeys(UUID userId, RegisterKeysRequest request) {
        IdentityKeyEntity identity = identityKeyRepo.findById(userId).orElse(null);
        if (identity == null) {
            identity = new IdentityKeyEntity();
            identity.setUserId(userId);
        }
        identity.setRegistrationId(request.registrationId());
        identity.setIdentityPublicKey(Base64.getDecoder().decode(request.identityPublicKey()));
        identityKeyRepo.save(identity);

        signedPreKeyRepo.deleteAllByUserId(userId);
        SignedPreKeyEntity spk = new SignedPreKeyEntity();
        spk.setUserId(userId);
        spk.setKeyId(request.signedPreKey().keyId());
        spk.setPublicKey(Base64.getDecoder().decode(request.signedPreKey().publicKey()));
        spk.setSignature(Base64.getDecoder().decode(request.signedPreKey().signature()));
        signedPreKeyRepo.save(spk);

        for (RegisterKeysRequest.PreKeyData pk : request.preKeys()) {
            PreKeyEntity preKey = new PreKeyEntity();
            preKey.setUserId(userId);
            preKey.setKeyId(pk.keyId());
            preKey.setPublicKey(Base64.getDecoder().decode(pk.publicKey()));
            preKeyRepo.save(preKey);
        }

        log.info("User {} registered E2EE keys: {} pre-keys uploaded", userId, request.preKeys().size());
    }

    @Transactional
    public void replenishPreKeys(UUID userId, ReplenishPreKeysRequest request) {
        if (!identityKeyRepo.existsById(userId)) {
            throw new AppException("Identity key not registered. Call /keys/register first.", HttpStatus.BAD_REQUEST);
        }
        for (RegisterKeysRequest.PreKeyData pk : request.preKeys()) {
            PreKeyEntity preKey = new PreKeyEntity();
            preKey.setUserId(userId);
            preKey.setKeyId(pk.keyId());
            preKey.setPublicKey(Base64.getDecoder().decode(pk.publicKey()));
            preKeyRepo.save(preKey);
        }
        log.info("User {} replenished {} pre-keys", userId, request.preKeys().size());
    }

    @Transactional
    public PreKeyBundleResponse getPreKeyBundle(UUID targetUserId) {
        IdentityKeyEntity identity = identityKeyRepo.findById(targetUserId)
                .orElseThrow(() -> new AppException("User has no E2EE keys", HttpStatus.NOT_FOUND));

        SignedPreKeyEntity spk = signedPreKeyRepo.findTopByUserIdOrderByCreatedAtDesc(targetUserId)
                .orElseThrow(() -> new AppException("User has no signed pre-key", HttpStatus.NOT_FOUND));

        PreKeyEntity preKey = preKeyRepo.findFirstByUserIdAndUsedFalse(targetUserId).orElse(null);
        Integer preKeyId = null;
        String preKeyPublic = null;
        if (preKey != null) {
            preKeyId = preKey.getKeyId();
            preKeyPublic = Base64.getEncoder().encodeToString(preKey.getPublicKey());
            preKey.setUsed(true);
            preKeyRepo.save(preKey);
        }

        return new PreKeyBundleResponse(
                targetUserId.toString(),
                identity.getRegistrationId(),
                Base64.getEncoder().encodeToString(identity.getIdentityPublicKey()),
                spk.getKeyId(),
                Base64.getEncoder().encodeToString(spk.getPublicKey()),
                Base64.getEncoder().encodeToString(spk.getSignature()),
                preKeyId,
                preKeyPublic
        );
    }

    public long getPreKeyCount(UUID userId) {
        return preKeyRepo.countByUserIdAndUsedFalse(userId);
    }

    public boolean hasKeys(UUID userId) {
        return identityKeyRepo.existsById(userId);
    }

    /**
     * Lightweight identity-only lookup. Does NOT consume a one-time pre-key.
     * Used by senders to detect when a recipient rotated their identity (e.g. reinstall)
     * so they can rebuild their Signal session and avoid sending messages encrypted
     * with stale session state.
     */
    public IdentityKeyResponse getIdentity(UUID targetUserId) {
        IdentityKeyEntity identity = identityKeyRepo.findById(targetUserId)
                .orElseThrow(() -> new AppException("User has no E2EE keys", HttpStatus.NOT_FOUND));
        return new IdentityKeyResponse(
                targetUserId.toString(),
                identity.getRegistrationId(),
                Base64.getEncoder().encodeToString(identity.getIdentityPublicKey())
        );
    }
}
