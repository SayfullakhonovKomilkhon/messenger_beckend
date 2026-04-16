package com.messenger.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);

    private final SecretKey secretKey;
    private final long accessExpiresSeconds;
    private final long refreshExpiresSeconds;

    public JwtService(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-expires}") long accessExpiresSeconds,
            @Value("${jwt.refresh-expires}") long refreshExpiresSeconds
    ) {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessExpiresSeconds = accessExpiresSeconds;
        this.refreshExpiresSeconds = refreshExpiresSeconds;
    }

    public String generateAccessToken(String userId) {
        return generateAccessToken(userId, null);
    }

    public String generateAccessToken(String userId, String deviceId) {
        return buildToken(userId, accessExpiresSeconds, "access", deviceId);
    }

    public String generateRefreshToken(String userId) {
        return buildToken(userId, refreshExpiresSeconds, "refresh");
    }

    public String extractUserId(String token) {
        return parseClaims(token).getSubject();
    }

    public String extractDeviceId(String token) {
        try {
            return parseClaims(token).get("deviceId", String.class);
        } catch (Exception e) {
            return null;
        }
    }

    public boolean isTokenValid(String token) {
        try {
            Claims claims = parseClaims(token);
            return !claims.getExpiration().before(new Date());
        } catch (JwtException | IllegalArgumentException e) {
            log.debug("Invalid JWT token: {}", e.getMessage());
            return false;
        }
    }

    public long getRemainingTtlSeconds(String token) {
        try {
            Claims claims = parseClaims(token);
            long expirationMs = claims.getExpiration().getTime();
            long nowMs = System.currentTimeMillis();
            return Math.max(0, (expirationMs - nowMs) / 1000);
        } catch (JwtException | IllegalArgumentException e) {
            return 0;
        }
    }

    public long getRefreshExpiresSeconds() {
        return refreshExpiresSeconds;
    }

    private String buildToken(String userId, long expiresSeconds, String type) {
        return buildToken(userId, expiresSeconds, type, null);
    }

    private String buildToken(String userId, long expiresSeconds, String type, String deviceId) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + expiresSeconds * 1000);
        var builder = Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(userId)
                .claim("type", type)
                .issuedAt(now)
                .expiration(expiry)
                .signWith(secretKey);
        
        if (deviceId != null) {
            builder.claim("deviceId", deviceId);
        }
        
        return builder.compact();
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
