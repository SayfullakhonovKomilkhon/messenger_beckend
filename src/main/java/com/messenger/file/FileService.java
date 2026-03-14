package com.messenger.file;

import com.messenger.common.exception.AppException;
import com.messenger.file.dto.FileUploadResponse;
import org.apache.tika.Tika;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@ConditionalOnBean(S3Client.class)
public class FileService {

    private static final Logger log = LoggerFactory.getLogger(FileService.class);

    private static final Set<String> ALLOWED_MIMES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "application/pdf", "audio/mpeg", "audio/ogg", "video/mp4"
    );

    private static final Map<String, String> MIME_TO_EXT = Map.of(
            "image/jpeg", ".jpg",
            "image/png", ".png",
            "image/gif", ".gif",
            "image/webp", ".webp",
            "application/pdf", ".pdf",
            "audio/mpeg", ".mp3",
            "audio/ogg", ".ogg",
            "video/mp4", ".mp4"
    );

    private final S3Client s3Client;
    private final R2Config r2Config;
    private final Tika tika = new Tika();
    private final long maxFileSizeBytes;

    public FileService(S3Client s3Client,
                       R2Config r2Config,
                       @Value("${file.max-size-bytes}") long maxFileSizeBytes) {
        this.s3Client = s3Client;
        this.r2Config = r2Config;
        this.maxFileSizeBytes = maxFileSizeBytes;
    }

    public FileUploadResponse upload(MultipartFile file) {
        if (file.getSize() > maxFileSizeBytes) {
            throw new AppException("File size exceeds the maximum allowed limit", HttpStatus.PAYLOAD_TOO_LARGE);
        }

        String mime;
        byte[] bytes;
        try {
            bytes = file.getBytes();
            mime = tika.detect(bytes);
        } catch (IOException e) {
            throw new AppException("Failed to read file", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        if (!ALLOWED_MIMES.contains(mime)) {
            throw new AppException("Unsupported file type: " + mime, HttpStatus.UNSUPPORTED_MEDIA_TYPE);
        }

        String extension = MIME_TO_EXT.getOrDefault(mime, "");
        String fileId = UUID.randomUUID().toString();
        String objectKey = fileId + extension;

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(r2Config.getBucketName())
                .key(objectKey)
                .contentType(mime)
                .build();

        s3Client.putObject(putRequest, RequestBody.fromBytes(bytes));

        String fileUrl = r2Config.getPublicUrl() + "/" + objectKey;
        log.info("File uploaded: {} ({})", fileId, mime);

        return new FileUploadResponse(fileId, fileUrl, mime, file.getSize());
    }
}
