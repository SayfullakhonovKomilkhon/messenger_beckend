package com.messenger.e2ee;

import com.messenger.e2ee.dto.*;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/keys")
public class E2eeKeyController {

    private final E2eeKeyService keyService;

    public E2eeKeyController(E2eeKeyService keyService) {
        this.keyService = keyService;
    }

    @PostMapping("/register")
    public ResponseEntity<Void> registerKeys(Principal principal,
                                              @Valid @RequestBody RegisterKeysRequest request) {
        UUID userId = UUID.fromString(principal.getName());
        keyService.registerKeys(userId, request);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/prekeys")
    public ResponseEntity<Void> replenishPreKeys(Principal principal,
                                                  @Valid @RequestBody ReplenishPreKeysRequest request) {
        UUID userId = UUID.fromString(principal.getName());
        keyService.replenishPreKeys(userId, request);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/bundle/{userId}")
    public ResponseEntity<PreKeyBundleResponse> getBundle(@PathVariable UUID userId) {
        return ResponseEntity.ok(keyService.getPreKeyBundle(userId));
    }

    @GetMapping("/count")
    public ResponseEntity<PreKeyCountResponse> getPreKeyCount(Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        return ResponseEntity.ok(new PreKeyCountResponse(keyService.getPreKeyCount(userId)));
    }

    @GetMapping("/check/{userId}")
    public ResponseEntity<Boolean> hasKeys(@PathVariable UUID userId) {
        return ResponseEntity.ok(keyService.hasKeys(userId));
    }

    /**
     * Returns ONLY the remote identity key + registrationId without consuming a
     * one-time pre-key. Allows senders to verify the recipient's current identity
     * and detect client reinstalls (identity rotation) before encrypting.
     */
    @GetMapping("/identity/{userId}")
    public ResponseEntity<IdentityKeyResponse> getIdentity(@PathVariable UUID userId) {
        return ResponseEntity.ok(keyService.getIdentity(userId));
    }
}
