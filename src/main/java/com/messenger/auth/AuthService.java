package com.messenger.auth;

import com.messenger.auth.dto.*;
import com.messenger.auth.entity.RefreshToken;
import com.messenger.common.cache.CacheService;
import com.messenger.common.exception.AppException;
import com.messenger.common.security.JwtService;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final String BLACKLIST_PREFIX = "blacklist:";

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final CacheService cacheService;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       JwtService jwtService,
                       PasswordEncoder passwordEncoder,
                       CacheService cacheService) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
        this.cacheService = cacheService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByPhone(request.phone())) {
            throw new AppException("Phone number already registered", HttpStatus.CONFLICT);
        }

        User user = new User();
        user.setPhone(request.phone());
        user.setName(request.name());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setPublicId(generateUniquePublicId());
        user.setWalletAddress(generateWalletAddress());
        user = userRepository.save(user);

        log.info("User registered: {} (publicId: {})", user.getId(), user.getPublicId());
        return buildAuthResponse(user, true);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        return login(request, null);
    }

    @Transactional
    public AuthResponse login(LoginRequest request, String deviceId) {
        var optUser = userRepository.findByPhone(request.phone());

        if (optUser.isPresent()) {
            User user = optUser.get();
            if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
                throw new AppException("Invalid credentials", HttpStatus.UNAUTHORIZED);
            }
            
            // Generate device ID if not provided
            if (deviceId == null || deviceId.isBlank()) {
                deviceId = java.util.UUID.randomUUID().toString();
            }
            
            // Update active device
            user.setActiveDeviceId(deviceId);
            user.setDeviceLastActive(LocalDateTime.now());
            userRepository.save(user);
            
            log.info("User logged in: {} (device: {})", user.getId(), deviceId);
            return buildAuthResponse(user, false, deviceId);
        }

        User user = new User();
        user.setPhone(request.phone());
        user.setName(request.phone());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setPublicId(generateUniquePublicId());
        user.setWalletAddress(generateWalletAddress());
        
        // Generate device ID if not provided
        if (deviceId == null || deviceId.isBlank()) {
            deviceId = java.util.UUID.randomUUID().toString();
        }
        user.setActiveDeviceId(deviceId);
        user.setDeviceLastActive(LocalDateTime.now());
        
        user = userRepository.save(user);
        log.info("Auto-registered and logged in: {} (device: {})", user.getId(), deviceId);
        return buildAuthResponse(user, true, deviceId);
    }

    @Transactional
    public TokenResponse refresh(RefreshRequest request) {
        String token = request.refreshToken();

        if (!jwtService.isTokenValid(token)) {
            throw new AppException("Invalid refresh token", HttpStatus.UNAUTHORIZED);
        }

        if (cacheService.exists(BLACKLIST_PREFIX + token)) {
            throw new AppException("Token has been revoked", HttpStatus.UNAUTHORIZED);
        }

        RefreshToken stored = refreshTokenRepository.findByToken(token)
                .orElseThrow(() -> new AppException("Refresh token not found", HttpStatus.UNAUTHORIZED));

        String userId = jwtService.extractUserId(token);

        refreshTokenRepository.deleteByToken(token);

        String newAccess = jwtService.generateAccessToken(userId);
        String newRefresh = jwtService.generateRefreshToken(userId);
        saveRefreshToken(stored.getUser(), newRefresh);

        log.info("Tokens refreshed for user: {}", userId);
        return new TokenResponse(newAccess, newRefresh);
    }

    @Transactional
    public Map<String, Boolean> logout(String accessToken, LogoutRequest request) {
        String refreshToken = request.refreshToken();

        long ttl = jwtService.getRemainingTtlSeconds(refreshToken);
        if (ttl > 0) {
            cacheService.set(BLACKLIST_PREFIX + refreshToken, "revoked", Duration.ofSeconds(ttl));
        }

        refreshTokenRepository.deleteByToken(refreshToken);

        if (accessToken != null) {
            long accessTtl = jwtService.getRemainingTtlSeconds(accessToken);
            if (accessTtl > 0) {
                cacheService.set(BLACKLIST_PREFIX + accessToken, "revoked", Duration.ofSeconds(accessTtl));
            }
        }

        log.info("User logged out");
        return Map.of("success", true);
    }

    private AuthResponse buildAuthResponse(User user, boolean isNewRegistration) {
        return buildAuthResponse(user, isNewRegistration, null);
    }

    private AuthResponse buildAuthResponse(User user, boolean isNewRegistration, String deviceId) {
        String userId = user.getId().toString();
        String accessToken = jwtService.generateAccessToken(userId, deviceId);
        String refreshToken = jwtService.generateRefreshToken(userId);
        saveRefreshToken(user, refreshToken);

        AuthResponse.UserInfo userInfo = new AuthResponse.UserInfo(
                userId,
                user.getPublicId(),
                user.getName(),
                user.getPhone(),
                user.getAvatarUrl(),
                isNewRegistration ? user.getWalletAddress() : null
        );
        return new AuthResponse(accessToken, refreshToken, userInfo);
    }

    private String generateWalletAddress() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        StringBuilder hex = new StringBuilder("0x");
        for (byte b : bytes) hex.append(String.format("%02x", b));
        return hex.toString();
    }

    private String generateUniquePublicId() {
        for (int i = 0; i < 10; i++) {
            String candidate = User.generatePublicId();
            if (!userRepository.existsByPublicId(candidate)) {
                return candidate;
            }
        }
        throw new AppException("Failed to generate unique public ID", HttpStatus.INTERNAL_SERVER_ERROR);
    }

    private void saveRefreshToken(User user, String tokenStr) {
        RefreshToken rt = new RefreshToken();
        rt.setUser(user);
        rt.setToken(tokenStr);
        rt.setExpiresAt(LocalDateTime.now().plusSeconds(jwtService.getRefreshExpiresSeconds()));
        refreshTokenRepository.save(rt);
    }
}
