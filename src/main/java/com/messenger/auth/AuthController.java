package com.messenger.auth;

import com.messenger.auth.dto.*;
import com.messenger.common.exception.AppException;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Auth", description = "Регистрация, логин, обновление токенов, выход")
public class AuthController {

    private final AuthService authService;
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @Operation(summary = "Регистрация", description = "Создание нового пользователя. Возвращает JWT токены.")
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@RequestBody @Valid RegisterRequest request,
                                                  HttpServletRequest httpRequest) {
        consumeToken(httpRequest);
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @Operation(summary = "Логин", description = "Авторизация по телефону и паролю. Возвращает JWT токены.")
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @RequestBody @Valid LoginRequest request,
            @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
            HttpServletRequest httpRequest) {
        consumeToken(httpRequest);
        return ResponseEntity.ok(authService.login(request, deviceId));
    }

    @Operation(summary = "Обновление токена", description = "Обмен refresh токена на новую пару access + refresh.")
    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(@RequestBody @Valid RefreshRequest request,
                                                  HttpServletRequest httpRequest) {
        consumeToken(httpRequest);
        return ResponseEntity.ok(authService.refresh(request));
    }

    @Operation(summary = "Выход", description = "Инвалидирует access и refresh токены.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/logout")
    public ResponseEntity<Map<String, Boolean>> logout(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody @Valid LogoutRequest request,
            HttpServletRequest httpRequest) {
        consumeToken(httpRequest);
        String accessToken = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            accessToken = authHeader.substring(7);
        }
        return ResponseEntity.ok(authService.logout(accessToken, request));
    }

    private void consumeToken(HttpServletRequest request) {
        String ip = extractIp(request);
        Bucket bucket = buckets.computeIfAbsent(ip, k -> createBucket());
        if (!bucket.tryConsume(1)) {
            throw new AppException("Too many requests. Try again later.", HttpStatus.TOO_MANY_REQUESTS);
        }
    }

    private Bucket createBucket() {
        Bandwidth limit = Bandwidth.classic(5, Refill.intervally(5, Duration.ofMinutes(1)));
        return Bucket.builder().addLimit(limit).build();
    }

    private String extractIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
