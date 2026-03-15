package com.messenger.common.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @Value("${fcm.project-id:}")
    private String projectId;

    @Value("${fcm.client-email:}")
    private String clientEmail;

    @Value("${fcm.client-id:}")
    private String clientId;

    @Value("${fcm.private-key:}")
    private String privateKey;

    @Value("${fcm.private-key-id:}")
    private String privateKeyId;

    @Bean
    public FirebaseMessaging firebaseMessaging() {
        if (projectId.isBlank() || clientEmail.isBlank() || privateKey.isBlank()
                || clientId.isBlank() || privateKeyId.isBlank()) {
            log.warn("FCM credentials not configured (need FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_CLIENT_ID, FCM_PRIVATE_KEY, FCM_PRIVATE_KEY_ID) — push disabled");
            return null;
        }

        try {
            String keyWithNewlines = privateKey.replace("\\n", "\n");
            Map<String, String> creds = Map.of(
                    "type", "service_account",
                    "project_id", projectId,
                    "private_key_id", privateKeyId,
                    "private_key", keyWithNewlines,
                    "client_email", clientEmail,
                    "client_id", clientId,
                    "token_uri", "https://oauth2.googleapis.com/token"
            );
            String serviceAccountJson = new ObjectMapper().writeValueAsString(creds);

            GoogleCredentials credentials = GoogleCredentials.fromStream(
                    new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8))
            );

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .setProjectId(projectId)
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }

            log.info("Firebase initialized for project: {}", projectId);
            return FirebaseMessaging.getInstance();
        } catch (IOException e) {
            log.error("Failed to initialize Firebase: {}", e.getMessage());
            return null;
        }
    }
}
