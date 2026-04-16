package com.messenger.user.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {

    private static final String PUBLIC_ID_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int PUBLIC_ID_LENGTH = 8;
    private static final SecureRandom RANDOM = new SecureRandom();

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "public_id", nullable = false, unique = true, length = 8)
    private String publicId;

    @Column(nullable = false, unique = true, length = 20)
    private String phone;

    @Column(nullable = false, unique = true, length = 100)
    private String name;

    @Column(unique = true, length = 50)
    private String username;

    @Column(name = "ai_name", length = 100)
    private String aiName;

    @Column(name = "avatar_url")
    private String avatarUrl;

    @Column(name = "wallet_address", length = 130)
    private String walletAddress;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "fcm_token")
    private String fcmToken;

    private String bio;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private String settings = "{}";

    @Column(name = "is_bot")
    private Boolean isBot = false;

    @Column(name = "is_online")
    private Boolean isOnline = false;

    @Column(name = "last_seen_at")
    private LocalDateTime lastSeenAt;

    @Column(name = "active_device_id")
    private String activeDeviceId;

    @Column(name = "device_last_active")
    private LocalDateTime deviceLastActive;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (publicId == null || publicId.isBlank()) {
            publicId = generatePublicId();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    public static String generatePublicId() {
        StringBuilder sb = new StringBuilder(PUBLIC_ID_LENGTH);
        for (int i = 0; i < PUBLIC_ID_LENGTH; i++) {
            sb.append(PUBLIC_ID_CHARS.charAt(RANDOM.nextInt(PUBLIC_ID_CHARS.length())));
        }
        return sb.toString();
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getPublicId() { return publicId; }
    public void setPublicId(String publicId) { this.publicId = publicId; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getAiName() { return aiName; }
    public void setAiName(String aiName) { this.aiName = aiName; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getWalletAddress() { return walletAddress; }
    public void setWalletAddress(String walletAddress) { this.walletAddress = walletAddress; }

    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }

    public String getFcmToken() { return fcmToken; }
    public void setFcmToken(String fcmToken) { this.fcmToken = fcmToken; }

    public Boolean getIsBot() { return isBot; }
    public void setIsBot(Boolean isBot) { this.isBot = isBot; }

    public Boolean getIsOnline() { return isOnline; }
    public void setIsOnline(Boolean isOnline) { this.isOnline = isOnline; }

    public String getBio() { return bio; }
    public void setBio(String bio) { this.bio = bio; }

    public String getSettings() { return settings; }
    public void setSettings(String settings) { this.settings = settings; }

    public LocalDateTime getLastSeenAt() { return lastSeenAt; }
    public void setLastSeenAt(LocalDateTime lastSeenAt) { this.lastSeenAt = lastSeenAt; }

    public String getActiveDeviceId() { return activeDeviceId; }
    public void setActiveDeviceId(String activeDeviceId) { this.activeDeviceId = activeDeviceId; }

    public LocalDateTime getDeviceLastActive() { return deviceLastActive; }
    public void setDeviceLastActive(LocalDateTime deviceLastActive) { this.deviceLastActive = deviceLastActive; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
