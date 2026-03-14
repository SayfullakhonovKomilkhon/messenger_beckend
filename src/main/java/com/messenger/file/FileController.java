package com.messenger.file;

import com.messenger.file.dto.FileUploadResponse;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.nio.file.Path;
import java.nio.file.Paths;

@RestController
@Tag(name = "Files", description = "Загрузка файлов (изображения, видео, аудио, PDF)")
public class FileController {

    private final LocalFileService localFileService;

    public FileController(LocalFileService localFileService) {
        this.localFileService = localFileService;
    }

    @Operation(summary = "Загрузить файл")
    @PostMapping("/api/v1/files/upload")
    public ResponseEntity<FileUploadResponse> upload(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(localFileService.upload(file));
    }

    @GetMapping("/uploads/{filename}")
    public ResponseEntity<Resource> serveFile(@PathVariable String filename) {
        try {
            if (filename.contains("..") || filename.contains("/")) {
                return ResponseEntity.badRequest().build();
            }
            Path filePath = Paths.get("uploads").resolve(filename).toAbsolutePath().normalize();
            Resource resource = new UrlResource(filePath.toUri());
            if (resource.exists() && resource.isReadable()) {
                String contentType = "application/octet-stream";
                String lower = filename.toLowerCase();
                if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) contentType = "image/jpeg";
                else if (lower.endsWith(".png")) contentType = "image/png";
                else if (lower.endsWith(".gif")) contentType = "image/gif";
                else if (lower.endsWith(".webp")) contentType = "image/webp";
                else if (lower.endsWith(".mp3")) contentType = "audio/mpeg";
                else if (lower.endsWith(".ogg")) contentType = "audio/ogg";
                else if (lower.endsWith(".m4a")) contentType = "audio/mp4";
                else if (lower.endsWith(".aac")) contentType = "audio/aac";
                else if (lower.endsWith(".mp4")) contentType = "video/mp4";
                else if (lower.endsWith(".mov")) contentType = "video/quicktime";
                else if (lower.endsWith(".pdf")) contentType = "application/pdf";

                return ResponseEntity.ok()
                        .contentType(MediaType.parseMediaType(contentType))
                        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000")
                        .body(resource);
            }
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }
}
