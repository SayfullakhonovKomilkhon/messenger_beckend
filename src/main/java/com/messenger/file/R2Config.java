package com.messenger.file;

import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

import java.net.URI;

@Configuration
@ConfigurationProperties(prefix = "r2")
@ConditionalOnExpression("!'${r2.endpoint:}'.trim().isEmpty()")
public class R2Config {

    private String endpoint;
    private String accessKeyId;
    private String secretAccessKey;
    private String bucketName;
    private String publicUrl;

    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretAccessKey)
                ))
                .region(Region.US_EAST_1)
                .forcePathStyle(true)
                .build();
    }

    public String getEndpoint() { return endpoint; }
    public void setEndpoint(String endpoint) { this.endpoint = endpoint; }

    public String getAccessKeyId() { return accessKeyId; }
    public void setAccessKeyId(String accessKeyId) { this.accessKeyId = accessKeyId; }

    public String getSecretAccessKey() { return secretAccessKey; }
    public void setSecretAccessKey(String secretAccessKey) { this.secretAccessKey = secretAccessKey; }

    public String getBucketName() { return bucketName; }
    public void setBucketName(String bucketName) { this.bucketName = bucketName; }

    public String getPublicUrl() { return publicUrl; }
    public void setPublicUrl(String publicUrl) { this.publicUrl = publicUrl; }
}
