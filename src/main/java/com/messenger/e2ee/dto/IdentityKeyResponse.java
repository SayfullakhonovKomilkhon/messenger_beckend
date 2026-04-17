package com.messenger.e2ee.dto;

public record IdentityKeyResponse(
        String userId,
        int registrationId,
        String identityPublicKey
) {}
