package com.messenger.file;

import com.messenger.common.exception.AppException;
import com.messenger.file.dto.FileUploadResponse;
import org.apache.tika.Tika;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class LocalFileService {

    private static final Logger log = LoggerFactory.getLogger(LocalFileService.class);

    private static final Set<String> ALLOWED_MIMES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "application/pdf", "audio/mpeg", "audio/ogg", "audio/mp4",
            "audio/aac", "audio/x-aac", "audio/x-m4a",
            "video/mp4", "video/quicktime"
    );

    private static final Map<String, String> MIME_TO_EXT = Map.ofEntries(
            Map.entry("image/jpeg", ".jpg"),
            Map.entry("image/png", ".png"),
            Map.entry("image/gif", ".gif"),
            Map.entry("image/webp", ".webp"),
            Map.entry("application/pdf", ".pdf"),
            Map.entry("audio/mpeg", ".mp3"),
            Map.entry("audio/ogg", ".ogg"),
            Map.entry("audio/mp4", ".m4a"),
            Map.entry("audio/aac", ".aac"),
            Map.entry("audio/x-aac", ".aac"),
            Map.entry("audio/x-m4a", ".m4a"),
            Map.entry("video/mp4", ".mp4"),
            Map.entry("video/quicktime", ".mov")
    );

    private final Tika tika = new Tika();
    private final long maxFileSizeBytes;
    private final Path uploadDir;
    private final String publicBaseUrl;

    public LocalFileService(
            @Value("${file.max-size-bytes:104857600}") long maxFileSizeBytes,
            @Value("${file.upload-dir:uploads}") String uploadDir,
            @Value("${file.public-base-url:http://localhost:3000/uploads}") String publicBaseUrl) {
        this.maxFileSizeBytes = maxFileSizeBytes;
        this.uploadDir = Paths.get(uploadDir);
        this.publicBaseUrl = publicBaseUrl;
        try {
            Files.createDirectories(this.uploadDir);
        } catch (IOException e) {
            log.error("Failed to create upload directory: {}", e.getMessage());
        }
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
        String fileName = fileId + extension;

        try {
            Path filePath = uploadDir.resolve(fileName);
            Files.write(filePath, bytes);
        } catch (IOException e) {
            throw new AppException("Failed to save file", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        String fileUrl = publicBaseUrl + "/" + fileName;
        log.info("File uploaded locally: {} ({})", fileId, mime);

        return new FileUploadResponse(fileId, fileUrl, mime, file.getSize());
    }
}
